Import-Module "$PSScriptRoot/../01.code/wm-usf-common.psm1" -Force || exit 1
${result} = Invoke-Pester -PassThru $PSScriptRoot/wm-usf-templates_test.ps1
$nr = $result.FailedCount
if (${nr} -ne 0) {
  Write-Host "${nr} tests failed, below the Pester object"
  $result
}
