@echo off

:: This script constants

:: log of our scripts
SET l=c:\y\sandbox\startup\dosSandboxStartup.log
SET pwsh_msi_file=c:\y\sandbox\startup\cache\pwsh_install.msi

CALL c:\s\setEnv.bat

:: At machine startup - install powershell %PWSH_VER%

mkdir c:\y
mkdir c:\y\sandbox
mkdir c:\y\sandbox\startup\
mkdir c:\y\sandbox\startup\cache

pushd . >> %l%
cd c:\y\sandbox

echo %TIME% - 01.s - Preparing sandbox on %DATE% ... >> %l%

mkdir c:\x
mkdir c:\t

:: We want to test both with native paths and linked ones
subst K: c:\k
subst L: c:\l
subst P: c:\P
subst S: c:\S
subst X: c:\x
subst Y: c:\Y

echo %TIME% - 01.s - Preparing folders ... >> %l%

start cmd /c "echo Installing necessary modules, this may take a while... & timeout /T 50"
if exist %pwsh_msi_file% GOTO INSTALL_PWSH

echo %TIME% - 01.s - Downloading powershell msi installer from %pu% ... >> %l%
:: Test - is curl launched too early?
timeout /T 10
curl -o %pwsh_msi_file% -L %pu% -v >> %l% 2>>%l%.err
echo %TIME% - 01.s - curl download result is: %rd% >> %l%
SET rd=%ERRORLEVEL%
if "%rd%"=="0" GOTO INSTALL_PWSH
GOTO ERR

:INSTALL_PWSH
echo %TIME% - 01.s - Installing pwsh ... >> %l%
msiexec.exe /I %pwsh_msi_file% /passive /QB /L*V ^
  Y:\sandbox\msilog.log MYPROPERTY=1 ^
  >> %l%

SET ri=%ERRORLEVEL%
echo %TIME% - 01.s - Installed pwsh, result is: %ri% >> %l%
if "%ri%"=="0" GOTO PWSH_INSTALLED
GOTO ERR

:PWSH_INSTALLED
popd >> %l%
echo %TIME% - 01.s - PATH=%PATH% >> %l%
echo %TIME% - 01.s - checking pwsh version: >> %l%
pwsh -v >> %l%
echo %TIME% - 01.s - checking C:\Program Files\PowerShell\7\pwsh.exe version: >> %l%
cmd /c "C:\Program Files\PowerShell\7\pwsh.exe" -v  >> %l%

"C:\Program Files\PowerShell\7\pwsh.exe" -ExecutionPolicy Bypass -File c:\s\02.b.prepareMachine.ps1
rl=%ERRORLEVEL%

echo %TIME% - 01.s - powershell script ended with code %rl% >> %l%
echo %TIME% - 01.s - Finished>> %l%

::cmd /c start notepad %l%
::start cmd /c "echo Finished installing, press any key to see the log. & timeout 5 & start notepad %l%"
start cmd /c "echo Finished installing & timeout /T 10"
GOTO END

:ERR 
start cmd /c "echo Startup script encountered an error, check the logs & timeout /T 120"

:END