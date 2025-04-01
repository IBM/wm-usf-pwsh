Context 'Audit' {
  Describe 'WMUSF_Audit' {
    It 'should have a static instance' {
      $instance = [WMUSF_Audit]::GetInstance()
      $instance | Should -Not -BeNullOrEmpty
      $instance.WMUSF_AuditTarget | Should -Not -BeNullOrEmpty
      #[WMUSF_Audit]::LogI("Test message")
    }
  }
}