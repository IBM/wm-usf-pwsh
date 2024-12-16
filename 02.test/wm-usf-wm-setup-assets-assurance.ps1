Import-Module "$PSScriptRoot/../01.code/wm-usf-common.psm1" -Force || exit 1

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

try {
  checkPester
}
catch {
  Write-Host "FATAL - Pester module KO!"
  exit 1
}

Describe "Resolves webMethods Downloadable Files" {
  Context 'Download Center' {
    It 'Resolves Installer for Windows' {
      $url = "https://empowersdc.softwareag.com/ccinstallers/SoftwareAGInstaller20240626-w64.exe"
      $ckSum = "cdfff7e2f420d182a4741d90e4ee02eb347db28bdaa4969caca0a3ac1146acd3"
      Resolve-WebFileWithChecksumVerification `
        -url $url -expectedHash $ckSum | Should -Be $true
    }

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