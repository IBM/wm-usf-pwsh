# Manual testing of templates inside the sandbox
* Review the desired test configuration first
  + If database is needed, set up connectivity and provision the database first
* Look at the properties and adapt their values according to context
  + License files
  + IP for the Sandbox gateway
  + Database service used

After reviewing the configuration run the test with

```bat
run.bat %FOLDER_NAME%
```

Example

```bat
run.bat TestUm01
```
