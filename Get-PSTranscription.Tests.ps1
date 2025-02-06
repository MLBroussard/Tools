# Define the list of servers manually
$servers = @("Server1", "Server2", "Server3")  # Replace with actual server names

# Define registry path and values
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
$RegistryKeys = @("EnableTranscripting", "EnableInvocationHeader", "OutputDirectory")

# Import Pester module
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Pester module is required. Install it using: Install-Module -Name Pester -Force"
    exit
}

# Run Pester tests
Describe "PowerShell Transcription Policy Validation" {
    foreach ($server in $servers) {
        Context "Testing PowerShell Transcription on $server" {
            It "Should connect to $server" {
                $reachable = Test-Connection -ComputerName $server -Count 2 -Quiet
                $reachable | Should -Be $true
            }

            It "Should have registry path $RegistryPath" {
                $exists = Invoke-Command -ComputerName $server -ScriptBlock {
                    Test-Path $using:RegistryPath
                } -ErrorAction SilentlyContinue
                $exists | Should -Be $true
            }

            It "Should have PowerShell Transcription enabled" {
                $value = Invoke-Command -ComputerName $server -ScriptBlock {
                    (Get-ItemProperty -Path $using:RegistryPath -Name "EnableTranscripting" -ErrorAction SilentlyContinue)."EnableTranscripting"
                } -ErrorAction SilentlyContinue
                $value | Should -Be 1
            }

            It "Should have Invocation Headers enabled" {
                $value = Invoke-Command -ComputerName $server -ScriptBlock {
                    (Get-ItemProperty -Path $using:RegistryPath -Name "EnableInvocationHeader" -ErrorAction SilentlyContinue)."EnableInvocationHeader"
                } -ErrorAction SilentlyContinue
                $value | Should -Be 1
            }

            It "Should have an Output Directory set" {
                $value = Invoke-Command -ComputerName $server -ScriptBlock {
                    (Get-ItemProperty -Path $using:RegistryPath -Name "OutputDirectory" -ErrorAction SilentlyContinue)."OutputDirectory"
                } -ErrorAction SilentlyContinue
                $value | Should -Not -BeNullOrEmpty
            }

            It "Should retrieve OS Caption" {
                $OSCaption = Invoke-Command -ComputerName $server -ScriptBlock {
                    (Get-WmiObject Win32_OperatingSystem).Caption
                } -ErrorAction SilentlyContinue
                $OSCaption | Should -Not -BeNullOrEmpty
            }
        }
    }
}
