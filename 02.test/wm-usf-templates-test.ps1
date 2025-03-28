Import-Module "$PSScriptRoot/../01.code/wm-usf-common.psm1" -Force || exit 1

${comspec} = ${env:COMSPEC} ?? ${env:SHELL} ?? '/bin/sh'
#${posixCmd} = (${comspec}.Substring(0, 1) -eq '/') ? $true : $false

## Convenient Constants
${pathSep} = [IO.Path]::DirectorySeparatorChar
${posixCmd} = (${pathSep} -eq '/') ? $true : $false
${pesVersion} = ${env:PESTER_VERSION} ?? "5.7.1"

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

Describe "Templates" {
  Context 'Fundamentals' {
    It 'Checks base folder resolution' {
      Get-TemplateBaseFolder "a" | Should -Be 1
      Get-TemplateBaseFolder "DBC\1011" | Should -Be 2
      Get-TemplateBaseFolder "DBC\1011\full" | Should -Match "DBC.1011.full"
    }
  }
  Context 'Inventory Files' {
    It 'Generates inventory file in the temp location' {
      Get-InventoryForTemplate "DBC\1011\full"
    }

    It 'Checks templates default values' {
      Set-DefaultWMSCRIPT_Vars
      (Get-Variable -Name "WMSCRIPT_adminPassword" -Scope Global).Value | Should -Be "Manage01"
      'adminPassword=${WMSCRIPT_adminPassword}' | Invoke-EnvironmentSubstitution | Should -Be 'adminPassword=Manage01'
    }

    It 'Checks templates default values not overwriding provided values part 1' {
      Set-Variable -Name "WMSCRIPT_adminPassword" -Scope Global -Value "AnotherPassword"
      Set-DefaultWMSCRIPT_Vars
      (Get-Variable -Name "WMSCRIPT_adminPassword" -Scope Global).Value | Should -Be "AnotherPassword"
    }

    It 'Checks templates default values not overwriding provided values part 2' {
      Set-Variable -Name "WMSCRIPT_adminPassword" -Scope Global -Value "YetAnotherPassword"
      Set-DefaultWMSCRIPT_Vars
      'adminPassword=${WMSCRIPT_adminPassword}' | Invoke-EnvironmentSubstitution | Should -Be 'adminPassword=YetAnotherPassword'
    }
  }

  Context 'Product Lists' {
    It 'Gets DBC 1011 product list' {
      $pl = Get-ProductListForTemplate "DBC\1011\full" 
      $pl | Should -Not -Be $null
      $pl | Should -Not -Be 2
      $pl | Should -Not -Be ""
      Debug-WmUifwLogD "Read product list is: $pl"
    }
  }

  Context 'Downloads' {
    It 'Checks the server URL for product downloading' {
      Get-DownloadServerUrlForTemplate "DBC\1011\full" | Should -Be 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1011.cgi'
      Get-DownloadServerUrlForTemplate "DBC\1015\full" | Should -Be 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1015.cgi'
      Get-DownloadServerUrlForTemplate "anything" | Should -Be 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1015.cgi'
    }
  }

}
