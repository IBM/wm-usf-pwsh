Using module "../../01.code/wm-usf-installation.psm1"
Using module "../../01.code/wm-usf-audit.psm1"
Using module "../../01.code/wm-usf-result.psm1"

$audit = [WMUSF_Audit]::GetInstance()


${template} = ${env:WMUSF_SBX_STARTUP_TEMPLATE} ?? "None"

if (${template} -eq "None") {
  $audit.LogI("Sandbox test -------------------> No template set, nothing to do at this point")
}
else {
  ${installDir} = ${env:WMUSF_SBX_STARTUP_INSTALL_DIR} ?? "C:\x\webMethods"
  $installation = [WMUSF_Installation]::new(${template}, ${installDir})

  $audit.LogI("Sandbox test -------------------> Starting installation of products")

  $r = $installation.InstallProducts()
  if ($r.Code -ne 0) {
    $audit.LogE("Sandbox test --------------------> Unable to install products: " + $r.Code)
    $r
    exit 1
  }
  $audit.LogI("Sandbox test -------------------> Completed installation of products, Patching the installation...")

  $installation.Patch()

  $audit.LogI("Sandbox test -------------------> Completed patching of products too")
}
