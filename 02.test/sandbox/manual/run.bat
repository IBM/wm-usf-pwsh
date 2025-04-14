@echo off
REM Must pass the child folder to test
REM e.g. run.bat testUm01

SET TEST_CHILD_DIR=%1

call %1\setEnv.bat
pwsh test.ps1
