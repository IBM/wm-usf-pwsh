Using module "../01.code/wm-usf-audit.psm1"
Using module "../01.code/wm-usf-result.psm1"
Using module "../01.code/wm-usf-setup-template.psm1"

Import-Module -Name "$PSScriptRoot/../01.code/wm-usf-setup-template.psm1"

Describe "Templates" {
  Context 'Fundamentals' {

    It 'Initializes a fake template' {
      $template = [WMUSF_SetupTemplate]::new("a\b\c")
      $template.templateFolderExists | Should -Be 'false'
    }

    It 'Checks a good template' {
      $template = [WMUSF_SetupTemplate]::new("DBC\1011\full")
      $template.templateFolderExists | Should -Be 'true'
      $template.productsListExists | Should -Be 'true'
      $template.installerScriptExists | Should -Be 'true'
    }
  }
  Context 'Inventory Files' {
    It 'Generates inventory file' {
      $template = [WMUSF_SetupTemplate]::new("DBC\1011\full")
      $r = $template.GenerateInventoryFile()
      $r.Code | Should -Be 0
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
      $template = [WMUSF_SetupTemplate]::new("DBC\1011\full")
      $pl = $template.GetProductList()
      $pl | Should -Not -Be $null
      $pl.Code | Should -Be 0
      $audit = [WMUSF_Audit]::GetInstance()
      $audit.LogD("Read product list is: " + $pl.PayloadString)
    }
    It 'Generates payload for products image download script' {
      $template = [WMUSF_SetupTemplate]::new("DBC\1011\full")
      $pl = $template.GenerateProductsImageDownloadScript()
      $pl | Should -Not -Be $null
      $pl.Code | Should -Be 0
      $audit = [WMUSF_Audit]::GetInstance()
      $audit.LogD("Generated payload for products image download script is: " + $pl.PayloadString)
    }
  }

  # TODO: move
  # Context 'Downloads' {
  #   It 'Checks the server URL for product downloading' {
  #     Get-DownloadServerUrlForTemplate "DBC\1011\full" | Should -Be 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1011.cgi'
  #     Get-DownloadServerUrlForTemplate "DBC\1015\full" | Should -Be 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1015.cgi'
  #     Get-DownloadServerUrlForTemplate "anything" | Should -Be 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1015.cgi'
  #   }
  # }
}
