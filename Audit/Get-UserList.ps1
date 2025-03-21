# Define output file location
$outputFile = "$env:USERPROFILE\Desktop\LocalUserAuditReport.csv"

# Get local users via ADSI
$computerName = $env:COMPUTERNAME
$users = [ADSI]"WinNT://$computerName"

# Initialize array to store user data
$userList = @()

foreach ($user in $users.psbase.Children) {
    if ($user.SchemaClassName -eq 'User') {
        # Get user properties
        $userName = $user.Name
        $sid = if ($user.objectSid) { 
            (New-Object System.Security.Principal.SecurityIdentifier($user.objectSid[0], 0)).Value 
        } else { "Unknown" }
        
        $enabled = -not ($user.AccountDisabled -eq $true)
        $description = $user.Description
        $lastLogin = if ($user.LastLogin) { $user.LastLogin } else { "Unknown" }
        
        # Password-related details (converted from seconds)
        $passwordAge = $user.PasswordAge
        $maxPasswordAge = $user.MaxPasswordAge
        
        $passwordLastSet = if ($passwordAge -gt 0) {
            (Get-Date).AddSeconds(-$passwordAge)
        } else { "Never" }
        
        $passwordExpires = if ($maxPasswordAge -gt 0 -and $passwordAge -gt 0) {
            $passwordLastSet.AddSeconds($maxPasswordAge)
        } else { "Never" }

        # Store results in an object
        $userObj = [PSCustomObject]@{
            "Username"          = $userName
            "SID"              = $sid
            "Enabled"          = $enabled
            "Last Login"       = $lastLogin
            "Password Last Set" = $passwordLastSet
            "Password Expires"  = $passwordExpires
            "Description"      = $description
        }

        # Add object to list
        $userList += $userObj
    }
}

# Export to CSV
#$userList | Export-Csv -NoTypeInformation -Path $outputFile

# Display results in table format
$userList | Format-Table -AutoSize

Write-Host "`nLocal User Audit Completed. Report saved to: $outputFile" -ForegroundColor Green
