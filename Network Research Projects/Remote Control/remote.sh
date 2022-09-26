#!/bin/bash

# INSTRUCTION
# 1. sudo bash remote.ssh <target ip address> <user id> <password> <[optional] "install">

# HURDLE(S)
# [-] Overcome fingerprint prompt
# 	[+] ..ssh -o "StrictHostKeyChecking no".. for fingerprint prompt handling

# 0. Variables for bridging/deciding with initialized values
anon=0

# 1. Install applications
if [ "$4" == "install" ]
then
	# [Work around]To enable tor installation
	sudo apt-get update

	# Non nipe
	declare -a install_list=("openssh-server" "sshpass" "tor" "nmap" "whois")

	for app in ${install_list[@]}
	do
		sudo apt-get -y install "$app" > /dev/null
	done

	# nipe
	sudo git clone https://github.com/htrgouvea/nipe && cd nipe
	sudo cpan install Try::Tiny Config::Simple JSON
	sudo perl nipe.pl install
fi

# 2. Check anonymous
function check_anonymous()
{
	# Set to nipe file location
	cd nipe 
	
	# Run nipe
	sudo perl nipe.pl restart
	stat_check=$(sudo perl nipe.pl status | grep -w activated)
	
	# Check anonymous status
	if [ ! -z "$stat_check" ]
	then
		echo "You are anonymous"
		anon=1
	else
		echo "You are exposed..retry in progress"
		anon=0
		check_anonymous
	fi
}

check_anonymous

# Set to intial location for output file storage
cd ..

# 3. Connect to Remote Target IP Address
if [ "$anon" -gt 0 ]
then
	read -p "Type A - for whois OR Type B - for nmap " Selection
	case "$Selection" in
		A)
			echo "Enter IP or website for whois check:"
			read A_answer
			sudo sshpass -p "$3" ssh -o "StrictHostKeyChecking no" "$2"@"$1" "hostname -I && whois $A_answer|grep OrgName" > ./whois_output
		;;
		B)
			echo "Enter IP or website for nmap scan:"
			read B_answer
			sudo sshpass -p "$3" ssh -o "StrictHostKeyChecking no" "$2"@"$1" "hostname -I && nmap $B_answer --open -sV -Pn -p1-500" > ./nmap_output
		;;
		esac

fi
