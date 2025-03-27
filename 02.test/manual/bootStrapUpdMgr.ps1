Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1" -Force || exit 1

${BootstrapBinary} = ${env:WMUSF_BOOTSTRAP_UPD_MGR_BIN} ?? (Read-Host "Input the full path for Update Manager Bootstrap binary")

New-BootstrapUpdMgr -BoostrapUpdateManagerBinary ${BootstrapBinary}
