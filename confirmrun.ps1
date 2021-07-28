<#
EvacuateNode.ps1

William David van Collenburg
Scale Computing

Script to demonstrate how to read a list of VM's and start them. If they are already running no task tag will be returned.

List the UUID's of the VM's in a UTF-8 encoded txt file located at c:\temp\vmlist.txt

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


foreach($line in (Get-Content "c:\temp\vmlist.txt")) {
	
	$Body = ConvertTo-Json @(@{
		actionType = "START"
		virDomainUUID = "$line"
		})
		
		Invoke-RestMethod -Method 'POST' -Uri $actionUrl -Credential $Cred @restOpts -Body $body
		
}
