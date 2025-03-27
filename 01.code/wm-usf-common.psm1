
## Convenient Constants
${pathSep} = [IO.Path]::DirectorySeparatorChar
# TODO: enforce, this is a bit naive
${sysTemp} = ${env:TEMP} ?? '/tmp'
#${comspec} = ${env:COMSPEC} ?? ${env:SHELL} ?? '/bin/sh'
#${posixCmd} = (${comspec}.Substring(0, 1) -eq '/') ? $true : $false
${posixCmd} = (${pathSep} -eq '/') ? $true : $false

# Context constants
${defaultInstallerDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/SoftwareAGInstaller20240626-w64.exe"
${defaultInstallerFileName} = "SoftwareAGInstaller20240626-w64.exe"
${defaultInstallerFileHash} = "cdfff7e2f420d182a4741d90e4ee02eb347db28bdaa4969caca0a3ac1146acd3"
${defaultInstallerFileHashAlgorithm} = "SHA256"

${defaultWmumBootstrapDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/SAGUpdateManagerInstaller-windows-x64-11.0.0.0000-0823.exe"
${defaultWmumBootstrapFileName} = "SAGUpdateManagerInstaller-windows-x64-11.0.0.0000-0823.exe"
${defaultWmumBootstrapFileHash} = "53d283ba083a3535dd12831aa05ab0e8a590ff577053ab9eebedabe5a499fbfa"
${defaultWmumBootstrapFileHashAlgorithm} = "SHA256"

${defaultCceBootstrapDownloadURL} = "https://empowersdc.softwareag.com/ccinstallers/cc-def-10.15-fix8-w64.bat"
${defaultCceBootstrapFileName} = "cc-def-10.15-fix8-w64.bat"
${defaultCceBootstrapFileHash} = "728488F53CFD54B5835205F960C6501FE96B14408529EAA048441BA711B8F614"
${defaultCceBootstrapFileHashAlgorithm} = "SHA256"

${debugOn} = ${env:WMUSF_DEBUG_ON} ?? 0

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
function Get-WmUsfHomeDir() {
  #Get-Variable -Name 'WmUsfHomeDir' -Scope Script -ValueOnly
  #Set-Variable -Name 'WmUsfHomeDir' -Value (GetItem ${PSScriptRoot}).parent -Scope Script
  (Get-Item ${PSScriptRoot}).parent
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
    [string]${sev} = "I"
  )
  $l = Get-LogSessionDir
  ${callingPoint} = $(Get-PSCallStack).SyncRoot.Get(2)
  if (${debugOn} -eq 0) {
    ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')${sev}|${msg}"
    Write-Host "${fs}"
    Add-content "${l}/session.log" -value "$fs"
  }
  else {
    ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')${sev}|${callingPoint}|${msg}"
    Write-Host "${fs}"
    Add-content "${l}/session.log" -value "$fs"
  }
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
  Debug-WmUifwLog -msg $msg -sev "W"
}

function Debug-WmUifwLogE {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  Debug-WmUifwLog -msg $msg -sev "E"
}

function Debug-WmUifwLogD {
  param (
    # Where to download from
    [Parameter(Mandatory = $true)]
    [string]$msg
  )
  if (${debugOn} -eq 1) {
    Debug-WmUifwLog -msg $msg -sev "D"
  }
}
##### End Audit

########### Tools
function Read-UserSecret() {
  param (
    [Parameter(Mandatory = $true)]
    [string]${Label}
  )
  #TODO: enforce with double read
  $x = Read-Host -MaskInput ${Label}
  $x
}

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
  if (${posixCmd}) {
    ${fullCmd} += '" || echo $LastExitCode >"'
  }
  else {
    # TODO: Find out how to capture the real exit code in Windows
    ${fullCmd} += '" || echo 255 >"'
  }
  ${fullCmd} += "${baseOutputFileName}.exitcode.${ts}.txt"
  ${fullCmd} += '"'

  Add-Content -Path "${baseOutputFileName}.exitcode.${ts}.txt" -Value "0"
  Debug-WmUifwLogD "Executing Command:"

  Debug-WmUifwLogD "${fullCmd}"

  Invoke-Expression "${fullCmd}"
  ${exitCode} = Get-Content -Path "${baseOutputFileName}.exitcode.${ts}.txt"

  Debug-WmUifwLogD "Command exited with code ${exitCode}"
  return ${exitCode} 
}

