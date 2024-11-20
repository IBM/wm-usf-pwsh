$l="c:/y/sandbox/pwshSandboxStartup.log"
Function LogWrite
{
  Param ([string]$logstring)
  Add-content $l -value "02.b - $logstring"
}

LogWrite "Starting..."

LogWrite "Importing module Pester v ${env:PESTER_VERSION} ..."
Install-Module -Name Pester -RequiredVersion ${env:PESTER_VERSION} -Force -SkipPublisherCheck

LogWrite "Finished..."

# Start-Process notepad "$l"
Start-Process "C:\Program Files\PowerShell\7\pwsh.exe" -ArgumentList "-noexit", "-command c:\s\03.runLocalTests.ps1"