Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1" -Force || exit 1

${template} = Read-Host "Input a template ID"
${template}

Get-InventoryForTemplate $template
