netshPacketCap
==============
This script is used to fire off a remote netsh packet capture trace, compress the trace, then transfer it to an analyis machine.
	
Requires Windows 7 and newer.

You will need 5 pieces of information: The target computer, destDir, maxSize, and the scenario you'd want to capture.

Info on Scenarios:
There are several scenarios you can use to capture packets to tailor your capture. (see below) Typically the LAN works well...

Available scenarios (18):
-------------------------------------------------------------------
AddressAcquisition       : Troubleshoot address acquisition-related issues
DirectAccess             : Troubleshoot DirectAccess related issues
FileSharing              : Troubleshoot common file and printer sharing problems
InternetClient           : Diagnose web connectivity issues
InternetServer           : Troubleshoot server-side web connectivity issues
L2SEC                    : Troubleshoot layer 2 authentication related issues
LAN                      : Troubleshoot wired LAN related issues
Layer2                   : Troubleshoot layer 2 connectivity related issues
MBN                      : Troubleshoot mobile broadband related issues
NDIS                     : Troubleshoot network adapter related issues
NetConnection            : Troubleshoot issues with network connections
P2P-Grouping             : Troubleshoot Peer-to-Peer Grouping related issues
P2P-PNRP                 : Troubleshoot Peer Name Resolution Protocol (PNRP) related issues
RemoteAssistance         : Troubleshoot Windows Remote Assistance related issues
RPC                      : Troubleshoot issues related to RPC framework
WCN                      : Troubleshoot Windows Connect Now related issues
WFP-IPsec                : Troubleshoot Windows Filtering Platform and IPsec related issues
WLAN                     : Troubleshoot wireless LAN related issues