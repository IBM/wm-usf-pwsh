# This class is a representation of the webMethods Update Manager installation in the current system.
using module "./wm-usf-audit.psm1"
using module "./wm-usf-result.psm1"
using module "./wm-usf-downloader.psm1"

class WMUSF_UpdMgr {
  static [WMUSF_UpdMgr] $Instance = [WMUSF_UpdMgr]::GetInstance()
  hidden static [WMUSF_UpdMgr] $_instance = [WMUSF_UpdMgr]::new()

  [string] $installHome
  [WMUSF_Audit] $audit

  [Guid] $WMUSF_UpdMgrTarget = [Guid]::NewGuid()

  hidden WMUSF_UpdMgr() { 
    $this.init( (${env:WMUSF_UPD_MGR_HOME} ?? "\webMethods\UpdateManager"))
  }

  hidden WMUSF_UpdMgr([string] ${GivenUpdMgrHome}) {
    $this.init(${GivenUpdMgrHome}) 
  }
  
  hidden static [WMUSF_UpdMgr] GetInstance() {
    return [WMUSF_UpdMgr]::_instance
  }

  hidden init([string] ${installHome}) {
    $this.audit = [WMUSF_Audit]::GetInstance()
    $this.audit.LogD("11111")
    $this.audit.LogD("1:${installHome}")
    $this.installHome = ${installHome}
    $this.audit.LogD("WMUSF UpgMgr object initialized")
    if (-Not (Test-Path -Path $this.installHome -PathType Container)) {
      $this.audit.LogW("WMUSF UpgMgr installation home not found: " + $this.installHome)
    }
  }

  [WMUSF_Result] Bootstrap() {
    $downloader = [WMUSF_Downloader]::GetInstance()
    $this.audit.LogD("Bootstrapping Update Manager, no parameters received ...")
    $r = [WMUSF_Result]::New()
    $r1 = $downloader.AssureDefaultUpdateManagerBootstrap()
    if ($r1.Code -ne 0) {
      $r.Code = 1
      $r.Description = "Bootstrap file not found: " + $r1.Description
      $this.audit.LogE($r.Description)
      $r.NestedResults += $r1
      return $r
    }

    $r2 = $this.Bootstrap($downloader.currentUpdateManagerBootstrapBinary, $null)

    if ($r2.Code -ne 0) {
      $r.Code = 2
      $r.Description = "Bootstrap command failed: " + $r2.Description
      $this.audit.LogE($r.Description)
      $r.NestedResults += $r2
    }
    else {
      $r.Code = 0
      $r.Description = "Bootstrap command succeeded"
    }

    return $r
  }

