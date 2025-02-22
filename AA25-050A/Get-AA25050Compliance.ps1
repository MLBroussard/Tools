<#
.SYNOPSIS
    This script checks the compliance of a Windows Server based on the FBI/CISA Advisory for Ghost (Cring) Ransomware.
.DESCRIPTION
    This script performs the following compliance checks:
    1. Security patches installed
    2. PowerShell Transcription is enabled
    3. PowerShell Script Block Logging is enabled
    4. SMBv1 is disabled
    5. Local Administrators are listed
    6. Suspicious processes running from Temp or AppData are detected
    7. Recent failed login attempts are checked
    The script generates a CSV report and an HTML report with the compliance status.
.NOTES
    Author         : Michelle Broussard
    Last Modified  : 22 FEB 2025

    TODO:
    - Replace placeholder KB numbers with actual security patches.
    - Research if disabling SMBv1 is necessary for compliance.
    - Add scanning for specific file hashes.
    - Add error handling.
#>

$reportData = @()

# Function to check installed security patches
function Get-PatchStatus {
	param([string[]]$KBList)
	$missingPatches = @()
	foreach ($KB in $KBList) {
		if (-not (Get-HotFix | Where-Object { $_.HotFixID -eq $KB })) {
			$missingPatches += $KB
		}
	}
	if ($missingPatches.Count -eq 0) {
		$result = "Compliant"
	} else {
		$result = "Non-Compliant: Missing patches: $($missingPatches -join ', ')"
	}
	$reportData += [pscustomobject]@{ Check = "Security Patches"; Status = $result }
}

# Function to check PowerShell Transcription settings
function Get-PowerShellLogging {
	$transcriptionEnabled = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription" -Name EnableTranscripting -ErrorAction SilentlyContinue).EnableTranscripting
	if ($transcriptionEnabled -eq 1) {
		$result = "Compliant"
	} else {
		$result = "Non-Compliant: Transcription is not enabled"
	}
	$reportData += [pscustomobject]@{ Check = "PowerShell Logging"; Status = $result }
}

# Function to check PowerShell Script Block Logging
function Get-ScriptBlockLogging {
	$scriptBlockLogging = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging" -Name EnableScriptBlockLogging -ErrorAction SilentlyContinue).EnableScriptBlockLogging
	$result = if ($scriptBlockLogging -eq 1) { "Compliant" } else { "Non-Compliant: Script Block Logging is not enabled" }
	$reportData += [pscustomobject]@{ Check = "PowerShell Script Block Logging"; Status = $result }
}

# Function to check if SMBv1 is disabled
function Get-SMBv1 {
	$smb1Status = (Get-SmbServerConfiguration).EnableSMB1Protocol
	$result = if ($smb1Status -eq $false) { "Compliant" } else { "Non-Compliant: SMBv1 is enabled" }
	$reportData += [pscustomobject]@{ Check = "SMBv1 Disabled"; Status = $result }
}

# Function to list local administrators
function Get-LocalAdmins {
	$admins = Get-LocalGroupMember -Group "Administrators" | Select-Object -ExpandProperty Name
	$reportData += [pscustomobject]@{ Check = "Local Administrators"; Status = "Found: $($admins -join ', ')" }
}

# Function to detect suspicious processes running from Temp or AppData
function Get-SuspiciousProcesses {
	$suspiciousProcs = Get-Process | Where-Object { $_.Path -match "Temp|AppData" }
	$result = if ($suspiciousProcs) { "Non-Compliant: Suspicious processes detected" } else { "Compliant" }
	$reportData += [pscustomobject]@{ Check = "Suspicious Processes"; Status = $result }
}

# Function to check for recent failed login attempts
function Get-FailedLogins {
	$failedLogins = Get-EventLog -LogName Security -InstanceId 4625 -Newest 10
	$result = if ($failedLogins) { "Non-Compliant: Recent failed login attempts detected" } else { "Compliant" }
	$reportData += [pscustomobject]@{ Check = "Failed Login Attempts"; Status = $result }
}

# Run all compliance checks
Get-PatchStatus -KBList @("KB5019077","KB5009557","KB5008102") # Replace with actual KBs
Get-PowerShellLogging
Get-ScriptBlockLogging
Get-SMBv1
Get-LocalAdmins
Get-SuspiciousProcesses
Get-FailedLogins

# Export report to CSV
$csvPath = "$env:SystemDrive\AA25-050A_ComplianceReport.csv"
$reportData | Export-Csv -Path $csvPath -NoTypeInformation
Write-Output "CSV report saved to $csvPath"

# Generate HTML Report
$htmlPath = "$env:SystemDrive\AA25-050A_ComplianceReport.html"
$htmlContent = @"
<html>
<head>
    <title>Windows Server AA25-050A Compliance Report</title>
    <style>
        body { font-family: Arial, sans-serif; }
        table { border-collapse: collapse; width: 100%; }
        th, td { border: 1px solid black; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .compliant { background-color: #c6efce; } /* Green */
        .non-compliant { background-color: #ffc7ce; } /* Red */
    </style>
</head>
<body>
    <h2>Windows Server AA25-050A Compliance Report</h2>
    <table>
        <tr>
            <th>Check</th>
            <th>Status</th>
        </tr>
"@

foreach ($entry in $reportData) {
	$statusClass = if ($entry.Status -match "Non-Compliant") { "non-compliant" } else { "compliant" }
	$htmlContent += "<tr><td>$($entry.Check)</td><td class='$statusClass'>$($entry.Status)</td></tr>`n"
}

$htmlContent += @"
    </table>
</body>
</html>
"@

$htmlContent | Out-File -FilePath $htmlPath -Encoding utf8
Write-Output "HTML report saved to $htmlPath"
