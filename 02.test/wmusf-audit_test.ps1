Context 'Audit' {
  Describe 'WMUSF_Audit' {
    It 'should have a static instance' {
      $instance = [WMUSF_Audit]::GetInstance()
      $instance | Should -Not -BeNullOrEmpty
      $instance.WMUSF_AuditTarget | Should -Not -BeNullOrEmpty
      #[WMUSF_Audit]::LogI("Test message")
    }

    It 'should invoke simple echo HW' {
      $audit = [WMUSF_Audit]::GetInstance()
      $r = $audit.InvokeCommand('echo "Hello World"', 'hello-w')
      $r.Code | Should -Be 0
    }

    It 'should invoke simple erroneous command' {
      $audit = [WMUSF_Audit]::GetInstance()
      $r = $audit.InvokeCommand('echox "a"', 'ecox')
      $r.Code | Should -Be 2
    }

    It 'should invoke simple good command' {
      $audit = [WMUSF_Audit]::GetInstance()
      $r = $audit.InvokeCommand('Get-Process', 'Get-Process')
      $r.Code | Should -Be 0
    }
  }
}