function Invoke-WinrsAuditedCommandOnServerList {
  param (
    [Parameter(Mandatory = $true)]
    [string]${command},

    [Parameter(Mandatory = $true)]
    [string]${tag},

    [Parameter(Mandatory = $true)]
    [string]${serverListFile}
  )

  Debug-WmUifwLogI "Reading boxes from file ${serverListFile} ..."
  Get-Content -Path "${serverListFile}" | ForEach-Object {
    Debug-WmUifwLogI "Checking if box $_ is active..."
    ${active} = Invoke-Expression "winrs -r:$_ ""echo 0"" || echo 254" 
    if (${active} -eq "0") {
      Debug-WmUifwLogI "Invoking command having tag ${tag} on server $_ ..."
      Invoke-AuditedCommand "winrs -r:$_ ${command}" "${tag}_$_"
    }
    else {
      Debug-WmUifwLogE "Server $_ not active!"
    }
  }
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

function Get-ProductListForTemplate() {
  param (
    [Parameter(Mandatory = $true)]
    [string]${TemplateId}
  )

  ${templateFolder} = Get-TemplateBaseFolder "${TemplateId}"

  ${plFile} = "${templateFolder}${PathSep}ProductsList.txt"
  if ( -Not (Test-Path -Path ${plFile} -PathType Leaf )) {
    Debug-WmUifwLogE "File ${plFile} does not exist"
    return 2
  }

  return ( Get-Content ${plFile} ) -join ","
}

function Get-NewTempDir() {
  param (
    # log message
    [Parameter(Mandatory = $false)]
    [string]${tmpBaseDir} = `
    $(Get-Variable -Name 'TempSessionDir' -Scope Script).Value ?? ${sysTemp}
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
    [string]$hashAlgorithm = "SHA256"
  )

  Debug-WmUifwLogI "Downloading file ${fullOutputDirectoryPath}/${fileName}"
  Debug-WmUifwLogI "From ${url}"
  
  # assure destination folder
  Debug-WmUifwLogD "Eventually create folder ${fullOutputDirectoryPath}..."
  New-Item -Path ${fullOutputDirectoryPath} -ItemType Directory -Force | Out-Null
  $fullFilePath = "${fullOutputDirectoryPath}/${fileName}"
  # Download the file
  Invoke-WebRequest -Uri ${url} -OutFile "${fullFilePath}.verify"

  # Calculate the SHA256 hash of the downloaded file
  Debug-WmUifwLogD "Guaranteeing ${hashAlgorithm} checksum ${expectedHash}"
  ${fileHash} = Get-FileHash -Path "${fullFilePath}.verify" -Algorithm ${hashAlgorithm}
  Debug-WmUifwLogD("File hash is " + ${fileHash}.Hash.ToString() + " .")
  #Write-Host $fileHash
  # Compare the calculated hash with the expected hash
  $r = $false
  if (${fileHash}.Hash -eq ${expectedHash}) {
    Debug-WmUifwLogI "The file's $hashAlgorithm hash matches the expected hash."
    Debug-WmUifwLogD "Renaming ${fullFilePath}.verify to ${fullFilePath}"
    Rename-Item -Path "${fullFilePath}.verify" -NewName "${fileName}"
    $r = $true
  }
  else {
    Rename-Item -Path "${fullFilePath}.verify" -NewName "${fileName}.dubious"
    Debug-WmUifwLogE "The file's ${hashAlgorithm} hash does not match the expected hash."
    Debug-WmUifwLogE "Got ${fileHash}.Hash, but expected ${expectedHash}!"
  }
  Debug-WmUifwLogD("wmUifwCommon|Get-WebFileWithChecksumVerification returns ${r}")
  return ${r}
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
    [string]${hashAlgorithm} = "SHA256"
  )

  # Calculate the SHA256 hash of the downloaded file
  $fullFilePath = "${fullOutputDirectoryPath}${pathSep}${fileName}"
  Debug-WmUifwLogI "Resolving file $fullFilePath ..."

  # if File exists, just check the checksum
  if (Test-Path $fullFilePath -PathType Leaf) {
    Debug-WmUifwLogD("file $fullFilePath already exists.")
    $fileHash = Get-FileHash -Path $fullFilePath -Algorithm $hashAlgorithm
    Debug-WmUifwLogD("its hash is " + $fileHash.Hash)
    if ($fileHash.Hash -eq $expectedHash) {
      Debug-WmUifwLogD "The file's $hashAlgorithm hash matches the expected hash."
      return $true
    }
    else {
      Debug-WmUifwLogE "The $fullFilePath file's $hashAlgorithm hash does not match the expected hash. Downloaded file renamed"
      Debug-WmUifwLogE ("Got " + ${fileHash}.Hash + ", but expected $expectedHash!")
      return $false
    }
  }
  Debug-WmUifwLogD("file $fullFilePath does not exist. Attempting to download...")
  $r = Get-WebFileWithChecksumVerification `
    -url "$url" `
    -fullOutputDirectoryPath "$fullOutputDirectoryPath" `
    -fileName "$fileName" `
    -expectedHash "$expectedHash" `
    -hashAlgorithm "$hashAlgorithm"
  
  Debug-WmUifwLogD "Resolve-WebFileWithChecksumVerification returns $r"
  return $r
}

function Resolve-DefaultInstaller() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = "..${pathSep}09.artifacts",

    [Parameter(Mandatory = $false)]
    [string]${fileName} = ${defaultInstallerFileName}
  )

  Resolve-WebFileWithChecksumVerification `
    -url ${defaultInstallerDownloadURL} `
    -expectedHash ${defaultInstallerFileHash} `
    -hashAlgorithm ${defaultInstallerFileHashAlgorithm} `
    -fullOutputDirectoryPath ${fullOutputDirectoryPath} `
    -fileName ${fileName}
}

function Resolve-DefaultUpdateManagerBootstrap() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = "..${pathSep}09.artifacts",

    [Parameter(Mandatory = $false)]
    [string]${fileName} = ${defaultWmumBootstrapFileName}
  )

  Resolve-WebFileWithChecksumVerification `
    -url ${defaultWmumBootstrapDownloadURL} `
    -expectedHash ${defaultWmumBootstrapFileHash} `
    -hashAlgorithm ${defaultWmumBootstrapFileHashAlgorithm} `
    -fullOutputDirectoryPath ${fullOutputDirectoryPath} `
    -fileName ${fileName}
}

