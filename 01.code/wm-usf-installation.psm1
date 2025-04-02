# This object represents an installation of webMethods done with this framework.
# Each installation is associated to a template

Using module "./wm-usf-result.psm1"
Using module "./wm-usf-downloader.psm1"
Using module "./wm-usf-setup-template.psm1"
Using module "./wm-usf-audit.psm1"
#       $audit.LogD("Read product list is: " + $pl.PayloadString)

class WMUSF_Installation {
  [string] $TemplateId
  [string] $InstallDir
  [WMUSF_Audit] $audit
  hidden [WMUSF_SetupTemplate] $template

  WMUSF_Installation([string] $templateId) {
    $this.init($templateId, [IO.Path]::DirectorySeparatorChar + "webMethods")
  }
  WMUSF_Installation([string] $templateId, [string] $installPath) {
    $this.init($templateId, $installPath)
  }
  hidden init([string] $templateId, [string] $installPath) {
    $this.TemplateId = $templateId
    $this.InstallDir = $installPath
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.audit.LogI("WMUSF Installation Subsystem initialized")
    $this.audit.LogI("WMUSF Installation TemplateId: " + $this.TemplateId)
    $this.audit.LogI("WMUSF Installation InstallDir: " + $this.InstallDir)
    $this.template = [WMUSF_SetupTemplate]::new($this.TemplateId)
  }

  [WMUSF_Result] InstallProducts() {
    $r = [WMUSF_Result]::new()
    
    $r1 = $this.template.AssureImagesZipFiles()
    if ($r1.Code -ne 0) {
      $r.Code = 1
      $r.Description = "Error assuring images zip files, code: " + $r.Code
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }

    return $r
  }
}