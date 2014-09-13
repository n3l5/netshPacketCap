<#
.SYNOPSIS
    
.DESCRIPTION
    This script is used to fire off a remote netsh packet capture trace, compress the trace, then transfer it to an analyis machine.
	
	Requires Windows 7 and newer.

	You will need 4 pieces of information: The target computer, destDir, maxSize.

.PARAMETER Computer
    This is the target computer where you will be collecting packets from.
.PARAMERT Destdir
	This the file path destination of the dump on the analysis system.
.PARAMETER maxSize
	This is the max size in MB of the packet capture. Default is 250MB.
.EXAMPLE
    C:\PS> netshPacketCap.ps1 -Computer COMPUTER1 -Location c:\temp -maxSize 50
 
.NOTES

The packet capture results in a .ETL file which Microsoft Message Analyzer can open 

    Author: Matt Nelson
    Date:   2014-07-11  
#>
Param(
  [Parameter(Mandatory=$True,Position=0)]
   [string]$Computer,
   
   [Parameter(Mandatory=$True)]
   [string]$destdir,
   
   [Parameter(Mandatory=$True)]
   [string]$maxSize
   )

echo ""
echo "=============================================="
Write-Host -Fore Yellow "Run as administrator/elevated privileges!!!"
echo "=============================================="
echo ""

Write-Host -Fore Cyan ">>>>> Press a key to begin...."
[void][System.Console]::ReadKey($TRUE)
echo ""
echo ""
$userDom = Read-Host "Enter your target DOMAIN (if any)..."
$username = Read-Host "Enter your UserID..."
$domCred = "$userDom" + "\$username"
$compCred = "$computer" + "\$username"
#Fill credentials based on whether domain or remote system credentials used 
if (!($userDom)){
	$cred = Get-Credential $compCred
	}
else {
	$cred = Get-Credential $domCred
	}
echo ""
#Validates network connectivy of current computer in loop.
if(!(Test-Connection -Cn $Computer -BufferSize 16 -Count 1 -ea 0 -quiet)){Write-Host -ForegroundColor Red "$Computer does not appear to be alive..."}
else {
    	#Display the target system and the target ip
		$targetName = Get-WMIObject Win32_ComputerSystem -ComputerName $Computer -Credential $cred | ForEach-Object Name
		$targetIP = Get-WMIObject -Class Win32_NetworkAdapterConfiguration -ComputerName $Computer -Credential $cred -Filter "IPEnabled='TRUE'" | Where {$_.IPAddress} | Select -ExpandProperty IPAddress | Where{$_ -notlike "*:*"}
		echo "=============================================="
		Write-Host -ForegroundColor Magenta "==[ $targetName - $targetIP ]=="
		echo "=============================================="
		echo ""						
		
		$date = Get-Date -format yyyy-MM-dd_HHmm_
		$artFolder = $date + $targetName + "_packtcap"
		
		##Set up PSDrive mapping to remote drive
		New-PSDrive -Name x -PSProvider filesystem -Root \\$Computer\c$ -Credential $cred | Out-Null
		New-Item -Path x:\windows\temp\$artfolder -ItemType Directory | Out-Null
		
		#Set up dump location (remote)
		$fileloc = "c:\windows\temp\$artFolder" + "\packetcap.etl"
		
		#Set up interface. Only use the interface with a defaultgateway
		#$interface = Get-WmiObject -Class Win32_NetworkAdapterConfiguration | Where-Object { ($_.DefaultIPGateway -gt "0") } | foreach {$_.SettingID}
		#add to commmand below: captureInterface=$interface
		
		#Command for packet capture on remote machine
		$netshCMD = "netsh trace start capture=yes report=yes maxsize=$maxSize fileMode=circular tracefile=$fileloc"
		
		#Initiate the Packet Capture command on remote system
		InVoke-WmiMethod -class Win32_process -name Create -ArgumentList $netshCMD -ComputerName $Computer -Credential $cred | Out-Null
				
		#Define Remote File Location using mapping
		$remfileloc = "x:\windows\temp\$artfolder\packetcap.etl"
		
		#Defining TraceStop
		$traceStop = "netsh trace stop"
		
		#Size Kill
		Write-Host -ForegroundColor Magenta "Dumping packets until size reaches: <[ $maxSize MB ]>"
		do { 
			if (Test-Path $remfileloc -Pathtype Leaf){
				$fileSize = "{0:N2}" -f (Get-ChildItem $remfileloc | foreach-Object {$_.Length / 1MB})
				Write-Host -ForegroundColor Cyan "   Current packet file size = $fileSize MB"
				Start-Sleep -Seconds 30 }
			}
		until (($fileSize) -ge $maxSize)
		echo ""
		Write-Host -Foregroundcolor Green "Max Size of $fileSize reached"
		echo ""	
		
		#STOP TRACE - Initiate the Trace stop command on remote system
		Write-Host -Foregroundcolor Yellow "Killing the packet trace"
		echo ""
		InVoke-WmiMethod -class Win32_process -name Create -ArgumentList $traceStop -ComputerName $Computer -Credential $cred | Out-Null
		
		#Detect Netsh doing Generating Data Collection
		Write-Host -ForegroundColor Magenta "Generating data collection and report. (be patient)"
		do {(Write-Host -ForegroundColor Cyan "    generating data collection and report..."),(Start-Sleep -Seconds 15)}
		until ((Get-WMIobject -Class Win32_process -Filter "Name='netsh.exe'" -ComputerName $Computer -Credential $cred | where {$_.Name -eq "netsh.exe"}).ProcessID -eq $null)
		Write-Host -ForegroundColor Green "Data collection and report DONE."
		echo ""	
				
		#COMPRESS THE PacketCap
		$remfileDir = "\\$Computer\c$\windows\temp\$artfolder"
		$zipFile = "\\$Computer\c$\windows\temp" + "\$artFolder.zip"
		[Reflection.Assembly]::LoadWithPartialName( "System.IO.Compression.FileSystem" ) | Out-Null
		[System.IO.Compression.ZipFile]::CreateFromDirectory($remfileDir, $zipFile) | Out-Null
		Write-Host -Foreground Green "Zip process complete."
		echo ""
		
		Write-Host -ForegroundColor Yellow "[Package Stats]"
		Write-Host -ForegroundColor Cyan "  Raw packet dump size: $fileSize "
		$zipSize = "{0:N2}" -f ((Get-ChildItem $zipFile | Measure-Object -property length -sum ).Sum / 1MB) + " MB"
		Write-Host -ForegroundColor Cyan "  Compressed packet dump size: $zipSize "
		echo ""
		
		#MOVE THE FILES
		Write-Host -ForegroundColor Magenta "Copying $zipFile to $destDir (be patient)"
		echo ""
		$zipName = $artFolder + ".zip"
		Copy-Item $zipFile $destDir -force
		Write-Host -ForegroundColor Yellow "Copy operation complete."
		
		#Clean-Up remote environment
		Remove-Item $remfileDir -Recurse -Force
		Remove-Item $zipFile -Force
		
		##Disconnect the PSDrive X mapping##
		Remove-PSDrive X
		echo ""
		echo "=============================================="
		Write-Host "Packet Capture operation complete"
		echo "=============================================="
	}