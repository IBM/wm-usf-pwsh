@echo off
SET secs=6
pwsh run-audit-tests.ps1
echo Audit tests completed.
timeout /t %secs%
pwsh run-common-tests.ps1
echo Common tests completed.
timeout /t %secs%
pwsh run-templates-tests.ps1
echo Templates tests completed.
timeout /t %secs%
pwsh run-wm-usf-wm-setup-assets-assurance-tests.ps1
echo WM Setup Assets Assurance tests completed.
timeout /t %secs%
