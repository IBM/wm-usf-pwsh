# This class encapsulates the functionality to download binaries from webMethods download center
Using module "./wm-usf-result.psm1"

class WMUSF_Audit {
  static [WMUSF_Audit] $Instance = [WMUSF_Audit]::GetInstance()
  hidden static [WMUSF_Audit] $_instance = [WMUSF_Audit]::new()

  [string] $AuditDir
  [string] $LogSessionDir
  [string] $debugOn = "0"

  [Guid] $WMUSF_AuditTarget = [Guid]::NewGuid()

  # Convention: environment variables with prefix WMUSF_AUDIT_ are used to initialize this class
  
  hidden WMUSF_Audit() {
    if (${env:WMUSF_AUDIT_DEBUG} -eq "1") {
      $this.debugOn = "1"
    }
    $dv = [System.IO.Path]::GetTempPath() + "WMUSF_AUDIT"
    $this.AuditDir = $(${env:WMUSF_AUDIT_DIR} ?? "${dv}")
    Write-Host "AuditDir: " $this.AuditDir

    $l = $this.AuditDir + [IO.Path]::DirectorySeparatorChar + $(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')
    $this.LogSessionDir = $l
    $this.LogSessionDir = $(${env:WMUSF_AUDIT_LOG_SESSION_DIR} ?? "${l}")

    if (-not (Test-Path -Path $this.LogSessionDir)) {
      Write-Host "Creating directory: " $this.LogSessionDir
      New-Item -Path $this.LogSessionDir -ItemType Directory
    }

    Write-Host "WMUSF_AUDIT_DEBUG: " $this.debugOn

    $this.LogI("WMUSF Audit Subsystem initialized")
    $this.LogI("WMUSF_Audit Directory: " + $this.AuditDir)
    $this.LogI("WMUSF_Audit Session Directory: " + $this.LogSessionDir)
    $this.LogI("WMUSF_Audit Debug: " + $this.debugOn)
  }

  hidden static [WMUSF_Audit] GetInstance() {
    return [WMUSF_Audit]::_instance
  }

  [void] Log([string]${msg}, [string]${sev} = "I") {

    $sessionFile = $this.LogSessionDir + [IO.Path]::DirectorySeparatorChar + "session.log"
    ${callingPoint} = $(Get-PSCallStack).SyncRoot.Get(2)
    if ($this.debugOn -eq "0") {
      ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')${sev}| ${msg}"
      Write-Host "${fs}"
      Add-content $sessionFile -value "$fs"
    }
    else {
      ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')${sev}| ${callingPoint} | ${msg}"
      Write-Host "${fs}"
      Add-content $sessionFile -value "$fs"
    }
  }
  
  [void] LogI([string]${msg}) { $this.Log($msg, "I") }
  [void] LogW([string]${msg}) { $this.Log($msg, "W") }
  [void] LogE([string]${msg}) { $this.Log($msg, "E") }
  [void] LogD([string]${msg}) {
    if ($this.debugOn -eq "1") {
      $this.Log($msg, "D")
    }
  }

  [WMUSF_Result] InvokeCommand([string]$Command, [string]$AuditTag) {
    $r = [WMUSF_Result]::new()

    ${ts} = Get-Date -UFormat "%s"
    ${baseOutputFileName} = $this.LogSessionDir + [IO.Path]::DirectorySeparatorChar + "${ts}_${AuditTag}"

    # Protect logging of passwords
    # ATTN: framework convention -pass and -empowerPass to be passed as the last parameter
    # installer
    ${cmdToLog} = ${Command} -replace "(.*)\-pass\ (.*)", "`${1}-pass ***"
    # update manager
    ${cmdToLog} = ${cmdToLog} -replace "(.*)\-empowerPass\ (.*)", "`${1}-empowerPass ***"

    ${fullCmd} = $Command + " >>""${baseOutputFileName}.out.txt"" 2>>""${baseOutputFileName}.err.txt"
    ${cmdToLog} += " >>""${baseOutputFileName}.out.txt"" 2>>""${baseOutputFileName}.err.txt"
    if ("/" -eq [IO.Path]::DirectorySeparatorChar) {
      ${fullCmd} += '" || echo $LastExitCode >"'
      ${cmdToLog} += '" || echo $LastExitCode >"'
    }
    else {
      ${fullCmd} += '" || echo 255 >"'
      ${cmdToLog} += '" || echo 255 >"'
    }
    ${fullCmd} += "${baseOutputFileName}.exitcode.txt" + '"'
    ${cmdToLog} += "${baseOutputFileName}.exitcode.txt" + '"'

    $cmdToLog = ${fullCmd}
    $this.LogI("Executing command: ${fullCmd}")
    try {
      Add-Content -Path "${baseOutputFileName}.exitcode.txt" -Value "0"
      # & ${Command}
      Invoke-Expression ${fullCmd}
      $this.LogI("Command output: " + ${baseOutputFileName})

      ${exitCode} = Get-Content -Path "${baseOutputFileName}.exitcode.txt"
      if ("0" -ne ${exitCode}) {
        $this.LogE("Command finished with error code: ${exitCode}")
        $r.Code = 1
        $r.Description = "Error executing command: ${Command}, error code ${exitCode}"
        $r.Errors += $r.Description
      }
      else {
        $r.Code = 0
        $r.Description = "Command execution successful"
      }
    }
    catch {
      $r.Code = 2
      $r.Description = "Exception executing command: ${Command}"
      $this.LogE($r.Description)
      $this.LogE($_.Exception.Message)
      $_ | Out-File "${baseOutputFileName}.pwsh.err.txt"
      $_
    }
    return $r
  }

}