  [WMUSF_Result] Bootstrap([string] ${bootstrapBinary}, [string] ${bootstrapImage}) {
    $this.audit.LogI("Bootstrapping Update Manager ...")
    $this.audit.LogI("Bootstrap binary: " + ${bootstrapBinary})
    $this.audit.LogI("Bootstrap image: " + ${bootstrapImage})
    $this.audit.LogI("Bootstrap home: " + $this.installHome)

    $sl = [IO.Path]::DirectorySeparatorChar

    if (Test-Path -Path ($this.installHome + "${sl}bin${sl}UpdateManager.CMD.bat") -PathType Leaf) {
      $this.audit.LogI("Update Manager already installed: " + $this.installHome)
      return [WMUSF_Result]::GetSuccessResult()
    }

    if (-Not (Test-Path -Path ${bootstrapBinary} -PathType Leaf)) {
      $this.audit.LogE("Update Manager received bootstrap file not found: ${bootstrapBinary}")
      return [WMUSF_Result]::GetSimpleResult(1, "Bootstrap file not found: ${bootstrapBinary}", $this.audit)
    }

    if (-Not ($null -eq ${bootstrapImage} -or "" -eq ${bootstrapImage} -or (Test-Path -Path ${bootstrapImage} -PathType Leaf))) {
      $this.audit.LogE("Update Manager received bootstrap image not found: ${bootstrapImage}")
      return [WMUSF_Result]::GetSimpleResult(2, "Bootstrap image not found: ${bootstrapImage}", $this.audit)
    }

    ${tempFolder} = [System.IO.Path]::GetTempPath() + 'UpdMgrInstallation'

    try {
      New-Item -Path ${tempFolder} -ItemType Container
      Expand-Archive -Path ${bootstrapBinary} -DestinationPath "${tempFolder}"
    }
    catch {
      $this.audit.LogE("Update Manager bootstrap file could not be expanded: ${bootstrapBinary}")
      return [WMUSF_Result]::GetSimpleResult(3, "Bootstrap file could not be expanded: ${bootstrapBinary}" + $_.Exception.Message, $this.audit)
    }
    
    if (-Not (Test-Path ("${tempFolder}" + [IO.Path]::DirectorySeparatorChar + "sum-setup.bat") -PathType Leaf)) {
      return [WMUSF_Result]::GetSimpleResult(4, "Bootstrap command file not in the bootstrap archive. Wrong archive?", $this.audit)
    }

    [WMUSF_Result] $result = [WMUSF_Result]::new()
    Push-Location .
    Set-Location -Path "${tempFolder}"
    $cmd = "." + [IO.Path]::DirectorySeparatorChar + "sum-setup.bat --accept-license -d " + '"' + $this.installHome + '"'
    if (-Not ($null -eq ${bootstrapImage} -or "" -eq ${bootstrapImage})) {
      $cmd += " -i " + '"' + ${bootstrapImage} + '"'
    }
    $r2 = $this.audit.InvokeCommand($cmd, "bootstrap-update-manager")
    if ( $r2.Code -ne 0) {
      $result.Code = 5
      $result.Description = "Bootstrap command failed: " + $cmd
      $this.audit.LogE($result.Description)
      $result.NestedResults += $r2
    }
    Pop-Location

    return $result
  }

  [WMUSF_Result] SelfPatch([string] $FixesImageFile, [string] $OnlineMode) {

    $this.audit.LogD("Patching Update Manager installation, parameters received: 1: $FixesImageFile 2: $OnlineMode")
    $r = [WMUSF_Result]::new()
    $sl = [IO.Path]::DirectorySeparatorChar
    if (-Not (Test-Path -Path ($this.installHome + "${sl}bin${sl}UpdateManagerCMD.bat") -PathType Leaf)) {
      $r.Code = 1
      $r.Description = "Update Manager not found at " + $this.installHome + ", install it first!"
      $this.audit.LogE($r.Description)
      return $r
    }

    $cmd = ".${sl}UpdateManagerCMD.bat -selfUpdate true"
    if ( $onlineMode -eq 'false') {
      if (-Not (Test-Path "${FixesImagefile}" -PathType Leaf)) {
        $r.Code = 2
        $r.Description = "Trying to patch offline, but image file not present: ${FixesImagefile}"
        $this.audit.LogE("$r.Description")
        return $r
      }
      $cmd += " -installFromImage ""${FixesImagefile}"""
    }

    $r1 = $this.ExecuteCommand($cmd, "PatchUpdMgr")
    if ( $r1.Code -ne 0) {
      $r.Code = 3
      $r.Description = "Error executing Update Manager patch command: " + $r1.Description
      $this.audit.LogE($r.Description)
      $r.NestedResults = $r1
    }
    else {
      $this.audit.LogI("Update Manager patch completed successfully")
      $r.Messages += "Update Manager patch completed successfully"
      $r.Code = 0
      $r.Description = "Update Manager patched"
    }
    return $r
  }

