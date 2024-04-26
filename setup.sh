#!/bin/bash

clear

##############################################################
# Define ANSI escape sequence for green, red and yellow font #
##############################################################

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'


########################################################
# Define ANSI escape sequence to reset font to default #
########################################################

NC='\033[0m'


#################
# Intro message #
#################

# Get the short hostname directly
HOSTNAME=$(hostname -s)

# Extract the domain name from /etc/resolv.conf

# Method 1: Using awk
DOMAIN_LOCAL=$(awk -F' ' '/^domain/ {print $2; exit}' /etc/resolv.conf)
if [[ -n "$DOMAIN_LOCAL" ]]; then
    echo -e "${GREEN} Domain name found using:${NC} awk"
else
    # Method 2: Using sed
    DOMAIN_LOCAL=$(sed -n 's/^domain //p' /etc/resolv.conf)
    if [[ -n "$DOMAIN_LOCAL" ]]; then
        echo -e "${GREEN} Domain name found using:${NC} sed"
    else
        echo -e "${RED} Domain name not found using available methods .${NC}"
        exit 1
    fi
fi

# IP Address extraction

# Method 1: Using hostname -I to get the local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}') # Picks the first IP address
if [[ -n "$LOCAL_IP" ]]; then
    echo -e "${GREEN} IP Address found using:${NC} hostname -I"
else
    # Method 2: Parsing through ip addr show
    LOCAL_IP=$(ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $2}' | cut -d/ -f1 | grep -v '127.0.0.1')
    if [[ -n "$LOCAL_IP" ]]; then
        echo -e "${GREEN} IP Address parsed from uotput of:${NC} ip addr show"
    else
        echo -e "${RED} IP Address not found using available methods .${NC}"
    fi
fi

echo
echo -e "${GREEN} This script will install and configure latest${NC}" Nextcloud server 
echo -e "${GREEN} and it's prerequisites:${NC} Apache HTTP Server, PHP 8.3, MariaDB, Redis ${GREEN}and${NC} Certbot" 
echo
echo
echo -e "${GREEN} Local IP Address      :${NC} $LOCAL_IP"
echo -e "${GREEN} Machine hostname      :${NC} $HOSTNAME"
echo -e "${GREEN} Local domain          :${NC} $DOMAIN_LOCAL"
echo
echo
echo -e "${GREEN} Be sure that you are logged in as a${NC} non-root ${GREEN}user and that user is added to the${NC} sudo ${GREEN}group"${NC}

sleep 0.5 # delay for 0.5 seconds
echo

echo -e "${GREEN} Decide what you will use for: ${NC}"
echo -e " - Public Key to configure your SSH access to container"
echo -e " - User name and Password for Nextcloud Admin user"
echo -e " - Email Address for Certificate registration"
echo -e " - Cloudflare API token"
echo -e " - for external access: Domain name, optionally: Subdomain ${NC}"
echo


#######################################
# Prompt user to confirm script start #
#######################################

while true; do
    echo -e "${GREEN} Start installation and configuration?${NC} (yes/no) "
    echo
    read choice
    echo
    choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]') # Convert input to lowercase

    # Check if user entered "yes"
    if [[ "$choice" == "yes" ]]; then
        # Confirming the start of the script
        echo
        echo -e "${GREEN} Starting... ${NC}"
        sleep 0.5 # delay for 0.5 second
        echo
        break

    # Check if user entered "no"
    elif [[ "$choice" == "no" ]]; then
        echo -e "${RED} Aborting script. ${NC}"
        exit

    # If user entered anything else, ask them to correct it
    else
        echo -e "${YELLOW} Invalid input. Please enter${NC} 'yes' or 'no'"
        echo
    fi
done


################## T e m p l a t e  p a r t ##################
### ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ###


####################
# Install Packages #
####################

echo -e "${GREEN} Installing packages... ${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

# Update the package repositories
if ! sudo apt update; then
    echo -e "${RED} Failed to update package repositories. Exiting.${NC}"
    exit 1
fi

# Template packages
if ! sudo apt install -y \
    ufw \
    wget \
    curl \
    gnupg2 \
    argon2 \
    fail2ban \
    lsb-release \
    gnupg-agent \
    libpam-tmpdir \
    bash-completion \
    ca-certificates \
    qemu-guest-agent \
    unattended-upgrades \
    cloud-initramfs-growroot \
    software-properties-common; then
    echo -e "${RED} Failed to install packages. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN} Setting up PHP Repository...${NC}"

# Add the GPG key for the Ondřej Surý PHP repository
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
if [ $? -ne 0 ]; then
    echo -e "${RED} Error downloading the GPG key for PHP repository. Exiting.${NC}"
    exit 1
fi

# Add the PHP repository to the sources list
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
if [ $? -ne 0 ]; then
    echo -e "${RED} Error adding the PHP repository to sources list. Exiting.${NC}"
    exit 1
fi

# Update the package repositories
if ! sudo apt update; then
    echo -e "${RED} Failed to update package repositories. Exiting.${NC}"
    exit 1
fi

# Application packages
if ! sudo apt install -y \
    apache2 \
    mariadb-server \
    redis-server \
    p7zip-full \
    apt-transport-https \
    certbot \
    python3-certbot-dns-cloudflare \
    php8.3 \
    libapache2-mod-php8.3 \
    php8.3-{zip,xml,mbstring,gd,curl,imagick,intl,bcmath,gmp,cli,mysql,apcu,redis,smbclient,ldap,bz2,fpm} \
    php-dompdf \
    libmagickcore-6.q16-6-extra \
    php-pear; then
    echo -e "${RED} Failed to install packages. Exiting.${NC}"
    exit 1
fi


#######################
# Create backup files #
#######################

echo
echo -e "${GREEN} Creating backup files${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

# Backup the existing /etc/hosts file
if [ ! -f /etc/hosts.backup ]; then
    sudo cp /etc/hosts /etc/hosts.backup
    echo -e "${GREEN} Backup of${NC} /etc/hosts ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/hosts ${YELLOW}already exists. Skipping backup.${NC}"
fi

# Backup the existing 50unattended-upgrades file
if [ ! -f /etc/apt/apt.conf.d/50unattended-upgrades.backup ]; then
    sudo cp /etc/apt/apt.conf.d/50unattended-upgrades /etc/apt/apt.conf.d/50unattended-upgrades.backup
    echo -e "${GREEN} Backup of${NC} /etc/apt/apt.conf.d/50unattended-upgrades ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/apt/apt.conf.d/50unattended-upgrades ${YELLOW}already exists. Skipping backup.${NC}"
fi

# To preserve fail2ban custom settings...
if ! sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local; then
    echo -e "${RED} Failed to copy jail.conf to jail.local. Exiting.${NC}"
    exit 1
