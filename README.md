# webMethods Unattended Setup Platform With Powershell - Collection of reusable scripts based on powershell for webMethods setup and deployments

This repository groups a collection of powershell tools that allow webMethods users to better automate tasks in the areas of:

* installation
* patching
* environment configuration
* operational tasks

## Quick Start With Windows

The scripts are intended for Windows installations for webMethods. Tests can be run on a local Windows box having the Sandbox feature enabled
To quickstart a simple installation:

1. Go to `.sandbox/wm-usf-pwsh-dev-02/inside` folder
2. Copy `EXAMPLE.setStartupTemplate.bat` into 
3. Edit the file `setStartupTemplate.bat` and set the necessary variables
4. Go to `.sandbox/wm-usf-pwsh-dev-02`
5. Run the file `startupSandbox.bat`

The sandbox will take some time for its first run. After the startup finishes, you sohuld have a sandbox with the template of choice installed.

## Framework Environment Variables

### Default values

Name|Default Posix Value|Default Windows Value|Notes
-|-|-|-
WMUSF_ARTIFACTS_CACHE_HOME| `/opt/WMUSF/Artifacts` | `C:\WMUSF\Artifacts` |Artifacts cache directory for the framework
WMUSF_AUDIT_DIR| `/tmp/WMUSF_Audit` | `c:\y\sandbox\WMUSF_Audit` |Audit base directory for the framework
WMUSF_BOOTSTRAP_UPD_MGR_BIN| `${WMUSF_ARTIFACTS_CACHE_HOME}/${defaultWmumBootstrapFileName}` |Same as left|Binary file for Update Manager bootstrap
WMUSF_DEBUG_ON|0|0|Put on 1 to have more debugging information in the audit
WMUSF_LOG_SESSION_DIR| `${WMUSF_AUDIT_DIR}/logs` | `${WMUSF_AUDIT_DIR}\logs` |Log directory for the current session
WMUSF_TEMP_DIR| `/tmp` | `${env:TEMP}` |Temporary directory for the framework
WMUSF_UPD_MGR_HOME| `/opt/wmUpdMgr11` | `c:\webMethodsUpdateManager` |Home installation Folder for Update Manager

### Test scenarios for this project values

Name|Default Value in Sandbox|Default Value in devcontainer|Default Framework Value|Notes
-|-|-|-|-
WMUSF_AUDIT_DIR| `c:\y\sandbox\WMUSF_Audit` | `${project_home}$/local/devcontainer/audit` |
WMUSF_ARTIFACTS_CACHE_HOME| `K:` | `${project_home}$/09.artifacts`

## Script Scoped Variables

The variables below are resolved in the provided order

(To Review)
Variable Name|Description|Derived from env Var|Default Value
-|-|-|-
TempSessionDir|Temporary directory for the session| `${env:WMUSF_TEMP_DIR}` | `(${env: TEMP} ?? '/tmp) + [IO.Path]::DirectorySeparatorChar + "WMUSF` "
AuditBaseDir|Audit base directory for the framework| `${env:WMUSF_AUDIT_DIR}` | `${tempSessionDir}/WMUSF_AUDIT` |
LogSessionDir|Log directory for the current session| `${env:WMUSF_LOG_SESSION_DIR}` | `"${auditBaseDir}/$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')")`
