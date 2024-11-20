Import-Module "$PSScriptRoot/../01.code/wm-usf-common.psm1" -Force

function checkPester() {
  $pesterModules = @( Get-Module -Name "Pester" -ErrorAction "SilentlyContinue" );
  if ( ($null -eq $pesterModules) -or ($pesterModules.Length -eq 0) ) {
    Import-Module -Name Pester -RequiredVersion ${env:PESTER_VERSION}
    $pesterModules = @( Get-Module -Name "Pester" -ErrorAction "SilentlyContinue" );
    if ( ($null -eq $pesterModules) -or ($pesterModules.Length -eq 0) ) {
      throw "no pester module loaded!";
    }
  }

  if ( $pesterModules.Length -gt 1 ) {
    throw "multiple pester modules loaded!";
  }
  if ( $pesterModules[0].Version -ne ([version] "${env:PESTER_VERSION}") ) {
    throw "unsupported pester version '$($pesterModules[0].Version)'";
  }
  Write-Output "Pester module OK"
}
checkPester || exit 1 # Cannot continue if pester setup is incorrect

Describe "Basics" {
  Context 'Environment Substitutions' {
    It 'Substitutes env vars' {
      $inString = 'aa ${env:b} cc'
      $env:b = 'B'
      $inString | Invoke-EnvironmentSubstitution | Should -Be 'aa B cc'
    }
    It 'Substitutes absent vars' {
      $inString = 'aa ${env:b} cc'
      $env:b = $null
      $inString | Invoke-EnvironmentSubstitution | Should -Be 'aa  cc'
    }
  }

  Context 'Temp Directories' {
    It 'Check trailing separator passed' {
      ${newTmpDir} = $(Get-NewTempDir("/tmp" + [IO.Path]::DirectorySeparatorChar))
      ${newTmpDir}.Substring(0, 6) | Should -Not -Be $("/tmp" + [IO.Path]::DirectorySeparatorChar + [IO.Path]::DirectorySeparatorChar)

    }
    It 'Check  trailing separator not passed' {
      ${newTmpDir} = Get-NewTempDir("/tmp")
      ${newTmpDir}.Substring(0, 5) | Should -Be $("/tmp" + [IO.Path]::DirectorySeparatorChar)

    }
    It 'Create and destroy new temp dir' {
      ${newTmpDir} = Get-NewTempDir($env:TEMP ?? "/tmp")
      Test-Path ${newTmpDir} | Should -be $false
      New-Item ${newTmpDir} -Force
      Test-Path ${newTmpDir} | Should -be $true
      Remove-Item ${newTmpDir}
      Test-Path ${newTmpDir} | Should -be $false
    }
  }
}