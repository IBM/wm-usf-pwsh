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
  [string] $productsZipFullPath
  [string] $fixesZipFullPath
  [WMUSF_Audit] $audit
  hidden [WMUSF_SetupTemplate] $template

  WMUSF_Installation([string] $templateId) {
    $this.init($templateId, [IO.Path]::DirectorySeparatorChar + "webMethods", "", "")
  }

  WMUSF_Installation([string] $templateId, [string] $installPath) {
    $this.init($templateId, $installPath, "", "")
  }

  WMUSF_Installation([string] $templateId, [string] $installPath, [string] $givenproductsZipFullPath, [string] $givenfixesZipFullPath) {
    $this.init($templateId, $installPath, $givenproductsZipFullPath, $givenfixesZipFullPath)
  }

  hidden init([string] $templateId, [string] $installPath, [string] $givenproductsZipFullPath, [string] $givenfixesZipFullPath) {
    $this.TemplateId = $templateId
    $this.InstallDir = $installPath
    $this.productsZipFullPath = $givenproductsZipFullPath
    $this.fixesZipFullPath = $givenfixesZipFullPath
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.audit.LogI("WMUSF Installation Subsystem initialized")
    $this.audit.LogI("WMUSF Installation TemplateId: " + $this.TemplateId)
    $this.audit.LogI("WMUSF Installation InstallDir: " + $this.InstallDir)
    $this.template = [WMUSF_SetupTemplate]::new($this.TemplateId)
  }

  [WMUSF_Result] InstallProducts() {
    return $this.InstallProducts($null, $null, 'false')
  }

  [WMUSF_Result] InstallProducts([string] $givenproductsZipFullPath, [string] $givenfixesZipFullPath, [string] $skipFixes) {
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
    if (-Not (Test-Path -Path $this.template.productsZipFullPath -PathType Leaf)) {
      $r.Code = 2
      $r.Description = "The products file does not exist: " + $this.template.productsZipFullPath
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

    $r3 = $this.template.GenerateInstallScript($this.audit.LogSessionDir, "install.wmscript")
    if ($r3.Code -ne 0) {
      $r.Code = 4
      $r.Description = "Error generating install script, code: " + $r.Code
      $r.NestedResults += $r3
      $this.audit.LogE($r.Description)
      $this.audit.LogE($r.PayloadString)
      return $r
    }
    $installWmScript = $r3.PayloadString

    $installLogFile = $this.audit.LogSessionDir + [IO.Path]::DirectorySeparatorChar + "install.log"

    $installCmd = "$installerBinary -console -scriptErrorInteract no -debugLvl verbose"
    $installCmd += " -debugFile " + '"' + $installLogFile + '"'
    $installCmd += " -installDir " + '"' + $this.InstallDir + '"'
    $installCmd += " -readScript " + '"' + $installWmScript + '"'
    #$installCmd += " -readImage " + '"' + $this.template.productsZipFullPath + '"'

    $r4 = $this.audit.InvokeCommand($installCmd, "ProductInstall")
    if ( $r4.Code -ne 0) {
      $r.Code = 5
      $r.Description = "Error installing products, code: " + $r.Code
      $r.NestedResults += $r4
      $this.audit.LogE($r.Description)
      return $r
    }
    $r.Code = 0
    $r.Description = "Products installed successfully"
    return $r
  }

  [WMUSF_Result] Patch() {
    $this.ResolveFixesFoldersNames()
    return $this.Patch($this.template.latestfixesZipFullPath)
  }

  [WMUSF_Result] Patch([string] $givenfixesZipFullPath) {
    $r = [WMUSF_Result]::new()
    if (-Not (Test-Path -Path $this.template.latestfixesZipFullPath -PathType Leaf)) {
      $r.Code = 2
      $r.Description = "The fixes file does not exist: " + $this.template.latestfixesZipFullPath
      $this.audit.LogE($r.Description)
      return $r
    }

    $r1 = $this.template.GenerateFixApplyScriptFile($this.audit.LogSessionDir, $this.InstallDir, $givenfixesZipFullPath)
    if ($r1.Code -ne 0) {
      $r.Code = 1
      $r.Description = "Error generating fix apply script, code: " + $r.Code
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }
    $fixScriptFile = $r1.PayloadString

    $cmd = '.' + [IO.Path]::DirectorySeparatorChar + 'UpdateManagerCMD.bat'
    $cmd += ' -readScript "' + $fixScriptFile + '"'

    $this.audit.InvokeCommand($cmd, "FixApply")
    return $r
  }
}
