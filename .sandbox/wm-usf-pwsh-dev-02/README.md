# Windows Sandbox

This Sandbox is provided as a convenience tool for exploratory testing when the scripts are used under Windows, which is the main purpose of this repository.

Note that the sandbox file is a template and cannot be run directly. Use the `startupSandbox.bat` to start the sandbox.

Important note: currently, only onw sandbox at a time can be spun.
The sandbox may be used to setup an installation directly at startup. The template to be used for test is specified with the environment variable `WMUSF_SBX_STARTUP_TEMPLATE` .
If the variable is set, the startup code will attempt its installation. If not, there will be no attempt at the installation of webMethods.

Set the variable by copying `EXAMPLE.setStartupTemplate.bat` into `setStartupTemplate.bat` in the folder `.sandbox/wm-usf-pwsh-dev-02/inside` and editing the contents accordingly before starting the sandbox.

## Quick startup

Just run / double-click on `startupSandbox.bat`

## Prerequisites

Any Windows machine able to run a Windows Sandbox

## Conventions

### Folders

For all the read only folders edit or produce files outside of the sandbox and use them as needed inside the sandbox.

|Folder|Remapped to disk|Mapped to host folder|Read Only ?|Notes
|-|-|-|-|-
| `c:\k` | `K:` | `${env:currentDirectory}/Artifacts` |No|Installation artifacts folder
| `c:\l` | `L:` | `${env:currentDirectory}/Licenses` |Yes|Licenses folder. Never commit these, the licenses are to be considered as "secrets"
| `c:\p` | `P:` | `${env:currentDirectory}/../../` |Yes|This git repo project folder. 
| `c:\s` | `S:` | `${env:currentDirectory}/inside/` |Yes|Local sandbox guest folders
| `c:\x` | `X:` |Not mapped|No|webMethods installation(s) home disk
| `c:\y` | `Y:` | `${env:currentDirectory}/logs/` | No | webMethods logging volume

## Tools inside the Sandbox

The sandbox is intended to mimic a production like Windows machine holding webMethods installations.

The tools expected to be installed are:

* powershell with version ${env: POWERSHELL_VERSION}
* pester with version ${env: PESTER_VERSION}