fi

# Backup the existing /etc/fail2ban/jail.local file
if [ ! -f /etc/fail2ban/jail.local.backup ]; then
    sudo cp /etc/fail2ban/jail.local /etc/fail2ban/jail.local.backup
    echo -e "${GREEN} Backup of${NC} /etc/fail2ban/jail.local ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/fail2ban/jail.local ${YELLOW}already exists. Skipping backup.${NC}"
fi

# Backup the existing /etc/ssh/sshd_config file
if [ ! -f /etc/ssh/sshd_config.backup ]; then
    sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    echo -e "${GREEN} Backup of${NC} /etc/ssh/sshd_config ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/ssh/sshd_config ${YELLOW}already exists. Skipping backup.${NC}"
fi

# Backup the existing /etc/pam.d/sshd file
if [ ! -f /etc/pam.d/sshd.backup ]; then
    sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.backup
    echo -e "${GREEN} Backup of${NC} /etc/pam.d/sshd ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/pam.d/sshd ${YELLOW}already exists. Skipping backup.${NC}"
fi

# Backup the existing /etc/fstab file
if [ ! -f /etc/fstab.backup ]; then
    sudo cp /etc/fstab /etc/fstab.backup
    echo -e "${GREEN} Backup of${NC} /etc/fstab ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/fstab ${YELLOW}already exists. Skipping backup.${NC}"
fi

# Backup the existing /etc/sysctl.conf file
if [ ! -f /etc/sysctl.conf.backup ]; then
    sudo cp /etc/sysctl.conf /etc/sysctl.conf.backup
    echo -e "${GREEN} Backup of${NC} /etc/sysctl.conf ${GREEN}created.${NC}"
else
    echo -e "${YELLOW} Backup of${NC} /etc/sysctl.conf ${YELLOW}already exists. Skipping backup.${NC}"
fi


######################
# Prepare hosts file #
######################

echo
echo -e "${GREEN} Setting up hosts file ${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

# Extract the domain name from /etc/resolv.conf
domain_name=$(awk -F' ' '/^domain/ {print $2; exit}' /etc/resolv.conf)

# Get the host's IP address and hostname
host_ip=$(hostname -I | awk '{print $1}')
host_name=$(hostname)

# Construct the new line for /etc/hosts
new_line="$host_ip $host_name $host_name.$domain_name"

# Create a temporary file with the desired contents
{
    echo "$new_line"
    echo "============================================"
    # Replace the line containing the current hostname with the new line
    awk -v hostname="$host_name" -v new_line="$new_line" '!($0 ~ hostname) || $0 == new_line' /etc/hosts
} > /tmp/hosts.tmp

# Move the temporary file to /etc/hosts
sudo mv /tmp/hosts.tmp /etc/hosts

echo -e "${GREEN} File${NC} /etc/hosts ${GREEN}has been updated ${NC}"
echo


############################################
# Automatically enable unattended-upgrades #
############################################

echo -e "${GREEN} Enabling unattended-upgrades ${NC}"

# Enable unattended-upgrades
if echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | sudo debconf-set-selections && sudo dpkg-reconfigure -f noninteractive unattended-upgrades; then
    echo
    echo -e "${GREEN} Unattended-upgrades enabled successfully.${NC}"
    echo
else
    echo -e "${RED} Failed to enable unattended-upgrades. Exiting.${NC}"
    exit 1
fi

# Define the file path
FILEPATH="/etc/apt/apt.conf.d/50unattended-upgrades"

# Check if the file exists before attempting to modify it
if [ ! -f "$FILEPATH" ]; then
    echo -e "${RED}$FILEPATH does not exist. Exiting.${NC}"
    exit 1
fi

# Uncomment the necessary lines
if sudo sed -i 's|//Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";|g' $FILEPATH \
   && sudo sed -i 's|//Unattended-Upgrade::Remove-New-Unused-Dependencies "true";|Unattended-Upgrade::Remove-New-Unused-Dependencies "true";|g' $FILEPATH \
   && sudo sed -i 's|//Unattended-Upgrade::Remove-Unused-Dependencies "false";|Unattended-Upgrade::Remove-Unused-Dependencies "true";|g' $FILEPATH \
   && sudo sed -i 's|//Unattended-Upgrade::Automatic-Reboot "false";|Unattended-Upgrade::Automatic-Reboot "true";|g' $FILEPATH \
   && sudo sed -i 's|//Unattended-Upgrade::Automatic-Reboot-Time "02:00";|Unattended-Upgrade::Automatic-Reboot-Time "02:00";|g' $FILEPATH; then
    echo -e "${GREEN} unattended-upgrades configuration updated successfully.${NC}"
    echo
else
    echo -e "${RED} Failed to update configuration. Please check your permissions and file paths. Exiting.${NC}"
    exit 1
fi


#######################
# Setting up Fail2Ban #
#######################

echo -e "${GREEN} Setting up Fail2Ban...${NC}"
echo

# Check if Fail2Ban is installed
if ! command -v fail2ban-server >/dev/null 2>&1; then
    echo -e "${RED}Fail2Ban is not installed. Please install Fail2Ban and try again. Exiting.${NC}"
    exit 1
fi

# Fixing Debian bug by setting backend to systemd
if ! sudo sed -i 's|backend = auto|backend = systemd|g' /etc/fail2ban/jail.local; then
    echo -e "${RED}Failed to set backend to systemd in jail.local. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN} Configuring Fail2Ban for SSH protection...${NC}"
echo

# Set the path to the sshd configuration file
config_file="/etc/fail2ban/jail.local"

# Use awk to add "enabled = true" below the second [sshd] line (first is a comment)
if ! sudo awk '/\[sshd\]/ && ++n == 2 {print; print "enabled = true"; next}1' "$config_file" > temp_file || ! sudo mv temp_file "$config_file"; then
    echo -e "${RED}Failed to enable SSH protection. Exiting.${NC}"
    exit 1
fi

# Change bantime to 15m
if ! sudo sed -i 's|bantime  = 10m|bantime  = 15m|g' /etc/fail2ban/jail.local; then
    echo -e "${RED}Failed to set bantime to 15m. Exiting.${NC}"
    exit 1
fi

# Change maxretry to 3
if ! sudo sed -i 's|maxretry = 5|maxretry = 3|g' /etc/fail2ban/jail.local; then
    echo -e "${RED}Failed to set maxretry to 3. Exiting.${NC}"
    exit 1
fi

echo -e "${GREEN} Fail2Ban setup completed.${NC}"
sleep 0.5 # delay for 0.5 seconds
echo


##################
# Setting up UFW #
##################

echo -e "${GREEN} Setting up UFW...${NC}"
echo

