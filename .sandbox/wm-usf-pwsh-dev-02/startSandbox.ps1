Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1" -Force

${env:currentDirectory} = $PSScriptRoot

${tempDir} = Get-NewTempDir(${env:TEMP})

New-Item -ItemType Directory -Path "${tempDir}" -Force

Get-Content -Raw "$PSScriptRoot/wm-usf-02.wsb" | Invoke-EnvironmentSubstitution > "${tempDir}/wm-usf-02.wsb"

Write-Output "Executing from temp folder ${tempDir}"

Start-Process -FilePath "C:\Windows\System32\WindowsSandbox.exe" `
  -ArgumentList "${tempDir}/wm-usf-02.wsb"
