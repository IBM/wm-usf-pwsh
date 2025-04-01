# This class encapsulates the functionality to download binaries from webMethods download center
class WMUSF_Result {
  [int]$Code
  [string]$Description
  [string]$PayloadString
  [array]$Warnings
  [array]$Messages
  [array]$Errors
  [array]$NestedResults
  ResultObject() {
    $this.Code = 99
    $this.Description = "Initialized"
    $this.PayloadString = ""
    $this.Warnings = @()
    $this.Messages = @()
    $this.Errors = @()
    $this.NestedResults = @()
  }

  [WMUSF_Result] GetSuccessResult() {
    $r = [WMUSF_Result]::new()
    $r.Code = 0
    $r.Description = "Success"
    return $r
  }

  [WMUSF_Result] GetSimpleResult([string]$Code, [string]$Description, $audit) {
    $r = [WMUSF_Result]::new()
    $r.Code = $Code
    $r.Description = $Code
    if ($Code -ne 0) {
      $r.Errors += $Description
      if ($null -ne $audit) {
        #TODO: enforce
        $audit.LogE("Returning error code ${Code}, description ${Description}")
      }
    }
    return $r
  }
}
