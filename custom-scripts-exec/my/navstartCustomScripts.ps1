# this is from custom-scripts package
$downloadCustomScriptsScript = "C:\run\my\CC-DownloadCustomScripts.ps1"

if (Test-Path "C:\CosmoSetupCompleted.txt")
{
   Remove-Item -path "C:\CosmoSetupCompleted.txt" -force | Out-Null
   Write-Host "Remove marker for health check"
}

if ($env:mode -eq "4ps") {
  Write-Host "4PS mode, set time zone"
  tzutil /s "W. Europe Standard Time"
}

$volPath = "$env:volPath"

if ($volPath -ne "" -and (Test-Path $volPath) -and (Get-ChildItem $volPath).Count -ne 0) {
  # database volume path is provided and the database files are there, so this seems to be a restart
  $env:cosmoServiceRestart = $true
  Write-Host "This seems to be a service restart"
}
else {
  $env:cosmoServiceRestart = $false
  Write-Host "This seems to be a regular service start"
}

if (Test-Path $downloadCustomScriptsScript) {
  . $downloadCustomScriptsScript
}

if (Test-Path "C:\licenses\licenseUrl") {
  $customLicenseUrl = Get-Content "C:\licenses\licenseUrl"
  Write-Host "Downloading license"
  (New-Object System.Net.WebClient).DownloadFile($customLicenseUrl, $env:licensefile)
}


