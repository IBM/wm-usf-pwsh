Using module "../../01.code/wm-usf-audit.psm1"
Using module "../../01.code/wm-usf-downloader.psm1"
Using module "../../01.code/wm-usf-setup-template.psm1"
Using module "../../01.code/wm-usf-result.psm1"

$audit = [WMUSF_Audit]::GetInstance()
$downloader = [WMUSF_Downloader]::GetInstance()

$audit.LogI( "Sandbox test -> Resolving Update Manage Installation")
$r1 = $downloader.AssureUpdateManagerInstallation()

if ($r1.Code -ne 0) {
  $audit.LogE("Sandbox test -> Unable to resolve Update Manager installation: " + $r1.Code)
  $r1
  exit 1
}

$audit.LogI("Sandbox test -> Resolving Default Installer binary")
$r3 = $downloader.AssureDefaultInstaller()

if ($r3.Code -ne 0) {
  $audit.LogE("Sandbox test -> Unable to resolve Installer binary: " + $r3.Code)
  exit 3
}

if ("${env:WMUSF_SBX_STARTUP_TEMPLATE}" -ne "" ) {
  $audit.LogI("System received the following template to be automatically set up: WMUSF_SBX_STARTUP_TEMPLATE=${env:WMUSF_SBX_STARTUP_TEMPLATE}")
}
else {
  $audit.LogI("System did not receive any template to be automatically set up, exiting")
  exit 0
}

$template = [WMUSF_SetupTemplate]::New(${env:WMUSF_SBX_STARTUP_TEMPLATE})
$r4 = $template.AssureImagesZipFiles
if ( $r4.Code -ne 0) {
  $audit.LogE("Sandbox test -> Unable to resolve template images zip files: " + $r4.Code)
  exit 4
}

exit 111


## Below code to be refactored
Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1"
${templateId} = "${env:WMUSF_SBX_STARTUP_TEMPLATE}"

${pathSep} = [IO.Path]::DirectorySeparatorChar

${artifactsFolder} = ((Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') + ${pathSep} + 'images')
${currentDay} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%d')"
${pFile} = "${artifactsFolder}\products\${templateId}\products.zip".Replace('\', ${pathSep})
${fFile} = "${artifactsFolder}\fixes\${currentDay}\${templateId}\fixes.zip".Replace('\', ${pathSep})

${credentialsNeeded} = $false

if (Test-Path -Path ${pFile} -PathType Leaf) {
  $audit.LogI("Products file already exist")
  if (-Not (Test-Path -Path ${fFile} -PathType Leaf)) {
    $audit.LogI( "Fixes file does not exist: ${fFile}")
    ${credentialsNeeded} = $true
  }
}
else {
  $audit.LogI("Products file does not exist: ${pFile}")
  ${credentialsNeeded} = $true
}

${user} = "N/A"
${pass} = "N/A"
if ( ${credentialsNeeded} ) {
  $audit.LogI("At least one image for database configurator setup is missing.")
  $audit.LogI("Provide download center username and password interactively or via the dedicated environment variables WMUSF_SBX_WM_DOWNLOAD_USER and WMUSF_SBX_WM_DOWNLOAD_PASS.")
  $user = ${env:WMUSF_SBX_WM_DOWNLOAD_USER} ?? (Read-Host "User for download")
  $audit.LogI("Considering download user $user")
  ${pass} = ${env:WMUSF_SBX_WM_DOWNLOAD_PASS} ?? (Read-UserSecret "User password for download")
}

$audit.LogI("Sandbox test -> Resolving DBC template binaries")
Get-ProductsImageForTemplate -TemplateId "${templateId}" `
  -BaseFolder "${artifactsFolder}" -UserName "${user}" -UserPassword "${pass}"

Get-FixesImageForTemplate -TemplateId "${templateId}" `
  -BaseFolder "${artifactsFolder}" -UserName "${user}" -UserPassword "${pass}"

## Still WIP: set up template. First run the variables setup from the folder test folder

${installHome} = "C:\webMethods"
$audit.LogI("Sandbox test -> Setting up webMethods from template ${templateId}")
New-InstallationFromTemplate -TemplateId "${templateId}" `
  -InstallHome "${installHome}" `
  -ProductsImagefile "${pFile}" `
  -FixesImagefile "${fFile}"

