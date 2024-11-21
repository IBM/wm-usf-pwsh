# Context constants
${defaultInstallerDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/SoftwareAGInstaller20230725-w64.exe"
${defaultInstallerFileHash} = "26236aac5e5c20c60d2f7862c606cdfdd86f08e0a1a39dbfc3e09d2ba50b8bce"
${defaultInstallerFileHashAlgorithm} = "SHA256"

${defaultSumBootstrapDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/SoftwareAGUpdateManagerInstaller20230322-11-Windows.exe"
${defaultSumBootstrapFileHash} = "f64d438c23acd7d41f22e632ef067f47afc19f12935893ffc89ea2ccdfce1c02"
${defaultSumBootstraprFileHashAlgorithm} = "SHA256"


#################### Auditing & the folders castle
# All executions are producing logs in the audit folder

function Set-LogSessionDir {
  param (
    [Parameter(Mandatory = $true)]
    [string]${NewSessionDir}
  )
  Set-Variable -Name 'LogSessionDir' -Value ${NewSessionDir} -Scope Script
}

function Set-TodayLogSessionDir {
  ${auditDir} = Get-Variable -Name 'AuditSessionDir' -Scope Script -ValueOnly
  Set-LogSessionDir -NewSessionDir "${auditDir}/$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%d')"
}

function Get-LogSessionDir {
  # Retrieve the module-scoped variable
  Get-Variable -Name 'LogSessionDir' -Scope Script -ValueOnly
}

function Get-TempSessionDir {
  # Retrieve the module-scoped variable
  return Get-Variable -Name 'TempSessionDir' -Scope Script -ValueOnly
}

function Debug-WmUifwLog {
  param (
    # log message
    [Parameter(Mandatory = $true)]
    [string]${msg},
    # log severity
    [Parameter(Mandatory = $false)]
    [string]${sev} = " INFO"
  )
  ${fs} = "$(Get-SessionLogDir)|${sev}|${msg}"
  Write-Host "${fs}"
  Add-content "${logSessionDir}/session.log" -value "$fs"
}

function Debug-WmUifwLogI {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  Debug-WmUifwLog -msg $msg
}

function Debug-WmUifwLogW {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  Debug-WmUifwLog -msg $msg -sev " WARN"
}

function Debug-WmUifwLogE {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  Debug-WmUifwLog -msg $msg -sev "ERROR"
}
##### End Audit

function Invoke-EnvironmentSubstitution() {
  param([Parameter(ValueFromPipeline)][string]$InputObject)

  Get-ChildItem Env: | Set-Variable
  $ExecutionContext.InvokeCommand.ExpandString($InputObject)
}

function Get-NewTempDir() {
  param (
    # log message
    [Parameter(Mandatory = $false)]
    [string]${tmpBaseDir} = `
    $(Get-Variable -Name 'TempSessionDir' -Scope Script) ?? `
      ${env:TEMP} ?? '/tmp'
  )

  if ( ${tmpBaseDir}.Substring(${tmpBaseDir}.Length - 1, 1) -ne [IO.Path]::DirectorySeparatorChar ) {
    ${tmpBaseDir} += [IO.Path]::DirectorySeparatorChar
  }

  $r = $tmpBaseDir + (Get-Date -UFormat "%y%m%d%R" | ForEach-Object { $_ -replace ":", "." })
  return $r
}

########### Sacure Assets Assurance
function Get-WebFileWithChecksumVerification {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$url,

    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]$fullOutputDirectoryPath = $(Get-TempSessionDir) ,

    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]$fileName = "file.bin",
    # Hash to be checked
    [Parameter(Mandatory = $true)]
    [string]$expectedHash,

    # Hash to be checked
    [Parameter(Mandatory = $false)]
    [string]$hashAlgoritm = "SHA256"
  )

  Debug-WmUifwLogI "wmUifwCommon|Get-WebFileWithChecksumVerification() - Downloading file "$fullOutputDirectoryPath/$fileName""
  Debug-WmUifwLogI "wmUifwCommon|Get-WebFileWithChecksumVerification() - From $url"
  Debug-WmUifwLogI "wmUifwCommon|Get-WebFileWithChecksumVerification() - Guaranteeing $hashAlgoritm checksum $expectedHash"
  
  # assure destination folder
  Debug-WmUifwLogI "Eventually create folder $fullOutputDirectoryPath..."
  New-Item -Path $fullOutputDirectoryPath -ItemType Directory -Force | Out-Null
  $fullFilePath = "$fullOutputDirectoryPath/$fileName"
  # Download the file
  Invoke-WebRequest -Uri $url -OutFile "$fullFilePath.verify"

  # Calculate the SHA256 hash of the downloaded file
  $fileHash = Get-FileHash -Path "$fullFilePath.verify" -Algorithm $hashAlgoritm
  Debug-WmUifwLogI("wmUifwCommon|Get-WebFileWithChecksumVerification() - File hash is $fileHash.Hash .")
  Write-Host $fileHash
  # Compare the calculated hash with the expected hash
  $r = $false
  if ($fileHash.Hash -eq $expectedHash) {
    Rename-Item -Path "$fullFilePath.verify" -NewName "$fullFilePath"
    Debug-WmUifwLogI "wmUifwCommon|Get-WebFileWithChecksumVerification() - The file's $hashAlgoritm hash matches the expected hash."
    $r = $true
  }
  else {
    Rename-Item -Path "$fullFilePath.verify" -NewName "$fullFilePath.dubious"
    Debug-WmUifwLogE "wmUifwCommon| Get-WebFileWithChecksumVerification() - The file's $hashAlgoritm hash does not match the expected hash."
    Debug-WmUifwLogE "wmUifwCommon|Get-WebFileWithChecksumVerification() - Got $fileHash.Hash, but expected $expectedHash!"
  }
  Debug-WmUifwLogI("wmUifwCommon|Get-WebFileWithChecksumVerification returns $r")
  return $r
}

