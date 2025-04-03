Using module "../01.code/wm-usf-audit.psm1"
Using module "../01.code/wm-usf-result.psm1"
Using module "../01.code/wm-usf-setup-template.psm1"

Import-Module -Name "$PSScriptRoot/../01.code/wm-usf-setup-template.psm1"

Describe "Templates" {
  Context 'Fundamentals' {

    It 'Initializes a fake template' {
      $template = [WMUSF_SetupTemplate]::new("a\b\c")
      $template.templateFolderFullPathExists | Should -Be 'false'
    }

    It 'Checks a good template' {
      $template = [WMUSF_SetupTemplate]::new("Example")
      $template.templateFolderFullPathExists | Should -Be 'true'
      $template.productsListFileFullPathExists | Should -Be 'true'
      $template.installerScriptFullPathExists | Should -Be 'true'
    }
  }
  Context 'Inventory Files' {
    It 'Generates inventory file' {
      $template = [WMUSF_SetupTemplate]::new("Example")
      $r = $template.GenerateInventoryFile()
      $r.Code | Should -Be 0
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

  Context 'Properties' {

    It 'Validates default properties are set correctly' {
      $lAudit = [WMUSF_Audit]::GetInstance()
      $defaultProperties = [WMUSF_SetupTemplate]::defaultGlobalProperties
      $defaultProperties | Should -Not -Be $null
      $defaultProperties | Should -BeOfType [hashtable]
      $defaultProperties.ContainsKey('WMSCRIPT_HostName') | Should -Be $true
      $defaultProperties['WMSCRIPT_HostName'] | Should -Be 'localhost'
    }

    It 'Checks the template properties with missing key' {
      $template = [WMUSF_SetupTemplate]::new("Example")
      $r = $template.AssureSetupProperties()
      $r.Code | Should -be 1
      "AAA ${WMSCRIPT_HostName} XX" | Invoke-EnvironmentSubstitution | Should -Be 'AAA  XX'
    }

    It 'Checks the template properties with explict env key' {
      $env:WMSCRIPT_OtherProperty = 'YYY'
      $template = [WMUSF_SetupTemplate]::new("Example")
      $r = $template.AssureSetupProperties()
      $r.Code | Should -be 0
      "AAA ${WMSCRIPT_HostName} XX" | Invoke-EnvironmentSubstitution | Should -Be 'AAA localhost XX'
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
