Using module "../../01.code/wm-usf-audit.psm1"
Using module "../../01.code/wm-usf-result.psm1"
#Using module "../../01.code/wm-usf-downloader.psm1"
Using module "../../01.code/wm-usf-setup-template.psm1"
#Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1"

$audit = [WMUSF_Audit]::GetInstance()

# Use env vars to iterate faster eventually
${templateId} = ${env:WMUSF_CURRENT_TEMPLATE_ID} ?? (Read-Host "Input a template ID, e.g. DBC\1011\full")
$audit.LogI("Considering templateId ${templateId}")

$template = [WMUSF_SetupTemplate]::new(${templateId}, 'true')

$r1 = $template.AssureProductsZipFile()
if ($r1.Code -ne 0) {
  $audit.LogE("AssureProductsZipFile failed")
  $r1
}

$r2 = $template.AssureFixesZipFile()
if ($r2.Code -ne 0) {
  $audit.LogE("AssureFixesZipFile failed")
  $r2
}