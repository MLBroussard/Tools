$STIGxml = Select-Xml -Path .\WinServer2022.ckl -XPath '/CHECKLIST' | ForEach-Object { $PSItem.Node }

#$headers = (($STIGxml.STIGS.iSTIG.VULN)[0]).STIG_DATA.VULN_ATTRIBUTE

$hostData = $STIGxml.ASSET

$STIG = ($STIGxml.STIGS.iSTIG.VULN.STIG_DATA | Where-Object { $_.VULN_ATTRIBUTE -eq 'STIGRef' }).ATTRIBUTE_DATA

$VulnData = $STIGxml.STIGS.iSTIG.VULN |  ForEach-Object {
    [PSCustomObject]@{
        HostName = $hostData.HOST_NAME
        IP = $hostData.HOST_IP
        STIG = $STIG -split ' Security Technical Implementation Guide' | Select-Object -First 1
        Vuln = ($PSItem.STIG_DATA | Where-Object { $PSItem.VULN_ATTRIBUTE -eq 'Vuln_Num' }).ATTRIBUTE_DATA
        Title = ($PSItem.STIG_DATA | Where-Object { $PSItem.VULN_ATTRIBUTE -eq 'Rule_Title' }).ATTRIBUTE_DATA
        Severity = ($PSItem.STIG_DATA | Where-Object { $PSItem.VULN_ATTRIBUTE -eq 'Severity' }).ATTRIBUTE_DATA
        Discussion = ($PSItem.STIG_DATA | Where-Object { $PSItem.VULN_ATTRIBUTE -eq 'Vuln_Discuss' }).ATTRIBUTE_DATA
    }
    
}

$VulnData | Select-Object -Property HostName, IP, STIG, Vuln, Title, Severity, Discussion | Format-Table

$VulnData | Export-Csv -Path ".\$($hostData.HOST_NAME)_Checklist.csv" -NoTypeInformation -Force