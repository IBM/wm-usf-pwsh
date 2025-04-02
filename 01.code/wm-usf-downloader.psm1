# This class encapsulates the functionality to download binaries from webMethods download center
Using module "./wm-usf-audit.psm1"
Using module "./wm-usf-result.psm1"
class WMUSF_Downloader {
  static [WMUSF_Downloader] $Instance = [WMUSF_Downloader]::GetInstance()
  hidden static [WMUSF_Downloader] $_instance = [WMUSF_Downloader]::new()
  hidden [WMUSF_Audit] $audit
  hidden [string] $cacheDir
  [string] $updateManagerHome
  [string] $onlineMode
  [string] $currentInstallerBinary
  [string] $currentUpdateManagerBootstrapBinary

  # Download constants
  #TODO check if Set-Variable test -Option Constant -Value 100 approach is better
  hidden static [string] $defaultInstallerDownloadURL = "https://empowersdc.softwareag.com/ccinstallers/SoftwareAGInstaller20240626-w64.exe"
  hidden static [string] $defaultInstallerFileName = "SoftwareAGInstaller20240626-w64.exe"
  hidden static [string] $defaultInstallerFileHash = "cdfff7e2f420d182a4741d90e4ee02eb347db28bdaa4969caca0a3ac1146acd3"
  hidden static [string] $defaultInstallerFileHashAlgorithm = "SHA256"

  hidden static [string] $defaultWmumBootstrapDownloadURL = "https://empowersdc.softwareag.com/ccinstallers/SAGUpdateManagerInstaller-windows-x64-11.0.0.0000-0823.exe"
  hidden static [string] $defaultWmumBootstrapFileName = "SAGUpdateManagerInstaller-windows-x64-11.0.0.0000-0823.exe"
  hidden static [string] $defaultWmumBootstrapFileHash = "53d283ba083a3535dd12831aa05ab0e8a590ff577053ab9eebedabe5a499fbfa"
  hidden static [string] $defaultWmumBootstrapFileHashAlgorithm = "SHA256"

  hidden static [string] $defaultCceBootstrapDownloadURL = "https://empowersdc.softwareag.com/ccinstallers/cc-def-10.15-fix8-w64.bat"
  hidden static [string] $defaultCceBootstrapFileName = "cc-def-10.15-fix8-w64.bat"
  hidden static [string] $defaultCceBootstrapFileHash = "728488F53CFD54B5835205F960C6501FE96B14408529EAA048441BA711B8F614"
  hidden static [string] $defaultCceBootstrapFileHashAlgorithm = "SHA256"

  [Guid] $WMUSF_DownloaderTarget = [Guid]::NewGuid()

  hidden WMUSF_Downloader() {
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.cacheDir = ${env:WMUSF_DOWNLOADER_CACHE_DIR} ?? ([System.IO.Path]::GetTempPath() + "WMUSF_CACHE")
    $this.updateManagerHome = ${env:WMUSF_UPD_MGR_HOME} ?? [System.IO.Path]::GetTempPath() + 'WmUpdateMgr'
    $this.currentInstallerBinary = ${env:WMUSF_INSTALLER_BINARY} ?? "N/A"
    $this.currentUpdateManagerBootstrapBinary = ${env:WMUSF_UPD_MGR_BOOTSTRAP_BINARY} ?? "N/A"
    $this.onlineMode = ${env:WMUSF_DOWNLOADER_ONLINE_MODE} ?? 'true'
    $this.audit.LogI("WMUSF_Downloader initialized")
    $this.audit.LogI("WMUSF_Downloader CacheDir: " + $this.cacheDir)
    $this.audit.LogI("WMUSF_Downloader Update Manager Home: " + $this.updateManagerHome)
  }


  hidden static [WMUSF_Downloader] GetInstance() {
    return [WMUSF_Downloader]::_instance
  }

