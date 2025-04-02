Using module "../01.code/wm-usf-audit.psm1"
Using module "../01.code/wm-usf-downloader.psm1"

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
    # i.e. either env or global work
    It 'Substitutes Given Variable' {
      ${inString} = 'begin|${TestVariable1}|${TestVariable2}|${TestVariable3}|end'
      [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Justification = 'Our substitution is not detected as a use by the linter')]
      ${TestVariable1} = "XX"
      Set-Variable -Name "TestVariable2" -Value "YY" -Scope Script
      Set-Variable -Name "TestVariable3" -Value "ZZ" -Scope Global
      ${inString} | Invoke-EnvironmentSubstitution | Should -Be 'begin|||ZZ|end'
    }

    # It 'Checks wmUsfHomeDir' {
    #   ${WmUsfHomeDir} = Get-WmUsfHomeDir
    #   ${WmUsfHomeDir} | Should -Not -Be $null
    #   Test-Path -Path ${WmUsfHomeDir} -PathType Container | Should -Be $true
    # }

    # It 'Checks ResolveGlobalScriptVar default framework variable' {
    #   Resolve-GlobalScriptVar ('WMUSF_UPD_MGR_HOME') | Should -Not -Be ""
    # }

    # It 'Checks ResolveGlobalScriptVar explictly set env var' {
    #   ${env:A} = "B"
    #   ${env:A} | Should -Be "B"
    #   Resolve-GlobalScriptVar ('A') | Should -Be "B"
    # }

    # It 'Checks ResolveGlobalScriptVar explictly set global var' {
    #   Set-Variable -Name "C" -Scope Global -Value "D" 
    #   Resolve-GlobalScriptVar ('C') | Should -Be "D"
    # }

    # It 'Checks ResolveGlobalScriptVar explictly set default global var' {
    #   Set-DefaultGlobalVariable "E" "F" 
    #   Resolve-GlobalScriptVar ('E') | Should -Be "F"
    # }

  }

  Context 'Checksums' {
    It 'Checks folder contents checksums' {
      ${pathSep} = [IO.Path]::DirectorySeparatorChar
      $downloader = [WMUSF_Downloader]::new()
      $testDir = $downloader.cacheDir

      Get-CheckSumsForAllFilesInFolder -Path $downloader.cacheDir
      Test-Path -Path ${testDir}${pathSep}checksums.txt | Should -Be $true
      Test-Path -Path ${testDir}${pathSep}checksums_ns.txt | Should -Be $true
    }
  }
}