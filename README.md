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

The sandbox will take some time for its first run. After the startup finishes, you should have a sandbox with the template of choice installed.

## Framework Environment Variables

### Default values

For the sake of conciseness, the path separator in the constants is backslash, but the framework adapts in case of POSIX environments.
Some variables have pseudo names, e.g. `${SYSTEM_TEMP}` in reality is `[System.IO.Path]::GetTempPath()` , reduced in the presentation below for readability purposes:

Pseudo Variable Name|Value or Formula
-|-
SYSTEM_TEMP|[System. IO. Path]:: GetTempPath()
CRT_DAY| ( `Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%d` )
CRT_TIMESTAMP| ( `Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S` )

Name|Default Value|Notes
-|-|-
WMUSF_AUDIT_DEBUG_ON| `'0'` | put on `'1'` for more verbose logging and tracing
WMUSF_AUDIT_DIR| `"${SYSTEM_TEMP}\WMUSF_AUDIT"` |Base directory for Audit, i.e. logs and traces
WMUSF_AUDIT_LOG_SESSION_DIR| `"${WMUSF_AUDIT_DIR}\${CRT_TIMESTAMP}"` |Base directory for this session logs and traces
WMUSF_DOWNLOADER_CACHE_DIR| `"${SYSTEM_TEMP}\WMUSF_CACHE"` | Base directory for locally cached artifacts
WMUSF_DOWNLOADER_ONLINE_MODE | `'true'` | Tells the framework's downloader if an internet link for downloading is available. If not, only cached objects are usable. User may copy over the cached contents for air-gapped installations
WMUSF_INSTALLER_BINARY | `"N/A"` | When using an already existing installer binary, the user may declare it here. If not declared, the framework's downloader object will automatically download and cache the latest tested version from source
WMUSF_UPD_MGR_BOOTSTRAP_BINARY | `"N/A"` | Same regimen as `${WMUSF_INSTALLER_BINARY}` .
WMUSF_CCE_BOOTSTRAP_BINARY| `"N/A"` | Same regimen as `${WMUSF_INSTALLER_BINARY}` .
WMUSF_UPD_MGR_HOME| `\webMethods\UpdateManager` | Home of update manager installation
WMUSF_DOWNLOAD_USER| | Download user for webMethods
WMUSF_DOWNLOAD_PASSWORD| | Download password for webMethods

### Sandbox Variable Values

_This section is "work in Progress"_

The sandbox variable values are set in the files `.sandbox/wm-usf-pwsh-dev-02/inside/setEnv.bat` , for startup, and in `.sandbox/wm-usf-pwsh-dev-02/inside/02.b.prepareMachine.ps1` at sandbox level for subsequent shells.

Besides the framework environment variables, the sandbox also uses the following specific environment variables. They are defined in the file .sandbox/wm-usf-pwsh-dev-02/startupSandbox.bat.

Name|Default Value|Notes
-|-|-
WMUSF_ARTIFACTS_CACHE_HOME| `K:` | Internal older mapped to the project's `09.Artifacts` folder
WMUSF_AUDIT_DIR| `c:\y\sandbox\WMUSF_Audit` | Internal older mapped to the project's `"10.local-files\sbx\Runs\r-${CRT_TIMESTAMP}"` folder
WMUSF_DBC_HOME | `'C:\x\webMethods\DBC'` | Home installation for database configurator, which normally is necessary to start with a database backed installation
WMUSF_SBX_STARTUP_INSTALL_DIR| `'C:\x\webMethods\DBC'` | Same as WMUSF_DBC_HOME
WMUSF_SBX_STARTUP_TEMPLATE| `'DBC\1011\full'` | Template to install directly at startup of the Sandbox

### Devcontainer Variable Values

Name|Default Value|Notes
-|-|-
WMUSF_AUDIT_DIR| `"${project_home}$/local/devcontainer/audit"` | Local audit folder for devcontainer, where unit tests may be run
WMUSF_ARTIFACTS_CACHE_HOME| `"${project_home}$/09.artifacts"` | Local artifacts cache for devcontainer
