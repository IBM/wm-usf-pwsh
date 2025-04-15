Using module "../../01.code/wm-usf-installation.psm1"
Using module "../../01.code/wm-usf-audit.psm1"
Using module "../../01.code/wm-usf-result.psm1"

$audit = [WMUSF_Audit]::GetInstance()

${templateId} = ${env:WMUSF_SBX_MANUAL_INSTALL_TEMPLATE} ?? (Read-Host "Input the template to install")
${installDir} = ${env:WMUSF_SBX_MANUAL_INSTALL_HOME} ?? (Read-Host "Input the folder to install to")
${installerBinary} = ${env:WMUSF_SBX_MANUAL_INSTALLER_BIN} ?? (Read-Host "Input the installer binary full path")
${productsZip} = ${env:WMUSF_SBX_MANUAL_PRODUCTS_ZIP} ?? (Read-Host "Input the full path to products zip file")
${fixesZip} = ${env:WMUSF_SBX_MANUAL_FIXES_ZIP} ?? (Read-Host "Input the full path to fixes zip file")

if (${templateId} -eq "None") {
  $audit.LogI("Sandbox test -------------------> No template set, nothing to do at this point")
}
else {
  $installation = [WMUSF_Installation]::new(${templateId}, ${installDir}, ${installerBinary}, ${productsZip}, $null, ${fixesZip})

  $audit.LogI("Sandbox test -------------------> Starting installation of products")

  $r = $installation.InstallProducts()
  if ($r.Code -ne 0) {
    $audit.LogE("Sandbox test --------------------> Unable to install products: " + $r.Code)
    $r
    exit 1
  }
  $audit.LogI("Sandbox test -------------------> Completed installation of products, Patching the installation...")

  $installation.Patch(${fixesZip})

  $audit.LogI("Sandbox test -------------------> Completed patching of products too")
}
