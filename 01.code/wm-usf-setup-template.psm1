# This class encapsulates the functionality to download binaries from webMethods download center
Using module "./wm-usf-audit.psm1"
Using module "./wm-usf-result.psm1"
Using module "./wm-usf-downloader.psm1"

class WMUSF_SetupTemplate {
  static [string] $baseTemplatesFolderFolder = [WMUSF_SetupTemplate]::GetBaseTemplatesFolder()

  [WMUSF_Audit] $audit
  [string]$imagesFolder = "N/A"
  [string]$id = "N/A"
  [string]$templateFolder = "N/A"
  [string]$templateFolderExists = 'false'

  [string]$productsListFile = "N/A"
  [string]$productsListExists = 'false'

  [string]$installerScriptFile = "N/A"
  [string]$installerScriptExists = 'false'

  [string]$productsFolder = "N/A"
  [string]$productsZipFile = "N/A"

  [string]$todayFixesFolder = "N/A"
  [string]$todayFixesZipLocation = "N/A"
  [string]$latestFixesFolder = "N/A"
  [string]$latestFixesZipLocation = "N/A"

  [string]$useTodayFixes = "false"

  WMUSF_SetupTemplate([string] $id) {
    $this.init($id, 'true')
  }
  WMUSF_SetupTemplate([string] $id, [string] $useTodayFixes) {
    $this.init($id, $useTodayFixes)
  }

  hidden init([string] $id, [string] $useTodayFixes) {

    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.id = $id
    $this.useTodayFixes = $useTodayFixes
    $this.templateFolder = [WMUSF_SetupTemplate]::baseTemplatesFolderFolder + [IO.Path]::DirectorySeparatorChar + $id
    # By convention template ids must contain backslash as path separator
    $this.templateFolder = $this.templateFolder.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $this.audit.LogD("Template folder: " + $this.templateFolder)
    if (-not (Test-Path $this.templateFolder -PathType Container)) {
      $this.audit.LogE("Template folder " + $this.templateFolder + " does not exist")
    }
    else {
      $this.templateFolderExists = 'true' 
  
      $this.productsListFile = $this.templateFolder + [IO.Path]::DirectorySeparatorChar + "ProductsList.txt"
      if (Test-Path $this.productsListFile -PathType Leaf) {
        $this.productsListExists = 'true'
      }
      else {
        $this.productsListExists = 'false'
      }

      $this.installerScriptFile = $this.templateFolder + [IO.Path]::DirectorySeparatorChar + "install.wmscript"
      if (Test-Path $this.installerScriptFile -PathType Leaf) {
        $this.installerScriptExists = 'true'
      }
      else {
        $this.installerScriptExists = 'false'
      }
    }
    $this.imagesFolder = ${env:WMUSF_DOWNLOADER_CACHE_DIR} ?? ([System.IO.Path]::GetTempPath() + "WMUSF_CACHE")
    $this.imagesFolder = $this.imagesFolder + [IO.Path]::DirectorySeparatorChar + "images"
    $this.productsFolder = $this.imagesFolder + [IO.Path]::DirectorySeparatorChar + $id.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $this.productsZipFile = $this.productsFolder + [IO.Path]::DirectorySeparatorChar + "products.zip"
  }

