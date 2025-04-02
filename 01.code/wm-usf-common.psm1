
Using module "./wm-usf-audit.psm1"
Using module "./wm-usf-result.psm1"
Using module "./wm-usf-downloader.psm1"
Using module "./wm-usf-setup-template.psm1"

Import-Module "$PSScriptRoot/wm-usf-utils.psm1"

$audit = [WMUSF_Audit]::GetInstance()
$downloader = [WMUSF_Downloader]::GetInstance()

## Convenient Constants
${pathSep} = [IO.Path]::DirectorySeparatorChar
# TODO: enforce, this is a bit naive

${posixCmd} = (${pathSep} -eq '/') ? $true : $false

function Get-WmUsfHomeDir() {
  (Get-Item ${PSScriptRoot}).parent
}

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
      $audit.InvokeCommand("winrs -r:$_ ${command}", "${tag}_$_")
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

# function Get-TemplateBaseFolder {
#   param(
#     [Parameter(mandatory = $true)]
#     [string] ${TemplateId}
#   )
#   ${templateFolder} = "${PSScriptRoot}\..\03.templates\01.setup\${TemplateId}".Replace('\', ${pathSep})
#   if ( -Not (Test-Path -Path ${templateFolder} -PathType Container )) {
#     $audit.LogE("Template ${TemplateId} does not exist")
#     return 1
#   }
#   if ( -Not (Test-Path -Path ${templateFolder}${pathSep}ProductsList.txt -PathType Leaf)) {
#     $audit.LogE("Folder --${templateFolder}-- exists, but it is not a template!")
#     return 2
#   }
#   return ${templateFolder}
# }

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
  $audit.InvokeCommand("$cmd", "UpdMgrPatchFromImage")
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

  $template = [WMUSF_SetupTemplate]::new(${TemplateId})
  $pl = $template.GetProductList().PayloadString

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

  $audit.InvokeCommand("$cmd", "01.InstallProducts")

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
