#! /usr/bin/env bash

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

script1() {
	set -e

	compose_file="$PWD/compose.yml"

	system_name="$(hostnamectl | grep "Operating System" | sed 's/^[ \t]*//;s/[ \t]*$//')"
	echo "$system_name"

	if command -v apt &> /dev/null; then
		package_manager="apt"
		echo -e "${GREEN}Package manager: $package_manager${NC}"
	else
		echo "${RED}In the system the package manager is NOT an apt. Only apt (Ubuntu, Debian and etc.)${NC}"
		exit 1
	fi

	echo -e "${GREEN}The system is in the process of updating and installing software...You need to wait${NC}"
	export DEBIAN_FRONTEND=noninteractive
	apt update -y &> /dev/null
	apt install -y debconf-utils &> /dev/null
	echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections &> /dev/null
	echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections &> /dev/null
	apt install -y curl git nano nmap iptables-persistent &> /dev/null


	if command -v docker &> /dev/null; then
		echo -e "${GREEN}Docker is installed${NC}"
	else
		echo -e "${GREEN}Docker is not installed. Proceeding with download and installation${NC}"
		curl -fsSL https://get.docker.com | sh &> /dev/null
	fi

	container1='amnezia'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container1}\$"; then
    		echo -e "${GREEN}VPN Server is running. The service is already. Use 4 point in menu${NC}"
    		echo
		sleep 3
		return
	fi

	while true; do
		read -p "Enter the language for the Amnezia web interface (en, ua, ru, tr, no, pl, fr, de, ca, es, ko, vi, nl, is, pt, chs, cht, it, th, hi, ja, si): " lang
		if [ -z "$lang" ]; then
			echo -e "${GREEN}Without a choice of language, then your language will be default language (En)${NC}"
			lang="en"
			break
		fi
		if [[ "$lang" =~ ^(en|ua|ru|tr|no|pl|fr|de|ca|es|ko|vi|nl|is|pt|chs|cht|it|th|hi|ja|si)$ ]]; then
			break
		else
			echo -e "${RED}Incorrect language selection entered. Try again${NC}"
		fi
	done

	compose_file="$PWD/compose.yml"
	echo -e "${GREEN}Your chosen interface language:${NC}" "$lang"
	sed -i "s/^ *- LANG=.*/       - LANG=${lang}/" "$compose_file"

	ip="$(curl ifconfig.me 2> /dev/null)"
	echo -e "${GREEN}Your routed IP address:${NC}" "$ip"
	sed -i "s/^ *- WG_HOST=.*/       - WG_HOST=${ip}/" "$compose_file"

	random_wg_port="$((RANDOM % 10001 + 35000))"
	sed -i "/wireguard:/,/ports:/ s|\(.*ports:.*\)|\1\n       - \"${random_wg_port}:${random_wg_port}/udp\"|" "$compose_file"
	sed -i "s/^ *- WG_PORT=.*/       - WG_PORT=${random_wg_port}/" "$compose_file"
	sleep 2

	while true; do
		read -p "Enter your password and press Enter to access the Amnezia web interface: " password
		if [ -z "$password" ]; then
			echo -e "${RED}You can't get into the panel without a password. Password cannot be empty. Try again${NC}"
		elif [[ ! "$password" =~ ^[a-zA-Z0-9]+$ ]]; then
			echo -e "${RED}Password must contain only english characters and numbers. Try again${NC}"
		else
			break
		fi
	done

	echo -e "${GREEN}Your password to access the Amnezia web interface:${NC}" "$password"
	hash="$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$password" 2>/dev/null)"
	escaped_hash=$(echo "$hash" | grep -oP "PASSWORD_HASH='\K.*(?=')" | sed 's/\$/\$\$/g')
	awk -v hash="$escaped_hash" '/^ *- PASSWORD_HASH=/ { sub(/- PASSWORD_HASH=.*/, "- PASSWORD_HASH=" hash) } 1' "$compose_file" > temp_compose.yml && mv temp_compose.yml "$compose_file"
	sleep 2

	random_octet="$((RANDOM % 100))"
	wg_default_addres="10.${random_octet}.0.x"
	wg_default_address_1="10.${random_octet}.0.0"
	sed -i "s/^ *- WG_DEFAULT_ADDRESS=.*/       - WG_DEFAULT_ADDRESS=${wg_default_addres}/" "$compose_file"
	sleep 2

	if ! grep -q "net.ipv4.ip_forward = 1" /etc/sysctl.conf; then
		echo "net.ipv4.ip_forward = 1"  >> /etc/sysctl.conf
		echo -e "${GREEN}Add IP forward rule in config${NC}"
	else
		echo -e "${GREEN}IP forward rule already exists in config. Its ok${NC}"
	fi
	echo
	sleep 2

	sysctl -p &> /dev/null

	interface="$(ip -br a | grep -Ev '^(lo|docker)' | awk '$2 == "UP" {print $1}' | head -n 1)"

	echo -e "${GREEN}An example of a free service for getting your own free name${NC}"
	echo "Use a web browser and click on the link https://www.duckdns.org, log in to your account"
	sleep 2
	echo
	echo "On your personal account page, add your domain name in the sub domain column, and click on the add domain button"
	sleep 2
	echo
	echo "If a name already exists, think of another one"
	sleep 2
	echo
	echo "After adding it, you will see a line where your name and IP address will be indicated, you need to change it to your $ip and click the update ip button"
	sleep 2
	echo
	echo "Repeat these operations for the second domain"
	sleep 2
	echo

	while true; do
		read -p "Now write me your first domain name Web-panel Amnezia, for example.org and press Enter " d_name1
		if [[ "$d_name1" =~ ^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$ ]]; then
			echo -e "${GREEN}You entered domain name:${NC}" "$d_name1"
			break
		else
			echo -e "${RED}Try again, incorrect format. Enter your domain name in the format example.org${NC}"
		fi
	done

	sed -i "/wireguard:/,/environment:/!b;/environment:/a \ \ \ \    - VIRTUAL_HOST=${d_name1}\n\ \ \ \    - LETSENCRYPT_HOST=${d_name1}" $compose_file

	sleep 1

	while true; do
		read -p "Now write me your second domain name Web-panel Beszel, for example.org and press Enter " d_name2
		if [[ "$d_name2" =~ ^[a-zA-Z0-9-]+(\.[a-zA-Z0-9-]+)*$ ]]; then
			echo -e "${GREEN}You entered domain name:${NC}" "$d_name2"
			break
		else
			echo -e "${RED}Try again, incorrect format. Enter your domain name in the format example.org${NC}"
		fi
	done

	sed -i "/beszel:/,/environment:/!b;/environment:/a \ \ \ \    - VIRTUAL_HOST=${d_name2}\n\ \ \ \    - LETSENCRYPT_HOST=${d_name2}" $compose_file

	sleep 1

	while true; do
		read -p "Enter your valid email address and press Enter " email
		if [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$  ]]; then
			echo -e "${GREEN}You entered email address:${NC}" "$email"
			break
		else
			echo -e "${RED}Try again, incorrect email format. Make sure to include an '@' symbol and a valid domain${NC}"
		fi
	done

	sed -i "/wireguard:/,/environment:/!b;/environment:/a \ \ \ \    - LETSENCRYPT_EMAIL=${email}" $compose_file
	sed -i "/beszel:/,/environment:/!b;/environment:/a \ \ \ \    - LETSENCRYPT_EMAIL=${email}" $compose_file

	sleep 1

	iptables -t nat -A POSTROUTING -s "$wg_default_address_1/24" -o "$interface" -j MASQUERADE

	sleep 3

	if sudo systemctl is-enable netfilter-persistent &> /dev/null; then
		echo "Netfilter-persistent is already enabled at startup"
	else
		echo "Enabling netfilter-persistent at startup"
		systemctl enable netfilter-persistent
	fi

	sleep 1

	if sudo systemctl is-active netfilter-persistent &> /dev/null; then
		echo "Netfilter-persistent restarted"
		systemctl restart netfilter-persistent
	else
		echo "Start netfilter-persistent"
		systemctl start netfilter-persistent
	fi

	sleep 1

	iptables-save | tee /etc/iptables/rules.v4 &> /dev/null
	systemctl restart docker &> /dev/null
	sleep 5
	docker compose -f $compose_file up -d &> /dev/null
	sleep 2

	echo -e "${GREEN}Receiving two SSL certificates...You need to wait${NC}"

	if timeout 120 bash -c '
		count=0
		while [ $count -lt 2 ]; do
			find_count=$(docker logs letsencrypt 2>&1 | grep -c "Cert success" 2>/dev/null | tr -cd "0-9")
			find_count=${find_count:-0}
			if [ $find_count -gt $count ]; then
				echo "Received $find_count certificates"
				count=$find_count
			fi
			[ $count -eq 2 ] && exit 0
			sleep 5
		done
	'; 	then
			echo -e "${GREEN}All certificates received${NC}"
			sleep 2
	else
                echo -e "${RED}The problem is on the side of the certificate authority. The script will be stopped in an emergency, try to start it again in a few minutes${NC}"
                docker compose -f $compose_file down &> /dev/null
                docker volume rm vpn-amnezia-wg-main_conf.d vpn-amnezia-wg-main_vhost.d vpn-amnezia-wg-main_html vpn-amnezia-wg-main_certs vpn-amnezia-wg-main_etc_wireguard &> /dev/null
                rm -r $compose_file &> /dev/null
                curl -L -O https://raw.githubusercontent.com/sergeybezlepkin/vpn-amnezia-wg/main/compose.yml &> /dev/null
                exit 1
    fi

    if nmap -sU -p $random_wg_port $ip &> /dev/null; then
                echo -e "${GREEN}Your port $random_wg_port is open${NC}"
    else
                echo -e "Your port $random_wg_port is not open. You need to contact your service provider and show the output below. And run the script again${NC}"
                docker compose -f $compose_file down &> /dev/null
                docker volume rm vpn-amnezia-wg-main_conf.d vpn-amnezia-wg-main_vhost.d vpn-amnezia-wg-main_html vpn-amnezia-wg-main_certs vpn-amnezia-wg-main_etc_wireguard &> /dev/null
                rm -r $compose_file &> /dev/null
                curl -L -O https://raw.githubusercontent.com/sergeybezlepkin/vpn-amnezia-wg/main/compose.yml &> /dev/null
                nmap -sU -p $random_wg_port $ip
                exit 1
    fi

	echo
	compose_beszel="$PWD/agent.yml"
	port_beszel_agent="$((RANDOM % 10001 + 55000))"

	echo -e "${GREEN}Configure the Beszel Web Dashboard${NC}"
	echo "Go to the panel https://$d_name2, create a user for this, enter your email and come up with a password. And enter the panel"
	echo
	sleep 2
	echo "In the upper-right corner, click on the 'Add System' button"
	echo
	sleep 2
	echo -e "${GREEN}In the 'Add system' window, you need to fill in the lines:${NC}"
	echo
	sleep 1
	echo -e "${GREEN}Come up with a name${NC}"
	echo
	sleep 1
	echo -e "${GREEN}Add this IP address:${NC}" "$ip"
	echo
	sleep 1
	echo -e "${GREEN}Add this port:${NC}" "$port_beszel_agent"
	echo
	sleep 1
	echo -e "${GREEN}Copy the line with the Public key and click Add system${NC}"

	sed -i "s|^[[:space:]]*LISTEN:.*|       LISTEN: \"$port_beszel_agent\"|" "$compose_beszel"
	echo
        sleep 1
	while true; do
		echo "Insert the ssh-ed public key, use for example shift + insert to paste the code and press Enter"
		read -r code
		if [[ $code =~ ^ssh-ed25519[[:space:]]+[A-Za-z0-9+/=]+[A-Za-z0-9+/=]*$ ]]; then
			echo -e "${GREEN}The key is accepted${NC}"
			break
		else
			echo "${RED}Incorrect key format. It must start with 'ssh-ed25519' and must contain a base64 string after a space${NC}"
		fi
	done

	sed -i "s|^[[:space:]]*KEY:[[:space:]].*|       KEY: \"$code\"|" "$compose_beszel"
	sed -i "s|^[[:space:]]*HUB_URL:.*|       HUB_URL: \"$d_name2\"|" "$compose_beszel"

	echo -e "${GREEN}Do not close this page, there is no data from the system yet, but YOU NEED TO WAIT 1-5 minutes${NC}"
	docker compose -f $compose_beszel up -d &> /dev/null
	sleep 3
	echo

	container1='amnezia'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container1}\$"; then
		status=$(docker inspect --format='{{.State.Status}}' "$container1" 2>/dev/null)
		health=$(docker inspect --format='{{.State.Health.Status}}' "$container1" 2>/dev/null)

		if [[ "$status" == "running" && "$health" == "healthy" ]]; then
    			echo -e "${GREEN}VPN Server is running. The service is already${NC}"
		fi
	fi

	sleep 1

	container2='beszel'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container2}\$"; then
		status=$(docker inspect --format='{{.State.Status}}' "$container2" 2>/dev/null)
        	health=$(docker inspect --format='{{.State.Health.Status}}' "$container2" 2>/dev/null)

        	if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                	echo -e "${GREEN}Monitoring is running. The service is already${NC}"
        	fi
	fi

	sleep 1

	container3='beszel-agent'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container3}\$"; then
		status=$(docker inspect --format='{{.State.Status}}' "$container3" 2>/dev/null)
        	health=$(docker inspect --format='{{.State.Health.Status}}' "$container3" 2>/dev/null)

        	if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                	echo -e "${GREEN}Agent monitoring is running. The service is already${NC}"
        	fi
	fi

	sleep 1

	container4='nginx'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container4}\$"; then
		status=$(docker inspect --format='{{.State.Status}}' "$container4" 2>/dev/null)
        	health=$(docker inspect --format='{{.State.Health.Status}}' "$container4" 2>/dev/null)

        	if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                	echo -e "${GREEN}Reverse-proxy is running. The service is already${NC}"
        	fi
	fi

	sleep 1

	container5='letsencrypt'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container5}\$"; then
		status=$(docker inspect --format='{{.State.Status}}' "$container5" 2>/dev/null)
        	health=$(docker inspect --format='{{.State.Health.Status}}' "$container5" 2>/dev/null)

        	if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                	echo -e "${GREEN}Certificate Authority is running. The service is already${NC}"
        	fi
	fi

	sleep 1

	container6='watchtower'
	if docker ps -a --format '{{.Names}}' | grep -q "^${container6}\$"; then
		status=$(docker inspect --format='{{.State.Status}}' "$container6" 2>/dev/null)
        	health=$(docker inspect --format='{{.State.Health.Status}}' "$container6" 2>/dev/null)

        	if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                	echo -e "${GREEN}Update images service is running. The service is already${NC}"
        	fi
	fi

	sleep 1

	echo
        echo -e "${GREEN}Setup is complete${NC}"
	echo
	sleep 1
	echo -e "To access the server web panel Amnezia, use ${GREEN}https://$d_name1 and password: $password${NC}, go to the panel, log in with your password and create the first user"
	echo
	sleep 1
	echo "To do this, click on '+ New Client', and enter your client name and click 'Create'"
	echo
	sleep 1
	echo "And you will see add new client"
	echo
	sleep 1
	echo -e "${GREEN}You can download the app for any device here: https://github.com/amnezia-vpn/amnezia-client/releases - Windows, Linux, Android, and look in the App store on your smartphone - AmneziaWG${NC}"
	echo
	sleep 1
	echo "Click on the 'Download' configuration icon and add it to the Amnezia VPN application on your computer"
	echo
	sleep 1
	echo "Click on the 'QR code' icon to display the code, open the application on your mobile device, press '+' and select 'Create from QR code' and put your camera on the qr-code"
	echo
	sleep 1
	echo -e "${GREEN}It can be used. That's all${NC}"
        echo
	echo -e "${GREEN}Web-panel Beszel - https://$d_name2 and your password"
	echo
	sleep 7
}

