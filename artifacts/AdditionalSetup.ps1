﻿# Check, if -includeCSide exists, because --volume ""$($programFilesFolder):C:\navpfiles"" is mounted
if ("$($env:includeCSide)" -eq "y" -or (Test-Path "c:\navpfiles\")) {
    Write-Host ""
    Write-Host "=== Additional Setup Freddy ==="
    
    if ($restartingInstance -eq $false -and $databaseServer -eq "localhost" -and $databaseInstance -eq "SQLEXPRESS") {
        sqlcmd -S 'localhost\SQLEXPRESS' -d $DatabaseName -Q "update [dbo].[Object] SET [Modified] = 0" | Out-Null
    }

    if (!(Test-Path "c:\navpfiles\*")) {
        Copy-Item -Path "C:\Program Files (x86)\Microsoft Dynamics NAV\*" -Destination "c:\navpfiles" -Recurse -Force -ErrorAction Ignore
        $destFolder = (Get-Item "c:\navpfiles\*\RoleTailored Client").FullName
        $ClientUserSettingsFileName = "$runPath\ClientUserSettings.config"
        [xml]$ClientUserSettings = Get-Content $clientUserSettingsFileName
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""Server""]").value = "$PublicDnsName"
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServerInstance""]").value = $ServerInstance
        if ($multitenant) {
            $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""TenantId""]").value = "$TenantId"
        }
        if ($null -ne $clientUserSettings.SelectSingleNode("//appSettings/add[@key=""ServicesCertificateValidationEnabled""]")) {
            $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ServicesCertificateValidationEnabled""]").value = "false"
        }
        if ($null -ne $clientUserSettings.SelectSingleNode("//appSettings/add[@key=""ClientServicesCertificateValidationEnabled""]")) {
            $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCertificateValidationEnabled""]").value = "false"
        }
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesPort""]").value = "$publicWinClientPort"
        $acsUri = "$federationLoginEndpoint"
        if ($acsUri -ne "") {
            if (!($acsUri.ToLowerInvariant().Contains("%26wreply="))) {
                $acsUri += "%26wreply=$publicWebBaseUrl"
            }
        }
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ACSUri""]").value = "$acsUri"
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""DnsIdentity""]").value = "$dnsIdentity"
        $clientUserSettings.SelectSingleNode("//configuration/appSettings/add[@key=""ClientServicesCredentialType""]").value = "$Auth"
        $clientUserSettings.Save("$destFolder\ClientUserSettings.config")
    }
    Write-Host "=== Additional Setup Freddy Done ==="
    Write-Host ""    
}

Write-Host ""
Write-Host "=== Additional Setup ==="

if (Test-Path "c:\run\PPIArtifactUtils.psd1") {
    Write-Host "Import PPI Setup Utils from c:\run\PPIArtifactUtils.psd1"
    Import-Module "c:\run\PPIArtifactUtils.psd1" -DisableNameChecking -Force
}

if (Test-Path "$serviceTierFolder") {
    Write-Host "Import Management Utils from $serviceTierFolder\Microsoft.Dynamics.Nav.Management.psd1"
    Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Management.psd1" -Force -ErrorAction SilentlyContinue -DisableNameChecking
    Write-Host "Import App Management Utils from $serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1"
    Import-Module "$serviceTierFolder\Microsoft.Dynamics.Nav.Apps.Management.psd1" -Force -ErrorAction SilentlyContinue -DisableNameChecking
}
if (Test-Path "$roleTailoredClientFolder") {
    Write-Host "Import Nav IDE from $roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1"
    Import-Module "$roleTailoredClientFolder\Microsoft.Dynamics.Nav.Ide.psm1" -Force -ErrorAction SilentlyContinue -DisableNameChecking
}


$targetDir = "C:\run\my\apps"
$telemetryClient = Get-TelemetryClient -ErrorAction SilentlyContinue
$properties = @{}

Invoke-LogEvent -name "AdditionalSetup - Started" -telemetryClient $telemetryClient
# Download Artifacts
try {
    $started = Get-Date -Format "o"
    $artifacts = Get-ArtifactsFromEnvironment -path $targetDir -telemetryClient $telemetryClient -ErrorAction SilentlyContinue
    $artifacts | Invoke-DownloadArtifact -destination $targetDir -telemetryClient $telemetryClient -ErrorAction SilentlyContinue

    $properties["artifats"] = ($artifacts | ConvertTo-Json -Depth 50 -ErrorAction SilentlyContinue)
    Invoke-LogOperation -name "AdditionalSetup - Get Artifacts" -started $started -telemetryClient $telemetryClient -properties $properties
}
catch {
    Add-ArtifactsLog -message "Donwload Artifacts Error: $($_.Exception.Message)" -severity Error
}
finally {
    Add-ArtifactsLog -message "Donwload Artifacts done."
}

# Import Artifacts
try {
    $SyncMode = $env:IMPORT_SYNC_MODE
    $Scope = $env:IMPORT_SCOPE
    if (! ($SyncMode -in @("Add", "ForceSync")) ) { $SyncMode = "Add" }
    if (! ($Scope -in @("Global", "Tenant")) ) { $Scope = "Global" }

    Import-Artifacts `
        -Path            $targetDir `
        -NavServiceName  $NavServiceName `
        -ServerInstance  $ServerInstance `
        -Tenant          $TenantId `
        -SyncMode        $SyncMode `
        -Scope           $Scope `
        -telemetryClient $telemetryClient `
        -ErrorAction     SilentlyContinue
}
catch {
    Write-Host "Import Artifacts Error: $($_.Exception.Message)" -f Red
}
finally {
    Write-Host "Import Artifacts done."
}

$artifactSettings = "c:\run\ArtifactSettings.ps1"
Set-Content $artifactSettings -Value ("# Container Settings from Additional setup")
Add-Content $artifactSettings -Value ('$NavServiceName   = "' + "$NavServiceName" + '"')
Add-Content $artifactSettings -Value ('$ServerInstance   = "' + "$ServerInstance" + '"')
Add-Content $artifactSettings -Value ('$DatabaseServer   = "' + "$databaseServer" + '"')
Add-Content $artifactSettings -Value ('$DatabaseInstance = "' + "$databaseInstance" + '"')
Add-Content $artifactSettings -Value ('$DatabaseName     = "' + "$DatabaseName" + '"')
Add-Content $artifactSettings -Value ('$TenantId         = "' + "$TenantId" + '"')
Add-Content $artifactSettings -Value ('$SyncMode         = "' + "$SyncMode" + '"')
Add-Content $artifactSettings -Value ('$Scope            = "' + "$Scope" + '"')

Invoke-LogEvent -name "AdditionalSetup - Done" -telemetryClient $telemetryClient
Write-Host "=== Additional Setup Done ==="
Write-Host ""