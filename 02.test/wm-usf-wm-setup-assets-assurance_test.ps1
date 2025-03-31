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