# This class encapsulates the functionality to download binaries from webMethods download center
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
    $tempDir = [System.IO.Path]::GetTempPath()
    $dv = "${tempDir}" + [IO.Path]::DirectorySeparatorChar + "WMUSF_AUDIT"
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
    $this.LogI("WMUSF_AUDIT_DIR:" + $this.AuditDir)
    $this.LogI("WMUSF_LOG_SESSION_DIR:" + $this.LogSessionDir)
    $this.LogI("WMUSF_AUDIT_DEBUG:" + $this.debugOn)
  }

  hidden static [WMUSF_Audit] GetInstance() {
    return [WMUSF_Audit]::_instance
  }

  [void] Log([string]${msg}, [string]${sev} = "I") {

    $l = $this.LogSessionDir
    ${callingPoint} = $(Get-PSCallStack).SyncRoot.Get(2)
    if ($this.debugOn -eq "0") {
      ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')${sev}| ${msg}"
      Write-Host "${fs}"
      Add-content ("${l}" + [IO.Path]::PathSeparator + "session.log") -value "$fs"
    }
    else {
      ${fs} = "$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')${sev}| ${callingPoint} | ${msg}"
      Write-Host "${fs}"
      Add-content ("${l}" + [IO.Path]::PathSeparator + "session.log") -value "$fs"
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
}