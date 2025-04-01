Using module "../../01.code/wm-usf-audit.psm1"
Using module "../../01.code/wm-usf-result.psm1"
Using module "../../01.code/wm-usf-downloader.psm1"
Using module "../../01.code/wm-usf-setup-template.psm1"
Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1"

$audit = [WMUSF_Audit]::GetInstance()

# Use env vars to iterate faster eventually
$template = ${env:WMUSF_CURRENT_TEMPLATE_ID} ?? (Read-Host "Input a template ID, e.g. DBC\1011\full")
$audit.LogI("Considering templateId $template")

# $folder = ${env:WMUSF_DOWNLOAD_BASE_FOLDER} ?? (Read-Host "Where is the download base folder?")
# $audit.LogI("Considering output base folder $folder")

# $installer = ${env:WMUSF_INSTALLER_BINARY} ?? (Read-Host "Where is the installer executable?")
# $audit.LogI("Using Installer $installer")

# $updMgrHome = ${env:WMUSF_UPD_MGR_HOME} ?? (Read-Host "Where is the Update Manager Home (it must exist!)?")
# $audit.LogI("Using Installer $installer")

# $user = ${env:WMUSF_CURRENT_DOWNLOAD_USER} ?? (Read-Host "User for download")
# $audit.LogI("Considering download user $user")

# $pwd = ${env:WMUSF_CURRENT_DOWNLOAD_PASSWORD} ?? (Read-UserSecret "User password for download")

$template = [WMUSF_SetupTemplate]::new($template)

$r1 = $template.AssureProductsZipFile()
$r1

# Get-ProductsImageForTemplate `
#   -TemplateId "$template" `
#   -InstallerBinary "$installer" `
#   -BaseFolder "$folder" `
#   -UserName "$user" `
#   -UserPassword "$pwd"

# Get-FixesImageForTemplate `
#   -TemplateId "$template" `
#   -UpdMgrHome "$updMgrHome" `
#   -BaseFolder "$folder" `
#   -UserName "$user" `
#   -UserPassword "$pwd"