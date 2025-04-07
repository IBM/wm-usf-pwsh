# This object represents an installation of webMethods done with this framework.
# Each installation is associated to a template

Using module "./wm-usf-result.psm1"
Using module "./wm-usf-downloader.psm1"
Using module "./wm-usf-setup-template.psm1"
Using module "./wm-usf-audit.psm1"
using module "./wm-usf-update-manager.psm1"
#       $audit.LogD("Read product list is: " + $pl.PayloadString)

class WMUSF_Installation {
  [string] $InstallDir
  static [WMUSF_UpdMgr] $UpdateManager = [WMUSF_UpdMgr]::GetInstance()
  [WMUSF_Audit] $audit
  hidden [WMUSF_SetupTemplate] $template

  WMUSF_Installation([string] ${TemplateId}) {
    $this.init(${TemplateId}, [IO.Path]::DirectorySeparatorChar + "webMethods", "", "")
  }

  WMUSF_Installation([string] ${TemplateId}) {
    $this.init(${TemplateId}, 'C:\webMethods')
  }

  WMUSF_Installation([string] ${TemplateId}, [string] ${InstallPath}) {
    $this.init(${TemplateId}, ${InstallPath})
  }

  hidden init([string] ${TemplateId}, [string] ${InstallPath}) {
    $this.InstallDir = ${InstallPath}
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.audit.LogI("WMUSF Installation Subsystem initialized")
    $this.audit.LogI("WMUSF Installation TemplateId: " + ${TemplateId})
    $this.audit.LogI("WMUSF Installation InstallDir: " + $this.InstallDir)
    $this.template = [WMUSF_SetupTemplate]::new($this.TemplateId)
  }

  [WMUSF_Result] InstallProducts() {
    [WMUSF_Result] $r = [WMUSF_Result]::new()
    $this.audit.LogD("Installing products with no parameters. Assuming default products zip file")
    $r1 = $this.template.ResolveProductsFoldersNames()
    if ( $r1.Code -ne 0) {
      $r.Code = 1
      $r.Description = "Error resolving products folders names, code: " + $r.Code
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }
    $this.audit.LogD("Taking the resolved products zip file: " + $this.template.productsZipFullPath)
    $r2 = $this.template.AssureProductsZipFile()
    if ($r2.Code -ne 0) {
      $r.Code = 2
      $r.Description = "Error assuring products zip file, code: " + $r.Code
      $r.NestedResults += $r2
      $this.audit.LogE($r.Description)
      return $r
    }
    return $this.InstallProducts($this.template.productsZipFullPath, 'false')
  }

  [WMUSF_Result] InstallProducts([string] ${GivenProductsZipFullPath}, [string] $skipFixes) {
    $r = [WMUSF_Result]::new()

    if (-Not (Test-Path -Path ${GivenProductsZipFullPath} -PathType Leaf)) {
      $r.Code = 1
      $r.Description = "The products zip image file does not exist: " + ${GivenProductsZipFullPath}
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
    $this.audit.LogD("Patching installation with no parameters")
    $this.template.ResolveFixesFoldersNames()
    $this.audit.LogD("Taking the resolved fixes zip file: " + $this.template.fixesZipFullPath)
    return $this.updateManager.PatchInstallation($this.InstallDir, $this.template.fixesZipFullPath)
  }

  [WMUSF_Result] Patch([string] ${GivenFixesZipFullPath}) {
    $this.audit.LogI("Patching installation with fixes zip file: " + ${GivenFixesZipFullPath})
    return $this.updateManager.PatchInstallation($this.InstallDir, ${GivenFixesZipFullPath})
  }
}
