SET POWERSHELL_VERSION=7.5.1
SET PESTER_VERSION=5.7.1


SET WMUSF_AUDIT_DEBUG=1
SET WMUSF_AUDIT_DIR=c:\y\sandbox\WMUSF_Audit
SET WMUSF_DBC_HOME=c:\x\webMethods\DBC
SET WMUSF_DOWNLOADER_CACHE_DIR=K:
SET WMUSF_UPD_MGR_HOME=C:\x\wmUpdMgr

:: Powershell download parameters#
:: FileName (last part of URL)
SET PU_FILE_NAME=PowerShell-%POWERSHELL_VERSION%-win-x64.msi
:: URL
SET PU=https://github.com/PowerShell/PowerShell/releases/download/v%POWERSHELL_VERSION%/%PU_FILE_NAME%
:: Local File full pathname
SET PU_FILE=%WMUSF_DOWNLOADER_CACHE_DIR%\%PU_FILE_NAME%
