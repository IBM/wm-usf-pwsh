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
  }

  Context 'Checksums' {
    It 'Checks folder contents checksums' {
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
      if (${posixCmd}) {
        Invoke-AuditedCommand 'ls -lart /' 'test1' | Should -Be '0'
      }
      else {
        Invoke-AuditedCommand 'dir' 'test1' | Should -Be '0'
      }
    }

    It 'Invokes audited command having error' {
      if (${posixCmd}) {
        $LastExitCode | Should -Be 0
        Invoke-AuditedCommand 'ls -lart \' 'test2' | Should -Not -Be '0'
      }
      else {
        $LastExitCode | Should -Be $null
        Invoke-AuditedCommand 'dir CCC:' 'test2' | Should -Not -Be '0' 
      }
    }
  }

  Context 'Temp Directories' {
    It 'Checks trailing separator passed' {
      ${localTempBaseDir} = "." + ${pathSep} + "tmp" + ${pathSep}
      ${newTmpDir} = $(Get-NewTempDir(${localTempBaseDir}))
      ${newTmpDir}.Substring(0, ${localTempBaseDir}.Length + 1) | `
        Should -Not -Be $(${localTempBaseDir} + ${pathSep} + ${pathSep})
    }
    It 'Checks trailing separator not passed' {
      ${localTempBaseDir} = "." + ${pathSep} + "tmp"
      ${newTmpDir} = Get-NewTempDir(${localTempBaseDir})
      ${newTmpDir}.Substring(0, ${localTempBaseDir}.Length + 1) | `
        Should -Be $(${localTempBaseDir} + ${pathSep})
      ${localTempBaseDir}
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

  Context 'Logging' {
    It 'logs an info message' {
      Debug-WmUifwLogI "Log message" | Should -Be $null
    }
  }
  
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
      Debug-WmUifwLogD "Read product list is: $pl"
    }
  }

}

Describe "Transports Assurance" {
  
}