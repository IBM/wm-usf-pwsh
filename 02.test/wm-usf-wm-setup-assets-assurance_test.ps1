Using module "../01.code/wm-usf-downloader.psm1"
Using module "../01.code/wm-usf-audit.psm1"
Using module "../01.code/wm-usf-result.psm1"

Describe "Resolves webMethods Downloadable Files" {
  Context 'Download Center' {

    It 'Resolves Default Installer for Windows' {
      $a = [WMUSF_Audit]::GetInstance()
      $a.LogI("Testing Default Installer for Windows")
      $d = [WMUSF_Downloader]::GetInstance()
      $r = $d.AssureDefaultInstaller()

      $r

      $r.Code | Should -Be 0
    }

    It 'Resolves Default Update Manager Bootstrap for Windows' {
      $d = [WMUSF_Downloader]::GetInstance()
      $d.AssureDefaultUpdateManagerBootstrap().Code | Should -Be 0
    }

    It 'Resolves Default Command Central Bootstrap for Windows' {
      $d = [WMUSF_Downloader]::GetInstance()
      $d.AssureDefaultCceBootstrap().Code | Should -Be 0
    }
  }
}