  [WMUSF_Result] GetWebFileWithChecksumVerification(
    [string]$url,
    [string]$fullOutputDirectoryPath,
    [string]$fileName,
    [string]$expectedHash,
    [string]$hashAlgorithm
  ) {

    $r = [WMUSF_Result]::new()
    
    $this.audit.LogI("Downloading file ${fullOutputDirectoryPath}" + [IO.Path]::DirectorySeparatorChar + "${fileName}")
    $this.audit.LogI("From ${url}")
    
    # assure destination folder
    $this.audit.LogD("Eventually create folder ${fullOutputDirectoryPath}...")
    New-Item -Path ${fullOutputDirectoryPath} -ItemType Directory -Force | Out-Null
    $fullFilePath = ${fullOutputDirectoryPath} + [IO.Path]::DirectorySeparatorChar + ${fileName}
    # Download the file
    Invoke-WebRequest -Uri ${url} -OutFile "${fullFilePath}.verify"
  
    # Calculate the SHA256 hash of the downloaded file
    $this.audit.LogD("Guaranteeing ${hashAlgorithm} checksum ${expectedHash}")
    ${fileHash} = Get-FileHash -Path "${fullFilePath}.verify" -Algorithm ${hashAlgorithm}
    $this.audit.LogD("File hash is " + ${fileHash}.Hash.ToString() + " .")
    #Write-Host $fileHash
    # Compare the calculated hash with the expected hash
    $r.Code = 1
    if (${fileHash}.Hash -eq ${expectedHash}) {
      $this.audit.LogD("The file's $hashAlgorithm hash matches the expected hash.")
      $this.audit.LogD("Renaming ${fullFilePath}.verify to ${fullFilePath}")
      Rename-Item -Path "${fullFilePath}.verify" -NewName "${fileName}"
      $r.Code = 0
      $r.Description = "Success"
      $r.PayloadString = ${fileName}
    }
    else {
      Rename-Item -Path "${fullFilePath}.verify" -NewName "${fileName}.dubious"
      $this.audit.LogE("The file's ${hashAlgorithm} hash does not match the expected hash.")
      $this.audit.LogE("Got ${fileHash}.Hash, but expected ${expectedHash}!")
      $r.Code = 2
      $r.Description = "Checksum verification failed"
    }
    $this.audit.LogD("wmUifwCommon|Get-WebFileWithChecksumVerification returns " + $r.Code)
    return ${r}
  }

  [WMUSF_Result] AssureWebFileWithChecksumVerification(
    [string]$url,
    [string]$fullOutputDirectoryPath,
    [string]$fileName,
    [string]$expectedHash
  ) {
    return $this.AssureWebFileWithChecksumVerification(
      $url,
      $fullOutputDirectoryPath,
      $fileName,
      $expectedHash,
      "SHA256"
    )
  }

  [WMUSF_Result] AssureWebFileWithChecksumVerification(
    [string]$url,
    [string]$fullOutputDirectoryPath,
    [string]$fileName,
    [string]$expectedHash,
    [string]$hashAlgorithm
  ) {

    $r = [WMUSF_Result]::new()
    # Calculate the SHA256 hash of the downloaded file
    $fullFilePath = ${fullOutputDirectoryPath} + [IO.Path]::DirectorySeparatorChar + ${fileName}
    $this.audit.LogI("Resolving file $fullFilePath ...")

    # if File exists, just check the checksum
    if (Test-Path $fullFilePath -PathType Leaf) {
      $this.audit.LogD("file $fullFilePath already exists.")
      $fileHash = Get-FileHash -Path $fullFilePath -Algorithm $hashAlgorithm
      $this.audit.LogD("its hash is " + $fileHash.Hash)
      if ($fileHash.Hash -eq $expectedHash) {
        $this.audit.LogI("The file's $hashAlgorithm hash matches the expected hash.")
        $r.Code = 0
        $r.Description = "Success"
        $r.PayloadString = $fullFilePath
        return  $r
      }
      else {
        $this.audit.LogE("The $fullFilePath file's $hashAlgorithm hash does not match the expected hash. Downloaded file renamed")
        $this.audit.LogE("Got " + ${fileHash}.Hash + ", but expected $expectedHash!")
        return  [WMUSF_Result]::GetSimpleResult(9, "Checksum verification failed", $this.audit)
      }
    }
    $this.audit.LogD("file $fullFilePath does not exist. Attempting to download...")
    $r = $this.GetWebFileWithChecksumVerification(
      "$url",
      "$fullOutputDirectoryPath",
      "$fileName",
      "$expectedHash",
      "$hashAlgorithm"
    )
  
    $this.audit.LogD("Resolve-WebFileWithChecksumVerification returns " + $r.Code)
    return $r
  }

  [WMUSF_Result] AssureDefaultInstaller() {
    $this.audit.LogD("Assuring default installer for Windows, no parameters received")
    return $this.AssureDefaultInstaller($this.cacheDir, [WMUSF_Downloader]::defaultInstallerFileName)
  }

