using module "./wm-usf-audit.psm1"
using module "./wm-usf-result.psm1"

class WMUSF_DBC {

  [string] $DBC_InstallDir
  [string] $DBC_BinDir
  [string] $healthy
  [WMUSF_Audit] $audit

  # Convention: environment variables with prefix WMUSF_AUDIT_ are used to initialize this class
  
  WMUSF_DBC() {
    $this.init("$env:WMUSF_DBC_HOME")
  }

  WMUSF_DBC([string] ${InstallHome}) {
    $this.init(${InstallHome})
  }

  hidden init([string] ${InstallHome}) {
    $this.audit = [WMUSF_Audit]::GetInstance()
    $binDir = "${InstallHome}\common\db\bin".Replace('\', [IO.Path]::DirectorySeparatorChar )
    ${binfile} = $binDir + [IO.Path]::DirectorySeparatorChar + "dbConfigurator.bat"
    if ( Test-Path -Path (${binfile}) -PathType Leaf) {
      $this.DBC_InstallDir = ${InstallHome}
      $this.DBC_BinDir = ${binDir}
      $this.healthy = $true
      $this.audit.LogI("Database configurator installation found in ${InstallHome}")
    }
    else {
      $this.DBC_InstallDir = "N/A"
      $this.DBC_BinDir = "N/A"
      $this.healthy = $false
      $this.audit.LogE("Database configurator installation NOT found in ${InstallHome}")
      throw "Database configurator installation NOT found in ${InstallHome}"
    }
  }

  [WMUSF_Result] CreateStorageSqlServer(
    [string] $url,
    [string] $adminUser,
    [string] $adminPass,
    [string] $databaseName,
    [string] $userName,
    [string] $userPass
  ) {
    $r = [WMUSF_Result]::new()
    if (-Not $this.healthy) {
      $r.Code = 1
      $r.Description = "DBC object not initialized correctly!"
    }
    else {
      $cmd = ".\dbConfigurator.bat --action create"
      $cmd += " --component storage"
      $cmd += " --dbms sqlserver"
      $cmd += " --url " + '"' + $url + '"'
      $cmd += " --user " + $userName
      $cmd += " --dbname " + $databaseName
      $cmd += " --admin_user " + $adminUser
      $cmd += " --printActions"
      $cmd += " --password " + '"' + $userPass + '"'
      $cmd += " --admin_password " + '"' + $adminPass + '"'
      Push-Location -Path .
      $this.audit.LogD("1: " + $this.DBC_InstallDir )
      Set-Location -Path ($this.DBC_InstallDir + "/common/db/bin")
      $r2 = $this.audit.InvokeCommand($cmd, "CreateUserAndStorage")
      if ($r2.Code -ne 0) {
        $r.Code = 2
        $r.Description = "Command failed"
        $r2
      }
      $this.audit.LogD(3)
      Pop-Location
    }
    return $r
  }

  [WMUSF_Result] CreateAllComponentsSqlServer(
    [string] $url,
    [string] $userName,
    [string] $userPass
  ) {
    $r = [WMUSF_Result]::new()
    if (-Not $this.healthy) {
      $r.Code = 1
      $r.Description = "DBC object not initialized correctly!"
    }
    else {
      $cmd = ".\dbConfigurator.bat --action create"
      $cmd += " --component all"
      $cmd += " --dbms sqlserver"
      $cmd += " --url " + '"' + $url + '"'
      $cmd += " --user " + $userName
      $cmd += " --printActions"
      $cmd += " --password " + '"' + $userPass + '"'
      Push-Location -Path .
      $this.audit.LogD("1: " + $this.DBC_InstallDir )
      Set-Location -Path ($this.DBC_InstallDir + "/common/db/bin")
      $r2 = $this.audit.InvokeCommand($cmd, "CreateAllcomponents")
      if ($r2.Code -ne 0) {
        $r.Code = 2
        $r.Description = "Command failed"
        $r2
      }
      $this.audit.LogD(3)
      Pop-Location
    }
    return $r
  }
}