  [WMUSF_Result] ExecuteCommand([string] $cmd, [string] $auditTag) {
    $this.audit.LogI("Executing Update Manager command, parameters received: 1: * 2: $auditTag")
    $r = [WMUSF_Result]::new()

    if (-Not (Test-Path ($this.updateManagerHome + [IO.Path]::DirectorySeparatorChar + 'bin') -PathType Container)) {
      $this.audit.LogW("Update Manager not installed, attempting to install it")
      $r1 = $this.Bootstrap()
      if ($r1.Code -ne 0) {
        $r.Description = "Error bootstrapping Update Manager: " + $r1.Description
        $this.audit.LogE($r.Description)
        $r.Code = 1
        $r.NestedResults += $r1
        return $r
      }
    }

    Push-Location .
    Set-Location ($this.installHome + [IO.Path]::DirectorySeparatorChar + 'bin')
    if (-Not (Test-Path -PathType Leaf -Path "UpdateManagerCMD.bat")) {
      $r.Code = 3
      $r.Description = "Ineffective change directory, current directory is not the Update Manager bin folder. You should not see this message!"
      $this.audit.LogE($r.Description)
      Pop-Location
      return $r
    }

    $r1 = $this.audit.InvokeCommand($cmd, $auditTag)
    if ($r1.Code -ne 0) {
      $r.Description = "Error executing download command: " + $r1.Description
      $this.audit.LogE($r.Description)
      $r.Code = 2
      $r.NestedResults = $r1
    }
    else {
      $r.Description = "Update Manager command executed successfully"
      $r.Code = 0
      $this.audit.LogD($r.Description)
      #$r.PayloadString = $r1.PayloadString
    }
    Pop-Location
    return $r
  }

  [WMUSF_Result] PatchInstallation([string] ${InstallationHome}, [string] ${FixesImageFile}) {

    $r = [WMUSF_Result]::new()
    if (-Not (Test-Path -Path ${FixesImageFile} -PathType Leaf)) {
      $r.Code = 2
      $r.Description = "The fixes file does not exist: " + ${FixesImageFile}
      $this.audit.LogE($r.Description)
      return $r
    }

    $r1 = $this.GenerateAllFixesApplyScriptFile($this.audit.LogSessionDir, ${InstallationHome}, ${FixesImageFile})
    if ($r1.Code -ne 0) {
      $r.Code = 1
      $r.Description = "Error generating fix apply script, code: " + $r.Code
      $r.NestedResults += $r1
      $this.audit.LogE($r.Description)
      return $r
    }
    ${fixScriptFile} = $r1.PayloadString

    $cmd = '.' + [IO.Path]::DirectorySeparatorChar + 'UpdateManagerCMD.bat'
    $cmd += ' -readScript "' + ${fixScriptFile} + '"'

    return $this.ExecuteCommand($cmd, "UpdateManager")
  }

  [WMUSF_Result] GenerateFixDownloadScriptFile([string] ${ScriptFolder}) {

    $this.audit.LogD("Generating Fix Download Script file in folder ${ScriptFolder}")
    $r = [WMUSF_Result]::new()
    $scriptFile = ${ScriptFolder} + [IO.Path]::DirectorySeparatorChar + "get-fixes.wmscript"

    $lines = @()
    $lines += "# Generated"
    $lines += "scriptConfirm=N"
    $lines += "installSP=N"
    $lines += "action=Create or add fixes to fix image"
    $lines += "selectedFixes=spro:all"
    $lines += "installDir=fixes.zip" # This should be overwritten by the command line
    $lines += "imagePlatform=W64" # TODO - generalize this
    $lines += "createEmpowerImage=C"

    ${lines} | Out-File -FilePath ${scriptFile}

    $r.Code = 0
    $r.Description = "Fixes download script file generated"
    $r.PayloadString = $scriptFile
    return $r
  }

  [WMUSF_Result] GenerateAllFixesApplyScriptFile([string] ${ScriptFolder}, [string] $installDir, [string] $imageFile) {

    $this.audit.LogD("Generating Fix Apply Script file in folder ${ScriptFolder}")
    $this.audit.LogD("Installation directory to patch: " + $installDir)
    $this.audit.LogD("Using image file: " + $imageFile)
    $r = [WMUSF_Result]::new()
    $scriptFile = ${ScriptFolder} + [IO.Path]::DirectorySeparatorChar + "apply-fixes.wmscript"
  
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

  [string] EscapeWmscriptString([string] $inputString) {
    # Escape the string for wmscript
    $escaped = $inputString -replace '\\', '\\'
    $escaped = $escaped -replace ':', '\:'
    return $escaped
  }
}