  [WMUSF_Result] AssureDefaultInstaller(
    [string]${fullOutputDirectoryPath},
    [string]${fileName}
  ) {

    $this.audit.LogD("Assuring default installer for Windows, parameters received: 1: ${fullOutputDirectoryPath} 2: ${fileName}")
    $r = $this.AssureWebFileWithChecksumVerification(
      [WMUSF_Downloader]::defaultInstallerDownloadURL,
      ${fullOutputDirectoryPath},
      ${fileName},
      [WMUSF_Downloader]::defaultInstallerFileHash,
      [WMUSF_Downloader]::defaultInstallerFileHashAlgorithm
    )
    $this.audit.LogD("AssureDefaultInstaller returns " + $r.Code)
    if ($r.Code -eq 0) {
      $this.currentInstallerBinary = $r.PayloadString
      $this.audit.LogI("Installer binary found: " + $this.currentInstallerBinary)
    }
    else {
      $this.audit.LogE("Error assuring default installer binary")
    }
    return $r
  }


  [WMUSF_Result] AssureDefaultUpdateManagerBootstrap() {
    return $this.AssureDefaultUpdateManagerBootstrap($this.cacheDir, [WMUSF_Downloader]::defaultWmumBootstrapFileName)
  }


  [WMUSF_Result] AssureDefaultUpdateManagerBootstrap(
    [string]${fullOutputDirectoryPath} = $this.cacheDir,
    [string]${fileName} = $defaultCceBootstrapFileName) {
    $this.audit.LogI("Assuring default boostrap for Update Manager")
    $r1 = $this.AssureWebFileWithChecksumVerification(
      [WMUSF_Downloader]::defaultWmumBootstrapDownloadURL,
      ${fullOutputDirectoryPath},
      ${fileName},
      [WMUSF_Downloader]::defaultWmumBootstrapFileHash,
      [WMUSF_Downloader]::defaultWmumBootstrapFileHashAlgorithm
    )
    $this.currentUpdateManagerBootstrapBinary = $r1.PayloadString
    return $r1
  }


  [WMUSF_Result] AssureDefaultCceBootstrap() {
    return $this.AssureDefaultCceBootstrap($this.cacheDir, [WMUSF_Downloader]::defaultCceBootstrapFileName)
  }

  [WMUSF_Result] AssureDefaultCceBootstrap(
    [string]${fullOutputDirectoryPath} = $this.cacheDir,
    [string]${fileName} = $defaultCceBootstrapFileName
  ) {
    $this.audit.LogI("Assuring default boostrap for CCE")
    return $this.AssureWebFileWithChecksumVerification(
      [WMUSF_Downloader]::defaultCceBootstrapDownloadURL,
      ${fullOutputDirectoryPath},
      ${fileName},
      [WMUSF_Downloader]::defaultCceBootstrapFileHash,
      [WMUSF_Downloader]::defaultCceBootstrapFileHashAlgorithm
    )
  }

  [WMUSF_Result] GetInstallerBinary(
  ) {
    $this.audit.LogI("Assuring default installer binary")
    $r = $this.AssureDefaultInstaller()
    if ($r.Code -ne 0) {
      $this.audit.LogE("Error assuring default installer binary")
      return $r
    }
    $installerBinary = [WMUSF_Downloader]::defaultInstallerFileName
    $installerBinaryPath = [System.IO.Path]::Combine($this.cacheDir, $installerBinary)
    if (Test-Path -PathType Leaf -Path $installerBinaryPath) {
      $r.Code = 0
      $r.Description = "Installer binary found"
      $r.PayloadString = $installerBinaryPath
    }
    else {
      return [WMUSF_Result]::GetSimpleResult(1, "Installer binary not found", $this.audit)
    }
    return $r
  }

  [WMUSF_Result] AssureUpdateManagerInstallation() {
    $this.audit.LogI("Assuring default Update Manager installation")
    $r = [WMUSF_Result]::new()
    $r1 = $this.AssureDefaultUpdateManagerBootstrap()
    if ($r1.Code -ne 0) {
      $this.audit.LogE("Error assuring default Update Manager bootstrap binary")
      $r.Code = 1
      $r.Description = "Error assuring default Update Manager bootstrap binary"
      $r.NestedResults = $r1
    }
    $r.Messages += "Update Manager bootstrap binary found: " + $r1.PayloadString
    $r.PayloadString = $r1.PayloadString
    $this.audit.LogI($r.Description)
    $r2 = $this.BootstrapUpdateManager($r1.PayloadString)
    if ( $r2.Code -ne 0) {
      $this.audit.LogE("Error bootstrapping Update Manager")
      $r.Code = 2
      $r.Description = "Error bootstrapping Update Manager: " + $r2.Description
      $r.NestedResults = $r2
    }
    $r.Code = 0
    $r.Description = "Update Manager setup OK"
    return $r
  }

