Using module "../01.code/wm-usf-audit.psm1"
${result} = Invoke-Pester -PassThru $PSScriptRoot/wmusf-audit_test.ps1
$nr = $result.FailedCount
if (${nr} -ne 0) {
  Write-Host "${nr} tests failed, below the Pester object"
  $result
}
