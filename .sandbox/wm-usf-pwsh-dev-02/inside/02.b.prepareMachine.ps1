$l = "c:/y/sandbox/pwshSandboxStartup.log"
function LogWrite {
  Param ([string]$logstring)
  Add-content $l -value "02.b - $logstring"
}

function SetBoxEnvVar {
  Param ([string]$VarName, [string]$VarValue)
  # This will be valid for the new shells
  [System.Environment]::SetEnvironmentVariable($VarName, $VarValue, [System.EnvironmentVariableTarget]::Machine)
  # This is for the process and following subshells
  [System.Environment]::SetEnvironmentVariable($VarName, $VarValue, [System.EnvironmentVariableTarget]::Process)
}

LogWrite "Starting..."

LogWrite "Importing module Pester v ${env:PESTER_VERSION} ..."
Install-Module -Name Pester -RequiredVersion ${env:PESTER_VERSION} -Force -SkipPublisherCheck


LogWrite "Setting framework variables on the machine ..."
# This speeds up testing. Values are valid from the next shell instances
SetBoxEnvVar 'WMUSF_AUDIT_DIR' 'c:\y\sandbox\WMUSF_Audit'
SetBoxEnvVar 'WMUSF_UPD_MGR_HOME' 'C:\wmUpdMgr'
SetBoxEnvVar 'WMUSF_ARTIFACTS_CACHE_HOME' 'K:\'

LogWrite "Finished setting up, running local tests..."

# Start-Process notepad "$l"
Start-Process "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "-noexit", "-command c:\s\03.runLocalTests.ps1"