function Resolve-DefaultCceBootstrap() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = "..${pathSep}09.artifacts",

    [Parameter(Mandatory = $false)]
    [string]${fileName} = ${defaultCceBootstrapFileName}
  )

  Resolve-WebFileWithChecksumVerification `
    -url ${defaultCceBootstrapDownloadURL} `
    -expectedHash ${defaultCceBootstrapFileHash} `
    -hashAlgorithm ${defaultCceBootstrapFileHashAlgorithm} `
    -fullOutputDirectoryPath ${fullOutputDirectoryPath} `
    -fileName ${fileName}
}

function Get-CheckSumsForAllFilesInFolder {
  param (
    # What folder to inspect
    [Parameter(Mandatory = $true)]
    [string]${Path},

    # where to save the results
    [Parameter(Mandatory = $false)]
    [string]${OutFile} = "${Path}${pathSep}checksums.txt",

    # where to save the results
    [Parameter(Mandatory = $false)]
    [string]${OutFileNamesSorted} = "${Path}${pathSep}checksums_ns.txt",

    # Hash to be checked
    [Parameter(Mandatory = $false)]
    [string]${hashAlgorithm} = "SHA256"
  )

  if (Test-Path -Path ${OutFile}) {
    Debug-WmUifwLogI "Removing older ${OutFile}"
    Remove-Item -Path ${OutFile}
  }

  if (Test-Path -Path ${OutFileNamesSorted}) {
    Debug-WmUifwLogI "Removing older ${OutFileNamesSorted}"
    Remove-Item -Path ${OutFileNamesSorted}
  }

  # Get all files in the folder (and subfolders if needed)
  $files = Get-ChildItem -Path $Path -Recurse | Where-Object { ! $_.PSIsContainer }
  ${checksums} = @()
  ${checksums2} = @()
  foreach ($file in $files) {
    Debug-WmUifwLogI "Computing the checksum for file: $($file.FullName)"
    ${line} = Get-FileHash -Path "$($file.FullName)" -Algorithm ${hashAlgorithm}
    ${checksums} += (${line}.hash + "<--$($file.FullName)")
    ${checksums2} += ("$($file.FullName)-->" + ${line}.hash)
  }
  ${checksums} | Sort-Object | Out-File -FilePath ${OutFile}
  ${checksums2} | Sort-Object | Out-File -FilePath ${OutFileNamesSorted}
}

function Get-DownloadServerUrlForTemplate {
  param (
    [Parameter(Mandatory = $true)]
    [string]${TemplateId}
  )
  # Note: this is subject to change according to client geolocation and to evolution and transition to the new owner
  switch -Regex (${TemplateId}) {
    ".*\\1011\\.*" {
      return 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1011.cgi'
    }
    default {
      return 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1015.cgi'
    }
  }
}

function Get-ProductsImageForTemplate() {
  param (
    [Parameter(Mandatory = $true)]
    [string]${TemplateId},
    [Parameter(Mandatory = $true)]
    [string]${BaseFolder},
    [Parameter(Mandatory = $true)]
    [string]${InstallerBinary},
    [Parameter(Mandatory = $true)]
    [string]${UserName},
    [Parameter(Mandatory = $true)]
    [string]${UserPassword}
  )
  $pl = Get-ProductListForTemplate ${TemplateId}
  if ($pl.Length -le 5) {
    Debug-WmUifwLogE "Wrong product list: $pl"
    return 1
  }

  if (-Not (Test-Path -Path ${BaseFolder} -PathType Container)) {
    Debug-WmUifwLogW "Folder ${BaseFolder} does not exist, creating now..."
    New-Item -Path ${BaseFolder} -ItemType Container
  }
  $templateDestinationfolder = "${BaseFolder}\products\${TemplateId}".Replace('\', ${pathSep})
  if (-Not (Test-Path -Path ${templateDestinationfolder} -PathType Container)) {
    Debug-WmUifwLogW "Folder ${templateDestinationfolder} does not exist, creating now..."
    New-Item -Path ${templateDestinationfolder} -ItemType Container
  }
  ${zipLocation} = "$templateDestinationfolder${pathSep}products.zip"
  $scriptLocation = "$templateDestinationfolder${pathSep}image.creation.wmscript"
  $debugFile = "$templateDestinationfolder${pathSep}image.creation.debug.log"

  if (Test-Path -Path ${zipLocation} -PathType Leaf) {
    Debug-WmUifwLogI "Products zip file already exists, nothing to do"
    # Potential increment: force overwwrite
  }
  else {
    if (Test-Path -Path ${scriptLocation} -PathType Leaf) {
      Debug-WmUifwLogI "Image creation script already exists: $scriptLocation"
      # Potential increment: force overwwrite
    }
    else {
      $pl = Get-ProductListForTemplate "${TemplateId}"
      $su = Get-DownloadServerUrlForTemplate "${TemplateId}"
      $lines = @()
      $lines += "# Generated"
      $lines += "InstallProducts=$pl"
      $lines += "ServerURL=$su"
      $lines += "imagePlatform=W64"
      $lines += "InstallLocProducts="
      $lines += "# Workaround; installer wants this line even if it is overwritten by the commandline"
      $lines += "imageFile=products.zip"
    
      ${lines} | Out-File -FilePath $scriptLocation
    }

    $cmd = "${InstallerBinary} -console -scriptErrorInteract no -debugLvl verbose "
    $cmd += "-debugFile ""$debugFile""  -readScript ""$scriptLocation"" -writeImage ""${zipLocation}"" -user ""${UserName}"" -pass "

    Debug-WmUifwLogI "Executing the following image creation command:"
    Debug-WmUifwLogI "$cmd ***"
    $cmd += """${UserPassword}"""
    Invoke-AuditedCommand "$cmd" "CreateProductsZip"
  }
}

function New-BootstrapUpdMgr {
  param (
    [Parameter(Mandatory = $true)]
    [string]${BoostrapUpdateManagerBinary},
    [Parameter(Mandatory = $false)]
    [string]${UpdMgrHome} = "c:\webMethodsUpdateManager",
    [Parameter(Mandatory = $false)]
    [string]${OnlineMode} = $true,
    [Parameter(Mandatory = $false)]
    [string]${ImageFile} = "N/A" # ImageFile mandatory if bootstrapping offline
  )

  if (Test-Path -Path "${UpdMgrHome}${pathSep}bin${pathSep}UpdateManagerCMD.bat" -PathType Leaf) {
    Debug-WmUifwLogw "Installation already exists, nothing to do" 
  }
  else {
    if (-Not (Test-Path ${BoostrapUpdateManagerBinary} -PathType Leaf)) {
      Debug-WmUifwLogE "Bootstrap binary does not exist: ${BoostrapUpdateManagerBinary}"
      return 1
    }
    # Workaround for Windows: unzip and run the bat file manually
    # Warning: this is not documented and subject to change
    ${tempFolder} = Get-NewTempDir
    ${tempFolder} += "${pathSep}UpdMgrInstallation"
    Debug-WmUifwLogI "Using temporary folder ${tempFolder}"
    New-Item -Path ${tempFolder} -ItemType Container
    Expand-Archive -Path "${BoostrapUpdateManagerBinary}" -DestinationPath "${tempFolder}"
    if (-Not (Test-Path "${tempFolder}${pathSep}sum-setup.bat")) {
      Debug-WmUifwLogE "Wrong archive, it does not contain the file sum-setup.bat"
    }
    else {
      Push-Location .
      Set-Location -Path "${tempFolder}" || return 2
      $cmd = ".${pathSep}sum-setup.bat --accept-license -d ""${UpdMgrHome}"""
      if (${OnlineMode} -ne $true) {
        $cmd += "-i ""${ImageFile}"""
      }
      Debug-WmUifwLogI "Bootstrapping UpdateManager with the following command"
      Debug-WmUifwLogI "$cmd"
      Invoke-AuditedCommand "$cmd" "BootstrapUpdMgr"
      Pop-Location
    }
    Remove-Item "${tempFolder}" -Force -Recurse
  }
}

function Get-InventoryForTemplate {
  param (
    [Parameter(Mandatory = $true)]
    [string]${TemplateId},
    [Parameter(Mandatory = $false)]
    [string]${OutFile} = "",
    [Parameter(Mandatory = $false)]
    [string]${sumPlatformString} = "W64",
    [Parameter(Mandatory = $false)]
    [string]${updateManagerVersion} = "11.0.0.0040-0819",
    [Parameter(Mandatory = $false)]
    [string]${SumPlatformGroupString} = """WIN-ANY"""
  )

  $lProductsCsv = Get-ProductListForTemplate ${TemplateId}
  if ($lProductsCsv.Length -le 5) {
    Debug-WmUifwLogE "Wrong product list: $lProductsCsv"
    return 1
  }

  if (${Outfile} -eq "") {
    ${ts} = Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S'
    ${f} = "${PSScriptRoot}\..\03.templates\01.setup\${TemplateId}\trace\local\${ts}".Replace('\', ${pathSep})
    New-Item ${f} -ItemType Container
    ${Outfile} = "${f}${pathSep}inventory.json"
  }

  ${productsHash} = @{} #using a hash for unique values

  foreach ($productString in ${lProductsCsv}.split(',')) {
    $productCode = $productString.split('/')[-1]
    $verArray = $productString.split('/')[2].split('_')[-1].split('.')
    $productVersion = $verArray[0] + '.' + $verArray[1] + '.' + $verArray[2]
    ${productsHash}["$productCode"] = $productVersion
  }
  if (${productsHash}.Count -gt 0) {
    ${installedProducts} = @()
    foreach (${productId} in ${productsHash}.Keys) {
      ${installedProducts} += (@{
          "productId"   = ${productId}
          "displayName" = ${productId}
          "version"     = ${productsHash}["${productId}"]
        })
    }
    $document = @{
      "installedFixes"          = @()
      "installedSupportPatches" = @()
      "envVariables"            = @{
        "platformGroup"        = @(${SumPlatformGroupString})
        "UpdateManagerVersion" = "${updateManagerVersion}"
        "Hostname"             = "localhost"
        "platform"             = "$sumPlatformString"
      }
      "installedProducts"       = $installedProducts
    }
    $document | ConvertTo-Json -depth 100 | Out-File -Encoding "ascii" "${OutFile}"
  }
}

function Get-FixesImageForTemplate {
  param (
    [Parameter(Mandatory = $true)]
    [string]${TemplateId},
    [Parameter(Mandatory = $true)]
    [string]${BaseFolder},
    [Parameter(Mandatory = $true)]
    [string]${UpdMgrHome},
    [Parameter(Mandatory = $false)]
    [string]${PlatformString} = "W64",
    [Parameter(Mandatory = $true)]
    [string]${UserName},
    [Parameter(Mandatory = $true)]
    [string]${UserPassword}
  )

  if (-Not (Test-Path -Path "${UpdMgrHome}${pathSep}bin${pathSep}UpdateManagerCMD.bat" -PathType Leaf)) {
    Debug-WmUifwLogE "Incorrect Update Manager path: ${UpdMgrHome}"
    return 1
  }

  if (-Not (Test-Path -Path ${BaseFolder} -PathType Container)) {
    Debug-WmUifwLogW "Folder ${BaseFolder} does not exist, creating now..."
    New-Item -Path ${BaseFolder} -ItemType Container
  }
  ${currentDay} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%d')"
  ${templateDestinationfolder} = "${BaseFolder}\fixes\${currentDay}\${TemplateId}".Replace('\', ${pathSep})
  if (-Not (Test-Path -Path ${templateDestinationfolder} -PathType Container)) {
    Debug-WmUifwLogW "Folder ${templateDestinationfolder} does not exist, creating now..."
    New-Item -Path ${templateDestinationfolder} -ItemType Container
  }

  ${zipLocation} = "$templateDestinationfolder${pathSep}fixes.zip"
  if (Test-Path -Path "${zipLocation}" -PathType Leaf) {
    Debug-WmUifwLogI "Fixes image file already exists: ${zipLocation}"
  }
  else {
    ${inventoryLocation} = "${templateDestinationfolder}${pathSep}inventory.json"
    if (Test-Path -Path "${inventoryLocation}" -PathType Leaf) {
      Debug-WmUifwLogI "Inventory file ${inventoryLocation} already exists, continuing with this one"
    }
    else {
      Get-InventoryForTemplate -TemplateId ${TemplateId} -OutFile "${inventoryLocation}"
    }
    if (Test-Path -Path "${inventoryLocation}" -PathType Leaf) {
      Debug-WmUifwLogI "Inventory file ${inventoryLocation} already exists, continuing with this one"
    }
    else {
      Get-InventoryForTemplate -TemplateId ${TemplateId} -OutFile "${inventoryLocation}"
    }

    ${scriptLocation} = "${templateDestinationfolder}${pathSep}create.fixes.image.wmscript"

    $lines = @()
    $lines += "# Generated"
    $lines += "scriptConfirm=N"
    $lines += "installSP=N"
    $lines += "action=Create or add fixes to fix image"
    $lines += "selectedFixes=spro:all"
    # $lines += "installDir=${inventoryLocation}"
    # $lines += "imagePlatform=${PlatformString}"
    $lines += "createEmpowerImage=C"
  
    ${lines} | Out-File -FilePath ${scriptLocation}

    Push-Location .
    Set-Location ${UpdMgrHome}${pathSep}bin${pathSep}
    $cmd = "./UpdateManagerCMD.bat -selfUpdate false -readScript ""${scriptLocation}"""
    $cmd += " -installDir ""${inventoryLocation}"""
    $cmd += "-imagePlatform ${PlatformString}"
    $cmd += " -createImage ""${zipLocation}"""
    $cmd += "-empowerUser ""${UserName}"""
    $cmd += " -empowerPass "
    Debug-WmUifwLogI "Executing audited command:"
    Debug-WmUifwLogI "$cmd ***"
    $cmd += """${UserPassword}"""
    Invoke-AuditedCommand "$cmd" "ComputeFixesImage"
    Pop-Location
  }
}

function Set-DefaultGlobalVariable {
  param(
    [Parameter(mandatory = $true)]
    [string] ${WMUSF_VariableName},
    [Parameter(mandatory = $true)]
    [string] ${WMUSF_DefaultValue}
  )
  if ($null -eq (Get-Variable -Name "WMSCRIPT_adminPassword" -Scope Global -ErrorAction SilentlyContinue)) {
    Debug-WmUifwLogI "Setting default variable value for ${WMUSF_VariableName} to ${WMUSF_DefaultValue}"
    Set-Variable -Name "${WMUSF_VariableName}" -Scope Global -Value "${WMUSF_DefaultValue}" 
  }
}
function Set-DefaultWMSCRIPT_Vars {
  # Installation Script Related Parameters
  Set-DefaultGlobalVariable "WMSCRIPT_adminPassword" "Manage01"
  Set-DefaultGlobalVariable "WMSCRIPT_HostName" "localhost"
  Set-DefaultGlobalVariable "WMSCRIPT_IntegrationServerdiagnosticPort" "9999"
  Set-DefaultGlobalVariable "WMSCRIPT_IntegrationServerPort" "5555"
  Set-DefaultGlobalVariable "WMSCRIPT_IntegrationServersecurePort" "5543"
  Set-DefaultGlobalVariable "WMSCRIPT_mwsPortField" "8585"
  Set-DefaultGlobalVariable "WMSCRIPT_SPMHttpPort" "8092"
  Set-DefaultGlobalVariable "WMSCRIPT_SPMHttpsPort" "8093"
  Set-DefaultGlobalVariable "WMSCRIPT_StartMenuFolder" "webMethods"

  Set-DefaultGlobalVariable "WMUSF_UPD_MGR_HOME" "C:\webMethodsUpdateManager"
}

function Install-FixesFromImage {

}

function Get-TemplateBaseFolder {
  param(
    [Parameter(mandatory = $true)]
    [string] ${TemplateId}
  )
  ${templateFolder} = "${PSScriptRoot}\..\03.templates\01.setup\${TemplateId}".Replace('\', ${pathSep})
  if ( -Not (Test-Path -Path ${templateFolder} -PathType Container )) {
    Debug-WmUifwLogE "Template ${TemplateId} does not exist"
    return 1
  }
  if ( -Not (Test-Path -Path ${templateFolder}${pathSep}ProductsList.txt -PathType Leaf)) {
    Debug-WmUifwLogE "Folder ${templateFolder} exists, but it is not a template!"
    return 2
  }
  return ${templateFolder}
}

function New-InstallationFromTemplate {
  param(
    [Parameter(mandatory = $true)]
    [string] ${InstallHome},
    [Parameter(mandatory = $true)]
    [string] ${TemplateId},
    [Parameter(mandatory = $true)]
    [string] ${InstallerBinaryFile}
  )
  if (Test-Path -Path "${InstallHome}${pathSep}install" -PathType Container) {
    Debug-WmUifwLogW "Installation folder ${InstallHome} not empty, this may be an overinstall!"
  }

  ${templateFolder} = Get-TemplateBaseFolder "${TemplateId}"

  ${plFile} = "${templateFolder}${PathSep}ProductsList.txt"
  if ( -Not (Test-Path -Path ${plFile} -PathType Leaf )) {
    Debug-WmUifwLogE "File ${plFile} does not exist"
    return 2
  }

}

############## Initialize Variables
# This library is founded on a set of variables
# The scripts are expected to use scoped variables
# The variables resolved here are "global" for the script importing this module
function Resolve-WmusfCommonModuleLocals() {
  ${tempFolder} = ${env:WMUSF_TEMP_DIR} ?? `
    ${sysTemp} + ${pathSep} + "WMUSF"
  Set-Variable -Name 'TempSessionDir' -Value ${tempFolder} -Scope Script

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
  Debug-WmUifwLogD "WmUsHome: $(Get-WmUsfHomeDir)"

}
Resolve-WmusfCommonModuleLocals