  [WMUSF_Result] BootstrapUpdateManager() {
    $f = $this.currentUpdateManagerBootstrapBinary
    if ($f -eq "N/A") {
      $this.audit.LogE("Update Manager bootstrap binary not yet inisitalized, attempting to do it now...")
      $r1 = $this.AssureDefaultUpdateManagerBootstrap()
      if ($r1.Code -ne 0) {
        $this.audit.LogE("Error assuring default Update Manager bootstrap binary")
        return $r1
      }
      $f = $r1.PayloadString
    }
    return $this.BootstrapUpdateManager($f)
  }

  [WMUSF_Result] BootstrapUpdateManager([string]$BootStrapBinaryFile) {

    $r = [WMUSF_Result]::new()

    if (-Not (Test-Path $BootStrapBinaryFile -PathType Leaf)) {
      $r.Description = "Bootstrap binary not found: " + $BootStrapBinaryFile
      $this.audit.LogE($r.Description)
      $r.Code = 3
      return $r
    }

    if (Test-Path ($this.updateManagerHome + [IO.Path]::DirectorySeparatorChar + 'bin') -PathType Container) {
      $this.audit.LogI("Update Manager home already exists, nothing to do")
      $r.Code = 0
      $r.Description = "Update Manager already present"
      return $r
    }

    $this.audit.LogI("Bootstrapping Update Manager from file: " + $BootStrapBinaryFile)

    ${tempFolder} = [System.IO.Path]::GetTempPath() + 'UpdMgrInstallation'
    $this.audit.LogI("Using temporary folder ${tempFolder} for Update Manager Bootstrap")

    New-Item -Path ${tempFolder} -ItemType Container
    Expand-Archive -Path $BootStrapBinaryFile -DestinationPath "${tempFolder}"
    if (-Not (Test-Path ("${tempFolder}" + [IO.Path]::DirectorySeparatorChar + "sum-setup.bat") -PathType Leaf)) {
      $r.Code = 2
      $r.Description = "Wrong archive, it does not contain the file sum-setup.bat"
      $this.audit.LogE($r.Description)
      return $r
    }

    Push-Location .
    Set-Location -Path "${tempFolder}" || return 2
    $cmd = "." + [IO.Path]::DirectorySeparatorChar + "sum-setup.bat --accept-license -d " + '"' + $this.updateManagerHome + '"'
    if ($this.onlineMode -ne 'true') {
      $this.audit.LogW("Offline mode not supported yet, using online mode")
    }
    $this.audit.LogI("Bootstrapping UpdateManager with the following command")
    $this.audit.LogI("$cmd")
    $this.audit.InvokeCommand("$cmd", "BootstrapUpdMgr")
    Pop-Location

    $r.Code = 0
    $r.Description = "Update Manager Installed"
    return $r
  }

  [WMUSF_Result] ExecuteUpdateManagerCommand([string] $cmd, [string] $auditTag) {
    $r = [WMUSF_Result]::new()

    if (-Not (Test-Path ($this.updateManagerHome + [IO.Path]::DirectorySeparatorChar + 'bin') -PathType Container)) {
      $this.audit.LogW("Update Manager not installed, attempting to install it")
      $r1 = $this.BootstrapUpdateManager()
      if ($r1.Code -ne 0) {
        $this.audit.LogE("Error bootstrapping Update Manager")
        $r.Code = 1
        $r.Description = "Error bootstrapping Update Manager: " + $r1.Description
        return $r
      }
    }

    Push-Location .
    Set-Location ($this.updateManagerHome + [IO.Path]::DirectorySeparatorChar + 'bin')
    if (-Not (Test-Path -PathType Leaf -Path "UpdateManagerCMD.bat")) {
      $r.Code = 3
      $r.Description = "Ineffective change directory, current directory is not the Update Manager bin folder"
      $this.audit.LogE($r.Description)
      return $r
    }

    $r1 = $this.audit.InvokeCommand($cmd, $auditTag)
    if ($r1.Code -ne 0) {
      $r.Description = "Error executing download command: " + $r1.Description
      $this.audit.LogE($r.Description)
      $r.Code = 2
      $r.NestedResults = $r1
    }
    else {
      $r.Description = "Update Manager command executed successfully"
      $r.Code = 0
      $this.audit.LogD($r.Description)
      $r.PayloadString = $r1.PayloadString
    }
    Pop-Location
    return $r
  }

}