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
SetBoxEnvVar 'WMUSF_UPD_MGR_HOME' "${env:WMUSF_UPD_MGR_HOME}"
SetBoxEnvVar 'WMUSF_DOWNLOADER_CACHE_DIR' "${env:WMUSF_DOWNLOADER_CACHE_DIR}"
if ( "${env:WMUSF_SBX_STARTUP_TEMPLATE}" -ne "" ) {
  LogWrite "User configured this sandbox to start with template ${env:WMUSF_SBX_STARTUP_TEMPLATE} setup"
  SetBoxEnvVar 'WMUSF_SBX_STARTUP_TEMPLATE' "${env:WMUSF_SBX_STARTUP_TEMPLATE}"
}

LogWrite "Finished setting up, running local tests..."

# Start-Process notepad "$l"
Start-Process "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "-noexit", "-command c:\s\03.runLocalTests.ps1"