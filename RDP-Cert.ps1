﻿# Manually Configure RDP to use SSL cert instead of Self-Signed

Write-Host "`nThis Script Does Nothing by itself."
Write-Host "Usage: Invoke-CheckMyCerts, Invoke-CheckRDPCert, Invoke-ImportCert password, Invoke-SetRDPCert cert_number`n"

<#
	.EXAMPLE From Windows Command line (requires elevation)
			C:> powershell.exe -ExecutionPolicy Bypass -command "& { . 'RDP-Cert.ps1'; Invoke-CheckMyCerts }"
			C:> powershell.exe -ExecutionPolicy Bypass -command "& { . 'RDP-Cert.ps1'; Invoke-ImportCert }"
			C:> powershell.exe -ExecutionPolicy Bypass -command "& { . 'RDP-Cert.ps1'; Invoke-SetRDPCert }"
			C:> powershell.exe -ExecutionPolicy Bypass -command "& { . 'RDP-Cert.ps1'; Invoke-CheckRDPCert }"
			
			
	.EXAMPLE From PowerShell
			PS> . "RDP-Cert.ps1"
			PS> Invoke-CheckMyCerts
			PS> Invoke-ImportCert <password>
			PS> Invoke-SetRDPCert <num>
			PS> Invoke-CheckRDPCert
#>

function Invoke-CheckMyCerts {
$certs = Get-ChildItem -Path cert:/LocalMachine/My
if ($certs -ne $null) { $certs } else { Write-Host "There are no certs in the LocalMachine Store" }
}

function Invoke-SetRDPCert ([Int]$skip = 0){
# get a reference to the config instance
$tsgs = gwmi -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'"

# grab the thumbprint of the desired SSL cert in the computer store
if ($skip -gt 0) {
	$thumb = (gci -path cert:/LocalMachine/My | select -skip $skip -first 1).Thumbprint
}
else {
	$thumb = (gci -path cert:/LocalMachine/My | select -first 1).Thumbprint
}

# set the new thumbprint value
if ($thumb -ne $null) { 
	swmi -path $tsgs.__path -argument @{SSLCertificateSHA1Hash="$thumb"}
	#Restart RDP Services
	<# Stop-Service UmRdpService
	Stop-Service TermService
	Start-Service UmRdpService
	Start-Service TermService #>
	}
	else { Write-Host "No certificate available"}	
}

function Invoke-CheckRDPCert {
$tsgs = gwmi -class "Win32_TSGeneralSetting" -Namespace root\cimv2\terminalservices -Filter "TerminalName='RDP-tcp'"
Write-Host "Current RDP Certificate info is: "
Write-Host "CertificateName: " $tsgs.CertificateName
Write-Host "SSLCertificateSHA1Hash: " $tsgs.SSLCertificateSHA1Hash
}

# There is a more secure way to take a password in as an argument but I'm lazy right now.
function Invoke-ImportCert ([String]$inpass = 0){
if ($inpass -eq 0) {
	$pass = Read-Host "Enter .pfx decryption password" -AsSecureString
} else { $pass = $inpass | ConvertTo-SecureString -AsPlainText -Force}

$pfx = new-object System.Security.Cryptography.X509Certificates.X509Certificate2
$pfxFile = Get-ChildItem -Path '\\path\to\ssl_certificate.pfx'

Try {
    $pfx.import($pfxFile,$pass,"PersistKeySet")
    $pfx
    $store = new-object System.Security.Cryptography.X509Certificates.X509Store("My","LocalMachine")
    $store.open("MaxAllowed")
    $store.add($pfx)
    $store.close()
    } Catch { Write-Host "There was an error importing the Certificate. The password was incorrrect" }
    
}
