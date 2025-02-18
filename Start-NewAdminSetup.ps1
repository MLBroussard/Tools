param (
    [switch]$Unattended
)

Add-Type -AssemblyName PresentationFramework

# Set paths
$AdminToolsPath = "C:\Temp\AdminTools"
$InstallFilesPath = "$AdminToolsPath\InstallFiles"

if (-Not (Test-Path $InstallFilesPath) -or -Not (Get-ChildItem -Path $InstallFilesPath -Filter "*.exe","*.msi")) {
    [System.Windows.MessageBox]::Show("No install files found in $InstallFilesPath. The script will continue, but no software will be installed.", "Warning", "OK", "Warning")
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
        return
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

# XAML for GUI
$inputXML = @"
<Window x:Class="AdminSetup.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="New Admin Setup on $ComputerName" Height="310" Width="635">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="Auto" />
            <ColumnDefinition Width="*" />
        </Grid.ColumnDefinitions>

        <Label Grid.Row="0" Grid.Column="0" Content="Find User:" Width="75" Height="25" Margin="0,0,232,5" />
        <TextBox Grid.Row="0" x:Name="txtUserName" Margin="70,0,90,5" Height="25" Width="400"  Grid.ColumnSpan="2" />
        <Button Grid.Row="0" Grid.Column="1" Content="Lookup" x:Name="btnLookup" Height="25" Width="75" Margin="205,0,10,5" />

        <Label Grid.Row="1" Grid.Column="0" Content="Select AD Groups:" />
        <StackPanel Grid.Row="1" Grid.Column="0" x:Name="spGroups" Orientation="Vertical" Margin="0,0,0,216" />
        <StackPanel Grid.Row="2" Grid.Column="0" x:Name="spGroupNames" Orientation="Vertical" Margin="0,28,0,36" />

        <Label Grid.Row="1" Grid.Column="1" Content="Select Software to Install:" />
        <StackPanel Grid.Row="1" Grid.Column="1" x:Name="spSoftware" Orientation="Vertical" Margin="0,0,0,216" />
        <StackPanel Grid.Row="2" Grid.Column="1" x:Name="spSoftwareTitles" Orientation="Vertical" Margin="0,28,0,36" />

        <Button Grid.Row="1" Grid.Column="0" Content="Add to Selected Groups" x:Name="btnAddGroups" Width="150" Height="24" VerticalAlignment="Bottom" HorizontalAlignment="Center" />
        <Button Grid.Row="1" Grid.Column="1" Content="Install Selected Software" x:Name="btnInstallSoftware" Width="150" Height="24" VerticalAlignment="Bottom" HorizontalAlignment="Center" />
    </Grid>
</Window>
"@

$inputXML = $inputXML -replace 'mc:Ignorable="d"','' -replace "x:N",'N' -replace '^<Win.*', '<Window'
[xml]$XAML = $inputXML
$reader = (New-Object System.Xml.XmlNodeReader $XAML)
try {
    $Form = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Warning "Unable to parse XML, with error: $($Error[0])`n Ensure that there are NO SelectionChanged or TextChanged properties in your textboxes (PowerShell cannot process them)"
    throw
}

# Load XAML Objects In PowerShell
$XAML.SelectNodes("//*[@Name]") | ForEach-Object {
    try {
        Set-Variable -Name "WPF$($_.Name)" -Value $Form.FindName($_.Name) -ErrorAction Stop
    } catch {
        throw
    }
}

# Populate Group Checkboxes
foreach ($Group in $DomainGroups) {
    $checkbox = New-Object Windows.Controls.CheckBox
    $checkbox.Content = $Group
    $WPFspGroupNames.Children.Add($checkbox)
}

# Populate Software Checkboxes
foreach ($Software in $SoftwareList) {
    $checkbox = New-Object Windows.Controls.CheckBox
    $checkbox.Content = $Software.Name
    $WPFspSoftware.Children.Add($checkbox)
}

# Event handler for Lookup button
$WPFbtnLookup.Add_Click({
    $userInfo = Get-ADUserInfo -UserName $WPFtxtUserName.Text
    [System.Windows.MessageBox]::Show($userInfo, "User Info", "OK", "Information")
})

# Event handler for Add to Selected Groups button
$WPFbtnAddGroups.Add_Click({
    $selectedGroups = @()
    foreach ($checkbox in $WPFspGroupNames.Children) {
        if ($checkbox.IsChecked) {
            $selectedGroups += $checkbox.Content
        }
    }
    Add-ToDomainGroups -User $WPFtxtUserName.Text -Groups $selectedGroups
})

# Event handler for Install Selected Software button
$WPFbtnInstallSoftware.Add_Click({
    foreach ($checkbox in $WPFspSoftwareTitles.Children) {
        if ($checkbox.IsChecked) {
            $softwareItem = $SoftwareList | Where-Object { $_.Name -eq $checkbox.Content }
            Install-Software -Name $softwareItem.Name -Installer $softwareItem.Installer -Arguments $softwareItem.Arguments
        }
    }
})


# Execution Flow
if (-not $Unattended) {
    # Show the GUI
    $Form.ShowDialog() | Out-Null
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