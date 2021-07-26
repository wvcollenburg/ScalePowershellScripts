<#
EvacuateNode.ps1 Test Change

William David van Collenburg
Scale Computing

Script to demonstrate Evacuating a node and distributing the VM's over the remaining nodes in a round-robin fashion.
ATTENTION: If not enough RAM is left on the remaining nodes the evacuate will fail for all VM's that can not be placed.

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
$readVMUrl = "https://$node/rest/v1/VirDomain"

$Folder = 'C:\Temp'
"Test to see if folder [$Folder]  exists"
if (Test-Path -Path $Folder) {
    "Path exists!"
} else {
    "Create [$Folder]"
	New-Item -Path "c:\" -Name "Temp" -ItemType "directory"
}


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

Write-Host "Select Node to evacuate"

$cntr = 0
ForEach ($i in $receivedInfo.uuid) {
	Write-Host $cntr  ":  " $receivedInfo.lanIP[$cntr] " - " $receivedInfo.uuid[$cntr]
	$cntr = $cntr +1
}

$Answer = Read-Host -Prompt 'Choose from the above list' 

Write-Host "You chose " $receivedInfo.lanIP[$Answer] " - " $receivedInfo.uuid[$Answer]
$EvacuateNode = $receivedInfo.uuid[$Answer]

$reply = Read-Host -Prompt "Continue?[y/n]"
if ( $reply -match "[yY]" ) { 
Write-Host "Commencing evacutation of node " $EvacuateNode 
$leftOverNodesCount = ($receivedInfo.uuid.Count - 1)

$cntr2 = 0
$balancer = 0
$leftNodes = ($receivedInfo.uuid | ? { $_ -ne $EvacuateNode })

$GetVMs = Invoke-RestMethod -Method 'GET' -Uri $readVMUrl -Credential $Cred @restOpts
ForEach ($VM in $GetVMs) {
	if ($GetVMs.nodeUUID[$cntr2] -eq $EvacuateNode) {
		
		$Body = ConvertTo-Json @(@{
		actionType = "LIVEMIGRATE"
		virDomainUUID = $GetVMs.uuid[$cntr2]
		nodeUUID = $leftNodes[$balancer]
		})
		
		Invoke-RestMethod -Method 'Post' -Uri $actionUrl -Credential $Cred @restOpts -Body $body
		$GetVMs.uuid[$cntr2] | Out-File C:\temp\migratedvms.txt -Append
		
		if ($balancer -eq ($leftOverNodesCount -1)) {
			$balancer = 0
		}
		else {
			$balancer = $balancer +1
		}
		
		}
	$cntr2 = $cntr2 +1
	}

}

else
{
	Write-Host "NOTHING DONE"
}
