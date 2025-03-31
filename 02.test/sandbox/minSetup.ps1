Import-Module "$PSScriptRoot/../../01.code/wm-usf-common.psm1" -Force || exit 1

Debug-WmUifwLogI "Sandbox test -> Resolving Default Update Manager Bootstrap binary"
Resolve-DefaultUpdateManagerBootstrap

Debug-WmUifwLogI "Sandbox test -> Bootstrapping Update Manager"
New-BootstrapUpdMgr

Debug-WmUifwLogI "Sandbox test -> Resolving Default Installer binary"
Resolve-DefaultInstaller

if ("${env:WMUSF_SBX_STARTUP_TEMPLATE}" -ne "" ) {
  Debug-WmUifwLogI "System received the follotin template to be automatically set up: WMUSF_SBX_STARTUP_TEMPLATE=${env:WMUSF_SBX_STARTUP_TEMPLATE}"
}

${templateId} = "${env:WMUSF_SBX_STARTUP_TEMPLATE}"
${pathSep} = [IO.Path]::DirectorySeparatorChar

${artifactsFolder} = ((Resolve-GlobalScriptVar 'WMUSF_ARTIFACTS_CACHE_HOME') + ${pathSep} + 'images')
${currentDay} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%Y-%m-%d')"
${pFile} = "${artifactsFolder}\products\${templateId}\products.zip".Replace('\', ${pathSep})
${fFile} = "${artifactsFolder}\fixes\${currentDay}\${templateId}\fixes.zip".Replace('\', ${pathSep})

${credentialsNeeded} = $false

if (Test-Path -Path ${pFile} -PathType Leaf) {
  Debug-WmUifwLogI "Products file already exist"
  if (-Not (Test-Path -Path ${fFile} -PathType Leaf)) {
    Debug-WmUifwLogI "Fixes file does not exist: ${fFile}"
    ${credentialsNeeded} = $true
  }
}
else {
  Debug-WmUifwLogI "Products file does not exist: ${pFile}"
  ${credentialsNeeded} = $true
}

${user} = "N/A"
${pass} = "N/A"
if ( ${credentialsNeeded} ) {
  Debug-WmUifwLogI "At least one image for database configurator setup is missing."
  Debug-WmUifwLogI "Provide download center username and password interactively or via the dedicated environment variables WMUSF_SBX_WM_DOWNLOAD_USER and WMUSF_SBX_WM_DOWNLOAD_PASS."
  $user = ${env:WMUSF_SBX_WM_DOWNLOAD_USER} ?? (Read-Host "User for download")
  Debug-WmUifwLogI "Considering download user $user"
  ${pass} = ${env:WMUSF_SBX_WM_DOWNLOAD_PASS} ?? (Read-UserSecret "User password for download")
}

Debug-WmUifwLogI "Sandbox test -> Resolving DBC template binaries"
Get-ProductsImageForTemplate -TemplateId "${templateId}" `
  -BaseFolder "${artifactsFolder}" -UserName "${user}" -UserPassword "${pass}"

Get-FixesImageForTemplate -TemplateId "${templateId}" `
  -BaseFolder "${artifactsFolder}" -UserName "${user}" -UserPassword "${pass}"

## Still WIP: set up template. First run the variables setup from the folder test folder

${installHome} = "C:\webMethods"
Debug-WmUifwLogI "Sandbox test -> Setting up webMethods from template ${templateId}"
New-InstallationFromTemplate -TemplateId "${templateId}" `
  -InstallHome "${installHome}" `
  -ProductsImagefile "${pFile}"