# Limit SSH to Port 22/tcp
if ! sudo ufw limit 22/tcp comment "SSH"; then
    echo -e "${RED} Failed to limit SSH access. Exiting.${NC}"
    exit 1
fi

# Allow Port 80
if ! sudo ufw allow 80/tcp comment "Nextcloud Port 80"; then
    echo -e "${RED} Failed to allow Samba. Exiting.${NC}"
    exit 1
fi

# Allow Port 443
if ! sudo ufw allow 443/tcp comment "Nextcloud Port 443"; then
    echo -e "${RED} Failed to allow Samba. Exiting.${NC}"
    exit 1
fi

# Enable UFW without prompt
if ! sudo ufw --force enable; then
    echo -e "${RED} Failed to enable UFW. Exiting.${NC}"
    exit 1
fi

# Set global rules
if ! sudo ufw default deny incoming || ! sudo ufw default allow outgoing; then
    echo -e "${RED} Failed to set global rules. Exiting.${NC}"
    exit 1
fi

# Reload UFW to apply changes
if ! sudo ufw reload; then
    echo -e "${RED} Failed to reload UFW. Exiting.${NC}"
    exit 1
fi

echo
echo -e "${GREEN} UFW setup completed.${NC}"
sleep 0.5 # delay for 0.5 seconds
echo


##########################
# Securing Shared Memory #
##########################

echo -e "${GREEN} Securing Shared Memory...${NC}"
echo

# Define the line to append
LINE="none /run/shm tmpfs defaults,ro 0 0"

# Append the line to the end of the file
if ! echo "$LINE" | sudo tee -a /etc/fstab > /dev/null; then
    echo -e "${RED}Failed to secure shared memory. Exiting.${NC}"
    exit 1
fi


###############################
# Setting up system variables #
###############################

echo -e "${GREEN} Setting up system variables...${NC}"
echo

# Define the file path
FILEPATH="/etc/sysctl.conf"

# Modify system variables for security enhancements
if ! sudo sed -i 's|#net.ipv4.conf.default.rp_filter=1|net.ipv4.conf.default.rp_filter=1|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv4.conf.all.rp_filter=1|net.ipv4.conf.all.rp_filter=1|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv4.conf.all.accept_redirects = 0|net.ipv4.conf.all.accept_redirects = 0|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv6.conf.all.accept_redirects = 0|net.ipv6.conf.all.accept_redirects = 0|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv4.conf.all.send_redirects = 0|net.ipv4.conf.all.send_redirects = 0|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv4.conf.all.accept_source_route = 0|net.ipv4.conf.all.accept_source_route = 0|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv6.conf.all.accept_source_route = 0|net.ipv6.conf.all.accept_source_route = 0|g' $FILEPATH \
   || ! sudo sed -i 's|#net.ipv4.conf.all.log_martians = 1|net.ipv4.conf.all.log_martians = 1|g' $FILEPATH; then
    echo -e "${RED}Error occurred during system variable configuration. Exiting.${NC}"
    exit 1
fi

# Reload sysctl with the new configuration
if ! sudo sysctl -p; then
    echo
    echo -e "${RED}Failed to reload sysctl configuration. Exiting.${NC}"
    exit 1
fi


####################################
# Obtain Public key for SSH access #
####################################

# Get the username running the script
user=$(whoami)

# Path to the authorized_keys
auth_keys="/home/$user/.ssh/authorized_keys"

# Ensure .ssh directory exists
if [ ! -d "/home/$user/.ssh" ]; then
    echo
    echo -e "${GREEN} Creating .ssh directory...${NC}"
    echo
    sudo mkdir -p "/home/$user/.ssh" || { echo -e "${RED}Error: Failed to create .ssh directory${NC}"; exit 1; }
fi

# Ensure authorized_keys file exists
if [ ! -f "$auth_keys" ]; then
    echo -e "${GREEN} Creating authorized_keys file...${NC}"
    echo
    sudo touch "$auth_keys" || { echo -e "${RED}Error: Failed to create authorized_keys file${NC}"; exit 1; }
fi

# Ask the user for the public key
while true; do
    echo
    echo -e "${YELLOW} Please enter your public SSH key:${NC}"
    echo
    read public_key

    # Check if the input was empty
    if [ -z "$public_key" ]; then
        echo -e "${RED} No input received, please enter a public key.${NC}"
    else
        # Validate the public key format
        if [[ "$public_key" =~ ^ssh-(rsa|dss|ecdsa|ed25519)[[:space:]][A-Za-z0-9+/]+[=]{0,2} ]]; then
            break
        else
            echo -e "${RED} Invalid SSH key format. Please enter a valid SSH public key.${NC}"
        fi
    fi
done

# Append the public key to the authorized_keys
echo "$public_key" | sudo tee -a "$auth_keys" > /dev/null || { echo -e "${RED} Error: Failed to append the public key to authorized_keys${NC}"; exit 1; }

echo
echo -e "${GREEN} Public key added successfully.${NC}"
sleep 0.5 # delay for 0.5 seconds
echo


#################################
# Locking root account password #
#################################

echo -e "${GREEN}Locking root account password...${NC}"
echo

# Attempt to lock the root account password
if ! sudo passwd -l root; then
    echo -e "${RED}Failed to lock root account password. Exiting.${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 seconds
echo


############################
# Setting up SSH variables #
############################

echo -e "${GREEN}Setting up SSH variables...${NC}"

# Define the file path
FILEPATH="/etc/ssh/sshd_config"

# Applying multiple sed operations to configure SSH securely. If any fail, an error message will be shown.
if ! (sudo sed -i 's|KbdInteractiveAuthentication no|#KbdInteractiveAuthentication no|g' $FILEPATH \
    && sudo sed -i 's|#LogLevel INFO|LogLevel VERBOSE|g' $FILEPATH \
    && sudo sed -i 's|#PermitRootLogin prohibit-password|PermitRootLogin no|g' $FILEPATH \
    && sudo sed -i 's|#StrictModes yes|StrictModes yes|g' $FILEPATH \
    && sudo sed -i 's|#MaxAuthTries 6|MaxAuthTries 3|g' $FILEPATH \
    && sudo sed -i 's|#MaxSessions 10|MaxSessions 2|g' $FILEPATH \
    && sudo sed -i 's|#IgnoreRhosts yes|IgnoreRhosts yes|g' $FILEPATH \
    && sudo sed -i 's|#PasswordAuthentication yes|PasswordAuthentication no|g' $FILEPATH \
    && sudo sed -i 's|#PermitEmptyPasswords no|PermitEmptyPasswords no|g' $FILEPATH \
    && sudo sed -i 's|UsePAM yes|UsePAM no|g' $FILEPATH \
    && sudo sed -i 's|#GSSAPIAuthentication no|GSSAPIAuthentication no|g' $FILEPATH \
    && sudo sed -i '/# Ciphers and keying/a Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr' $FILEPATH \
    && sudo sed -i '/chacha20-poly1305/a KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256' $FILEPATH \
    && sudo sed -i '/curve25519-sha256/a Protocol 2' $FILEPATH); then
    echo -e "${RED} Failed to configure SSH variables. Exiting.${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 seconds
