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
  [string] $productsZipFile
  [string] $fixesZipFile
  [WMUSF_Audit] $audit
  hidden [WMUSF_SetupTemplate] $template

  WMUSF_Installation([string] $templateId) {
    $this.init($templateId, [IO.Path]::DirectorySeparatorChar + "webMethods", "", "")
  }
  WMUSF_Installation([string] $templateId, [string] $installPath) {
    $this.init($templateId, $installPath, "", "")
  }
  WMUSF_Installation([string] $templateId, [string] $installPath, [string] $givenProductsZipFile, [string] $givenFixesZipFile) {
    $this.init($templateId, $installPath, $givenProductsZipFile, $givenFixesZipFile)
  }

  hidden init([string] $templateId, [string] $installPath, [string] $givenProductsZipFile, [string] $givenFixesZipFile) {
    $this.TemplateId = $templateId
    $this.InstallDir = $installPath
    $this.productsZipFile = $givenProductsZipFile
    $this.fixesZipFile = $givenFixesZipFile
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.audit.LogI("WMUSF Installation Subsystem initialized")
    $this.audit.LogI("WMUSF Installation TemplateId: " + $this.TemplateId)
    $this.audit.LogI("WMUSF Installation InstallDir: " + $this.InstallDir)
    $this.template = [WMUSF_SetupTemplate]::new($this.TemplateId)
  }

  [WMUSF_Result] InstallProducts() {
    return $this.InstallProducts($null, $null, 'false')
  }

  [WMUSF_Result] InstallProducts([string] $givenProductsZipFile, [string] $givenFixesZipFile, [string] $skipFixes) {
    $r = [WMUSF_Result]::new()
    
    # TODO: expand for given zip files
    $r1 = $this.template.AssureImagesZipFiles()
    if ($r1.Code -ne 0) {
      $r.Code = 1
      $r.Description = "Error assuring images zip files, code: " + $r.Code
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }
    if (-Not (Test-Path -Path $this.template.productsZipFile -PathType Leaf)) {
      $r.Code = 2
      $r.Description = "The products file does not exist: " + $this.template.productsZipFile
      $this.audit.LogE($r.Description)
      return $r
    }
    $downloader = [WMUSF_Downloader]::GetInstance()
    $r2 = $downloader.GetInstallerBinary()
    if ($r2.Code -ne 0) {
      $r.Code = 3
      $r.Description = "Error getting installer binary, code: " + $r.Code
      $r.NestedResults += $r2
      $this.audit.LogE($r.Description)
      return $r
    }
    $installerBinary = $r2.PayloadString

    $installWmScript = $this.audit.LogSessionDir + [IO.Path]::DirectorySeparatorChar + "install.wmscript"

    $r3 = $this.template.GenerateProductsImageDownloadScript()
    if ($r3.Code -ne 0) {
      $r.Code = 4
      $r.Description = "Error generating install script, code: " + $r.Code
      $r.NestedResults += $r3
      $this.audit.LogE($r.Description)
      $this.audit.LogE($r.PayloadString)
      return $r
    }

    $r3.PayloadString | Out-File $installWmScript -Encoding ascii

    $installLogFile = $this.audit.LogSessionDir + [IO.Path]::DirectorySeparatorChar + "install.log"

    $installCmd = "$installerBinary -console -scriptErrorInteract no -debugLvl verbose"
    $installCmd += " -debugFile " + '"' + $installLogFile + '"'
    $installCmd += " -installDir " + '"' + $this.InstallDir + '"'
    $installCmd += " -readScript " + '"' + $installWmScript + '"'
    $installCmd += " -readImage " + '"' + $this.template.productsZipFile + '"'

    $r4 = $this.audit.InvokeCommand($installCmd, "ProductInstall")
    if ( $r4.Code -ne 0) {
      $r.Code = 5
      $r.Description = "Error installing products, code: " + $r.Code
      $r.NestedResults += $r4
      $this.audit.LogE($r.Description)
      return $r
    }

    return $r
  }

  [WMUSF_Result] Patch() {
    $r = [WMUSF_Result]::new()
    return $r
  }
}