  hidden static [string] GetBaseTemplatesFolder() {
    return $PSScriptRoot + [IO.Path]::DirectorySeparatorChar + ".." + [IO.Path]::DirectorySeparatorChar `
      + "03.templates" + [IO.Path]::DirectorySeparatorChar + "01.setup"
  }


  [string] GetDownloadServerUrl() {

    # Note: this is subject to change according to client geolocation and to evolution and transition to the new owner
    switch -Regex ($this.id) {
      ".*\\1011\\.*" {
        return 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1011.cgi'
      }
    }
    # Default return value to ensure all code paths return a value
    return 'https\://sdc-hq.softwareag.com/cgi-bin/dataservewebM1015.cgi'
  }

  [WMUSF_Result] GetProductList() {
    $r = [WMUSF_Result]::new()
    if ($this.productsListExists -eq 'true') {
      $r = [WMUSF_Result]::GetSuccessResult()
      $r.Description = "Products list file found"
      $r.PayloadString = (Get-Content -Path $this.productsListFile) -join ","
    }
    else {
      $r = [WMUSF_Result]::GetSimpleResult(1, "Products list file not found", $this.audit)
    }
    return $r
  }

  [WMUSF_Result] GenerateProductsImageDownloadScript() {
    $r = [WMUSF_Result]::new()
    if ($this.productsListExists -eq 'false') {
      $r = [WMUSF_Result]::GetSimpleResult(1, "Products list file not found", $this.audit)
      return $r
    }
    else {
      $pl = $this.GetProductList()
      $su = $this.GetDownloadServerUrl()
      if ($pl.Code -ne 0) {
        $r = [WMUSF_Result]::GetSimpleResult(2, "Error producing the products list", $this.audit)
        return $r
      }
      $lines = @()
      $lines += "## This script is generated by wm-usf-setup-template.psm1"
      $lines += "InstallProducts=" + $pl.PayloadString
      $lines += "ServerURL=$su"
      $lines += "imagePlatform=W64"
      $lines += "InstallLocProducts="
      $lines += "# Workaround; installer wants this line even if it is overwritten by the commandline"
      $lines += "imageFile=products.zip"
      $r = [WMUSF_Result]::GetSuccessResult()
      $r.PayloadString = $lines -join "`n"
    }

    return $r
  }

  [WMUSF_Result] AssureProductsZipFile() {
    $r = [WMUSF_Result]::new()
    if (Test-Path $this.productsZipFile -PathType Leaf) {
      $r = [WMUSF_Result]::GetSuccessResult()
      $r.Description = "Products zip file already exists, nothing to do"
      $r.Code = 0
      $r.PayloadString = $this.productsZipFile
      return $r
    }

    $this.audit.LogI("Products zip file not found, generating download script...")
    $scriptFile = $this.productsFolder + [IO.Path]::DirectorySeparatorChar + "install.wmscript"
    $debugFile = $this.productsFolder + [IO.Path]::DirectorySeparatorChar + "install.debug.log"
    New-Item -Path $this.productsFolder -ItemType Directory
    $this.GenerateProductsImageDownloadScript | Out-File -FilePath "$scriptFile" -Encoding ascii
    $this.audit.LogI("Download script generated, now downloading the products zip file...")

    $user = $env:WMUSF_DOWNLOAD_USER ?? ( Read-Host -Prompt "Enter your webMethods download center user name" )
    $pass = $env:WMUSF_DOWNLOAD_PASSWORD ?? ( Read-Host -MaskInput "Enter your webMethods download center user password" )

    $downloader = [WMUSF_Downloader]::GetInstance()
    $installerBinary = $downloader.GetInstallerBinary().PayloadString # Postponed error checking
    $zipLocation = $this.productsZipFile

    $cmd = "${installerBinary} -console -scriptErrorInteract no -debugLvl verbose "
    $cmd += "-debugFile ""$debugFile""  -readScript ""$scriptFile"" -writeImage ""${zipLocation}"" -user ""${user}"" -pass "

    $this.audit.LogI("Executing the following image creation command:")
    $this.audit.LogI("$cmd ***")
    $cmd += """${pass}"""

    $rExec = $this.audit.InvokeCommand("$cmd", "CreateProductsZip")

    $rExec.Code
    if ($rExec.Code -eq 0) {
      $r.Description = "Products zip file created"
      $r.code = 0
      $r.PayloadString = $this.productsZipFile
      return $r
    }
    else {
      $r.Code = 1
      $r.Description = "Products zip file creation failed"
      $r.NestedResults += $rExec
    }
    return $r
  }

  [WMUSF_Result] AssureImagesZipFiles() {
    $r = [WMUSF_Result]::new()
    $r1 = $this.AssureImagesZipFiles()
    if ($r1.Code -ne 0) {
      $r.Description = "Images zip files cannot be assured, exitting with error"
      $r.Code = 1
      $r.NestedResults += $r1
      return $r
    }
    else {
      $this.audit.LogI("Images zip files assured, continuing with the fixes zip file")
    }
    return $r
  }
}
