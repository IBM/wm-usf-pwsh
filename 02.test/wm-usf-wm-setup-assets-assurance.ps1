Import-Module "$PSScriptRoot/../01.code/wm-usf-common.psm1" -Force || exit 1
${pesVersion} = ${env:PESTER_VERSION} ?? "5.6.1"

function checkPester() {
  $pesterModules = @( Get-Module -Name "Pester" -ErrorAction "SilentlyContinue" );
  if ( ($null -eq $pesterModules) -or ($pesterModules.Length -eq 0) ) {
    Import-Module -Name Pester -RequiredVersion ${pesVersion}
    $pesterModules = @( Get-Module -Name "Pester" -ErrorAction "SilentlyContinue" );
    if ( ($null -eq $pesterModules) -or ($pesterModules.Length -eq 0) ) {
      throw "no pester module loaded!";
    }
  }

  if ( $pesterModules.Length -gt 1 ) {
    throw "multiple pester modules loaded!";
  }
  if ( $pesterModules[0].Version -ne ([version] "${pesVersion}") ) {
    throw "unsupported pester version '$($pesterModules[0].Version)'";
  }
  Write-Output "Pester module OK"
}

try {
  checkPester
}
catch {
  Write-Host "FATAL - Pester module KO!"
  $_
  exit 1 # Cannot continue if pester setup is incorrect
}

Describe "Resolves webMethods Downloadable Files" {
  Context 'Download Center' {

    It 'Resolves Default Installer for Windows' {
      Resolve-DefaultInstaller | Should -Be $true
    }

    It 'Resolves Default Update Manager Bootstrap for Windows' {
      Resolve-DefaultUpdateManagerBootstrap | Should -Be $true
    }

    It 'Resolves Default Command Central Bootstrap for Windows' {
      Resolve-DefaultCceBootstrap | Should -Be $true
    }
  }
}