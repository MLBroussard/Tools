# Define input file containing server names (one per line)
$ServerListPath = "C:\Temp\servers.txt"
$servers = Get-Content -Path $ServerListPath

# Define registry path and values
$RegistryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\PowerShell\Transcription"
$RegistryKeys = @("EnableTranscripting", "EnableInvocationHeader", "OutputDirectory")

# Collect results
$results = foreach ($server in $servers) {
    try {
        Invoke-Command -ComputerName $server -ScriptBlock {
            param ($RegistryPath, $RegistryKeys)

            # Initialize result object
            $RegData = [ordered]@{
                ServerName             = $env:COMPUTERNAME
                OperatingSystem        = (Get-WmiObject Win32_OperatingSystem).Caption
                RegistryPathExist      = $false
                EnableTranscription    = "Pending"
                EnableInvocationHeader = "Pending"
                OutputDirectory        = "Pending"
                Status                 = "Pending"
            }

            # Check if registry path exists
            if (Test-Path $RegistryPath) {
                $RegData["RegistryPathExist"] = $true
                $RegValues = Get-ItemProperty -Path $RegistryPath -ErrorAction Stop

                # Extract values
                foreach ($Key in $RegistryKeys) {
                    if ($RegValues.PSObject.Properties.Name -contains $Key) {
                        $RegData[$Key] = $RegValues.$Key
                    }
                }
            }

            # Return object
            [PSCustomObject]$RegData
        } -ArgumentList $RegistryPath, $RegistryKeys -ErrorAction Stop
    }
    catch {
        # Handle unreachable servers or permission issues
        [PSCustomObject]@{
            ServerName             = $server
            OS_Caption             = "Unknown"
            RegistryPathExist      = "N/A"
            EnableTranscription    = "N/A"
            EnableInvocationHeader = "N/A"
            OutputDirectory        = "N/A"
            Status                 = "Failed - $($_.Exception.Message)"
        }
    }
}

# Display results in a table
$results | Format-Table -AutoSize

# Export results to a CSV (optional)
$results | Export-Csv -Path "C:\Temp\PowerShell_Transcription_Status.csv" -NoTypeInformation
