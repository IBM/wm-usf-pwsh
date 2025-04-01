Import-Module "$PSScriptRoot/../01.code/wm-usf-utils.psm1"
Import-Module "$PSScriptRoot/../01.code/wm-usf-common.psm1"
${result} = Invoke-Pester -PassThru $PSScriptRoot/wm-usf-common_test.ps1
$nr = $result.FailedCount
if (${nr} -ne 0) {
  Write-Host "${nr} tests failed, below the Pester object"
  $result
}
