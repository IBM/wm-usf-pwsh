# This class encapsulates the functionality to download binaries from webMethods download center
Using module "./wm-usf-audit.psm1"
Using module "./wm-usf-result.psm1"
Using module "./wm-usf-downloader.psm1"

Import-Module -Name "$PSScriptRoot/wm-usf-utils.psm1" -Force

class WMUSF_SetupTemplate {
  static [string] $baseTemplatesFolderFolder = [WMUSF_SetupTemplate]::GetBaseTemplatesFolder()

  [WMUSF_Audit] $audit
  [string]$id = "N/A"
  [string]$imagesFolderFullPath = "N/A"
  [string]$templateFolderFullPath = "N/A"
  [string]$templateFolderFullPathExists = 'false'

  [string]$productsListFileFullPath = "N/A"
  [string]$productsListFileFullPathExists = 'false'

  # Products Installation Script file, usually in the template folder
  [string]$installerScriptFullPath = "N/A"
  [string]$installerScriptFullPathExists = 'false'

  # Products Download Script file, usually dynamically generated in the cache / artifacts folder
  [string]$installerDownloadScriptFullPath = "N/A"
  [string]$installerDownloadScriptFullPathExists = 'false'

  [string]$productsFolderFullPath = "N/A"
  [string]$productsZipFileFullPath = "N/A"

  [string]$currentFixesFolderFullPath = "N/A"
  [string]$currentFixesZipFullPath = "N/A"
  [string]$todayFixesFolderFullPath = "N/A"
  [string]$todayFixesZipFullPath = "N/A"
  [string]$latestFixesFolderFullPath = "N/A"
  [string]$latestFixesZipFullPath = "N/A"

  [string]$useTodayFixes = "false"

  WMUSF_SetupTemplate([string] $id) {
    $this.init($id, 'false')
  }
  
  WMUSF_SetupTemplate([string] $id, [string] $useTodayFixes) {
    $this.init($id, $useTodayFixes)
  }

