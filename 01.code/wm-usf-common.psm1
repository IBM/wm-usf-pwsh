
Using module "./wm-usf-audit.psm1"
Using module "./wm-usf-result.psm1"
Using module "./wm-usf-setup-template.psm1"

Import-Module "$PSScriptRoot/wm-usf-utils.psm1"

$audit = [WMUSF_Audit]::GetInstance()

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

function Install-FixesForUpdateManager () {
  param(
    [Parameter(Mandatory = $false)]
    [string]${UpdMgrHome} = (Resolve-GlobalScriptVar "WMUSF_UPD_MGR_HOME"),
    [Parameter(mandatory = $true)]
    [string] ${FixesImagefile}
  )


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
