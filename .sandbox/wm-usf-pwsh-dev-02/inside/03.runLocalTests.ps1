Import-Module "P:\01.code\wm-usf-common.psm1" -Force || exit 1

$a = Invoke-Pester -PassThru P:\02.test\wm-usf-common_test.ps1
$a

$b = Invoke-Pester -PassThru P:\02.test\wm-usf-templates_test.ps1
$b

$c = Invoke-Pester -PassThru P:\02.test\wm-usf-wm-setup-assets-assurance_test.ps1
$c

P:\02.test\sandbox\minSetup.ps1