script2() {

	set -e
	echo
	container1='amnezia'
        if docker ps -a --format '{{.Names}}' | grep -q "^${container1}\$"; then
                status=$(docker inspect --format='{{.State.Status}}' "$container1" 2>/dev/null)
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container1" 2>/dev/null)

                if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                        echo
                fi
        else
                echo -e "${RED}Server VPN is not performed. The service is not ready, use the first point${NC}"
        	echo
		sleep 3
		return
	fi

	echo -e "${GREEN}Reset your password with web-panel Amnezia${NC}"
	echo

	while true; do
    		read -p "Ready? (yes/no) " answer
    		if [ -z "$answer" ]; then
        		echo -e "${RED}Empty answer is not accepted${NC}" "$answer"
    		elif [[ "$answer" = "no" ]]; then
        		echo -e "${GREEN}Operation cancelled${NC}"
			sleep 3
			return
    		elif [[ ! "$answer" =~ ^[a-zA-Z]+$ ]]; then
        		echo -e "${RED}Only english characters. Try again${NC}"
    		elif [[	"$answer" = "yes" ]]; then
        		break
    		fi
	done

	compose_file="$PWD/compose.yml"

	while true; do
    		read -p "Enter your new password and press Enter to access the Amnezia web interface: " password
    		if [ -z "$password" ]; then
        		echo -e "${RED}You can't get into the panel without a password. Password cannot be empty. Try again${NC}"
    		elif [[ ! "$password" =~ ^[a-zA-Z0-9]+$ ]]; then
        		echo -e "${RED}Password must contain only english characters and numbers. Try again${NC}"
    		else
        		break
    		fi
	done

	hash="$(docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$password" 2>/dev/null)"
	escaped_hash=$(echo "$hash" | grep -oP "PASSWORD_HASH='\K.*(?=')" | sed 's/\$/\$\$/g')
	awk -v hash="$escaped_hash" '/^ *- PASSWORD_HASH=/ { sub(/- PASSWORD_HASH=.*/, "- PASSWORD_HASH=" hash) } 1' "$compose_file" > temp_compose.yml && mv temp_compose.yml "$compose_file"
	sleep 1
	docker rm -f amnezia &> /dev/null
	docker compose up -d &> /dev/null
	sleep 3
	echo
	echo -e "${GREEN}Your new password to access the Amnezia web interface:${NC}" "$password"
	echo
	echo -e "${GREEN}Go to the panel with a new password${NC}"
	echo
	sleep 5
}

