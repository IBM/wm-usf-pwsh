using module "../../01.code/wm-usf-dbc.psm1"

$dbServer = $env:DB_SERVER ?? (Read-Host "Input the name of the DB server")
$dbAdminUser = $env:DB_ADMIN_USERNAME ?? (Read-Host "Input the name database administrator user")
$dbAdminPass = $env:DB_ADMIN_PASSWORD ?? (Read-Host "Input the password for the database administrator user")
$url = "jdbc:wm:sqlserver://${dbServer}:1433;databaseName=master"

$dbc = [WMUSF_DBC]::new()
$dbc.CreateStorageSqlServer($url, $dbAdminUser, $dbAdminPass, "wm-test", "wm-test", "wm-test" )

$url2 = "jdbc:wm:sqlserver://${dbServer}:1433;databaseName=wm-test"
$dbc.CreateAllComponentsSqlServer($url2, "wm-test", "wm-test" )