  hidden init([string] $id, [string] $useTodayFixes) {

    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.id = $id
    $this.useTodayFixes = $useTodayFixes
    $this.templateFolderFullPath = [WMUSF_SetupTemplate]::baseTemplatesFolderFolder + [IO.Path]::DirectorySeparatorChar + $id
    # By convention template ids must contain backslash as path separator
    $this.templateFolderFullPath = $this.templateFolderFullPath.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $this.audit.LogD("Template folder: " + $this.templateFolderFullPath)
    if (-not (Test-Path $this.templateFolderFullPath -PathType Container)) {
      $this.audit.LogE("Template folder " + $this.templateFolderFullPath + " does not exist. Cannot continue.")
      #throw "Template " + $this.id + " folder does not exist"
    }
    else {
      $this.templateFolderFullPathExists = 'true'
  
      $this.productsListFileFullPath = $this.templateFolderFullPath + [IO.Path]::DirectorySeparatorChar + "ProductsList.txt"
      if (Test-Path $this.productsListFileFullPath -PathType Leaf) {
        $this.productsListFileFullPathExists = 'true'
      }
      else {
        $this.productsListFileFullPathExists = 'false'
      }

      $this.installerScriptFullPath = $this.templateFolderFullPath + [IO.Path]::DirectorySeparatorChar + "install.wmscript"
      if (Test-Path $this.installerScriptFullPath -PathType Leaf) {
        $this.installerScriptFullPathExists = 'true'
      }
      else {
        $this.installerScriptFullPathExists = 'false'
      }
    }
    $this.imagesFolderFullPath = ${env:WMUSF_DOWNLOADER_CACHE_DIR} ?? ([System.IO.Path]::GetTempPath() + "WMUSF_CACHE")
    $this.imagesFolderFullPath = $this.imagesFolderFullPath + [IO.Path]::DirectorySeparatorChar + "images"
    $this.audit.LogD("Images folder for framework: " + $this.imagesFolderFullPath)
    $this.productsFolderFullPath = $this.imagesFolderFullPath + [IO.Path]::DirectorySeparatorChar + "products"
    $this.productsFolderFullPath = $this.productsFolderFullPath + [IO.Path]::DirectorySeparatorChar + $id.Replace('\', [IO.Path]::DirectorySeparatorChar)
    $this.audit.LogD("Products folder for template: " + $this.productsFolderFullPath)
    $this.productsZipFileFullPath = $this.productsFolderFullPath + [IO.Path]::DirectorySeparatorChar + "products.zip"
    $this.audit.LogD("Products zip file for template: " + $this.productsZipFileFullPath)

    $rrff = $this.ResolveFixesFoldersNames()
    if ($rrff.Code -ne 0) {
      $this.audit.LogE("Unable to resolve fixes folders: " + $rrff.Code)
    }
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
    $this.audit.LogD("Getting product list for template " + $this.id)
    $r = [WMUSF_Result]::new()
    if ($this.productsListFileFullPathExists -eq 'true') {
      $r = [WMUSF_Result]::GetSuccessResult()
      $r.Description = "Products list file found"
      $r.PayloadString = (Get-Content -Path $this.productsListFileFullPath) -join ","
    }
    else {
      $r = [WMUSF_Result]::GetSimpleResult(1, "Products list file not found", $this.audit)
    }
    return $r
  }

  [WMUSF_Result] GenerateProductsImageDownloadScript() {
    $this.audit.LogD("Generating products image download script for template " + $this.id)
    $r = [WMUSF_Result]::new()
    if ($this.productsListFileFullPathExists -eq 'false') {
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
      # Workaround; installer wants this line even if it is overwritten by the commandline
      # Hypothesis: the installer MUST receive the file here nonetheless.
      # tried to overwrite it in the command line, but it produces strange effects, like deleting the original
      $lines += "imageFile=" + $this.EscapeWmscriptString($this.productsZipFileFullPath)
      $r = [WMUSF_Result]::GetSuccessResult()
      $r.PayloadString = $lines -join "`n"
    }

    return $r
  }

  [WMUSF_Result] AssureProductsZipFile() {
    $this.audit.LogD("Assuring products zip file for template " + $this.id)
    $r = [WMUSF_Result]::new()
    if (Test-Path $this.productsZipFileFullPath -PathType Leaf) {
      $r = [WMUSF_Result]::GetSuccessResult()
      $r.Description = "Products zip file already exists at location " + $this.productsZipFileFullPath + ", nothing to do"
      $r.Code = 0
      $r.PayloadString = $this.productsZipFileFullPath
      $this.audit.LogI($r.Description)
      return $r
    }

    $this.audit.LogI("Products zip file not found, generating download script...")
    $scriptFile = $this.productsFolderFullPath + [IO.Path]::DirectorySeparatorChar + "products.download.wmscript"
    $debugFile = $this.productsFolderFullPath + [IO.Path]::DirectorySeparatorChar + "products.download.debug.log"
    New-Item -Path $this.productsFolderFullPath -ItemType Directory
    $scriptCreationResult = $this.GenerateProductsImageDownloadScript()
    if ($scriptCreationResult.Code -ne 0) {
      $r.Code = 2
      $r.Description = "Failed to produce the image download script: " + $scriptCreationResult.Code
      $r.NestedResults += $scriptCreationResult
      $this.audit.LogE($r.Description)
      return $r
    }
    $scriptCreationResult.PayloadString | Out-File -FilePath "$scriptFile" -Encoding ascii
    $this.audit.LogI("Download script generated, now downloading the products zip file...")

    $user = $env:WMUSF_DOWNLOAD_USER ?? ( Read-Host -Prompt "Enter your webMethods download center user name" )
    $pass = $env:WMUSF_DOWNLOAD_PASSWORD ?? ( Read-Host -MaskInput "Enter your webMethods download center user password" )

    $downloader = [WMUSF_Downloader]::GetInstance()
    $installerBinary = $downloader.GetInstallerBinary().PayloadString # Postponed error checking
    $zipLocation = $this.productsZipFileFullPath

    $cmd = "${installerBinary} -console -scriptErrorInteract no -debugLvl verbose "
    $cmd += "-debugFile ""$debugFile""  -readScript ""$scriptFile"" -writeImage ""${zipLocation}"" -user ""${user}"" -pass "
    $cmd += """${pass}"""

    $rExec = $this.audit.InvokeCommand("$cmd", "CreateProductsZip")

    $rExec.Code
    if ($rExec.Code -eq 0) {
      $r.Description = "Products zip file created"
      $r.code = 0
      $r.PayloadString = $this.productsZipFileFullPath
      return $r
    }
    else {
      $r.Code = 1
      $r.Description = "Products zip file creation failed"
      $r.NestedResults += $rExec
    }
    $this.audit.LogD($r.Description)
    return $r
  }

  [WMUSF_Result] GenerateInventoryFile() {
    $this.audit.LogD("Generating inventory file for template " + $this.id)
    $this.ResolveFixesFoldersNames()
    if ($this.currentFixesFolderFullPath -eq "N/A") {
      $temp = [System.IO.Path]::GetTempPath()
      $temp.Substring(0, $temp.Length - 1)
      $this.audit.LogE("Fixes folder not resolved, using the default temmporary folder to genereate the inventory file: $temp")
      return $this.GenerateInventoryFile($temp)
    }
    return $this.GenerateInventoryFile($this.currentFixesFolderFullPath)
  }

  [WMUSF_Result] GenerateInventoryFile([string] $destinationFolder) {
    $this.audit.LogD("Generating inventory file for template " + $this.id)
    $r = [WMUSF_Result]::new()
    # TODO: generalize these strings, for now they are constants
    $sumPlatformString = "W64"
    ${updateManagerVersion} = "11.0.0.0040-0819"
    ${SumPlatformGroupString} = """WIN-ANY"""

    $invFileName = $destinationFolder + [IO.Path]::DirectorySeparatorChar + "inventory.json"
    $r.PayloadString = $invFileName
    if (Test-Path $invFileName -PathType Leaf) {
      $r.Description = "Today's inventory file already exists, nothing to do"
      $r.Code = 0
      $this.audit.LogI($r.Description)
      return $r
    }
    $this.audit.LogI("Today's inventory file not found, generating it...")

    if (-Not (Test-Path $destinationFolder -PathType Container)) {
      New-Item -Path $destinationFolder -ItemType Directory
      $this.audit.LogD("Destination fixes folder created: " + $destinationFolder)
    }

    $productsList = $this.GetProductList()
    if ($productsList.Code -ne 0) {
      $r.Description = "Products list file not found, exiting with error"
      $r.Code = 1
      $this.audit.LogE($r.Description)
      return $r
    }
    ${productsHash} = @{}
    foreach ($productString in $productsList.PayloadString.split(',')) {
      $productCode = $productString.split('/')[-1]
      $verArray = $productString.split('/')[2].split('_')[-1].split('.')
      $productVersion = $verArray[0] + '.' + $verArray[1] + '.' + $verArray[2]
      ${productsHash}["$productCode"] = $productVersion
    }

    if (${productsHash}.Count -gt 0) {
      ${installedProducts} = @()
      foreach (${productId} in ${productsHash}.Keys) {
        ${installedProducts} += (@{
            "productId"   = ${productId}
            "displayName" = ${productId}
            "version"     = ${productsHash}["${productId}"]
          })
      }
      $document = @{
        "installedFixes"          = @()
        "installedSupportPatches" = @()
        "envVariables"            = @{
          "platformGroup"        = @(${SumPlatformGroupString})
          "UpdateManagerVersion" = "${updateManagerVersion}"
          "Hostname"             = "localhost"
          "platform"             = "$sumPlatformString"
        }
        "installedProducts"       = $installedProducts
      }
      $document | ConvertTo-Json -depth 100 | Out-File -Encoding "ascii" "$invFileName"
    }

    $r.Code = 0
    return $r
  }

  [WMUSF_Result] GenerateInstallScript([string] $ephmeralScriptFolder, [string] $ephemeralScriptFileName) {
    $this.audit.LogD("Generating install script file in folder $ephmeralScriptFolder")
    $this.audit.LogD("Using ephemeral script file name: " + $ephemeralScriptFileName)
    $r = [WMUSF_Result]::new()

    if ($this.installerScriptFullPathExists -eq 'false') {
      $r.Description = "Installer script file " + $this.installerScriptFullPath + " not present, is this a download only template?"
      $r.Code = 1
      $this.audit.LogE($r.Description)
      return $r
    }
    $destFolder = $ephmeralScriptFolder
    if ($null -eq $ephmeralScriptFolder -or "" -eq $ephmeralScriptFolder) {
      $destFolder = $this.audit.LogSessionDir
      $this.audit.LogW("Using Default destination folder for install script: " + $destFolder)
      if (-Not (Test-Path $destFolder -PathType Container)) {
        New-Item -Path $destFolder -ItemType Directory
        $this.audit.LogW("Destination folder for ephemeral script created: " + $destFolder)
      }
    }
    if ($null -eq $ephemeralScriptFileName -or "" -eq $ephemeralScriptFileName) {
      $scriptFileName = "install.wmscript"
      $this.audit.LogW("Using Default install script file name: " + $scriptFileName)
    }
    $destFile = $destFolder + [IO.Path]::DirectorySeparatorChar + $ephemeralScriptFileName
    $this.audit.LogI("Generating install script file: " + $destFile)
    $templateContent = Get-Content -Path $this.installerScriptFullPath -Raw
    $scriptContent = $templateContent | Invoke-EnvironmentSubstitution
    $scriptContent | Out-File -FilePath $destFile -Encoding ascii
    Select-String -Path $destFile -Pattern "WMSCRIPT_" -Quiet
    if ($scriptContent -match "WMSCRIPT_") {
      $r.Description = "Error generating install script file, exiting with error"
      $r.Code = 2
      $this.audit.LogE($r.Description)
      return $r
    }

    $checkUnsubstitutedRows = Select-String -Path ${destFile} -Pattern "WMSCRIPT_"
    if ( 0 -ne $checkUnsubstitutedRows.Count) {
      $r.Description = "Substitutions incomplete for the script file"
      $r.Code = 3
      $r.PayloadString = $checkUnsubstitutedRows -join "`n"
      $this.audit.LogE($r.Description)
      return $r
    }

    $r.Code = 0
    $r.PayloadString = $destFile
    return $r
  }

  [WMUSF_Result] GenerateFixDownloadScriptFile([string] $scriptFolder) {

    $this.audit.LogD("Generating Fix Download Script file in folder $scriptFolder")
    $r = [WMUSF_Result]::new()
    $scriptFile = $scriptFolder + [IO.Path]::DirectorySeparatorChar + "get-fixes.wmscript"

    $lines = @()
    $lines += "# Generated"
    $lines += "scriptConfirm=N"
    $lines += "installSP=N"
    $lines += "action=Create or add fixes to fix image"
    $lines += "selectedFixes=spro:all"
    $lines += "installDir=fixes.zip" # This should be overwritten by the command line
    $lines += "imagePlatform=W64" # TODO - gneralize this
    $lines += "createEmpowerImage=C"

    ${lines} | Out-File -FilePath ${scriptFile}

    $r.Code = 0
    $r.Description = "Fixes download script file generated"
    $r.PayloadString = $scriptFile
    return $r
  }

  [string] EscapeWmscriptString([string] $input) {
    # Escape the string for wmscript
    $escaped = $input -replace '\\', '\\'
    $escaped = $escaped -replace ':', '\:'
    return $escaped
  }

  # TODO: this methods would stay better in the downloader
  [WMUSF_Result] GenerateFixApplyScriptFile([string] $scriptFolder, [string] $installDir, [string] $imageFile) {

    $this.audit.LogD("Generating Fix Apply Script file in folder $scriptFolder")
    $this.audit.LogD("Using install directory: " + $installDir)
    $this.audit.LogD("Using image file: " + $imageFile)
    $r = [WMUSF_Result]::new()
    $scriptFile = $scriptFolder + [IO.Path]::DirectorySeparatorChar + "apply-fixes.wmscript"

    $lines = @()
    $lines += "# Generated"
    $lines += "installSP=N"
    $lines += "action=Install fixes from image"
    $lines += "selectedFixes=spro:all"
    $lines += "installDir=" + $this.EscapeWmscriptString($installDir)
    $lines += "imageFile=" + $this.EscapeWmscriptString($imageFile)

    ${lines} | Out-File -FilePath ${scriptFile}

    $r.Code = 0
    $r.Description = "Fixes download script file generated"
    $r.PayloadString = $scriptFile
    return $r
  }

  [WMUSF_Result] DownloadTodayFixes() {
    $this.audit.LogD("Downloading today's fixes zip file for template " + $this.id)
    $r = [WMUSF_Result]::new()
    if (-Not (Test-Path $this.todayFixesFolderFullPath -PathType Container)) {
      New-Item -Path $this.todayFixesFolderFullPath -ItemType Directory
      $this.audit.LogD("Today's fixes folder created: " + $this.todayFixesFolderFullPath)
    }
    $r1 = $this.GenerateInventoryFile()
    if ($r1.Code -ne 0) {
      $r.Description = "Today's inventory file cannot be generated, exiting with error"
      $r.Code = 1
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }
    $this.audit.LogI("Today's inventory file generated successfully in " + $r1.PayloadString)
    $this.audit.LogI("Downloading today's fixes zip file...")

    $this.latestFixesFolderFullPath = $this.todayFixesFolderFullPath
    $this.latestFixesZipFullPath = $this.todayFixesZipFullPath

    $r2 = $this.GenerateFixDownloadScriptFile($this.todayFixesFolderFullPath)
    if ($r2.Code -ne 0) {
      $r.Description = "Today's fixes download script file cannot be generated, exiting with error"
      $r.Code = 2
      $r.NestedResults += $r2
      $this.audit.LogE($r.Description)
      return $r
    }

    $user = $env:WMUSF_DOWNLOAD_USER ?? ( Read-Host -Prompt "Enter your webMethods download center user name" )
    $pass = $env:WMUSF_DOWNLOAD_PASSWORD ?? ( Read-Host -MaskInput "Enter your webMethods download center user password" )

    # Preparing the update command
    $cmd = "." + [IO.Path]::DirectorySeparatorChar + "UpdateManagerCMD.bat"
    $cmd += " -selfUpdate false"
    $cmd += " -readScript " + '"' + $r2.PayloadString + '"'
    $cmd += " -installDir " + '"' + $r1.PayloadString + '"'
    $cmd += " -imagePlatform W64" # TODO - generalize this
    $cmd += " -createImage " + '"' + $this.latestFixesZipFullPath + '"'
    $cmd += " -empowerUser ""${user}"""
    $cmd += " -empowerPass "

    $this.audit.LogI("Prepared fixes download command:")
    $this.audit.LogI("$cmd ***")

    $cmd += """${pass}"""

    $downloader = [WMUSF_Downloader]::GetInstance()
    $r3 = $downloader.ExecuteUpdateManagerCommand($cmd, "DownloadFixes")
    if ( $r3.Code -ne 0) {
      $r.Description = "Today's fixes zip file cannot be downloaded, exiting with error"
      $r.Code = 3
      $r.NestedResults += $r3
      $this.audit.LogE($r.Description)
      return $r
    }

    $r.Code = 0
    $r.PayloadString = $this.todayFixesZipFullPath
    return $r
  }

  [WMUSF_Result] AssureFixesZipFile() {
    $this.audit.LogD("Assuring fixes zip file for template " + $this.id)
    $r = [WMUSF_Result]::new()
    $r1 = $this.ResolveFixesFoldersNames()
    if ( $r1.Code -ne 0) {
      $r.Description = "Fixes folders names cannot be resolved, exiting with error"
      $r.Code = 1
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }

    if ($this.useTodayFixes -eq 'true') {
      $r.Description = "Using today's fixes zip file: " + $this.todayFixesZipFullPath
      $this.audit.LogI($r.Description)
      if (Test-Path $this.todayFixesZipFullPath -PathType Leaf) {
        $r.Description = "Today's fixes folder already exists, nothing to do"
        $r.PayloadString = $this.todayFixesZipFullPath
        $r.Code = 0
        $this.audit.LogI($r.Description)
        return $r
      }
    }
    else {
      $r.Description = "Using latest fixes zip file: " + $this.latestFixesZipFullPath
      $this.audit.LogI($r.Description)
      if (Test-Path $this.latestFixesZipFullPath -PathType Leaf) {
        $r.Description = "Latest fixes folder already exists, nothing to do"
        $r.PayloadString = $this.latestFixesZipFullPath
        $r.Code = 0
        $this.audit.LogI($r.Description)
        return $r
      }
    }
    # Need to generate the fixes zip file
    $r2 = $this.DownloadTodayFixes()
    if ($r2.Code -ne 0) {
      $r.Description = "Today's fixes zip file cannot be downloaded, exiting with error"
      $r.Code = 3
      $r.NestedResults += $r2
      $this.audit.LogE($r.Description)
      return $r
    }
    $r.PayloadString = $r2.PayloadString
    $r.Code = 0
    $r.Description = "Today's fixes zip file downloaded successfully in " + $r.PayloadString
    $this.audit.LogI($r.Description)
    return $r
  }

  [WMUSF_Result] ResolveFixesFoldersNames() {
    $this.audit.LogD("Resolving fixes folders names for template " + $this.id)
    $r = [WMUSF_Result]::new()

    $fixesBaseFolder = $this.imagesFolderFullPath + [IO.Path]::DirectorySeparatorChar + "fixes" `
      + [IO.Path]::DirectorySeparatorChar + $this.id.Replace('\', [IO.Path]::DirectorySeparatorChar)

    # Compute today's fixes folder
    $todayDate = (Get-Date -Format "yyyy-MM-dd")
    $this.todayFixesFolderFullPath = $fixesBaseFolder + [IO.Path]::DirectorySeparatorChar + $todayDate
    $this.todayFixesZipFullPath = $this.todayFixesFolderFullPath + [IO.Path]::DirectorySeparatorChar + "fixes.zip"
    $this.audit.LogD("Today's fixes folder set to: " + $this.todayFixesFolderFullPath)

    if (Test-Path $this.todayFixesZipFullPath -PathType Leaf) {
      $this.audit.LogD("Today's fixes zip image already exists: " + $this.todayFixesFolderFullPath)
      $this.currentFixesFolderFullPath = $this.todayFixesFolderFullPath
      $this.currentFixesZipFullPath = $this.todayFixesZipFullPath
      $this.latestFixesFolderFullPath = $this.todayFixesFolderFullPath
      $this.latestFixesZipFullPath = $this.todayFixesZipFullPath
    }
    else {
      $this.audit.LogD("Today's zipfixes folder does not exist: " + $this.todayFixesFolderFullPath)
      $this.audit.LogD("Computing the latest fixes folder...")

      # Compute the latest fixes folder
      $this.latestFixesFolderFullPath = "N/A"
      $this.latestFixesZipFullPath = "N/A"
      if (Test-Path $fixesBaseFolder -PathType Container) {
        $latestFolder = Get-ChildItem -Path $fixesBaseFolder -Directory | `
          Sort-Object -Property Name -Descending | Select-Object -First 1
        if ($latestFolder) {
          if (Test-Path -Path ($latestFolder.FullName + [IO.Path]::DirectorySeparatorChar + "fixes.zip") -PathType Leaf) {
            $this.currentFixesFolderFullPath = $latestFolder.FullName
            $this.currentFixesZipFullPath = $this.currentFixesFolderFullPath + [IO.Path]::DirectorySeparatorChar + "fixes.zip"
            $this.audit.LogD("Current fixes folder set to: " + $this.currentFixesFolderFullPath)
          }
          else {
            $this.audit.LogW("Latest fix folder does not contain the expected .zip file: " + $latestFolder.FullName)
            $this.audit.LogW("Continuing without setting a cached fixes zip file...")
          }
        }
        else {
          $this.audit.LogW("No subfolders found in fixes base folder: $fixesBaseFolder")
        }
      }
      else {
        $this.audit.LogW("Fixes base folder does not exist: $fixesBaseFolder")
      }
    }

    $r.Code = 0
    $r.Description = "Fixes folders resolved successfully"
    return $r
  }

  [WMUSF_Result] AssureImagesZipFiles() {
    $this.audit.LogD("Assuring images zip files for template " + $this.id)
    $r = [WMUSF_Result]::new()
    $r1 = $this.AssureProductsZipFile()
    if ($r1.Code -ne 0) {
      $r.Description = "Images zip files cannot be assured, exitting with error"
      $this.audit.LogE($r.Description)
      $r.Code = 1
      $r.NestedResults += $r1
      return $r
    }

    $r2 = $this.AssureFixesZipFile()
    if ($r2.Code -ne 0) {
      $r.Description = "Fixes zip file cannot be assured, exiting with error"
      $this.audit.LogE($r.Description)
      $r.Code = 2
      $r.NestedResults += $r2
      return $r
    }

    return $r
  }
}