script3() {

	set -e
	echo
	container2='beszel'
        if docker ps -a --format '{{.Names}}' | grep -q "^${container2}\$"; then
                status=$(docker inspect --format='{{.State.Status}}' "$container2" 2>/dev/null)
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container2" 2>/dev/null)

                if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                        echo
                fi
	else
		echo -e "${RED}Monitoring is not performed. The service is not ready, use the first point${NC}"
		echo
		sleep 3
		return
        fi

	echo -e "${RED}Reset your password with web-panel Beszel${NC}"
	echo
	echo -e "${GREEN}Before you can set a new password for your account, you need to reset your database password${NC}"
	echo
	while true; do
    		read -p "Enter your email and press Enter to access the Beszel web interface: " email
    		if [ -z "$email" ]; then
                        echo -e "${RED}Password cannot be empty. Try again${NC}"
		elif [[ "$email" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
       			break
    		else
       			echo -e "${RED}Try again, incorrect email format. Make sure to include an '@' symbol and a valid domain${NC}"
    		fi
	done

	while true; do
    		read -p "Enter your new password and press Enter to access the Beszel database: " pocketbase
    		if [ -z "$pocketbase" ]; then
        		echo -e "${RED}You can't get into data base without a password. Password cannot be empty. Try again${NC}"
    		elif [[ ! "$pocketbase" =~ ^[a-zA-Z0-9]+$ ]]; then
        		echo -e "${RED}Password must contain only english characters and numbers. Try again${NC}"
    		else
        		break
    		fi
	done

	docker exec beszel /beszel superuser upsert $email $pocketbase &> /dev/null

	echo
	echo -e "${GREEN}The password for the Beszel database has been reset. Now you need to set a new password for the web panel in the database${NC}"
	echo
	sleep 1
	echo -e "${GREEN}Set your new password with web-panel Beszel${NC}"
	echo
	sleep 1
	echo "Go to the database panel your_beszel_domain_name/_/#/login, for example: monv.duckdns.org/_/#/login and  using an email address and a new set password"
	echo
	sleep 1
	echo "In the menu on the left, select Collections and click on users"
	echo
	sleep 1
	echo "Select your user from the list"
	echo
	sleep 1
	echo "From the drop-left menu on the right, select - Change password"
	echo
	sleep 1
	echo "Enter your new password and click Save Changes"
	echo

	while true; do
                read -p "Ready? (yes) " answer
                if [ -z "$answer" ]; then
                        echo -e "${RED}Empty answer is not accepted. 6 points must be completed${NC}" "$answer"
                elif [[ ! "$answer" =~ ^[a-zA-Z]+$ ]]; then
                        echo -e "${RED}Password must contain only english characters and numbers. Try again${NC}"
                elif [[ "$answer" = "yes" ]]; then
                        break
                fi
        done
	echo
	echo -e "${GREEN}That's it. Go to the web-panel Beszel enter your email and new password${NC}"
	echo
	sleep 5
}

script4() {

	set -e
	echo
	compose_file="$PWD/compose.yml"

	container1='amnezia'
        if docker ps -a --format '{{.Names}}' | grep -q "^${container1}\$"; then
                status=$(docker inspect --format='{{.State.Status}}' "$container1" 2>/dev/null)
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container1" 2>/dev/null)

                if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                        echo -e "${GREEN}VPN Server is running. The service is already${NC}"
                        grep -E "VIRTUAL_HOST=[^[:space:]]+" "$compose_file" | grep -o 'VIRTUAL_HOST=[^[:space:]]*' | cut -d'=' -f2 | tr -d '"'\' | sed 's|.*|https://&|' | awk '{print "URL: " NR ": " $0}'
		fi
        else
		echo -e "${RED}Server VPN is not performed. The service is not ready, use the first point${NC}"
		echo
		sleep 3
		return
	fi
	echo
	sleep 5
}

script5() {

	set -e
	echo
	container2='beszel'
        if docker ps -a --format '{{.Names}}' | grep -q "^${container2}\$"; then
                status=$(docker inspect --format='{{.State.Status}}' "$container2" 2>/dev/null)
                health=$(docker inspect --format='{{.State.Health.Status}}' "$container2" 2>/dev/null)

                if [[ "$status" == "running" && "$health" == "healthy" ]]; then
                        echo
                fi
        else
                echo -e "${RED}Monitoring is not performed. The service is not ready, use the first point${NC}"
        	echo
		sleep 3
		return
	fi

	echo -e "${GREEN}Setting up Beszel notifications in Telegram${NC}"
        echo
	sleep 1
	echo "Open the Bezel Database Panel. You can use the address: your_domain/_/#/login, for example: monv.duckdns.org/_/#/login or in the Bezel monitoring system, click on the profile and select Systems"
	echo
	sleep 1
	echo "Enter the login and password from the panel Beszel, click Settings and in the Application URL field, add your domain so it looks like https://your_domain and click Save changes"
	echo
	sleep 1
	echo "Open the Beszel monitoring system"
	echo
	sleep 1
	echo "Click on the Settings"
	echo
	sleep 1
	echo "In the settings you need a Notifications section"
	echo
	sleep 1
	echo "In the Webhook / Push notifications section, click Add URL. A window for inserting text will appear"
	echo
	sleep 1
	echo "Do not close the notification settings page, you will need to add the required line here"
	echo

	while true; do
                read -p "Ready? (yes) " answer
                if [ -z "$answer" ]; then
                        echo -e "${RED}Empty answer is not accepted${NC}" "$answer"
                elif [[ ! "$answer" =~ ^[a-zA-Z]+$ ]]; then
                        echo -e "${RED}Only english characters. Try again${NC}"
                elif [[ "$answer" = "yes" ]]; then
                        break
                fi
        done
	echo "To set up, you need a Telegram bot token"
	echo
	sleep 1
        echo -e "${GREEN}Create a bot and get an API token${NC}"
	echo
	sleep 1
	echo -e "${RED}A Quick Guide to Creating a Telegram Bot${NC}"
	echo
	sleep 1
	echo "Open the Telegram app on your device"
	echo
	sleep 1
	echo "In the search, type @BotFather, select the bot with the wrench icon and the word Verified (this is the official bot). Type the command /start in the chat with BotFather"
	echo
	sleep 1
	echo "Then send the command /newbot. BotFather will ask you to enter a name for your bot (this is the name that users will see). For example, MyTestBot"
	echo
	sleep 1
	echo "After that, you will need to come up with a username for your bot. Eventually, it should become a bot (for example, MyTestBot_bot). This username should be successful"
	echo
	sleep 1
	echo "After creating the bot, BotFather will send you a message with an API token. It looks like a string of numbers and letters, for example: 123456789:ABCdefGhIJKlmNoPQRstuVWXyz"
	echo
	sleep 1

	while true; do
                read -p "Ready? The token may already be ready, copy it (yes) " answer
                if [ -z "$answer" ]; then
                        echo -e "${RED}Empty answer is not accepted${NC}" "$answer"
                elif [[ ! "$answer" =~ ^[a-zA-Z]+$ ]]; then
                        echo -e "${RED}Only english characters. Try again${NC}"
                elif [[ "$answer" = "yes" ]]; then
                        break
                fi
        done
	echo
	echo -e "${GREEN}To insert a token into the terminal, use for example Shift + Insert${NC}"
	echo
	sleep 1
	echo -e "${GREEN}The service will be launched now, answer the questions and as a result you will receive a string${NC}"
	sleep 3
	echo
	docker pull containrrr/shoutrrr &> /dev/null
	docker run --rm -it containrrr/shoutrrr generate telegram
	echo
	sleep 1
	echo "Paste the line into the Webhook/Push Notifications field starting with telegram://.... and click "Test URL". After clicking "Save Settings" you will receive a test message"
	echo
	sleep 1
	echo "On the main page of the monitoring system, next to your system, click on the bell and turn on the sliders"
	echo
	echo -e "${GREEN}That's all${NC}"
	echo
	sleep 5
}

script6() {
	exit 1
}

menu() {
    echo -e "	Automatic installation and configuration of ${RED}Amnezia VPN server${NC} with web interface,"
    echo "      		 node monitoring, with encryption on a free domain name"
    echo
    echo -e "${GREEN}1. Install and configure VPN server Amnezia${NC}"
    echo
    echo "  - VPN server with web control panel"
    echo "  - Monitoring service and Bezel agent"
    echo "  - Nginx web server for proxying and access to the panel via a free domain name"
    echo "  - LetsEncrypt for automatic issuance of free SSL certificates"
    echo "  - Watchtower for automatic monitoring and updating of containers"
    echo
    echo -e "${GREEN}2. Reset web panel password Amnezia${NC}"
    echo
    echo "  - Reset password for access to web-panel to vpn server"
    echo
    echo -e "${GREEN}3. Reset web panel password Beszel${NC}"
    echo
    echo "  - Database profile password reset"
    echo "  - Web panel profile password reset"
    echo
    echo -e "${GREEN}4. Find out your domain names${NC}"
    echo
    echo "  - Let's check if the container works with the VPN server"
    echo "  - It will display domain name records on the screen"
    echo
    echo -e "${GREEN}5. Setting up Beszel notifications in Telegram${NC}"
    echo
    echo "  - Notifications in Beszel are defined using Shoutrrr URL schemas"
    echo "  - A Quick Guide to Creating a Telegram Bot"
    echo
    echo -e "${GREEN}6. Exit${NC}"
}

while true; do
    echo
    menu
    echo
    read -p "Enter number (1-6): " choice
	case $choice in
             1)
		script1
		;;
	     2)
                script2
		;;
	     3)
		script3
		;;

            4)
		script4
		;;

	     5)
		script5
		;;

	     6)
		script6
		break
		;;
	esac
done
