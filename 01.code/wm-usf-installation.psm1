# This object represents an installation of webMethods done with this framework.
# Each installation is associated to a template

Using module "./wm-usf-result.psm1"
Using module "./wm-usf-downloader.psm1"
Using module "./wm-usf-setup-template.psm1"
Using module "./wm-usf-audit.psm1"
using module "./wm-usf-update-manager.psm1"
#       $audit.LogD("Read product list is: " + $pl.PayloadString)

# TODO / Option
# Skip fixes scenarios not fully implemented. Not needed now, they might be needed in the future.
# For now, always ensure that fixes are computed upfront, as it should be, not contextual to installation

class WMUSF_Installation {
  # Where to install? Accept over-installs
  [string] $InstallDir
  # Which Installer binary to use?
  [string] $CurrentInstallerBinaryFullPath
  # which products fix image to use?
  [string] $CurrentProductsZipFullPath

  # By default always consider fixes. May avoid to install eventually, when the products are just published as GA
  [string] $skipFixes

  # which fixes zip image to use?
  [string] $CurrentFixesZipFullPath

  # which fixes zip image to use?
  [string] $CurrentPropertiesFile

  [WMUSF_UpdMgr] $UpdateManager
  [WMUSF_Audit] $audit
  hidden [WMUSF_SetupTemplate] $template

  # Full Defaults
  WMUSF_Installation([string] ${TemplateId}) {
    $this.init(${TemplateId}, [IO.Path]::DirectorySeparatorChar + "webMethods", $null, $null, $null, $null)
  }

  WMUSF_Installation([string] ${TemplateId}, [string] ${InstallPath}) {
    $this.init(${TemplateId}, ${InstallPath}, $null, $null, $null, $null)
  }

  # Eventually install but don't try to patch. This may be the case when the products are new
  WMUSF_Installation(
    [string] ${TemplateId},
    [string] ${InstallPath},
    [string] ${GivenInstallerBinary},
    [string] ${GivenInstallZip},
    [string] ${GivenPropertiesFile}
  ) {
    $this.init(${TemplateId}, ${InstallPath}, ${GivenInstallerBinary}, ${GivenInstallZip}, ${GivenPropertiesFile}, $null)
  }

  WMUSF_Installation(
    [string] ${TemplateId},
    [string] ${InstallPath},
    [string] ${GivenInstallerBinary},
    [string] ${GivenInstallZip},
    [string] ${GivenPropertiesFile},
    [string] ${GivenFixesZip}
  ) {
    $this.init(
      ${TemplateId}, ${InstallPath}, ${GivenInstallerBinary}, 
      ${GivenInstallZip}, ${GivenPropertiesFile}, ${GivenFixesZip})
  }

  hidden init(
    [string] ${TemplateId},
    [string] ${InstallPath},
    [string] ${GivenInstallerBinary},
    [string] ${GivenInstallZip},
    [string] ${GivenPropertiesFile},
    [string] ${GivenFixesZip}
  ) {
    $this.InstallDir = ${InstallPath}
    $this.CurrentInstallerBinaryFullPath = ${GivenInstallerBinary}
    $this.CurrentProductsZipFullPath = ${GivenInstallZip}
    $this.CurrentPropertiesFile = ${GivenPropertiesFile}
    $this.skipFixes = 'false' # hardwired for now, will eventually consider when the case presents itself
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.audit.LogI("Initializing installation object with the following received values")
    $this.audit.LogI("InstallDir: " + $this.InstallDir)
    $this.audit.LogI("CurrentInstallerBinaryFullPath: " + $this.CurrentInstallerBinaryFullPath)
    $this.audit.LogI("CurrentProductsZipFullPath: " + $this.CurrentProductsZipFullPath)
    $this.UpdateManager = [WMUSF_UpdMgr]::GetInstance()

    if ($this.skipFixes -eq 'false') {
      $this.CurrentFixesZipFullPath = ${GivenFixesZip}
      $this.audit.LogI("CurrentFixesZipFullPath: " + $this.CurrentFixesZipFullPath)
    }
    else {
      $this.audit.LogW("Skipping fixes for this installation...")
    }

    # TODO: enforce files existence

    $this.template = [WMUSF_SetupTemplate]::new(${TemplateId})
  }

  [WMUSF_Result] InstallProducts() {
    [WMUSF_Result] $r = [WMUSF_Result]::new()
    $this.audit.LogD("Installing products with no parameters. Assuming default products zip file ...")  

    if (($this.CurrentProductsZipFullPath + "") -eq "") {
      $r2 = $this.template.AssureProductsZipFile()
      if ($r2.Code -ne 0) {
        $r.Code = 2
        $r.Description = "Error assuring products zip file, code: " + $r.Code
        $r.NestedResults += $r2
        $this.audit.LogE($r.Description)
        return $r
      }
      $this.CurrentProductsZipFullPath = $this.template.productsZipFullPath
    }
    else {
      $this.audit.LogD("CurrentProductsZipFullPath: " + $this.CurrentProductsZipFullPath)
    }
    return $this.InstallProducts($this.CurrentProductsZipFullPath, $this.skipFixes)
  }

  # TODO: add option to pass installer
  [WMUSF_Result] InstallProducts([string] ${GivenProductsZipFullPath}, [string] $skipFixes) {
    $r = [WMUSF_Result]::new()

    if (-Not (Test-Path -Path ${GivenProductsZipFullPath} -PathType Leaf)) {
      $r.Code = 1
      $r.Description = "The products zip image file does not exist: " + ${GivenProductsZipFullPath}
      $this.audit.LogE($r.Description)
      return $r
    }
    if (($this.CurrentInstallerBinaryFullPath + "") -eq "") {
      $downloader = [WMUSF_Downloader]::GetInstance()
      $r2 = $downloader.GetInstallerBinary()
      if ($r2.Code -ne 0) {
        $r.Code = 3
        $r.Description = "Error getting installer binary, code: " + $r.Code
        $r.NestedResults += $r2
        $this.audit.LogE($r.Description)
        return $r
      }
      $this.CurrentInstallerBinaryFullPath = $r2.PayloadString
    }

    $r3 = $this.template.GenerateInstallScript(
      $this.audit.LogSessionDir, "install.wmscript",
      ${GivenProductsZipFullPath}, $this.CurrentPropertiesFile)
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

    $installCmd = $this.CurrentInstallerBinaryFullPath + " -console -scriptErrorInteract no -debugLvl verbose"
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
    if (($this.CurrentFixesZipFullPath + "") -eq "") {
      $this.template.ResolveFixesFoldersNames()
      $this.audit.LogD("Taking the resolved fixes zip file: " + $this.template.currentFixesZipFullPath)
      $this.CurrentFixesZipFullPath = $this.template.currentFixesZipFullPath
    }
    if ($this.CurrentFixesZipFullPath -eq "N/A") {
      $r = [WMUSF_Result]::new()
      $r.Description = "No fixes available for this installation"
      $this.audit.LogE($r.Description)
      $r.Code = 1
      return $r
    }
    return $this.updateManager.PatchInstallation($this.InstallDir, $this.CurrentFixesZipFullPath)
  }

  [WMUSF_Result] Patch([string] ${GivenFixesZipFullPath}) {
    $this.audit.LogI("Patching installation with fixes zip file: " + ${GivenFixesZipFullPath})
    return $this.updateManager.PatchInstallation($this.InstallDir, ${GivenFixesZipFullPath})
  }
}
