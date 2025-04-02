Using module "../../01.code/wm-usf-installation.psm1"
Using module "../../01.code/wm-usf-audit.psm1"

$audit = [WMUSF_Audit]::GetInstance()
$installation = [WMUSF_Installation]::new("DBC\1011\full", "C:\webMethods\DBC")

$r = $installation.InstallProducts()
if ($r.Code -ne 0) {
  $audit.LogE("Sandbox test -> Unable to install products: " + $r.Code)
  exit 1
}
