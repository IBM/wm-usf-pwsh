Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1" -Force || exit 1

# Use env vars to iterate faster eventually
$template = ${env:WMUSF_CURRENT_TEMPLATE_ID} ?? (Read-Host "Input a template ID, e.g. DBC\1011\full:")
Debug-WmUifwLogI "Considering templateId $template"

$folder = ${env:WMUSF_DOWNLOAD_BASE_FOLDER} ?? (Read-Host "Where is the download base folder?")
Debug-WmUifwLogI "Considering output base folder $folder"

$installer = ${env:WMUSF_INSTALLER_BINARY} ?? (Read-Host "Where is the installer executable?")
Debug-WmUifwLogI "Using Installer $installer"

$updMgrHome = ${env:WMUSF_UPD_MGR_HOME} ?? (Read-Host "Where is the Update Manager Home (it must exist!)?")
Debug-WmUifwLogI "Using Installer $installer"

$user = ${env:WMUSF_CURRENT_DOWNLOAD_USER} ?? (Read-Host "User for download")
Debug-WmUifwLogI "Considering download user $user"

$pwd = ${env:WMUSF_CURRENT_DOWNLOAD_PASSWORD} ?? (Read-UserSecret "User password for download")

Get-ProductsImageForTemplate `
  -TemplateId "$template" `
  -InstallerBinary "$installer" `
  -BaseFolder "$folder" `
  -UserName "$user" `
  -UserPassword "$pwd"

Get-FixesImageForTemplate `
  -TemplateId "$template" `
  -UpdMgrHome "$updMgrHome" `
  -BaseFolder "$folder" `
  -UserName "$user" `
  -UserPassword "$pwd"