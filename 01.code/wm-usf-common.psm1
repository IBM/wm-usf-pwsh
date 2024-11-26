
## Convenient Constanst
${pathSep} = [IO.Path]::DirectorySeparatorChar
# TODO: enforce, this is a bit naive
${sysTemp} = ${env:TEMP} ?? '/tmp'
#${comspec} = ${env:COMSPEC} ?? ${env:SHELL} ?? '/bin/sh'
#${posixCmd} = (${comspec}.Substring(0, 1) -eq '/') ? $true : $false

# Context constants
${defaultInstallerDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/SoftwareAGInstaller20240626-w64.exe"
${defaultInstallerFileHash} = "cdfff7e2f420d182a4741d90e4ee02eb347db28bdaa4969caca0a3ac1146acd3"
${defaultInstallerFileHashAlgorithm} = "SHA256"

${defaultWmumBootstrapDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/SAGUpdateManagerInstaller-windows-x64-11.0.0.0000-0823.exe"
${defaultWmumBootstrapFileHash} = "53d283ba083a3535dd12831aa05ab0e8a590ff577053ab9eebedabe5a499fbfa"
${defaultWmumBootstraprFileHashAlgorithm} = "SHA256"

${defaultCceBootstrapDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/cc-def-10.15-fix8-w64.bat"
${defaultCceBootstrapFileHash} = "489c2c6d831aca75ffcf24a931606982a1b5ab9bd33bd8324c2722a6ea0438d4"
${defaultCceBootstraprFileHashAlgorithm} = "SHA256"

#################### Auditing & the folders castle
# All executions are producing logs in the audit folder

function Set-LogSessionDir {
  param (
    [Parameter(Mandatory = $true)]
    [string]${NewSessionDir}
  )
  Resolve-WmusfDirectory -directory ${logSessionDir} -alsoLog $false
  Set-Variable -Name 'LogSessionDir' -Value ${NewSessionDir} -Scope Script
}

function Set-TodayLogSessionDir {
  ${auditDir} = Get-Variable -Name 'AuditBaseDir' -Scope Script -ValueOnly
  Set-LogSessionDir -NewSessionDir "${auditDir}${pathSep}$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%d')"
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
    [string]${sev} = "INF"
  )
  $l = Get-LogSessionDir
  ${callingPoint} = $(Get-PSCallStack).SyncRoot.Get(2)
  ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')|${sev}|${callingPoint}|${msg}"
  Write-Host "${fs}"
  Add-content "${l}/session.log" -value "$fs"
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
  Debug-WmUifwLog -msg $msg -sev "WRN"
}

function Debug-WmUifwLogE {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  Debug-WmUifwLog -msg $msg -sev "ERR"
}

function Debug-WmUifwLogD {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  Debug-WmUifwLog -msg $msg -sev "DBG"
}
##### End Audit

########### Tools
function Invoke-EnvironmentSubstitution() {
  param([Parameter(ValueFromPipeline)][string]$InputObject)

  #Get-ChildItem Env: | Set-Variable
  $ExecutionContext.InvokeCommand.ExpandString($InputObject)
}

# Haven't found a reliable way to extract the command exit code, only if it is successful or not.
# TODO: Check if this can be done better
function Invoke-AuditedCommand() {
  param (
    [Parameter(Mandatory = $true)]
    [string]${command},

    [Parameter(Mandatory = $true)]
    [string]${tag}
  )

  ${lsd} = Get-LogSessionDir
  #Debug-WmUifwLogD "Running in POSIX environment: ${posixCmd}"

  ${fullCmd} = ""
  ${baseOutputFileName} = "${lsd}${pathSep}${tag}"
  ${ts} = Get-Date -UFormat "%s" 
  ${fullCmd} = ${command}
  ${fullCmd} += ' >>"' 
  ${fullCmd} += "${baseOutputFileName}.out.txt"
  ${fullCmd} += '" 2>>"'
  ${fullCmd} += "${baseOutputFileName}.err.txt"
  ${fullCmd} += '" || echo False >"'
  ${fullCmd} += "${baseOutputFileName}.exitcode.${ts}.txt"
  ${fullCmd} += '"'

  Add-Content -Path "${baseOutputFileName}.exitcode.${ts}.txt" -Value "True"
  Debug-WmUifwLogD "Executing Command:"

  Debug-WmUifwLogD "${fullCmd}"

  Invoke-Expression "${fullCmd}"
  ${exitCode} = Get-Content -Path "${baseOutputFileName}.exitcode.${ts}.txt"

  Debug-WmUifwLogD "Command exitted with code ${exitCode}"
  return ${exitCode} 
}

function Resolve-ProductVersionToLatest() {
  param (
    [Parameter(Mandatory = $true)]
    [string]${InstallerProductCode}
  )
  $rgx = '^(.*\.)[0-9]+(\/.*)$'
  
  return ${InstallerProductCode} -replace $rgx, '${1}LATEST${2}'
}

function Build-ProductList() {
  param (
    [Parameter(Mandatory = $true)]
    [string]${InstallationProductList}

  )
  return "ProductList=" + ${InstallationProductList}.Replace([environment]::Newline, ",")
}

function Get-NewTempDir() {
  param (
    # log message
    [Parameter(Mandatory = $false)]
    [string]${tmpBaseDir} = `
    $(Get-Variable -Name 'TempSessionDir' -Scope Script) ?? ${sysTemp}
  )

  if ( ${tmpBaseDir}.Substring(${tmpBaseDir}.Length - 1, 1) -ne ${pathSep} ) {
    ${tmpBaseDir} += ${pathSep}
  }

  $r = $tmpBaseDir + (Get-Date -UFormat "%y%m%d%R" | ForEach-Object { $_ -replace ":", "." })
  return $r
}

function Resolve-WmusfDirectory {
  param (
    [Parameter(Mandatory = $true)]
    [string]${directory},
    
    [Parameter(Mandatory = $false)]
    [Boolean]$alsoLog = $false
  )

  if (Test-Path -Path "${directory}") {
    if ( -Not (Test-Path -Path "${directory}" -PathType Container)) {
      Write-Error "Path ${directory} is not a directory! This library may not work as expected!"
      if ($alsoLog) {
        Debug-WmUifwLogI "Path ${directory} is not a directory! This library may not work as expected!"
      }
      return "1"
    }
  }
  else {
    if ($alsoLog) {
      "Creating directory with path ${directory}"
    }
    New-Item -ItemType Directory -Path "${directory}" -Force
    if (Test-Path -Path "${directory}" -PathType Container) {
      if ($alsoLog) {
        Debug-WmUifwLogI "Created Directory ${directory}"
      }
      return "2"
    }
    else {
      if ($alsoLog) {
        Debug-WmUifwLogE "Path ${directory} was NOT created!"
      }
      return "3"
    }
  }
  
}

########### Assets Assurance
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

  Debug-WmUifwLogI "Downloading file $fullOutputDirectoryPath/$fileName"
  Debug-WmUifwLogI "From $url"
  Debug-WmUifwLogI "Guaranteeing $hashAlgoritm checksum $expectedHash"
  
  # assure destination folder
  Debug-WmUifwLogI "Eventually create folder $fullOutputDirectoryPath..."
  New-Item -Path $fullOutputDirectoryPath -ItemType Directory -Force | Out-Null
  $fullFilePath = "$fullOutputDirectoryPath/$fileName"
  # Download the file
  Invoke-WebRequest -Uri $url -OutFile "$fullFilePath.verify"

  # Calculate the SHA256 hash of the downloaded file
  $fileHash = Get-FileHash -Path "$fullFilePath.verify" -Algorithm $hashAlgoritm
  Debug-WmUifwLogI("File hash is " + ${fileHash}.Hash.ToString() + " .")
  #Write-Host $fileHash
  # Compare the calculated hash with the expected hash
  $r = $false
  if ($fileHash.Hash -eq $expectedHash) {
    Rename-Item -Path "$fullFilePath.verify" -NewName "$fullFilePath"
    Debug-WmUifwLogI "The file's $hashAlgoritm hash matches the expected hash."
    $r = $true
  }
  else {
    Rename-Item -Path "$fullFilePath.verify" -NewName "$fullFilePath.dubious"
    Debug-WmUifwLogE "wmUifwCommon| Get-WebFileWithChecksumVerification() - The file's $hashAlgoritm hash does not match the expected hash."
    Debug-WmUifwLogE "Got $fileHash.Hash, but expected $expectedHash!"
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
    [string]${fullOutputDirectoryPath} = $(Get-TempSessionDir),

    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fileName} = "file.bin",
    # Hash to be checked
    [Parameter(Mandatory = $true)]
    [string]${expectedHash},

    # Hash to be checked
    [Parameter(Mandatory = $false)]
    [string]${hashAlgoritm} = "SHA256"
  )

  # Calculate the SHA256 hash of the downloaded file
  $fullFilePath = "${fullOutputDirectoryPath}${pathSep}${fileName}"
  Debug-WmUifwLogI "checking file $fullFilePath ..."

  # if File exists, just check the checksum
  if (Test-Path $fullFilePath -PathType Leaf) {
    Debug-WmUifwLogI("file $fullFilePath found.")
    $fileHash = Get-FileHash -Path $fullFilePath -Algorithm $hashAlgoritm
    Debug-WmUifwLogI("its hash is " + $fileHash.Hash)
    if ($fileHash.Hash -eq $expectedHash) {
      Debug-WmUifwLogI "The file's $hashAlgoritm hash matches the expected hash."
      return $true
    }
    else {
      Debug-WmUifwLogI("wmUifwCommon| Resolve-WebFileWithChecksumVerification() - checking file $fullFilePath ...")
      Debug-WmUifwLogE "wmUifwCommon| Resolve-WebFileWithChecksumVerification() - The file's $hashAlgoritm hash does not match the expected hash. Downloaded file renamed"
      Debug-WmUifwLogE "Got " + $fileHash.Hash + ", but expected $expectedHash!"
      return $false
    }
  }
  Debug-WmUifwLogI("file $fullFilePath does not exist. Attempting to download...")
  $r = Get-WebFileWithChecksumVerification `
    -url "$url" `
    -fullOutputDirectoryPath "$fullOutputDirectoryPath" `
    -fileName "$fileName" `
    -expectedHash "$expectedHash" `
    -hashAlgoritm "$hashAlgoritm"
  
  Debug-WmUifwLogI "Initialize-SumBootstrapBinary returns $r"
  return $r
}

function Resolve-DefaultInstaller() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = "..${pathSep}09.artifacts",

    [Parameter(Mandatory = $false)]
    [string]${fileName} = "installer.exe"
  )

  Resolve-WebFileWithChecksumVerification `
    -url ${defaultInstallerDownloadURL} `
    -expectedHash ${defaultInstallerFileHash} `
    -hashAlgoritm ${defaultInstallerFileHashAlgorithm} `
    -fullOutputDirectoryPath ${fullOutputDirectoryPath} `
    -fileName ${fileName}
}

function Resolve-DefaultUpdateManagerBootstrap() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = "..${pathSep}09.artifacts",

    [Parameter(Mandatory = $false)]
    [string]${fileName} = "updateManagerBootstrap.exe"
  )

  Resolve-WebFileWithChecksumVerification `
    -url ${defaultWmumBootstrapDownloadURL} `
    -expectedHash ${defaultWmumBootstrapFileHash} `
    -hashAlgoritm ${defaultWmumBootstraprFileHashAlgorithm} `
    -fullOutputDirectoryPath ${fullOutputDirectoryPath} `
    -fileName ${fileName}
}

function Resolve-DefaultCceBootstrap() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = "..${pathSep}09.artifacts",

    [Parameter(Mandatory = $false)]
    [string]${fileName} = "updateManagerBootstrap.exe"
  )

  Resolve-WebFileWithChecksumVerification `
    -url ${defaultCceBootstrapDownloadURL} `
    -expectedHash ${defaultCceBootstrapFileHash} `
    -hashAlgoritm ${defaultCceBootstraprFileHashAlgorithm} `
    -fullOutputDirectoryPath ${fullOutputDirectoryPath} `
    -fileName ${fileName}
}


############## Initialize Variables
# This library is founded on a set of variables
# The scripts are expected to use scoped variables
# The variables resolved here are "global" for the script importing this module
function Resolve-WmusfCommonModuleLocals() {
  ${tempFolder} = ${env:WMUSF_TEMP_DIR} ?? `
    ${sysTemp} + ${pathSep} + "WMUSF"
  Set-Variable -Name 'TempSessionDir' -Value ${tempFolder} -Scope Script
  Write-Host "TempSessionDir script variable set to ${tempFolder}"

  ${auditDir} = ${env:WMUSF_AUDIT_DIR} ?? "${tempFolder}${pathSep}WMUSF_AUDIT"
  Set-Variable -Name 'AuditBaseDir' -Value ${auditDir} -Scope Script

  ${logSessionDir} = $(${env:WMUSF_LOG_SESSION_DIR} ?? `
      "${auditDir}${pathSep}$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')")
  Set-LogSessionDir -NewSessionDir ${logSessionDir}

  Resolve-WmusfDirectory -directory ${tempFolder} -alsoLog $true

  Debug-WmUifwLogI "Module wm-usf-common.psm1 initialized"
  Debug-WmUifwLogD "AuditBaseDir: ${auditDir}"
  Debug-WmUifwLogD "LogSessionDir: ${logSessionDir}"
  Debug-WmUifwLogD "TempSessionDir: ${tempFolder}"

}
Resolve-WmusfCommonModuleLocals