echo

# Disabling ChallengeResponseAuthentication explicitly #
echo -e "${GREEN} Disabling ChallengeResponseAuthentication...${NC}"

# Define the line to append
LINE="ChallengeResponseAuthentication no"
FILEPATH="/etc/ssh/sshd_config"

# Check if the line already exists to avoid duplications
if grep -q "^$LINE" "$FILEPATH"; then
    echo -e "${YELLOW} ChallengeResponseAuthentication is already set to no.${NC}"
else
    # Append the line to the end of the file
    if ! echo "$LINE" | sudo tee -a $FILEPATH > /dev/null; then
        echo -e "${RED} Failed to disable ChallengeResponseAuthentication. Exiting.${NC}"
        exit 1
    fi
fi

sleep 0.5 # delay for 0.5 seconds
echo


#############################################
# Allow SSH only for the current Linux user #
#############################################

echo -e "${GREEN} Allowing SSH only for the current Linux user...${NC}"

# Get the current Linux user
user=$(whoami)
FILEPATH="/etc/ssh/sshd_config"

# Check if "AllowUsers" is already set for the current user to avoid duplications
if grep -q "^AllowUsers.*$user" "$FILEPATH"; then
    echo -e "${YELLOW} SSH access is already restricted to the current user (${user}).${NC}"
else
    # Append the user's username to /etc/ssh/sshd_config
    if ! echo "AllowUsers $user" | sudo tee -a $FILEPATH >/dev/null; then
        echo -e "${RED} Failed to restrict SSH access to the current user. Exiting.${NC}"
        exit 1
    fi
    # Restart SSH to apply changes
    if ! sudo systemctl restart ssh; then
        echo -e "${RED} Failed to restart SSH service. Exiting.${NC}"
        exit 1
    fi
fi

sleep 0.5 # delay for 0.5 seconds
echo


################
# Restart sshd #
################

echo -e "${GREEN} Restarting sshd...${NC}"

# Attempt to restart the sshd service
if ! sudo systemctl restart sshd; then
    echo -e "${RED} Failed to restart sshd. Please check the service status and logs for more details. Exiting.${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 second
echo


################## A p p l i c a t i o n  p a r t ##################
### ↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓↓ ###


################################
# Setting up working directory #
################################

# Create directories
mkdir -p "$HOME/nextcloud" "$HOME/nextcloud/.secrets" || { echo -e "${RED} Failed to create directories${NC}"; exit 1; }

# Notify the creation of the directories
echo -e "${GREEN} Created directories: 'nextcloud', 'nextcloud/.secrets'${NC}"

# Set the WORK_DIR variable
WORKING_DIRECTORY=$HOME/nextcloud

echo
echo -e "${GREEN} Working directory:${NC} $WORKING_DIRECTORY"
echo


###########
# Secrets #
###########

echo
echo -e "${GREEN} Creating database passwords... ${NC}"
sleep 0.5 # delay for 0.5 seconds

# Generate ROOT_DB_PASSWORD
ROOT_DB_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating Root DB password. ${NC}"
    exit 1
fi

# Save ROOT_DB_PASSWORD
mkdir -p $WORKING_DIRECTORY/.secrets && echo $ROOT_DB_PASSWORD > $WORKING_DIRECTORY/.secrets/ROOT_DB_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving Root DB password. ${NC}"
    exit 1
fi

# Generate NEXTCLOUD_DB_PASSWORD
NEXTCLOUD_DB_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating Nextcloud DB password. ${NC}"
    exit 1
fi

# Save NEXTCLOUD_DB_PASSWORD
mkdir -p $WORKING_DIRECTORY/.secrets && echo $NEXTCLOUD_DB_PASSWORD > $WORKING_DIRECTORY/.secrets/NEXTCLOUD_DB_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving Nextcloud DB password. ${NC}"
    exit 1
fi

# Generate REDIS_PASSWORD
REDIS_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating Redis password. ${NC}"
    exit 1
fi

