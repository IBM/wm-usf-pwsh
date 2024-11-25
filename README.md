# webMethods Unattended Setup Platform With Powershell - Collection of reusable scripts based on powershell for webMethods setup and deployments

This repository groups a collection of powershell tools that allow webMethods users to better automate tasks in the areas of:

* installation
* patching
* environment configuration
* operational tasks

## Script scoped variables

The variables below are resolved in the provided order

Variable Name|Description|Derived from env Var|Default Value
-|-|-|-
TempSessionDir|Temporary directory for the session| `${env:WMUSF_TEMP_DIR}` | `(${env: TEMP} ?? '/tmp) + [IO.Path]::DirectorySeparatorChar + "WMUSF` "
AuditBaseDir|Audit base directory for the framework| `${env:WMUSF_AUDIT_DIR}` | `${tempSessionDir}/WMUSF_AUDIT` |
LogSessionDir|Log directory for the current session| `${env:WMUSF_LOG_SESSION_DIR}` | `"${auditBaseDir}/$(Get-Date (Get-Date).ToUniversalTime() -UFormat '+%y%m%dT%H%M%S')")`
