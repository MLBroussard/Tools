# Check if there is a DSC
try {
    Write-Output "Looking for a Desired State Configuration..."

    Get-DscConfiguration -ErrorAction Stop
}
catch [System.Exception] {
    Write-Warning "A current configuration does not exist."

    # Check if C:\Temp\Config\Backup exists. If not create it the create backups.
    if (-not(Test-Path -Path "C:\Temp\Config\Backup")) {
        New-Item -ItemType Directory 'C:\Temp\Config\Backup' -Force -Verbose | Out-Null # Suppress output
        
        Write-Output "Collecting System Information"

        # Get Registry Settings
        Write-Output "Exporting HKLM Entries"
        & "C:\Windows\system32\reg.exe" export HKLM C:\Temp\Config\Backup\HKLMBkUp.reg
        Write-Output "Exporting HKCU Entries"
        & "C:\Windows\system32\reg.exe" export HKCU C:\Temp\Config\Backup\HKCUBkUp.reg
        Write-Output "Exporting HKCR Entries"
        & "C:\Windows\system32\reg.exe" export HKCR C:\Temp\Config\Backup\HKCRBkUp.reg
        Write-Output "Exporting HKU Entries"
        & "C:\Windows\system32\reg.exe" export HKU C:\Temp\Config\Backup\HKUBkUp.reg
        Write-Output "Exporting HKCC Entries"
        & "C:\Windows\system32\reg.exe" export HKCC C:\Temp\Config\Backup\HKCCBkUp.reg

        # Get Installed Features
        Get-WindowsFeature | Where-Object Installed -eq $true | Select-Object Name, DisplayName | Export-Csv "C:\Temp\Config\Backup\InstalledFeatures.csv" -NoTypeInformation -Verbose

        # Get Installed Software
        Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -Exclude "Connection Manager","WIC" | Select-Object DisplayName, DisplayVersion | Export-Csv "C:\Temp\Config\Backup\InstalledSoftware.csv" -NoTypeInformation -Verbose

        # Get Local Users and Groups
        Get-LocalUser | Select-Object Name, Enabled, Description | Export-Csv "C:\Temp\Config\Backup\LocalUsers.csv" -NoTypeInformation -Verbose
        Get-LocalGroup | Select-Object Name, Description | Export-Csv "C:\Temp\Config\Backup\LocalGroups.csv" -NoTypeInformation -Verbose

        # Capture Network Configuration
        Get-NetIPConfiguration | Out-File "C:\Temp\Config\Backup\NetworkConfig.txt" -Verbose

        # Capture System Info
        Get-ComputerInfo | Select-Object CsName, OsName, OsArchitecture, OsVersion, WindowsVersion, WindowsBuildLabEx, CsTotalPhysicalMemory | Export-Csv "C:\Temp\Config\Backup\SystemInfo.csv" -NoTypeInformation -Verbose

        # Capture Services
        Get-Service | Where-Object { $_.Status -eq 'Running' } | Select-Object Name, DisplayName, Status | Export-Csv "C:\Temp\Config\Backup\Services.csv" -NoTypeInformation -Verbose

        # Capture Firewall Rules
        Get-NetFirewallRule | Where-Object {$PSItem.Enabled -eq 'True'} | Select-Object DisplayName, Direction, Action | Export-Csv "C:\Temp\Config\Backup\FirewallRules.csv" -NoTypeInformation -Verbose

        Set-Location "C:\Temp\Config"
    }
    else {
        Set-Location "C:\Temp\Config"
    }
}
