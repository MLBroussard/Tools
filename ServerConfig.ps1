configuration ServerConfig {
    Import-DscResource -ModuleName PSDesiredStateConfiguration

    Node localhost {

        # Read Installed Features from CSV and ensure they exist. If not, install them.
        Script WindowsFeaturesCheck {
            GetScript = {
                @{ InstalledFeatures = (Get-WindowsFeature | Where-Object Installed -eq $true).Name }
            }
            TestScript = {
                $expectedFeatures = (Import-Csv "C:\Temp\Config\Backup\InstalledFeatures.csv").Name
                $currentFeatures = (Get-WindowsFeature | Where-Object Installed -eq $true).Name
                $missingFeatures = Compare-Object -ReferenceObject $expectedFeatures -DifferenceObject $currentFeatures -PassThru
                return ($missingFeatures.Count -eq 0)  
            }
            SetScript = {
                $features = Import-Csv "C:\Temp\Config\Backup\InstalledFeatures.csv"
                foreach ($feature in $features) {
                    if (-not(Get-WindowsFeature -Name $feature.Name | Where-Object Installed -eq $true)) {
                        Install-WindowsFeature -Name $feature
                    }
                }
            }
        }

        # Read Local Users from CSV and ensure they exist. If not, create them.
        Script LocalUsersCheck {
            GetScript = {
                @{ LocalUsers = (Get-LocalUser).Name }
            }
            TestScript = {
                $expectedUsers = (Import-Csv "C:\Temp\Config\Backup\LocalUsers.csv").Name
                $currentUsers = (Get-WindowsFeature | Where-Object Installed -eq $true).Name
                $missingUsers = Compare-Object -ReferenceObject $expectedUsers -DifferenceObject $currentUsers -PassThru
                return ($missingUsers.Count -eq 0)
            }
            SetScript = {
                $users = Import-Csv "C:\Temp\Config\Backup\LocalUsers.csv"
                foreach ($user in $users) {
                    if (-not (Get-LocalUser -Name $user.Name -ErrorAction SilentlyContinue)) {
                        New-LocalUser -Name $user.Name -Description $user.Description -Password (ConvertTo-SecureString "P@ssw0rd" -AsPlainText -Force)
                    }
                }
            }
        }

        # Read Local Groups from CSV and ensure they exist. If not, create them.
        Script LocalGroupsCheck {
            GetScript = {
                @{ LocalUsers = (Get-LocalGroup).Name }
            }
            TestScript = {
                $expectedGroups = (Import-Csv "C:\Temp\Config\Backup\LocalGroups.csv").Name
                $currentGroups = (Get-WindowsFeature | Where-Object Installed -eq $true).Name
                $missingGroups = Compare-Object -ReferenceObject $expectedGroups -DifferenceObject $currentGroups -PassThru
                return ($missingGroups.Count -eq 0)
            }
            SetScript = {
                $groups = Import-Csv "C:\Temp\Config\Backup\LocalGroups.csv"
                foreach ($group in $groups) {
                    # Truncate the description if it exceeds 48 characters
                    $description = if ($group.Description.Length -gt 48) {
                        $group.Description.Substring(0, 48)
                    } else {
                        $group.Description
                    }

                    if (-not (Get-LocalGroup -Name $group.Name -ErrorAction SilentlyContinue)) {
                        New-LocalGroup -Name $group.Name -Description $description
                    }
                }
            }

        }

        # Read Installed Software from CSV and verify.
        Script InstalledSoftwareCheck {
            GetScript = {
                @{ InstalledSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -Exclude "Connection Manager","WIC" | Select-Object -Property DisplayName }
            }
            TestScript = {
                $expectedSoftware = Import-Csv "C:\Temp\Config\Backup\InstalledSoftware.csv"
                $installedSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -Exclude "Connection Manager","WIC" | Select-Object -Property DisplayName
                $missingSoftware = $expectedSoftware | Where-Object { $PSItem.DisplayName -notin $installedSoftware.DisplayName }
                return ($missingSoftware.Count -eq 0)
            }
            SetScript = {
                $expectedSoftware = Import-Csv "C:\Temp\Config\Backup\InstalledSoftware.csv"
                $installedSoftware = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* -Exclude "Connection Manager","WIC" | Select-Object -Property DisplayName
                $missingSoftware = $expectedSoftware | Where-Object { $PSItem.DisplayName -notin $installedSoftware.DisplayName }
                
                foreach ($software in $missingSoftware) {
                    Write-Output "Manual installation required for missing software: $($software.DisplayName)"
                }
            }
        }

        # Read Firewall Rules from CSV and ensure they exist. If not, apply them.
        Script FirewallRulesCheck {
            GetScript = {
                @{ FirewallRules = Import-Csv "C:\Temp\Config\Backup\FirewallRules.csv" }
            }
            TestScript = {
                $expectedRules = Import-Csv "C:\Temp\Config\Backup\FirewallRules.csv"
                $currentRules = Get-NetFirewallRule | Select-Object DisplayName, Enabled, Direction, Action
                $missingRules = $expectedRules.DisplayName | Where-Object { $PSItem -notin $currentRules }
                return ($missingRules.Count -eq 0)
            }
            SetScript = {
                $expectedRules = Import-Csv "C:\Temp\Config\Backup\FirewallRules.csv"
                $currentRules = Get-NetFirewallRule | Where-Object {$PSItem.Enabled -eq 'True'} | Select-Object DisplayName, Direction, Action
                $missingRules = $expectedRules| Where-Object { $PSItem.DisplayName -notin $currentRules.DisplayName }

                foreach ($rule in $missingRules) {
                    New-NetFirewallRule -DisplayName $rule.DisplayName -Direction $rule.Direction -Action $rule.Action
                }
            }
        }
    }
}

# Generate the MOF file explicitly
ServerConfig -OutputPath "C:\Temp\Config\ServerConfig"

# Apply the configuration
Start-DscConfiguration -Path "C:\Temp\Config\ServerConfig" -Wait -Verbose -Force
