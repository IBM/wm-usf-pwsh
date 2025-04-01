Using module "../01.code/wm-usf-audit.psm1"

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

    It 'Checks wmUsfHomeDir' {
      ${WmUsfHomeDir} = Get-WmUsfHomeDir
      ${WmUsfHomeDir} | Should -Not -Be $null
      Test-Path -Path ${WmUsfHomeDir} -PathType Container | Should -Be $true
    }

    It 'Checks ResolveGlobalScriptVar default framework variable' {
      Resolve-GlobalScriptVar ('WMUSF_UPD_MGR_HOME') | Should -Not -Be ""
    }

    It 'Checks ResolveGlobalScriptVar explictly set env var' {
      ${env:A} = "B"
      ${env:A} | Should -Be "B"
      Resolve-GlobalScriptVar ('A') | Should -Be "B"
    }

    It 'Checks ResolveGlobalScriptVar explictly set global var' {
      Set-Variable -Name "C" -Scope Global -Value "D" 
      Resolve-GlobalScriptVar ('C') | Should -Be "D"
    }

    It 'Checks ResolveGlobalScriptVar explictly set default global var' {
      Set-DefaultGlobalVariable "E" "F" 
      Resolve-GlobalScriptVar ('E') | Should -Be "F"
    }

  }

  Context 'Execution' {
    It 'Checks fundamental result object' {
      $ro = Get-NewResultObject
      $ro | Should -Not -Be $null
      $ro.Code | Should -Be 1
    }

    It 'Checks fundamental result object with error code' {
      $ro = Get-NewResultObject
      $r2 = Get-QuickReturnObject $ro 2 "Error message"
      $r2.Code | Should -Be 2
    }

    It 'Checks fundamental result object without code' {
      $ro = Get-NewResultObject
      $r2 = Get-QuickReturnObject $ro
      $r2.Code | Should -Be 0
    }

  }

  Context 'Checksums' {
    It 'Checks folder contents checksums' {
      ${pathSep} = [IO.Path]::DirectorySeparatorChar
      ${WmTempSessionDir} = Get-TempSessionDir
      Get-CheckSumsForAllFilesInFolder -Path ${WmTempSessionDir}
      Test-Path -Path ${WmTempSessionDir}${pathSep}checksums.txt | Should -Be $true
      Test-Path -Path ${WmTempSessionDir}${pathSep}checksums_ns.txt | Should -Be $true
    }
  }

  # TODO: Expand the script variable management
  Context 'Audit' {

    It 'Gets the current Temp session dir' {
      Get-TempSessionDir
      Get-TempSessionDir | Should -Not -Be ''
    }

    # It 'Sets Logging Folder' {
    #   Set-LogSessionDir '/tmp/log1'
    #   Get-LogSessionDir | Should -Be '/tmp/log1'
    # }

    It 'Sets Today Logging Folder' {
      ${pathSep} = [IO.Path]::DirectorySeparatorChar
      ${lsd} = Get-LogSessionDir

      ${localTempBaseDir} = ($env:TEMP ?? "/tmp") + ${pathSep} + "log1"
      Set-LogSessionDir -NewSessionDir ${localTempBaseDir}
      Get-LogSessionDir | Should -Be ${localTempBaseDir}
      Set-TodayLogSessionDir
      Get-LogSessionDir | Should -Not -Be ${localTempBaseDir}
      Set-LogSessionDir -NewSessionDir "${lsd}"
      Get-LogSessionDir | Should -Be "${lsd}"
    }

    It 'Invokes audited command' {
      if (${pathSep} -eq '/') {
        Invoke-AuditedCommand 'ls -lart /' 'test1' | Should -Be '0'
      }
      else {
        Invoke-AuditedCommand 'dir' 'test1' | Should -Be '0'
      }
    }

    It 'Invokes audited command having error' {
      if (${pathSep} -eq '/') {
        #$LastExitCode | Should -Be 0
        Invoke-AuditedCommand 'ls -lart \' 'test2' | Should -Not -Be '0'
      }
      else {
        #$LastExitCode | Should -Be $null
        Invoke-AuditedCommand 'dir CCC:' 'test2' | Should -Not -Be '0' 
      }
    }
  }

  Context 'Temp Directories' {
    It 'Checks trailing separator passed' {
      ${pathSep} = [IO.Path]::DirectorySeparatorChar
      ${localTempBaseDir} = "." + ${pathSep} + "tmp" + ${pathSep}
      ${newTmpDir} = $(Get-NewTempDir(${localTempBaseDir}))
      ${newTmpDir}.Substring(0, ${localTempBaseDir}.Length + 1) | `
        Should -Not -Be $(${localTempBaseDir} + ${pathSep} + ${pathSep})
    }
    It 'Checks trailing separator not passed' {
      ${pathSep} = [IO.Path]::DirectorySeparatorChar
      ${localTempBaseDir} = "." + ${pathSep} + "tmp"
      ${newTmpDir} = Get-NewTempDir(${localTempBaseDir})
      ${newTmpDir}.Substring(0, ${localTempBaseDir}.Length + 1) | `
        Should -Be $(${localTempBaseDir} + ${pathSep})
    }
    It 'Create and destroy new temp dir' {
      ${newTmpDir} = Get-NewTempDir($env:TEMP ?? "/tmp")
      Test-Path ${newTmpDir} | Should -be $false
      New-Item ${newTmpDir} -Force
      Test-Path ${newTmpDir} | Should -be $true
      Remove-Item ${newTmpDir}
      Test-Path ${newTmpDir} | Should -be $false
    }
  }

  # Todo - move to audit module
  # Context 'Logging' {
  #   It 'logs an info message' {
  #     Debug-WmUifwLogI "Log message" | Should -Be $null
  #   }
  # }
  
  Context 'String Utils' {
    It 'sets latest version for product installer code' {
      ${prdCode} = "e2ei/11/BR_10.5.0.0.1105/Broker/BrokerJMSShared"
      Resolve-ProductVersionToLatest -InstallerProductCode ${prdCode}  | Should -Be "e2ei/11/BR_10.5.0.0.LATEST/Broker/BrokerJMSShared"
    }

    It 'builds product list from multiline string' {
      ${prdCodes} = "e2ei/11/BR_10.5.0.0.LATEST/Broker/BrokerJMSShared"
      ${prdCodes} += [environment]::Newline
      ${prdCodes} += "e2ei/11/TPS_10.11.0.0.100/SCG/tppModelling"
      Build-ProductList -InstallationProductList ${prdCodes}  `
      | Should -Be "ProductList=e2ei/11/BR_10.5.0.0.LATEST/Broker/BrokerJMSShared,e2ei/11/TPS_10.11.0.0.100/SCG/tppModelling"
    }

    It 'Gets fake template product list' {
      Get-ProductListForTemplate "a/1011/b" | Should -Be 1
    }

    It 'Gets DBC 1011 product list' {
      $pl = Get-ProductListForTemplate "DBC\1011\full" 
      $pl | Should -Not -Be $null
      $pl | Should -Not -Be 2
      $pl | Should -Not -Be ""
      $audit = [WMUSF_Audit]::GetInstance()
      $audit.LogD("Read product list is: $pl")
    }

    It 'Checks Escape Strings Conversion' {
      Convert-EscapePathString 'c:\path\a' | Should -Be 'c\:\\path\\a'
    }
  }

}

Describe "Transports Assurance" {
  
}