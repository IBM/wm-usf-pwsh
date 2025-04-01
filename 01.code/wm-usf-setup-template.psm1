# This class encapsulates the functionality to download binaries from webMethods download center
Using module "./wm-usf-audit.psm1"
Using module "./wm-usf-result.psm1"

class WMUSF_SetupTemplate {
  static [string] $baseTemplatesFolderFolder = [WMUSF_SetupTemplate]::GetBaseTemplatesFolder()

  [WMUSF_Audit] $audit
  [string]$id = "N/A"
  [string]$templateFolder = "N/A"
  [string]$templateFolderExists = 'false'

  [string]$productsListFile = "N/A"
  [string]$productsListExists = 'false'

  [string]$installerScriptFile = "N/A"
  [string]$installerScriptExists = 'false'

  WMUSF_SetupTemplate([string] $id) {

    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.id = $id
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
  }

  hidden static [string] GetBaseTemplatesFolder() {
    return $PSScriptRoot + [IO.Path]::DirectorySeparatorChar + ".." + [IO.Path]::DirectorySeparatorChar `
      + "03.templates" + [IO.Path]::DirectorySeparatorChar + "01.setup"
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
}
