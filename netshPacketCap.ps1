<#
.SYNOPSIS
    
.DESCRIPTION
    This script is used to fire off a remote netsh packet capture trace, compress the trace, then transfer it to an analyis machine.
	
	Requires Windows 7 and newer.

	You will need 5 pieces of information: The target computer, destDir, maxSize, and the trace type you'd want to capture.

.PARAMETER Target
    This is the target computer where you will be collecting packets from.
.PARAMETER Destdir
	This the file path destination of the dump on the analysis system.
.PARAMETER Tracetype
	This the trace type you want to do, typically you can do LAN for wired and WLAN for wireless.
.PARAMETER MaxSize
	This is the max size in MB of the packet capture. Default is 250MB.
.EXAMPLE
    C:\PS> netshPacketCap.ps1 -Target COMPUTER1 -Location c:\temp -Tracetype LAN  -MaxSize 50
 
.NOTES

The packet capture results in a .ETL file which Microsoft Message Analyzer can open; you can then export the packet capture out to a regular .cap file for your favorite packet analysis tool like Wireshark.

    Author: Matt Nelson
    Date:   2014-07-11  
#>
Param(
  [Parameter(Mandatory=$True,Position=0)]
   [string]$target,
   
   [Parameter(Mandatory=$True)]
   [string]$destdir,
   
   [Parameter(Mandatory=$True)]
   [string]$tracetype,
   
   [Parameter(Mandatory=$True)]
   [string]$maxSize
   )

#Test if the box is up and running

	Write-Host -Fore Yellow ">>>>> Testing connection to $target...."
	echo ""
if ((!(Test-Connection -Cn $target -Count 3 -ea 0 -quiet)) -OR (!($socket = New-Object net.sockets.tcpclient("$target",445)))) {
		Write-Host -Foreground Magenta "$target appears to be down"
		}

else {
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
		$compCred = "$target" + "\$username"
	
	#Fill credentials based on whether domain or remote system credentials used 
		if (!($userDom)){
		$cred = Get-Credential $compCred
		}
		else {
		$cred = Get-Credential $domCred
		}
		echo ""
		
	#Display the target system and the target ip
		$targetName = Get-WMIObject Win32_ComputerSystem -ComputerName $target -Credential $cred | ForEach-Object Name
		$targetIP = Get-WMIObject -Class Win32_NetworkAdapterConfiguration -ComputerName $target -Credential $cred -Filter "IPEnabled='TRUE'" | Where {$_.IPAddress} | Select -ExpandProperty IPAddress | Where{$_ -notlike "*:*"}
		echo "=============================================="
		Write-Host -ForegroundColor Magenta "==[ $targetName - $targetIP ]=="
		echo "=============================================="
		echo ""						
		
		$date = Get-Date -format yyyy-MM-dd_HHmm_
		$artFolder = $date + $targetName + "_pktcap"
		
		##Set up PSDrive mapping to remote drive
		New-PSDrive -Name x -PSProvider filesystem -Root \\$target\c$ -Credential $cred | Out-Null
		New-Item -Path x:\windows\temp\$artfolder -ItemType Directory | Out-Null
		
		#Set up dump location (remote)
		$fileloc = "c:\windows\temp\$artFolder" + "\pktcap.etl"
				
		#Command for packet capture on remote machine
		$netshCMD = "cmd /c netsh trace start scenario=$tracetype capture=yes report=yes maxsize=$maxSize fileMode=circular tracefile=$fileloc"
		
		#Initiate the Packet Capture command on remote system
		InVoke-WmiMethod -class Win32_process -name Create -ArgumentList $netshCMD -ComputerName $target -Credential $cred | Out-Null
				
		#Define Remote File Location using mapping
		$remfileloc = "x:\windows\temp\$artfolder\pktcap.etl"
		
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
		InVoke-WmiMethod -class Win32_process -name Create -ArgumentList $traceStop -ComputerName $target -Credential $cred | Out-Null
		
		#Detect Netsh doing Generating Data Collection
		Write-Host -ForegroundColor Magenta "Generating data collection and report. (be patient)"
		do {(Write-Host -ForegroundColor Cyan "    generating data collection and report..."),(Start-Sleep -Seconds 15)}
		until ((Get-WMIobject -Class Win32_process -Filter "Name='netsh.exe'" -ComputerName $target -Credential $cred | where {$_.Name -eq "netsh.exe"}).ProcessID -eq $null)
		Write-Host -ForegroundColor Green "Data collection and report DONE."
		echo ""	
				
		#COMPRESS THE PacketCap
		$remfileDir = "\\$target\c$\windows\temp\$artfolder"
		$zipFile = "\\$target\c$\windows\temp" + "\$artFolder.zip"
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