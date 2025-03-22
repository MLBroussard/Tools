# Update-Winlogbeat.ps1
param (
    [string]$SourcePath = "C:\Path\To\Winlogbeat-8.17.3",
    [string]$InstallPath = "C:\Program Files",
    [string]$ConfigFile = "C:\Path\To\Winlogbeat-8.17.3\winlogbeat.yml"
)

function Copy-WinlogbeatFiles {
    param (
        [string]$source,
        [string]$destination
    )
    Copy-Item -Path "$source\*" -Destination $destination -Recurse -Force
}

function Update-WinlogbeatConfig {
    param (
        [string]$configFile,
        [string]$destination
    )
    Copy-Item -Path $configFile -Destination "$destination\winlogbeat.yml" -Force
}

function Copy-Certificates {
    param (
        [string]$source,
        [string]$destination
    )
    $certsDestination = "$destination\certs"
    if (-Not (Test-Path -Path $certsDestination)) {
        New-Item -Path $certsDestination -ItemType Directory
    }
    Copy-Item -Path "$source\*.crt" -Destination $certsDestination -Force
    Copy-Item -Path "$source\*.key" -Destination $certsDestination -Force
}

$winlogbeatPath = Get-WinlogbeatPath
if ($winlogbeatPath) {
    Write-Output "Winlogbeat found at $winlogbeatPath. Updating..."
    Stop-WinlogbeatService
    Copy-WinlogbeatFiles -source $SourcePath -destination $winlogbeatPath
    Update-WinlogbeatConfig -configFile $ConfigFile -destination $winlogbeatPath
    Copy-Certificates -source $SourcePath -destination $winlogbeatPath
    Start-WinlogbeatService
    Write-Output "Winlogbeat updated successfully."
} else {
    Write-Output "Winlogbeat not found. Installing..."
    Copy-WinlogbeatFiles -source $SourcePath -destination $InstallPath
    Update-WinlogbeatConfig -configFile $ConfigFile -destination $InstallPath
    Copy-Certificates -source $SourcePath -destination $InstallPath
    Start-WinlogbeatService
    Write-Output "Winlogbeat installed successfully."
}
