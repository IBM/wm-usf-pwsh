Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1" -Force

${env:currentDirectory} = $PSScriptRoot

$ts = Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%dT%H%M%S'

${env:wmusf-temp-dir} = $PSScriptRoot + "\..\..\10.local-files\sbx\Runs\r-${ts}"

New-Item -ItemType Directory -Path "${env:wmusf-temp-dir}" -Force

Get-Content -Raw "$PSScriptRoot/wm-usf-02.wsb" | Invoke-EnvironmentSubstitution > "${env:wmusf-temp-dir}/wm-usf-02.wsb"

Write-Output "Executing from temp folder ${env:wmusf-temp-dir}"

Start-Process -FilePath "C:\Windows\System32\WindowsSandbox.exe" `
  -ArgumentList "${env:wmusf-temp-dir}/wm-usf-02.wsb"
