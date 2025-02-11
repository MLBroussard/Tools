# PowerShell Tool for Installing Programs and Managing Groups with GUI
param (
    [switch]$Unattended
)

Add-Type -AssemblyName System.Windows.Forms

# Set paths
$AdminToolsPath = "C:\Temp\AdminTools"
$InstallFilesPath = "$AdminToolsPath\InstallFiles"

if (-Not (Test-Path $InstallFilesPath) -or -Not (Get-ChildItem -Path $InstallFilesPath -Filter "*.exe","*.msi")) {
    [System.Windows.Forms.MessageBox]::Show("No install files found in $InstallFilesPath. The script will continue, but no software will be installed.", "Warning", "OK", "Warning")
    $SoftwareList = @()
} else {
    $SoftwareFiles = Get-ChildItem -Path $InstallFilesPath -Filter "*.exe","*.msi" | Select-Object -ExpandProperty Name
    $SoftwareList = @()
    foreach ($File in $SoftwareFiles) {
        $SoftwareList += @{Name=$File; Installer=$File; Arguments="/silent"}
    }
}

$DomainGroups = @("Group1", "Group2", "Group3")
$ComputerName = $env:COMPUTERNAME

# Function to Lookup AD User
function Get-ADUserInfo {
    param (
        [string]$UserName
    )
    
    try {
        $User = Get-ADUser -Filter {SamAccountName -eq $UserName -or EmailAddress -eq $UserName} -Property DisplayName, EmailAddress, SamAccountName
        if ($User) {
            return "Name: $($User.DisplayName)  Email: $($User.EmailAddress)  sAMAccountName: $($User.SamAccountName)"
        } else {
            Write-Output "User not found.`r`nTry searching by Email or sAMAccountName."
            return $null
        }
    } catch {
        "Error retrieving user information.", "Unable to access Active Directory." | Write-Warning
        exit
    }
}

# Function to Install Software
function Install-Software {
    param (
        [string]$Name,
        [string]$Installer,
        [string]$Arguments
    )
    
    $InstallerPath = "$InstallFilesPath\$Installer"
    if (Test-Path $InstallerPath) {
        Write-Host "Installing $Name..."
        Start-Process -FilePath $InstallerPath -ArgumentList $Arguments -Wait -NoNewWindow
    } else {
        Write-Host "Installer for $Name not found at $InstallerPath"
    }
}

# Function to Add User to Domain Groups
function Add-ToDomainGroups {
    param (
        [string]$User,
        [array]$Groups
    )
    
    foreach ($Group in $Groups) {
        Write-Host "Adding $User to $Group..."
        Add-ADGroupMember -Identity $Group -Members $User -Confirm:$false
    }
}

# GUI Function
function Show-GUI {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "New Admin Setup on $ComputerName"
    $form.Size = New-Object System.Drawing.Size(600,500)
    $form.StartPosition = "CenterScreen"
    
    $label = New-Object System.Windows.Forms.Label
    $label.Text = "Find User:"
    $label.Location = New-Object System.Drawing.Point(20,20)
    $label.Size = New-Object System.Drawing.Size(150,20)
    $form.Controls.Add($label)
    
    $textbox = New-Object System.Windows.Forms.TextBox
    $textbox.Location = New-Object System.Drawing.Point(180,20)
    $textbox.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($textbox)
    
    $lookupButton = New-Object System.Windows.Forms.Button
    $lookupButton.Text = "Lookup"
    $lookupButton.Location = New-Object System.Drawing.Point(400, 18)
    $lookupButton.Add_Click({
        $userInfo = Get-ADUserInfo -UserName $textbox.Text
        [System.Windows.Forms.MessageBox]::Show($userInfo, "User Info", "OK", "Information")
    })
    $form.Controls.Add($lookupButton)
    
    $groupLabel = New-Object System.Windows.Forms.Label
    $groupLabel.Text = "Select AD Groups:"
    $groupLabel.Location = New-Object System.Drawing.Point(20,60)
    $groupLabel.Size = New-Object System.Drawing.Size(150,20)
    $form.Controls.Add($groupLabel)
    
    $groupCheckboxes = @()
    $yOffset = 90
    foreach ($Group in $DomainGroups) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $Group
        $checkbox.Location = New-Object System.Drawing.Point(20, $yOffset)
        $checkbox.AutoSize = $true
        $form.Controls.Add($checkbox)
        $groupCheckboxes += $checkbox
        $yOffset += 30
    }
    
    $softwareLabel = New-Object System.Windows.Forms.Label
    $softwareLabel.Text = "Select Software to Install:"
    $softwareLabel.Location = New-Object System.Drawing.Point(300,60)
    $softwareLabel.Size = New-Object System.Drawing.Size(200,20)
    $form.Controls.Add($softwareLabel)
    
    $softwareCheckboxes = @()
    $yOffsetSoftware = 90
    foreach ($Software in $SoftwareList) {
        $checkbox = New-Object System.Windows.Forms.CheckBox
        $checkbox.Text = $Software.Name
        $checkbox.Location = New-Object System.Drawing.Point(300, $yOffsetSoftware)
        $checkbox.AutoSize = $true
        $form.Controls.Add($checkbox)
        $softwareCheckboxes += $checkbox
        $yOffsetSoftware += 30
    }
    
    # Adjust button position based on the longest column
    $finalYOffset = [Math]::Max($yOffset, $yOffsetSoftware) + 20
    
    $installButton = New-Object System.Windows.Forms.Button
    $installButton.Text = "Install Selected Software"
    $installButton.AutoSize = $true
    $installButton.Location = New-Object System.Drawing.Point(300, $finalYOffset)
    $installButton.Add_Click({
        foreach ($checkbox in $softwareCheckboxes) {
            if ($checkbox.Checked) {
                $softwareItem = $SoftwareList | Where-Object { $_.Name -eq $checkbox.Text }
                Install-Software -Name $softwareItem.Name -Installer $softwareItem.Installer -Arguments $softwareItem.Arguments
            }
        }
    })
    $form.Controls.Add($installButton)
    
    $groupButton = New-Object System.Windows.Forms.Button
    $groupButton.Text = "Add to Selected Groups"
    $groupButton.AutoSize = $true
    $groupButton.Location = New-Object System.Drawing.Point(20, $finalYOffset)
    $groupButton.Add_Click({
        $selectedGroups = @()
        foreach ($checkbox in $groupCheckboxes) {
            if ($checkbox.Checked) {
                $selectedGroups += $checkbox.Text
            }
        }
        Add-ToDomainGroups -User $textbox.Text -Groups $selectedGroups
    })
    $form.Controls.Add($groupButton)
    
    $form.ShowDialog()
}

# Execution Flow
if (-not $Unattended) {
    Show-GUI
} else {
    foreach ($Software in $SoftwareList) {
        Install-Software -Name $Software.Name -Installer $Software.Installer -Arguments $Software.Arguments
    }
    do {
        $UserName = Read-Host "Enter the username to add to domain groups"
        $UserInfo = Get-ADUserInfo -UserName $UserName
    } while (-not $UserInfo)
    
    Write-Host "Adding $UserName to all listed groups..."
    Add-ToDomainGroups -User $UserName -Groups $DomainGroups
}

Write-Output "Process completed."