function Resolve-WebFileWithChecksumVerification {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$url,

    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]$fullOutputDirectoryPath = $(Get-TempSessionDir),

    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]$fileName = "/tmp/file.bin",
    # Hash to be checked
    [Parameter(Mandatory = $true)]
    [string]$expectedHash,

    # Hash to be checked
    [Parameter(Mandatory = $false)]
    [string]$hashAlgoritm = "SHA256"
  )

  # Calculate the SHA256 hash of the downloaded file
  $fullFilePath = "$fullOutputDirectoryPath/$fileName"
  Debug-WmUifwLogI("wmUifwCommon|Resolve-WebFileWithChecksumVerification() - checking file $fullFilePath ...")

  # if File exists, just check the checksum
  if (Test-Path $fullFilePath -PathType Leaf) {
    Debug-WmUifwLogI("wmUifwCommon|Resolve-WebFileWithChecksumVerification() - file $fullFilePath found.")
    $fileHash = Get-FileHash -Path $fullFilePath -Algorithm $hashAlgoritm
    Debug-WmUifwLogI("wmUifwCommon|Resolve-WebFileWithChecksumVerification() - its hash is $fileHash.Hash .")
    if ($fileHash.Hash -eq $expectedHash) {
      Debug-WmUifwLogI "wmUifwCommon|Resolve-WebFileWithChecksumVerification() - The file's $hashAlgoritm hash matches the expected hash."
      return $true
    }
    else {
      Debug-WmUifwLogI("wmUifwCommon| Resolve-WebFileWithChecksumVerification() - checking file $fullFilePath ...")
      Debug-WmUifwLogE "wmUifwCommon| Resolve-WebFileWithChecksumVerification() - The file's $hashAlgoritm hash does not match the expected hash. Downloaded file renamed"
      Debug-WmUifwLogE "wmUifwCommon|Resolve-WebFileWithChecksumVerification() - Got $fileHash.Hash, but expected $expectedHash!"
      return $false
    }
  }
  Debug-WmUifwLogI("wmUifwCommon|Resolve-WebFileWithChecksumVerification() - file $fullFilePath does not exist. Attempting to download...")
  $r = Get-WebFileWithChecksumVerification `
    -url "$url" `
    -fullOutputDirectoryPath "$fullOutputDirectoryPath" `
    -fileName "$fileName" `
    -expectedHash "$expectedHash" `
    -hashAlgoritm "$hashAlgoritm"
  
  Debug-WmUifwLogI "wmUifwCommon|Resolve-WebFileWithChecksumVerification() - Initialize-SumBootstrapBinary returns $r"
  return $r
}

function Resolve-WmusfCommonModuleLocalsInitialization() {
  ${sysTemp} = ${env:TEMP} ?? '/tmp'
  ${tempFolder} = ${env:WMUSF_TEMP_DIR} ?? `
    ${sysTemp} + [IO.Path]::DirectorySeparatorChar + "WMUSF"
  Set-Variable -Name 'TempSessionDir' -Value ${tempFolder} -Scope Script
  Write-Host "TempSessionDir script variable set to ${tempFolder}"

  ${auditDir} = ${env:WMUSF_AUDIT_DIR} ?? "${tempFolder}/WMUSF_AUDIT"
  Set-Variable -Name 'AuditSessionDir' -Value ${auditDir} -Scope Script

  Set-LogSessionDir $(${env:WMUSF_LOG_SESSION_DIR} ?? `
      "${auditDir}/$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')")
}
Resolve-WmusfCommonModuleLocalsInitialization
