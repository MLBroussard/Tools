<#
.SYNOPSIS
    This script remediates the compliance issues identified by the Get-AA25050Compliance.ps1 script.
.DESCRIPTION
    This script remediates the following compliance issues:
    1. Enable PowerShell Transcription
    2. Enable PowerShell Script Block Logging
    3. Disable SMBv1
    4. Remove unauthorized local administrators
    5. Stop suspicious processes running from Temp or AppData
    6. Block failed login attempts from specific IPs
    The script applies the necessary changes to bring the system into compliance.
.NOTES
    Author         : Michelle Broussard
    Last Modified  : 22 FEB 2025

    TODO:
    - Update the allowedAdmins variable with approved accounts/groups.
    - Add more detailed logic for registry settings.
    - Research if disabling SMBv1 is necessary for compliance.
    - Add file removal for know hashes.
    - Add error handling.
#>

# Function to enable PowerShell Transcription
function Enable-PowerShellTranscription {
    Write-Output "Enabling PowerShell Transcription..."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name EnableTranscripting -Value 1
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name OutputDirectory -Value "C:\Transcripts"
}

# Function to enable PowerShell Script Block Logging
function Enable-ScriptBlockLogging {
    Write-Output "Enabling PowerShell Script Block Logging..."
    New-Item -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Force | Out-Null
    Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -Value 1
}

# Function to disable SMBv1
function Disable-SMBv1 {
    Write-Output "Disabling SMBv1..."
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
}

# Function to remove unauthorized local administrators
function Remove-UnauthorizedAdmins {
    $allowedAdmins = @("Administrator", "Domain Admins") # Update with approved accounts
    $currentAdmins = Get-LocalGroupMember -Group "Administrators" | Select-Object -ExpandProperty Name
    foreach ($admin in $currentAdmins) {
        if ($allowedAdmins -notcontains $admin) {
            Write-Output "Removing unauthorized admin: $admin"
            Remove-LocalGroupMember -Group "Administrators" -Member $admin -ErrorAction SilentlyContinue
        }
    }
}

# Function to kill suspicious processes running from Temp/AppData
function Stop-SuspiciousProcesses {
    $suspiciousProcs = Get-Process | Where-Object { $_.Path -match "Temp|AppData" }
    foreach ($proc in $suspiciousProcs) {
        Write-Output "Stopping suspicious process: $($proc.Name)"
        Stop-Process -Id $proc.Id -Force
    }
}

# Function to block failed login attempts from a specific IP (Basic example)
function Block-FailedLoginIPs {
    $failedLogins = Get-EventLog -LogName Security -InstanceId 4625 -Newest 20 | Select-Object -ExpandProperty ReplacementStrings
    $failedIPs = $failedLogins | Select-Object -Unique
    foreach ($ip in $failedIPs) {
        Write-Output "Blocking failed login IP: $ip"
        New-NetFirewallRule -DisplayName "Block $ip" -Direction Inbound -RemoteAddress $ip -Action Block -ErrorAction SilentlyContinue
    }
}

# Apply all remediations
Enable-PowerShellTranscription
Enable-ScriptBlockLogging
Disable-SMBv1
Remove-UnauthorizedAdmins
Stop-SuspiciousProcesses
Block-FailedLoginIPs

Write-Output "Remediation Completed Successfully."
