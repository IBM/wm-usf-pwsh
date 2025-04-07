Using module "../../01.code/wm-usf-audit.psm1"
Using module "../../01.code/wm-usf-result.psm1"
#Using module "../../01.code/wm-usf-downloader.psm1"
Using module "../../01.code/wm-usf-setup-template.psm1"
#Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1"

$audit = [WMUSF_Audit]::GetInstance()

# Use env vars to iterate faster eventually
$template = ${env:WMUSF_CURRENT_TEMPLATE_ID} ?? (Read-Host "Input a template ID, e.g. DBC\1011\full")
$audit.LogI("Considering templateId $template")

$template = [WMUSF_SetupTemplate]::new($template)

$r1 = $template.AssureProductsZipFile()
$r1