# Save REDIS_PASSWORD
mkdir -p $WORKING_DIRECTORY/.secrets && echo $REDIS_PASSWORD > $WORKING_DIRECTORY/.secrets/REDIS_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving Redis password. ${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 seconds
echo

###

echo -e "${GREEN} Setting Nextcloud Admin user name and password... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Initialize variables
NEXTCLOUD_ADMIN_USER=""
NEXTCLOUD_ADMIN_PASSWORD=""

# Function to ask for the Nextcloud admin user
ask_admin_user() {
    read -p "Enter Nextcloud admin user: " NEXTCLOUD_ADMIN_USER
    if [[ -z "$NEXTCLOUD_ADMIN_USER" ]]; then
        echo -e "${YELLOW} The admin user cannot be empty. Please enter a valid user.${NC}"
        ask_admin_user
    fi
}

# Function to ask for the Nextcloud admin password
ask_admin_password() {
    # Use -s option to hide password input
    read -s -p "Enter Nextcloud admin password: " NEXTCLOUD_ADMIN_PASSWORD
    echo  # Move to a new line
    if [[ -z "$NEXTCLOUD_ADMIN_PASSWORD" ]]; then
        echo -e "${YELLOW} The admin password cannot be empty. Please enter a valid password.${NC}"
        ask_admin_password
    fi
}

# Call functions to get user input
ask_admin_user
ask_admin_password

# Ensure the .secrets directory exists
mkdir -p $WORKING_DIRECTORY/.secrets

# Save Admin User Name
echo "$NEXTCLOUD_ADMIN_USER" > $WORKING_DIRECTORY/.secrets/NEXTCLOUD_ADMIN_USER.secret
if [ $? -ne 0 ]; then
    echo -e "${RED} Error saving Admin User Name. ${NC}"
    exit 1
fi

# Save Admin Password
echo "$NEXTCLOUD_ADMIN_PASSWORD" > $WORKING_DIRECTORY/.secrets/NEXTCLOUD_ADMIN_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED} Error saving Admin Password. ${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 seconds
echo

###

echo -e "${GREEN} Setting up Email Address for certificate registration... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Prompt for email address for certificate registration
while true; do
    read -p "Please enter your Email Address for certificate registration: " EMAIL_ADDRESS
    if [ -z "$EMAIL_ADDRESS" ]; then
        echo -e "${RED} Error: Email Address cannot be empty. Please try again.${NC}"
    else
        # Validate the email address format if necessary
        # This is a simple regex for basic validation; for more complex validation consider using external tools
        if [[ "$EMAIL_ADDRESS" =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$ ]]; then
            break
        else
            echo -e "${RED} Error: Invalid email address format. Please try again.${NC}"
        fi
    fi
done

# Save Email Address
mkdir -p $WORKING_DIRECTORY/.secrets && echo $EMAIL_ADDRESS > $WORKING_DIRECTORY/.secrets/EMAIL_ADDRESS.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving Email address. ${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 seconds
echo

###

echo -e "${GREEN} Setting up Cloudflare API token... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Path to the Cloudflare credentials file
CREDENTIALS_FILE="/etc/letsencrypt/cloudflare.ini"

# Function to prompt for Cloudflare API token
prompt_for_api_token() {
    echo -e "${YELLOW} Enter your Cloudflare API token here:${NC}"
    echo
    read -r cloudflare_api_token
    echo

    # Check for empty input and repeat the prompt if necessary
    while [[ -z "$cloudflare_api_token" ]]; do
        echo -e "${RED} Error: Cloudflare API token is required.${NC}"
        echo -e "${YELLOW} Enter your Cloudflare API token:${NC}"
        read -r cloudflare_api_token
    done
}

# Call the function to prompt for the API token
prompt_for_api_token

# Ensure the directory for the credentials file exists
if ! sudo test -d "$(dirname "$CREDENTIALS_FILE")"; then
    echo -e "${YELLOW} Creating directory for Cloudflare credentials.${NC}"
    sudo mkdir -p "$(dirname "$CREDENTIALS_FILE")"
fi

# Attempt to create or overwrite the Cloudflare credentials file with the API token
if ! echo "dns_cloudflare_api_token = $cloudflare_api_token" | sudo tee "$CREDENTIALS_FILE" > /dev/null; then
    echo -e "${RED} Error: Failed to write to $CREDENTIALS_FILE${NC}"
    exit 1
fi

# Secure the API token file
if ! sudo chmod 600 "$CREDENTIALS_FILE"; then
    echo -e "${RED} Error: Failed to set permissions for $CREDENTIALS_FILE${NC}"
    exit 1
fi

echo
sleep 0.5 # delay for 0.5 seconds
echo -e "${GREEN} Cloudflare credentials file created and secured successfully.${NC}"
echo

###

# Prompt for domain name for external access, with error handling for empty input
sleep 0.5 # delay for 0.5 seconds

while true; do
    read -p "Please enter Domain Name for external access: (e.g., domain.com or subdomain.domain.com): " DOMAIN_INTERNET
    if [ -z "$DOMAIN_INTERNET" ]; then
        echo -e "${RED} Error: Domain Name cannot be empty. Please try again.${NC}"
    else
        break
    fi
done

echo


######################
# Apache HTTP Server #
######################

echo -e "${GREEN} Creating Apache Virtual hosts file for Nextcloud... ${NC}"
echo

# Configure Apache2 for Nextcloud
cat <<EOF | sudo tee /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
        ServerName LOCAL_DOMAIN
        ServerAlias LOCAL_IP
        ServerAlias DOMAIN_INTERNET
        ServerAlias www.DOMAIN_INTERNET

        Redirect permanent / https://LOCAL_DOMAIN

</VirtualHost>

<VirtualHost *:443>
        ServerAdmin EMAIL_ADDRESS
        DocumentRoot /var/www/nextcloud

        ServerName DOMAIN_INTERNET
        ServerAlias www.DOMAIN_INTERNET
        ServerAlias LOCAL_IP
        ServerAlias LOCAL_DOMAIN

        <Directory /var/www/nextcloud/>
            Options +FollowSymlinks
            AllowOverride All
            Require all granted
            <IfModule mod_dav.c>
                Dav off
            </IfModule>
            SetEnv HOME /var/www/nextcloud
            SetEnv HTTP_HOME /var/www/nextcloud
        </Directory>

        SSLEngine on
        SSLCertificateFile      /etc/ssl/certs/ssl-cert-snakeoil.pem
        SSLCertificateKeyFile   /etc/ssl/private/ssl-cert-snakeoil.key

        SSLProtocol all -SSLv2 -SSLv3
        SSLCipherSuite HIGH:!aNULL:!MD5
        Header always set Strict-Transport-Security "max-age=63072000; includeSubDomains"

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOF

echo
echo -e "${GREEN} Enabling Apache modules... ${NC}"
echo

# Enable required Apache modules
sudo a2enmod rewrite headers env dir mime ssl
echo

###################
# Configuring PHP #
###################

echo -e "${GREEN} Configuring PHP... ${NC}"
sleep 0.5 # delay for 0.5 seconds

# Path to php.ini
PHP_INI="/etc/php/8.3/apache2/php.ini"

# Update memory_limit
sudo sed -i 's/memory_limit = .*/memory_limit = 4096M/' "$PHP_INI"

# Update upload_max_filesize
sudo sed -i 's/upload_max_filesize = .*/upload_max_filesize = 20G/' "$PHP_INI"

# Update post_max_size
sudo sed -i 's/post_max_size = .*/post_max_size = 20G/' "$PHP_INI"

# Update date.timezone
sudo sed -i 's/;date.timezone =.*/date.timezone = Europe\/Berlin/' "$PHP_INI"

# Update output_buffering
sudo sed -i 's/output_buffering = .*/output_buffering = Off/' "$PHP_INI"

# Enable and configure OPcache
sudo sed -i 's/;opcache.enable=.*/opcache.enable=1/' "$PHP_INI"
sudo sed -i 's/;opcache.enable_cli=.*/opcache.enable_cli=1/' "$PHP_INI"
sudo sed -i 's/;opcache.interned_strings_buffer=.*/opcache.interned_strings_buffer=64/' "$PHP_INI"
sudo sed -i 's/;opcache.max_accelerated_files=.*/opcache.max_accelerated_files=10000/' "$PHP_INI"
sudo sed -i 's/;opcache.memory_consumption=.*/opcache.memory_consumption=1024/' "$PHP_INI"
sudo sed -i 's/;opcache.save_comments=.*/opcache.save_comments=1/' "$PHP_INI"
sudo sed -i 's/;opcache.revalidate_freq=.*/opcache.revalidate_freq=1/' "$PHP_INI"
echo


###########
# MariaDB #
###########

echo -e "${GREEN} Configuring MariaDB for Nextcloud...  ${NC}"
sleep 0.5 # delay for 0.5 seconds

# Secure MariaDB installation
sudo mysql -e "DELETE FROM mysql.user WHERE User=''"
sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1')"
sudo mysql -e "DROP DATABASE IF EXISTS test"
sudo mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%'"
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED BY '$ROOT_DB_PASSWORD'"
mysql -u root -p"$ROOT_DB_PASSWORD" -e "FLUSH PRIVILEGES;"

# Create Nextcloud database and user
mysql -u root -p"$ROOT_DB_PASSWORD" -e "CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;"
mysql -u root -p"$ROOT_DB_PASSWORD" -e "CREATE USER 'nextclouduser'@'localhost' IDENTIFIED BY '$NEXTCLOUD_DB_PASSWORD';"
mysql -u root -p"$ROOT_DB_PASSWORD" -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextclouduser'@'localhost';"
mysql -u root -p"$ROOT_DB_PASSWORD" -e "FLUSH PRIVILEGES;"
echo

sleep 0.5 # delay for 0.5 seconds


#############
# Nextcloud #
#############

echo -e "${GREEN} Fetching latest Nextcloud release... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Download Nextcloud
cd /tmp && wget https://download.nextcloud.com/server/releases/latest.zip
#install p7zip-full for progres bar (%)
7z x latest.zip
#unzip latest.zip > /dev/null
sudo mv nextcloud /var/www/
echo

###

echo -e "${GREEN} Creating data folder and setting premissions... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

NEXTCLOUD_DATA_DIR="/home/data/"

sudo mkdir /home/data/
sudo chown -R www-data:www-data /home/data/
sudo chown -R www-data:www-data /var/www/nextcloud/
sudo chmod -R 755 /var/www/nextcloud/

###

echo -e "${GREEN} Installing Nexcloud and configuring Admin user... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Use the NEXTCLOUD_DATA_DIR variable for the data directory location in the occ command
sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud" --database-user "nextclouduser" --database-pass "$NEXTCLOUD_DB_PASSWORD" --admin-user "$NEXTCLOUD_ADMIN_USER" --admin-pass "$NEXTCLOUD_ADMIN_PASSWORD" --data-dir "$NEXTCLOUD_DATA_DIR"

sleep 01 # delay for 1 seconds
echo


###################
# Trusted domains #
###################

# Get the short hostname directly
HOSTNAME=$(hostname -s)

# Extract the domain name from /etc/resolv.conf

# Method 1: Using awk
DOMAIN_LOCAL=$(awk -F' ' '/^domain/ {print $2; exit}' /etc/resolv.conf)
if [[ -n "$DOMAIN_LOCAL" ]]; then
    echo -e "${GREEN} Domain name found using:${NC} awk"
else
    # Method 2: Using sed
    DOMAIN_LOCAL=$(sed -n 's/^domain //p' /etc/resolv.conf)
    if [[ -n "$DOMAIN_LOCAL" ]]; then
        echo -e "${GREEN} Domain name found using:${NC} sed"
    else
        echo -e "${RED} Domain name not found using available methods .${NC}"
        exit 1
    fi
fi

# IP Address extraction

# Method 1: Using hostname -I to get the local IP address
LOCAL_IP=$(hostname -I | awk '{print $1}') # Picks the first IP address
if [[ -n "$LOCAL_IP" ]]; then
    echo -e "${GREEN} IP Address found using:${NC} hostname -I"
else
    # Method 2: Parsing through ip addr show
    LOCAL_IP=$(ip addr show | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | awk '{print $2}' | cut -d/ -f1 | grep -v '127.0.0.1')
    if [[ -n "$LOCAL_IP" ]]; then
        echo -e "${GREEN} IP Address parsed from uotput of:${NC} ip addr show"
    else
        echo -e "${RED} IP Address not found using available methods .${NC}"
    fi
fi


# Directly concatenate HOSTNAME and DOMAIN, leveraging shell parameter expansion for conciseness
LOCAL_DOMAIN="${HOSTNAME}${DOMAIN_LOCAL:+.$DOMAIN_LOCAL}"

# Display variable values for verification
echo
echo -e "${GREEN} Local access:${NC} $LOCAL_IP"
echo -e "${GREEN}             :${NC} $LOCAL_DOMAIN"
echo
echo -e "${GREEN} External access:${NC} $DOMAIN_INTERNET"
echo -e "${GREEN}                :${NC} www.$DOMAIN_INTERNET"
echo

    #   # Local
    #   0 => 'localhost',
    #   1 => 'local-ip',
    #   2 => 'subdomain.local-subdomain.domain.com',
    #   # Web
    #   3 => 'subdomain.domain.com',
    #   4 => 'www.subdomain.domain.com',

cd /var/www/nextcloud

sleep 0.5 # delay for 0.5 seconds
echo -e "${GREEN} Adding Trusted domains... ${NC}"
echo

sudo -u www-data php occ config:system:set trusted_domains 1 --value=$LOCAL_IP
sudo -u www-data php occ config:system:set trusted_domains 2 --value=$LOCAL_DOMAIN

sudo -u www-data php occ config:system:set trusted_domains 3 --value=$DOMAIN_INTERNET
sudo -u www-data php occ config:system:set trusted_domains 4 --value=www.$DOMAIN_INTERNET

# Verify Trusted Domains
echo
echo -e "${GREEN} Verifying... ${NC}"
echo
sudo -u www-data php occ config:system:get trusted_domains

cd $WORKING_DIRECTORY

echo
sleep 0.5 # delay for 0.5 seconds
echo -e "${GREEN} Trusted domains added to${NC} config.php ${GREEN}file. ${NC}"

### Configuring Trusted domains in Apache

# Define path to the file
APACHE_CONFIG_FILE="/etc/apache2/sites-available/nextcloud.conf"

# Check if the Apache configuration file exists
if [ ! -f "$APACHE_CONFIG_FILE" ]; then
    echo -e "${RED}Error: Apache configuration file does not exist at${NC} $APACHE_CONFIG_FILE"
    exit 1
fi

# Function to perform sed replacement safely
safe_sed_replace() {
    local pattern=$1
    local replacement=$2
    local file=$3

    # Attempt the replacement
    if ! sudo sed -i "s/$pattern/$replacement/g" "$file"; then
        echo -e "${RED}An error occurred trying to replace${NC} '$pattern' ${RED}in${NC} $file"
        exit 1
    fi
}

# Replace placeholders in Apache configuration file
safe_sed_replace "EMAIL_ADDRESS" "$EMAIL_ADDRESS" "$APACHE_CONFIG_FILE"
safe_sed_replace "DOMAIN_INTERNET" "$DOMAIN_INTERNET" "$APACHE_CONFIG_FILE"
safe_sed_replace "LOCAL_IP" "$LOCAL_IP" "$APACHE_CONFIG_FILE"
safe_sed_replace "LOCAL_DOMAIN" "$LOCAL_DOMAIN" "$APACHE_CONFIG_FILE"

echo
echo -e "${GREEN} Apache configuration updated successfully. ${NC}"
echo

###

echo -e "${GREEN} Nextcloud customization in progress... ${NC}"
echo
sleep 0.5 # delay for 0.5 second

# Navigate to Nextcloud installation directory
cd /var/www/nextcloud || { echo "Failed to change directory to /var/www/nextcloud"; exit 1; }

# Function to execute a command and check for errors
execute_command() {
    sudo -u www-data php occ "$@" || { echo "Command failed: $*"; exit 1; }
}

# Install and enable Collabora Online - Built-in CODE Server
execute_command app:install richdocumentscode

# Enable Nextcloud Office App
execute_command app:enable richdocuments
echo

# Set default app to Files
execute_command config:system:set defaultapp --value="files"

# Maintenance...
execute_command config:system:set maintenance_window_start --type=integer --value=1

# Generate URLs using a specific protocol
execute_command config:system:set overwriteprotocol --value="https"

# Allow list for WOPI requests
execute_command config:app:set richdocuments wopi_allowlist --value=$LOCAL_IP

# Disable specific apps
echo
execute_command app:disable dashboard
execute_command app:disable firstrunwizard
execute_command app:disable recommendations

echo
echo -e "${GREEN} All commands executed successfully. ${NC}"
echo

cd $WORKING_DIRECTORY


#####################
# Configuring Redis #
#####################

echo -e "${GREEN} Configuring Redis... ${NC}"
sleep 0.5 # delay for 0.5 seconds

# Define the Redis configuration file and its backup
REDISCONFIG_FILE="/etc/redis/redis.conf"
REDISBACKUP_FILE="/etc/redis/redis.conf.bak"

# Attempt to copy the Redis configuration file to a backup file
if ! sudo cp "$REDISCONFIG_FILE" "$REDISBACKUP_FILE"; then
  echo -e "${RED}Error: Failed to copy $REDISCONFIG_FILE to $REDISBACKUP_FILE.${NC}"
  exit 1
fi

echo
echo -e "${GREEN}Backup of Redis configuration file created successfully at $REDISBACKUP_FILE${NC}"
echo

# Check if REDIS_PASSWORD is set
if [ -z "$REDIS_PASSWORD" ]; then
  echo -e "${RED}Error: Redis password is not set.${NC}"
  exit 1
fi

# Check if the Redis configuration file exists using sudo
if ! sudo test -f "$REDISCONFIG_FILE"; then
  echo -e "${RED}Error: Redis configuration file does not exist at $REDISCONFIG_FILE.${NC}"
  exit 1
fi

# Attempt to update the Redis configuration file with the password
if ! sudo sed -i 's/# requirepass foobared/requirepass '"$REDIS_PASSWORD"'/' "$REDISCONFIG_FILE"; then
  echo -e "${RED}Error: Failed to update Redis password.${NC}"
  exit 1
fi

# Attempt to update the Redis configuration file with the new port number
if ! sudo sed -i 's/port 6379/port 0/' "$REDISCONFIG_FILE"; then
  echo -e "${RED}Error: Failed to update Redis port number.${NC}"
  exit 1
fi

# Attempt to enable Redis socket
if ! sudo sed -i 's|# unixsocket /run/redis/redis-server.sock|unixsocket /run/redis/redis-server.sock|' "$REDISCONFIG_FILE"; then
  echo -e "${RED}Error: Failed to enable Redis socket.${NC}"
  exit 1
fi

# Attempt to set Redis socket permissions
if ! sudo sed -i 's/# unixsocketperm 700/unixsocketperm 770/' "$REDISCONFIG_FILE"; then
  echo -e "${RED}Error: Failed to update Redis socket permissions.${NC}"
  exit 1
fi

###

# Define temporary configuration file
CONFIGREDIS_FILE="tmp.config.php"

echo -e "${GREEN} Creating file:${NC} $CONFIGREDIS_FILE"

# Temporary file to hold intermediate results
TEMP_FILE="$(mktemp)"

# Write the configuration to a temporary file first
cat <<EOF > "$TEMP_FILE"
  'htaccess.RewriteBase' => '/',
  'default_phone_region' => 'DE',
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'memcache.distributed' => '\\OC\Memcache\Redis',
  'redis' =>
  array (
    'host' => '/run/redis/redis-server.sock',
    'port' => 0,
    'password' => 'REDIS_PASSWORD',
  ),
EOF

# Replace placeholders in the temporary file
if ! sed -i "s/'REDIS_PASSWORD'/'$REDIS_PASSWORD'/g" "$TEMP_FILE"; then
    echo -e "${RED}Error replacing REDIS_PASSWORD in $TEMP_FILE.${NC}"
    exit 1
fi

# Move the temporary file to the final configuration file
if ! sudo mv "$TEMP_FILE" $WORKING_DIRECTORY/"$CONFIGREDIS_FILE"; then
    echo -e "${RED}Error moving $TEMP_FILE to $CONFIGREDIS_FILE.${NC}"
    exit 1
fi

echo
echo -e "${GREEN}Redis configuration is ready for copy in:${NC} $CONFIGREDIS_FILE"
echo
sleep 1 # delay for 1 seconds

###

# Search for tmp.config.php in the home directory and assign the path to TMP_FILE
TMP2_FILE=$(find ~/ -type f -name "tmp.config.php" 2>/dev/null)

# Check if TMP_FILE is not empty
if [ ! -z "$TMP2_FILE" ]; then
    echo "File found: $TMP2_FILE"
else
    echo -e "${RED}File not found.${NC}"
    # Consider whether you want to exit or just skip the next part
    exit 1 # or continue with a different part of the script
fi

# Define path to the file
CONFIG_FILE="/var/www/nextcloud/config/config.php"

# Backup original config file
if ! sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"; then
    echo -e "${RED}Error backing up $CONFIG_FILE.${NC}"
    exit 1
fi

# The pattern to match the line after which the new content will be appended
START_PATTERN="'maintenance_window_start' => 1,"

# Use awk to append the block from TMP_FILE after START_PATTERN
if ! sudo awk -v start="$START_PATTERN" -v file="$TMP2_FILE" '
$0 ~ start {print; while((getline line < file) > 0) {print line}; next}
{print}' "$CONFIG_FILE.bak" | sudo tee "$CONFIG_FILE" > /dev/null; then
    echo -e "${RED}Error updating $CONFIG_FILE with $TMP2_FILE content.${NC}"
    exit 1
fi

echo
sleep 0.5 # delay for 0.5 seconds
echo -e "${GREEN}The${NC} config.php ${GREEN}file has been updated.${NC}"
echo

# Adding Apache user to Redis group
sudo usermod -aG redis www-data


###########################
# Certbot SSL certificate #
###########################

# CERT_DOMAIN=LOCAL_DOMAIN

# Initialize user_choice to an empty string
user_choice=""

# Loop until a valid input is received
while [[ "$user_choice" != "yes" && "$user_choice" != "no" ]]; do
    echo -e "${YELLOW}Do you want to use Certbot to create SSL certificate for Local domain?${NC} (yes/no)"
    echo
    read -r user_choice
    echo
    
    # Convert input to lowercase to standardize comparison
    user_choice=$(echo "$user_choice" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$user_choice" == "yes" ]]; then
        # User chose to use Certbot for wildcard SSL certificate
        if sudo certbot certonly \
          --dns-cloudflare \
          --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
          -d $LOCAL_DOMAIN \
          --agree-tos \
          --email "$EMAIL_ADDRESS" \
          --non-interactive; then
            echo -e "${GREEN}Certificate obtained successfully.${NC}"
            echo
            
            # After successfully obtaining the certificate, modify the Apache configuration
            APACHE_CONF="/etc/apache2/sites-available/nextcloud.conf"
            sudo sed -i "s|SSLCertificateFile.*|SSLCertificateFile      /etc/letsencrypt/live/$LOCAL_DOMAIN/fullchain.pem|" "$APACHE_CONF"
            sudo sed -i "s|SSLCertificateKeyFile.*|SSLCertificateKeyFile   /etc/letsencrypt/live/$LOCAL_DOMAIN/privkey.pem|" "$APACHE_CONF"
            
            echo -e "${GREEN}Apache configuration updated successfully.${NC}"
            echo
            
            # Certbot backup
            cd $WORKING_DIRECTORY

            # Capture the current date and time in a variable
            CURRENT_DATE=$(date +%Y-%m-%d_%H-%M)

            # Backup parameters
            BACKUP_DIR="/etc/letsencrypt"
            BACKUP_FILE="certbot-backup-${CURRENT_DATE}.tar.gz"
            ENCRYPTED_FILE="${BACKUP_FILE}.gpg"

            # Check if the backup directory exists
            if [ ! -d "$BACKUP_DIR" ]; then
                echo -e "${RED}Error: Backup directory ${BACKUP_DIR} does not exist. Exiting.${NC}"
                exit 1
            fi

            # Create a Backup using the captured date and time
            echo -e "${YELLOW}Creating backup of ${BACKUP_DIR}...${NC}"

            # Directly checking the command's success with an if-statement
            if sudo tar -cvzf "${BACKUP_FILE}" "${BACKUP_DIR}" > /dev/null; then
                echo
                echo -e "${GREEN}Backup created successfully: ${BACKUP_FILE}${NC}"
            else
                echo -e "${RED}Error creating backup. Exiting.${NC}"
                exit 1
            fi

            # Encrypt the backup file using the same date and time
            echo
            echo -e "${YELLOW}Encrypting the backup file...${NC}"
            echo
            if echo $NEXTCLOUD_ADMIN_PASSWORD | gpg --batch --yes --passphrase-fd 0 --symmetric --cipher-algo aes256 -o "${ENCRYPTED_FILE}" "${BACKUP_FILE}"; then
                echo
                echo -e "${GREEN}Encryption successful: ${ENCRYPTED_FILE}${NC}"
                echo
            else
                echo -e "${RED}Error encrypting file. Exiting.${NC}"
                exit 1
            fi

            # Remove the original backup file after encryption
            sudo rm "${BACKUP_FILE}"

            echo -e "${GREEN}Backup and encryption process completed successfully.${NC}"
            echo
            echo -e "${GREEN}Use Nextcloud Admin user password to dencrypt the file.${NC}"

        else
            echo -e "${RED}Failed to obtain the certificate. Please check your settings and try again.${NC}"
        fi
        break # Exit the loop after completing the operation
        
    elif [[ "$user_choice" == "no" ]]; then
        # User chose to continue with self-signed certificates
        echo -e "${YELLOW}Continuing with self-signed certificates.${NC}"
        # Add any commands here for handling the self-signed certificate path
        break # Exit the loop
    else
        # User entered an invalid choice, prompt again
        echo -e "${RED}Invalid choice. Please type 'yes' to use Certbot or 'no' to continue with self-signed certificates.${NC}"
        # The loop will continue
    fi
done

echo


###########################
# Securing sensitive data #
###########################

echo -e "${GREEN} Securing sensitive data... ${NC}"
echo
sleep 0.5 # delay for 0.5 seconds

# Change ownership and permissions for .secrets/ folder
if ! sudo chown -R root:root $WORKING_DIRECTORY/.secrets/; then
    echo -e "${RED}Error changing ownership of secrets directory. ${NC}"
    exit 1
fi

if ! sudo chmod -R 600 $WORKING_DIRECTORY/.secrets/; then
    echo -e "${RED}Error changing permissions of secrets directory. ${NC}"
    exit 1
fi

echo -e "${GREEN} Operation completed successfully. ${NC}"
echo


###########################
# Activating Apache sites #
###########################

echo -e "${GREEN} Enabling the Nextcloud site configuration in Apache. ${NC}"
sleep 0.5 # delay for 0.5 seconds

# Enable the site (2>&1)
sudo a2ensite nextcloud.conf > /dev/null

# Restart Apache to apply changes
sudo service apache2 restart

# Restarting Redis
sudo systemctl restart redis-server


######################
# Info before reboot #
######################

HOST_IP=$(hostname -I | awk '{print $1}')
HOST_NAME=$(hostname --short)
DOMAIN_NAME=$(grep '^domain' /etc/resolv.conf | awk '{print $2}')

echo
echo -e "${GREEN}REMEMBER: ${NC}"
sleep 0.5 # delay for 0.5 seconds

echo
echo -e "${GREEN} You can find your${NC} Nexcloud server ${GREEN}instance at: ${NC}"
echo
echo -e " - $HOST_IP"
echo -e " - $LOCAL_DOMAIN"
echo
echo -e "${GREEN} If you have configured external access (NPM), at: ${NC}"
echo
echo -e " - $DOMAIN_INTERNET"
echo -e " - www.$DOMAIN_INTERNET"
echo
echo -e "${GREEN} Sensitive data will be stored in${NC} .secrets ${GREEN}folder${NC}"
echo


##########################
# Prompt user for reboot #
##########################

while true; do
    read -p "Do you want to reboot the server now (recommended)? (yes/no): " response
    case "${response,,}" in
        yes|y) echo; echo -e "${GREEN}Rebooting the server...${NC}"; sudo reboot; break ;;
        no|n) echo -e "${RED}Reboot cancelled.${NC}"; exit 0 ;;
        *) echo -e "${YELLOW}Invalid response. Please answer${NC} yes or no." ;;
    esac
done
