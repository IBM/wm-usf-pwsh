function Invoke-EnvironmentSubstitution() {
  param([Parameter(ValueFromPipeline)][string]$InputObject)

  Get-ChildItem Env: | Set-Variable
  $ExecutionContext.InvokeCommand.ExpandString($InputObject)
}

function Get-NewTempDir() {
  param (
    # log message
    [Parameter(Mandatory = $false)]
    [string]${tmpBaseDir} = ${env:TEMP}
  )

  if ( ${tmpBaseDir}.Substring(${tmpBaseDir}.Length - 1, 1) -ne [IO.Path]::DirectorySeparatorChar ) {
    ${tmpBaseDir} += [IO.Path]::DirectorySeparatorChar
  }

  $r = $tmpBaseDir + (Get-Date -UFormat "%y%m%d%R" | ForEach-Object { $_ -replace ":", "." })
  return $r
}
