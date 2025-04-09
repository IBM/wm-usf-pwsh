$l = "c:/y/sandbox/pwshSandboxStartup.log"
function LogWrite {
  Param ([string]$logstring)
  Add-content $l -value "02.b - $logstring"
  Write-Host "02.b - $logstring"
}

function SetBoxEnvVar {
  Param ([string]$VarName, [string]$VarValue)
  # This will be valid for the new shells
  [System.Environment]::SetEnvironmentVariable($VarName, $VarValue, [System.EnvironmentVariableTarget]::Machine)
  # This is for the process and following subshells
  # [System.Environment]::SetEnvironmentVariable($VarName, $VarValue, [System.EnvironmentVariableTarget]::Process)
}

$pesterModulePath = "C:\Program Files\WindowsPowerShell\Modules\Pester"

LogWrite "Starting..."

if (Test-Path -Path $pesterModulePath -PathType Container) {
  LogWrite "This box already has a pester version, removing it ..."
  $module = $pesterModulePath
  & takeown.exe /F $module /A /R
  & icacls.exe $module /reset
  & icacls.exe $module /grant "*S-1-5-32-544:F" /inheritance:d /T
  Remove-Item -Path $module -Recurse -Force -Confirm:$false
}

LogWrite "Importing module Pester v ${env:PESTER_VERSION} ..."
Install-Module -Name Pester -RequiredVersion ${env:PESTER_VERSION} -Force -SkipPublisherCheck


LogWrite "Setting framework variables on the machine ..."
# This speeds up testing. Values are valid from the next shell instances
SetBoxEnvVar 'WMUSF_AUDIT_DIR' "${env:WMUSF_AUDIT_DIR}"
SetBoxEnvVar 'WMUSF_DBC_HOME' "${env:WMUSF_DBC_HOME}"
SetBoxEnvVar 'WMUSF_UPD_MGR_HOME' "${env:WMUSF_UPD_MGR_HOME}"
SetBoxEnvVar 'WMUSF_DOWNLOADER_CACHE_DIR' "${env:WMUSF_DOWNLOADER_CACHE_DIR}"
if ( "${env:WMUSF_SBX_STARTUP_TEMPLATE}" -ne "" ) {
  LogWrite "User configured this sandbox to start with template ${env:WMUSF_SBX_STARTUP_TEMPLATE} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_TEMPLATE' "${env:WMUSF_SBX_STARTUP_TEMPLATE}"
}
if ( "${env:WMUSF_SBX_STARTUP_INSTALL_DIR}" -ne "" ) {
  LogWrite "User configured this sandbox install in folder ${env:WMUSF_SBX_STARTUP_INSTALL_DIR} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_INSTALL_DIR' "${env:WMUSF_SBX_STARTUP_INSTALL_DIR}"
}


if ( "${env:WMUSF_SBX_STARTUP_INSTALLER_BINARY}" -ne "" ) {
  LogWrite "User configured this sandbox installer binary ${env:WMUSF_SBX_STARTUP_INSTALLER_BINARY} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_INSTALLER_BINARY' "${env:WMUSF_SBX_STARTUP_INSTALLER_BINARY}"
}
if ( "${env:WMUSF_SBX_STARTUP_UM_BOOTSTRAP_BINARY}" -ne "" ) {
  LogWrite "User configured this sandbox bootstrap binary ${env:WMUSF_SBX_STARTUP_UM_BOOTSTRAP_BINARY} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_UM_BOOTSTRAP_BINARY' "${env:WMUSF_SBX_STARTUP_UM_BOOTSTRAP_BINARY}"
}
if ( "${env:WMUSF_SBX_STARTUP_PLATFORM_PRODUCTS_ZIP}" -ne "" ) {
  LogWrite "User configured this sandbox platform products zip file ${env:WMUSF_SBX_STARTUP_PLATFORM_PRODUCTS_ZIP} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_PLATFORM_PRODUCTS_ZIP' "${env:WMUSF_SBX_STARTUP_PLATFORM_PRODUCTS_ZIP}"
}
if ( "${env:WMUSF_SBX_STARTUP_PLATFORM_FIXES_ZIP}" -ne "" ) {
  LogWrite "User configured this sandbox  platform fixes zip file ${env:WMUSF_SBX_STARTUP_PLATFORM_FIXES_ZIP} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_PLATFORM_FIXES_ZIP' "${env:WMUSF_SBX_STARTUP_PLATFORM_FIXES_ZIP}"
}

SetBoxEnvVar 'WMUSF_DOWNLOAD_USER' "${env:WMUSF_DOWNLOAD_USER}"
# Use with care!
SetBoxEnvVar 'WMUSF_DOWNLOAD_PASSWORD' "${env:WMUSF_DOWNLOAD_PASSWORD}"

LogWrite "Finished setting up, running local tests..."

# Start-Process notepad "$l"
Start-Process "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "-noexit", "-command c:\s\03.runLocalTests.ps1"