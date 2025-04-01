
Using module "./wm-usf-audit.psm1"
$audit = [WMUSF_Audit]::GetInstance()

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

## Framework Error and Result Management
class ResultObject {
  [int]$Code
  [string]$Description
  [string]$PayloadString
  [array]$Warnings
  [array]$Messages
  [array]$Errors
  [array]$NestedResults
  ResultObject() {
    $this.Code = 1
    $this.Description = "Initialized"
    $this.PayloadString = ""
    $this.Warnings = @()
    $this.Messages = @()
    $this.Errors = @()
    $this.NestedResults = @()
  }
}
function Get-NewResultObject {
  $r = [ResultObject]::new()
  return $r
}

function Get-QuickReturnObject {
  param(
    [Parameter(Mandatory = $false)]
    [ResultObject]${r},

    [Parameter(Mandatory = $false)]
    [string]${Code} = 0,

    [Parameter(Mandatory = $false)]
    [string]${Description} = "Success"
  )
  $r.Code = $Code
  $r.Description = $Description
  if ($Code -ne 0) {
    $r.Errors += $Description
    $audit.LogE("Returning error code ${Code}, description ${Description}")
  }
  return $r
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
  #$audit.LogD("Running in POSIX environment: ${posixCmd}"

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
  $audit.LogD( "Executing Command:")

  $audit.LogD( "${fullCmd}")

  try {
    Invoke-Expression "${fullCmd}"
  }
  catch {
    $audit.LogE( "Error caught while executing audited command with tag ${tag}")
    $_ | Out-File "${baseOutputFileName}.pwsh.err.txt"
    $_
  }
  ${exitCode} = Get-Content -Path "${baseOutputFileName}.exitcode.${ts}.txt"

  $audit.LogD( "Command exited with code ${exitCode}")
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

  $audit.LogI( "Reading boxes from file ${serverListFile} ...")
  Get-Content -Path "${serverListFile}" | ForEach-Object {
    $audit.LogI( "Checking if box $_ is active...")
    ${active} = Invoke-Expression "winrs -r:$_ ""echo 0"" || echo 254" 
    if (${active} -eq "0") {
      $audit.LogI( "Invoking command having tag ${tag} on server $_ ...")
      Invoke-AuditedCommand "winrs -r:$_ ${command}" "${tag}_$_"
    }
    else {
      $audit.LogE( "Server $_ not active!")
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
    $audit.LogE( "File ${plFile} does not exist")
    return 1
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
        $audit.LogI("Path ${directory} is not a directory! This library may not work as expected!")
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
        $audit.LogI("Created Directory ${directory}")
      }
      return "2"
    }
    else {
      if ($alsoLog) {
        $audit.LogE("Path ${directory} was NOT created!")
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

  $audit.LogI("Downloading file ${fullOutputDirectoryPath}/${fileName}")
  $audit.LogI("From ${url}")
  
  # assure destination folder
  $audit.LogD("Eventually create folder ${fullOutputDirectoryPath}...")
  New-Item -Path ${fullOutputDirectoryPath} -ItemType Directory -Force | Out-Null
  $fullFilePath = "${fullOutputDirectoryPath}/${fileName}"
  # Download the file
  Invoke-WebRequest -Uri ${url} -OutFile "${fullFilePath}.verify"

  # Calculate the SHA256 hash of the downloaded file
  $audit.LogD("Guaranteeing ${hashAlgorithm} checksum ${expectedHash}")
  ${fileHash} = Get-FileHash -Path "${fullFilePath}.verify" -Algorithm ${hashAlgorithm}
  $audit.LogD("File hash is " + ${fileHash}.Hash.ToString() + " .")
  #Write-Host $fileHash
  # Compare the calculated hash with the expected hash
  $r = $false
  if (${fileHash}.Hash -eq ${expectedHash}) {
    $audit.LogI("The file's $hashAlgorithm hash matches the expected hash.")
    $audit.LogD("Renaming ${fullFilePath}.verify to ${fullFilePath}")
    Rename-Item -Path "${fullFilePath}.verify" -NewName "${fileName}"
    $r = $true
  }
  else {
    Rename-Item -Path "${fullFilePath}.verify" -NewName "${fileName}.dubious"
    $audit.LogE("The file's ${hashAlgorithm} hash does not match the expected hash.")
    $audit.LogE("Got ${fileHash}.Hash, but expected ${expectedHash}!")
  }
  $audit.LogD("wmUifwCommon|Get-WebFileWithChecksumVerification returns ${r}")
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
  $audit.LogI("Resolving file $fullFilePath ...")

  # if File exists, just check the checksum
  if (Test-Path $fullFilePath -PathType Leaf) {
    $audit.LogD("file $fullFilePath already exists.")
    $fileHash = Get-FileHash -Path $fullFilePath -Algorithm $hashAlgorithm
    $audit.LogD("its hash is " + $fileHash.Hash)
    if ($fileHash.Hash -eq $expectedHash) {
      $audit.LogD("The file's $hashAlgorithm hash matches the expected hash.")
      return $true
    }
    else {
      $audit.LogE("The $fullFilePath file's $hashAlgorithm hash does not match the expected hash. Downloaded file renamed")
      $audit.LogE("Got " + ${fileHash}.Hash + ", but expected $expectedHash!")
      return $false
    }
  }
  $audit.LogD("file $fullFilePath does not exist. Attempting to download...")
  $r = Get-WebFileWithChecksumVerification `
    -url "$url" `
    -fullOutputDirectoryPath "$fullOutputDirectoryPath" `
    -fileName "$fileName" `
    -expectedHash "$expectedHash" `
    -hashAlgorithm "$hashAlgorithm"
  
  $audit.LogD("Resolve-WebFileWithChecksumVerification returns $r")
  return $r
}

function Resolve-DefaultInstaller() {
  param (
    # where to save the file 
    [Parameter(Mandatory = $false)]
    [string]${fullOutputDirectoryPath} = (Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME'),

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
    [string]${fullOutputDirectoryPath} = (Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') ,

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
    [string]${fullOutputDirectoryPath} = (Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME'),

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
    $audit.LogI("Removing older ${OutFile}")
    Remove-Item -Path ${OutFile}
  }

  if (Test-Path -Path ${OutFileNamesSorted}) {
    $audit.LogI("Removing older ${OutFileNamesSorted}")
    Remove-Item -Path ${OutFileNamesSorted}
  }

  # Get all files in the folder (and subfolders if needed)
  $files = Get-ChildItem -Path $Path -Recurse | Where-Object { ! $_.PSIsContainer }
  ${checksums} = @()
  ${checksums2} = @()
  foreach ($file in $files) {
    $audit.LogI("Computing the checksum for file: $($file.FullName)")
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
    [Parameter(Mandatory = $false)]
    [string]${BaseFolder} = `
    ((Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') + ${pathSep} + 'images') `
      ,
    [Parameter(Mandatory = $false)]
    [string]${InstallerBinary} = `
    ((Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') + ${pathSep} + ${defaultInstallerFileName}) `
      ,
    [Parameter(Mandatory = $true)]
    [string]${UserName},
    [Parameter(Mandatory = $true)]
    [string]${UserPassword}
  )
  $pl = Get-ProductListForTemplate ${TemplateId}
  if ($pl.Length -le 5) {
    $audit.LogE("Wrong product list: $pl")
    return 1
  }

  if (-Not (Test-Path -Path ${BaseFolder} -PathType Container)) {
    $audit.LogW("Folder ${BaseFolder} does not exist, creating now...")
    New-Item -Path ${BaseFolder} -ItemType Container
  }
  $templateDestinationfolder = "${BaseFolder}\products\${TemplateId}".Replace('\', ${pathSep})
  if (-Not (Test-Path -Path ${templateDestinationfolder} -PathType Container)) {
    $audit.LogW("Folder ${templateDestinationfolder} does not exist, creating now...")
    New-Item -Path ${templateDestinationfolder} -ItemType Container
  }
  ${zipLocation} = "$templateDestinationfolder${pathSep}products.zip"
  $scriptLocation = "$templateDestinationfolder${pathSep}image.creation.wmscript"
  $debugFile = "$templateDestinationfolder${pathSep}image.creation.debug.log"

  if (Test-Path -Path ${zipLocation} -PathType Leaf) {
    $audit.LogI("Products zip file already exists, nothing to do")
    # Potential increment: force overwwrite
  }
  else {
    if (Test-Path -Path ${scriptLocation} -PathType Leaf) {
      $audit.LogI("Image creation script already exists: $scriptLocation")
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

    $audit.LogI("Executing the following image creation command:")
    $audit.LogI("$cmd ***")
    $cmd += """${UserPassword}"""
    Invoke-AuditedCommand "$cmd" "CreateProductsZip"
  }
}

function New-BootstrapUpdMgr {
  param (
    [Parameter(Mandatory = $false)]
    [string]${BoostrapUpdateManagerBinary} = (Resolve-GlobalScriptVar 'WMUSF_BOOTSTRAP_UPD_MGR_BIN') ,
    [Parameter(Mandatory = $false)]
    [string]${UpdMgrHome} = "N/A",
    [Parameter(Mandatory = $false)]
    [string]${OnlineMode} = $true,
    [Parameter(Mandatory = $false)]
    [string]${ImageFile} = "N/A" # ImageFile mandatory if bootstrapping offline
  )

  if ("N/A" -eq ${UpdMgrHome}) {
    ${UpdMgrHome} = ('${WMUSF_UPD_MGR_HOME}' | Invoke-EnvironmentSubstitution)
    $audit.LogI("Resolved Update Manager Home from global: ${UpdMgrHome}")
  }

  if ("" -eq "${UpdMgrHome}") {
    $audit.LogE("Framework error!")
    return 9
  } 
  if (Test-Path -Path "${UpdMgrHome}${pathSep}bin${pathSep}UpdateManagerCMD.bat" -PathType Leaf) {
    $audit.LogW("Installation already exists, nothing to do")
  }
  else {
    if (-Not (Test-Path ${BoostrapUpdateManagerBinary} -PathType Leaf)) {
      $audit.LogE("Bootstrap binary does not exist: ${BoostrapUpdateManagerBinary}")
      return 1
    }

    # Workaround for Windows: unzip and run the bat file manually
    # Warning: this is not documented and subject to change
    ${tempFolder} = Get-NewTempDir
    ${tempFolder} += "${pathSep}UpdMgrInstallation"
    $audit.LogI("Using temporary folder ${tempFolder}")
    New-Item -Path ${tempFolder} -ItemType Container
    Expand-Archive -Path "${BoostrapUpdateManagerBinary}" -DestinationPath "${tempFolder}"
    if (-Not (Test-Path "${tempFolder}${pathSep}sum-setup.bat")) {
      $audit.LogE("Wrong archive, it does not contain the file sum-setup.bat")
    }
    else {
      Push-Location .
      Set-Location -Path "${tempFolder}" || return 2
      $cmd = ".${pathSep}sum-setup.bat --accept-license -d ""${UpdMgrHome}"""
      if (${OnlineMode} -ne $true) {
        $cmd += "-i ""${ImageFile}"""
      }
      $audit.LogI("Bootstrapping UpdateManager with the following command")
      $audit.LogI("$cmd")
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
    $audit.LogE("Wrong product list: $lProductsCsv")
    return 1
  }

  if (${Outfile} -eq "") {
    ${ts} = Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S'
    ${tempFolder} = Get-NewTempDir
    ${f} = "${tempFolder}\${TemplateId}\trace\local\${ts}".Replace('\', ${pathSep})
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
    [Parameter(Mandatory = $false)]
    [string]${BaseFolder} = `
    ((Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') + ${pathSep} + 'images') `
      ,
    [Parameter(Mandatory = $false)]
    [string]${UpdMgrHome} = (Resolve-GlobalScriptVar "WMUSF_UPD_MGR_HOME"),
    [Parameter(Mandatory = $false)]
    [string]${PlatformString} = "W64",
    [Parameter(Mandatory = $true)]
    [string]${UserName},
    [Parameter(Mandatory = $true)]
    [string]${UserPassword}
  )

  if (-Not (Test-Path -Path "${UpdMgrHome}${pathSep}bin${pathSep}UpdateManagerCMD.bat" -PathType Leaf)) {
    $audit.LogE("Incorrect Update Manager path: ${UpdMgrHome}")
    return 1
  }

  if (-Not (Test-Path -Path ${BaseFolder} -PathType Container)) {
    $audit.LogW("Folder ${BaseFolder} does not exist, creating now...")
    New-Item -Path ${BaseFolder} -ItemType Container
  }
  ${currentDay} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%d')"
  ${templateDestinationfolder} = "${BaseFolder}\fixes\${currentDay}\${TemplateId}".Replace('\', ${pathSep})
  if (-Not (Test-Path -Path ${templateDestinationfolder} -PathType Container)) {
    $audit.LogW("Folder ${templateDestinationfolder} does not exist, creating now...")
    New-Item -Path ${templateDestinationfolder} -ItemType Container
  }

  ${zipLocation} = "$templateDestinationfolder${pathSep}fixes.zip"
  if (Test-Path -Path "${zipLocation}" -PathType Leaf) {
    $audit.LogI("Fixes image file already exists: ${zipLocation}")
  }
  else {
    ${inventoryLocation} = "${templateDestinationfolder}${pathSep}inventory.json"
    if (Test-Path -Path "${inventoryLocation}" -PathType Leaf) {
      $audit.LogI("Inventory file ${inventoryLocation} already exists, continuing with this one")
    }
    else {
      Get-InventoryForTemplate -TemplateId ${TemplateId} -OutFile "${inventoryLocation}"
    }
    if (Test-Path -Path "${inventoryLocation}" -PathType Leaf) {
      $audit.LogI("Inventory file ${inventoryLocation} already exists, continuing with this one")
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
    $audit.LogI("Executing audited command:")
    $audit.LogI("$cmd ***")
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
  ${s} = '${env:' + "${WMUSF_VariableName}" + "}"
  ${a} = ${s} | Invoke-EnvironmentSubstitution
  # $audit.LogI ("a=--${a}--" + "${a}".Length)
  if ( 0 -eq "${a}".Length) {
    $v2 = (Get-Variable -Name "${WMUSF_VariableName}" -Scope Global -ErrorAction SilentlyContinue).Value
    if ( 0 -eq "${v2}".Length) {
      $audit.LogD("Setting default variable value for ${WMUSF_VariableName} to ${WMUSF_DefaultValue}")
      Set-Variable -Name "${WMUSF_VariableName}" -Scope Global -Value "${WMUSF_DefaultValue}"
    }
    else {
      $audit.LogD("Variable ${WMUSF_VariableName} already set to ${WMUSF_DefaultValue} via global scope")
    }
  }
  else {
    $audit.LogD("Variable ${WMUSF_VariableName} already set to ${a} via environment, setting global value now...")
    Set-Variable -Name "${WMUSF_VariableName}" -Scope Global -Value "${a}"
  }
}
function Set-DefaultWMSCRIPT_Vars {
  # Installation Script Related Parameters
  # Call this before using installer scripts
  Set-DefaultGlobalVariable "WMSCRIPT_adminPassword" "Manage01"
  Set-DefaultGlobalVariable "WMSCRIPT_HostName" "localhost"
  Set-DefaultGlobalVariable "WMSCRIPT_IntegrationServerdiagnosticPort" "9999"
  Set-DefaultGlobalVariable "WMSCRIPT_IntegrationServerPort" "5555"
  Set-DefaultGlobalVariable "WMSCRIPT_IntegrationServersecurePort" "5543"
  Set-DefaultGlobalVariable "WMSCRIPT_mwsPortField" "8585"
  Set-DefaultGlobalVariable "WMSCRIPT_SPMHttpPort" "8092"
  Set-DefaultGlobalVariable "WMSCRIPT_SPMHttpsPort" "8093"
  Set-DefaultGlobalVariable "WMSCRIPT_StartMenuFolder" "webMethods"
}

function Set-DefaultWMUSF_Vars {
  # Framework related
  if ( ${posixCmd} ) {
    Set-DefaultGlobalVariable "WMUSF_UPD_MGR_HOME" "/opt/wmUpdMgr11"
    Set-DefaultGlobalVariable "WMUSF_ARTIFACTS_CACHE_HOME" "/opt/WMUSF/Artifacts"
  }
  else {
    Set-DefaultGlobalVariable "WMUSF_UPD_MGR_HOME" "C:\webMethodsUpdateManager"
    Set-DefaultGlobalVariable "WMUSF_ARTIFACTS_CACHE_HOME" "C:\WMUSF\Artifacts"
  }
  Set-DefaultGlobalVariable "WMUSF_BOOTSTRAP_UPD_MGR_BIN" `
  ((Resolve-GlobalScriptVar "WMUSF_ARTIFACTS_CACHE_HOME") + ${pathSep} + ${defaultWmumBootstrapFileName})
}

function Resolve-GlobalScriptVar {
  param(
    [Parameter(mandatory = $true)]
    [string] ${VariableName}
  )
  ${a} = '${env:' + ${VariableName} + '}'
  ${v} = $a | Invoke-EnvironmentSubstitution
  if ("" -eq $v ) {
    ${a} = '${' + ${VariableName} + '}'
    ${v} = $a | Invoke-EnvironmentSubstitution
  }
  return ${v}
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
    $audit.LogE("Template ${TemplateId} does not exist")
    return 1
  }
  if ( -Not (Test-Path -Path ${templateFolder}${pathSep}ProductsList.txt -PathType Leaf)) {
    $audit.LogE("Folder --${templateFolder}-- exists, but it is not a template!")
    return 2
  }
  return ${templateFolder}
}

function Install-FixesForInstallation () {
}

function Install-FixesForUpdateManager () {
  param(
    [Parameter(Mandatory = $false)]
    [string]${UpdMgrHome} = (Resolve-GlobalScriptVar "WMUSF_UPD_MGR_HOME"),
    [Parameter(mandatory = $true)]
    [string] ${FixesImagefile}
  )

  $r = Get-NewResultObject
  if (-Not (Test-Path "${UpdMgrHome}/bin/UpdateManagerCMD.bat" -PathType Leaf)) {
    $r.Code = 2
    $r.Description = "Update Manager not found at ${UpdMgrHome}, install it first!"
    $audit.LogE("$r.Description")
    return $r
  }
  if (-Not (Test-Path "${FixesImagefile}" -PathType Leaf)) {
    $r.Code = 3
    $r.Description = "Image file not present: ${FixesImagefile}"
    $audit.LogE("$r.Description")
    return $r
  }

  $audit.LogI("Patching Update Manager installation at ${UpdMgrHome} from ${FixesImagefile}")
  Push-Location .
  Set-Location "${UpdMgrHome}/bin"
  $cmd = ".${pathSep}UpdateManagerCMD.bat -selfUpdate true -installFromImage ""${FixesImagefile}"""
  Invoke-AuditedCommand "$cmd" "UpdMgrPatchFromImage"
  Pop-Location
  $r.Code = 0
  $r.Description = "Done"
  return $r
}
function New-InstallationFromTemplate {
  param(
    [Parameter(mandatory = $true)]
    [string] ${InstallHome},
    [Parameter(mandatory = $true)]
    [string] ${TemplateId},
    [Parameter(Mandatory = $false)]
    [string]${InstallerBinaryFile} = `
    ((Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') + ${pathSep} + ${defaultInstallerFileName}) `
      ,
    [Parameter(mandatory = $true)]
    [string] ${ProductsImagefile},
    [Parameter(Mandatory = $false)]
    [string]${UpdMgrHome} = (Resolve-GlobalScriptVar "WMUSF_UPD_MGR_HOME"),
    [Parameter(mandatory = $false)]
    [string] ${FixesImagefile} = "N/A"
  )

  $r = Get-NewResultObject

  if (Test-Path -Path "${InstallHome}${pathSep}install" -PathType Container) {
    $audit.LogW("Installation folder ${InstallHome} not empty, this may be an overinstall!")
    $r.Warnings += "Installation folder ${InstallHome} not empty, this may be an overinstall!"
    $r
  }

  ${templateFolder} = Get-TemplateBaseFolder "${TemplateId}"
  if ( "{templateFolder}".Length -le 6 ) {
    $r.Code = 2
    $r.Description = "Error (code {templateFolder}) while getting template folder for template ${TemplateId}"
    $audit.LogD("$r.Description")
    return $r
  }

  if ( -Not (Test-Path -Path "${templateFolder}${pathSep}install.wmscript" -PathType Leaf )) {
    $audit.LogE("The template is not installable!")
    return 2
  }

  if ( -Not (Test-Path -Path ${InstallerBinaryFile} -PathType Leaf )) {
    $audit.LogE("Installer binary file ${InstallerBinaryFile} does not exist")
    return 3
  }

  ${sessionLogDir} = Get-LogSessionDir
  $audit.LogI("Using session log folder ${sessionLogDir} for installation")

  Set-DefaultWMSCRIPT_Vars

  $sf = Get-Content ${templateFolder}${pathSep}install.wmscript -Raw | Invoke-EnvironmentSubstitution
  $sf > "${sessionLogDir}${pathSep}install.wmscript"

  $pl = Get-ProductListForTemplate "${TemplateId}"

  Add-content "${sessionLogDir}${pathSep}install.wmscript" -value "ProductList=$pl"
  Add-content "${sessionLogDir}${pathSep}install.wmscript" `
    -value ("InstallDir=" + (Convert-EscapePathString "${InstallHome}"))
  Add-content "${sessionLogDir}${pathSep}install.wmscript" `
    -value ("imageFile=" + (Convert-EscapePathString "${ProductsImagefile}"))

  $cmd = "${InstallerBinaryFile} -console -scriptErrorInteract no -debugLvl verbose"
  $cmd += " -debugFile ""${sessionLogDir}${pathSep}install.log"""
  $cmd += " -installDir ""${InstallHome}"""
  $cmd += " -readScript ""${sessionLogDir}${pathSep}install.wmscript"""
  $cmd += " -readImage ""${ProductsImagefile}"""

  $audit.LogI("Command to execute is")
  $audit.LogI("$cmd")

  Invoke-AuditedCommand "$cmd" "Install"

  if ("N/A" -eq ${FixesImagefile}) {
    $audit.LogI("Skipping fixes installation, image not provided")
  }
  else {
    $r1 = Install-FixesForUpdateManager -FixesImagefile ${FixesImagefile}
    if ($r1.Code -ne 0) {
      $audit.LogE("Update manager patch failed, cannot continue")
    }
  }
}

function Convert-EscapePathString {
  param(
    [Parameter(mandatory = $true)]
    [string] ${PathString}
  )
  ${PathString}.Replace('\', '\\').Replace(':', '\:')
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

  Set-DefaultWMUSF_Vars

  $audit.LogI("Module wm-usf-common.psm1 initialized")
  $audit.LogD("AuditBaseDir: ${auditDir}")
  $audit.LogD("LogSessionDir: ${logSessionDir}")
  $audit.LogD("TempSessionDir: ${tempFolder}")
  $audit.LogD("WmUsHome: $(Get-WmUsfHomeDir)")

}
Resolve-WmusfCommonModuleLocals
