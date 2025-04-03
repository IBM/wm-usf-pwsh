Using module "../../01.code/wm-usf-installation.psm1"
Using module "../../01.code/wm-usf-audit.psm1"

$audit = [WMUSF_Audit]::GetInstance()
$installation = [WMUSF_Installation]::new("DBC\1011\full", "C:\webMethods\DBC")

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
