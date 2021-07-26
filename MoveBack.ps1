<#
EvacuateNode.ps1

William David van Collenburg
Scale Computing

Script to demonstrate restoring VM's to their previous Node when evacuated with EvacuateNode.ps1

THIS SCRIPT IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND
feel free to use without attribution in any way as seen fit, at your own risc.

Usage: EvacuateNode.ps1 [IP or FQDN] [Credential Object] (if no Credential Object is given a login prompt will appear.
#>


[CmdletBinding()]
param(
	[Parameter(mandatory=$true)]
	[string]$node,
	[PSCredential] $Cred = (Get-Credential -Message "Enter Scale HC3 Credentials")
	)

$readURL = "https://$node/rest/v1/Node"
$actionUrl = "https://$node/rest/v1/VirDomain/action"

# The below is to ignore certificates. comment out or delete section if cerificates are handled properly (e.g. certificate has been uploaded to cluster)

add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@

[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

$restOpts = @{
    ContentType = 'application/json'
}

$receivedInfo = Invoke-RestMethod -Method 'Get' -Uri $readURL -Credential $Cred @restOpts

Write-Host "Select Node to restore to"

$cntr = 0
ForEach ($i in $receivedInfo.uuid) {
	Write-Host $cntr  ":  " $receivedInfo.lanIP[$cntr] " - " $receivedInfo.uuid[$cntr]
	$cntr = $cntr +1
}

$Answer = Read-Host -Prompt 'Choose from the above list' 

Write-Host "You chose " $receivedInfo.lanIP[$answer] " - " $receivedInfo.uuid[$Answer]
$MoveBackNode = $receivedInfo.uuid[$Answer]

foreach($line in Get-Content C:\temp\migratedvms.txt) {
	
	$Body = ConvertTo-Json @(@{
		actionType = "LIVEMIGRATE"
		virDomainUUID = "$line"
		nodeUUID = $MoveBackNode
		})
		
		Invoke-RestMethod -Method 'POST' -Uri $actionUrl -Credential $Cred @restOpts -Body $body
		
}

$reply = Read-Host -Prompt "Remove migratedvms.txt? [y/n]"
if ( $reply -match "[yY]" ) { 
	Remove-Item C:\Temp\migratedvms.txt
}
Else {
	Write-Host "Make sure to manually remove migratedvms.txt before running the EvacuateNode script again!" -ForegroundColor red -BackgroundColor white
}


