#!/bin/bash

sudo hwclock --hctosys

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

echo
echo -e "${GREEN} This script will install and configure latest${NC}" Nextcloud server 
echo -e "${GREEN} and it's prerequisites:${NC} Apache HTTP Server, PHP 8.3, Redis ${GREEN}and${NC} MariaDB" 

sleep 0.5 # delay for 0.5 seconds
echo

echo -e "${GREEN} You'll be asked to enter: ${NC}"
echo -e "${GREEN} - User name and Password for ${NC} Nextcloud Admin user"
echo -e "${GREEN} - for accessing Nextcloud instance outside your local network:${NC} Domain name${GREEN}, optionally:${NC} Subdomain ${NC}"
echo
echo -e "${GREEN} ... ${NC}"
echo


#######################################
# Prompt user to confirm script start #
#######################################

while true; do
    echo -e "${GREEN}Start installation and configuration?${NC} (y/n)"
    echo
    read choice

    # Check if user entered "y" or "Y"
    if [[ "$choice" == [yY] ]]; then

        # Confirming the start of the script
        echo
        echo -e "${GREEN}Starting... ${NC}"
        sleep 0.5 # delay for 0.5 second
        break

    # If user entered "n" or "N", exit the script
    elif [[ "$choice" == [nN] ]]; then
        echo -e "${RED}Aborting script. ${NC}"
        exit

    # If user entered anything else, ask them to correct it
    else
        echo -e "${YELLOW}Invalid input. Please enter${NC} 'y' or 'n' "
    fi
done



#######################
# Create backup files #
#######################

echo
echo -e "${GREEN} Creating backup files ${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

# Backup the existing /etc/hosts file
if [ ! -f /etc/hosts.backup ]; then
    sudo cp /etc/hosts /etc/hosts.backup
    echo -e "${GREEN}Backup of${NC} /etc/hosts ${GREEN}created.${NC}"
else
    echo -e "${YELLOW}Backup of${NC} /etc/hosts ${YELLOW}already exists. Skipping backup.${NC}"
fi

# Backup original /etc/cloud/cloud.cfg file before modifications
CLOUD_CFG="/etc/cloud/cloud.cfg"
if [ ! -f "$CLOUD_CFG.bak" ]; then
    sudo cp "$CLOUD_CFG" "$CLOUD_CFG.bak"
    echo -e "${GREEN}Backup of${NC} $CLOUD_CFG ${GREEN}created.${NC}"
else
    echo -e "${YELLOW}Backup of${NC} $CLOUD_CFG ${YELLOW}already exists. Skipping backup.${NC}"
fi


#######################
# Edit cloud.cfg file #
#######################

echo
echo -e "${GREEN}Preventing Cloud-init from rewriting hosts file${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Define the file path
FILE_PATH="/etc/cloud/cloud.cfg"
BACKUP_PATH="${FILE_PATH}.bak"

# Create a backup of the original file
sudo cp "$FILE_PATH" "$BACKUP_PATH"

# Comment out the specified modules and check for errors
if sudo sed -i '/^\s*- set_hostname/ s/^/#/' "$FILE_PATH" && \
   sudo sed -i '/^\s*- update_hostname/ s/^/#/' "$FILE_PATH" && \
   sudo sed -i '/^\s*- update_etc_hosts/ s/^/#/' "$FILE_PATH"; then
   echo -e "${GREEN}Modifications to${NC} $FILE_PATH ${GREEN}applied successfully.${NC}"
else
    # Restore from backup in case of error
    echo -e "${RED}An error occurred. Restoring backup...${NC}"
    sudo cp "$BACKUP_PATH" "$FILE_PATH"
    echo -e "${RED}Backup restored. Please check the cloud.cfg file manually.${NC}"
    exit 1
fi


######################
# Prepare hosts file #
######################

echo
echo -e "${GREEN}Setting up hosts file${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Extract the domain name from /etc/resolv.conf
DOMAIN_NAME=$(grep '^domain' /etc/resolv.conf | awk '{print $2}')

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}Could not determine the domain name from /etc/resolv.conf. Skipping operations that require the domain name.${NC}"
else
    # Identify the host's primary IP address and hostname
    HOST_IP=$(hostname -I | awk '{print $1}')
    HOST_NAME=$(hostname)

    if [ -z "$HOST_IP" ] || [ -z "$HOST_NAME" ]; then
        echo -e "${RED}Could not determine the host IP address or hostname. Skipping /etc/hosts update.${NC}"
    else
        # Display the extracted domain name, host IP, and hostname
        echo -e "${GREEN}Hostname:${NC} $HOST_NAME"
        echo -e "${GREEN}Domain name:${NC} $DOMAIN_NAME"
        echo -e "${GREEN}Host IP:${NC} $HOST_IP"

        # Backup /etc/hosts before making changes
        BACKUP_PATH="/etc/hosts.bak"
        sudo cp /etc/hosts "$BACKUP_PATH"
        
        # Attempt to update /etc/hosts
        if sudo sed -i "/$HOST_NAME/d" /etc/hosts && \
           echo "$HOST_IP $HOST_NAME $HOST_NAME.$DOMAIN_NAME" | sudo tee -a /etc/hosts > /dev/null; then
            echo
            echo -e "${GREEN}File /etc/hosts has been updated.${NC}"
        else
            # Restore from backup in case of error
            echo -e "${RED}Failed to update /etc/hosts. Restoring from backup...${NC}"
            sudo cp "$BACKUP_PATH" /etc/hosts
            echo -e "${RED}Backup restored. Please check /etc/hosts manually.${NC}"
            exit 1
        fi
    fi
fi


######################
# Database passwords #
######################

echo -e "${GREEN}Creating database passwords... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Generate ROOT_DB_PASSWORD
ROOT_DB_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating ROOT_DB_PASSWORD. ${NC}"
    exit 1
fi

# Save ROOT_DB_PASSWORD
mkdir -p ~/.secrets && echo $ROOT_DB_PASSWORD > ~/.secrets/ROOT_DB_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving ROOT_DB_PASSWORD. ${NC}"
    exit 1
fi

# Generate NEXTCLOUD_DB_PASSWORD
NEXTCLOUD_DB_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating NEXTCLOUD_DB_PASSWORD. ${NC}"
    exit 1
fi

# Save NEXTCLOUD_DB_PASSWORD
mkdir -p ~/.secrets && echo $NEXTCLOUD_DB_PASSWORD > ~/.secrets/NEXTCLOUD_DB_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving NEXTCLOUD_DB_PASSWORD. ${NC}"
    exit 1
fi

# Generate REDIS_PASSWORD
REDIS_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo -e "${RED}Error generating REDIS_PASSWORD. ${NC}"
    exit 1
fi

# Save REDIS_PASSWORD
mkdir -p ~/.secrets && echo $REDIS_PASSWORD > .secrets/REDIS_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving REDIS_PASSWORD. ${NC}"
    exit 1
fi

sleep 0.5 # delay for 0.5 seconds
echo


#############################################
# Updating system, installing some packages #
#############################################

echo -e "${GREEN} Updating packages and upgrading the system... ${NC}"
echo

# Update and upgrade packages
sudo apt update && sudo apt upgrade -y

sleep 0.5 # delay for 0.5 seconds
echo

echo -e "${GREEN} Installing Redis, p7zip... ${NC}"
echo

sudo apt install -y redis-server p7zip-full
echo

######################
# Apache HTTP Server #
######################

echo -e "${GREEN} Installing Apache... ${NC}"
echo

# Install Apache2
sudo apt install apache2 -y

# Configure Apache2 for Nextcloud
# first create/edit>move
#cat <<EOF | sudo tee nextcloud.conf ...

# Configure Apache2 for Nextcloud
cat <<EOF | sudo tee /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
     ServerAdmin master@domain.com
     DocumentRoot /var/www/nextcloud/

     ServerName DOMAIN_INTERNET
     ServerAlias WWW_DOMAININTERNET
     ServerAlias LOCAL_IP
     ServerAlias HOSTNAME_DOMAIN_LOCAL

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

    <IfModule mod_headers.c>
        Header always set Strict-Transport-Security "max-age=15552000; includeSubDomains"
    </IfModule>

     ErrorLog \${APACHE_LOG_DIR}/error.log
     CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

echo
echo -e "${GREEN} Enabling Nextcloud site and Apache modules... ${NC}"
echo

# Enable the site and required Apache modules
sudo a2ensite nextcloud.conf
sudo a2enmod rewrite headers env dir mime

# Restart Apache to apply changes
sudo service apache2 restart
echo


#############################################
# Install PHP 8.3 and necessary PHP modules #
#############################################

echo -e "${GREEN} Install PHP 8.3 and necessary PHP modules... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Install the apt-transport-https package for HTTPS support
sudo apt install apt-transport-https -y
if [ $? -ne 0 ]; then
    echo -e "${RED}Error installing apt-transport-https. Exiting.${NC}"
    exit 1
fi

# Add the GPG key for the Ondřej Surý PHP repository
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
if [ $? -ne 0 ]; then
    echo -e "${RED}Error downloading the GPG key for PHP repository. Exiting.${NC}"
    exit 1
fi

# Add the PHP repository to the sources list
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
if [ $? -ne 0 ]; then
    echo -e "${RED}Error adding the PHP repository to sources list. Exiting.${NC}"
    exit 1
fi

# Update apt sources
sudo apt update
if [ $? -ne 0 ]; then
    echo -e "${RED}Error updating apt sources. Exiting.${NC}"
    exit 1
fi

# Install PHP 8.3 and required packages
sudo apt install -y \
php8.3 \
libapache2-mod-php8.3 \
php8.3-{zip,xml,mbstring,gd,curl,imagick,intl,bcmath,gmp,cli,mysql,apcu,redis,smbclient,ldap,bz2,fpm} \
php-dompdf \
libmagickcore-6.q16-6-extra \
php-pear

if [ $? -ne 0 ]; then
    echo -e "${RED}Error installing PHP 8.3 and required packages. Exiting."
    exit 1
fi

echo
echo -e "${GREEN} PHP 8.3 and required packages have been installed successfully.${NC}"
echo


####################
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

# Restart web server
#sudo systemctl reload apache2
sudo systemctl restart apache2
echo


###################
# Install MariaDB #
###################

echo -e "${GREEN} Installing and configuring MariaDB...  ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Install MariaDB Server
sudo apt install mariadb-server -y

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


####################
# Prepare firewall #
####################

echo -e "${GREEN} Preparing firewall for local access...${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

sudo ufw allow 80/tcp comment "Nextcloud Local Access"
sudo systemctl restart ufw
echo


###################################
# Nextcloud Admin User / Password #
###################################

echo -e "${GREEN} Setting Nextcloud Admin user name/password... ${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

# Initialize variables
NEXTCLOUD_ADMIN_USER=""
NEXTCLOUD_ADMIN_PASSWORD=""

# Function to ask for the Nextcloud admin user
ask_admin_user() {
    read -p "Enter Nextcloud admin user: " NEXTCLOUD_ADMIN_USER
    if [[ -z "$NEXTCLOUD_ADMIN_USER" ]]; then
        echo -e "${YELLOW}The admin user cannot be empty. Please enter a valid user.${NC}"
        ask_admin_user
    fi
}

# Function to ask for the Nextcloud admin password
ask_admin_password() {
    read -p "Enter Nextcloud admin password: " NEXTCLOUD_ADMIN_PASSWORD
    if [[ -z "$NEXTCLOUD_ADMIN_PASSWORD" ]]; then
        echo -e "${YELLOW}The admin password cannot be empty. Please enter a valid password.${NC}"
        ask_admin_password
    fi
}

# Call functions to get user input
ask_admin_user
ask_admin_password

# Ensure the .secrets directory exists
mkdir -p ~/.secrets

# Save Admin User Name
echo "$NEXTCLOUD_ADMIN_USER" > ~/.secrets/NEXTCLOUD_ADMIN_USER.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving Admin User Name. ${NC}"
    exit 1
fi

# Save Admin Password
echo "$NEXTCLOUD_ADMIN_PASSWORD" > ~/.secrets/NEXTCLOUD_ADMIN_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo -e "${RED}Error saving Admin Password. ${NC}"
    exit 1
fi

# Ensure the .secrets directory has correct permissions
chmod 600 ~/.secrets


############################
# Data folder / Premission #
############################

echo -e "${GREEN} Creating data folder and setting premissions... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

NEXTCLOUD_DATA_DIR="/home/data/"

sudo mkdir /home/data/
sudo chown -R www-data:www-data /home/data/
sudo chown -R www-data:www-data /var/www/nextcloud/
sudo chmod -R 755 /var/www/nextcloud/


#######################
# Installing Nexcloud #
#######################

echo -e "${GREEN} Installing Nexcloud and configuring admin user... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Use the NEXTCLOUD_DATA_DIR variable for the data directory location in the occ command
sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud" --database-user "nextclouduser" --database-pass "$NEXTCLOUD_DB_PASSWORD" --admin-user "$NEXTCLOUD_ADMIN_USER" --admin-pass "$NEXTCLOUD_ADMIN_PASSWORD" --data-dir "$NEXTCLOUD_DATA_DIR"

sleep 01 # delay for 1 seconds
echo


###################
# Trusted domains #
###################

echo -e "${GREEN} Setting up Nextcloud Trusted domains... ${NC}"
sleep 0.5 # delay for 0.5 seconds

# Define the file
CONFIG_FILE="tmp.config.php"

echo
echo -e "${GREEN} Creating file:${NC} $CONFIG_FILE"

# Temporary file to hold intermediate results
TEMP_FILE="$(mktemp)"

# Write the configuration to a temporary file first
cat <<EOF > "$TEMP_FILE"
  'trusted_domains' =>
  array (
    0 => 'localhost',
    1 => 'LOCAL_IP',
    2 => 'HOSTNAME_DOMAIN_LOCAL',
    3 => 'DOMAIN_INTERNET',
    4 => 'WWW_DOMAIN_INTERNET',
  ),
EOF

# Get the primary local IP address of the machine
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Get the hostname
HOSTNAME=$(hostname --short)

# Extract the domain name from /etc/resolv.conf
DOMAIN_LOCAL=$(grep '^search' /etc/resolv.conf | awk '{print $2}')

# Concatenate HOSTNAME and DOMAIN if DOMAIN is not empty
if [ -n "$DOMAIN_LOCAL" ]; then
    HOSTNAME_DOMAIN_LOCAL="${HOSTNAME}.${DOMAIN_LOCAL}"
else
    HOSTNAME_DOMAIN_LOCAL="$HOSTNAME"
fi

# Display the variable values for verification
echo
echo -e "${GREEN} Configuration file created:${NC} $CONFIG_FILE"
echo -e "${GREEN} Local IP:${NC} $LOCAL_IP"
echo -e "${GREEN} Hostname:${NC} $HOSTNAME"
echo -e "${GREEN} Local Domain:${NC} $DOMAIN_LOCAL"
echo -e "${GREEN} Local Hostname and Domain Name:${NC} $HOSTNAME_DOMAIN_LOCAL"
echo

# Prompt for DOMAIN_INTERNET with error handling for empty input
while true; do
    read -p "Please enter Domain Name for external access: (e.g., domain.com or subdomain.domain.com): " DOMAIN_INTERNET
    if [ -z "$DOMAIN_INTERNET" ]; then
        echo -e "${RED}Error: Domain Name cannot be empty. Please try again.${NC}"
    else
        break
    fi
done

echo
echo -e "${GREEN} Domain name:${NC} $DOMAIN_INTERNET"

# Replace placeholders in the temporary file
sed -i "s/'LOCAL_IP'/'$LOCAL_IP'/g" "$TEMP_FILE"
sed -i "s/'HOSTNAME_DOMAIN_LOCAL'/'$HOSTNAME_DOMAIN_LOCAL'/g" "$TEMP_FILE"
sed -i "s/'DOMAIN_INTERNET'/'$DOMAIN_INTERNET'/g" "$TEMP_FILE"
sed -i "s/'WWW_DOMAIN_INTERNET'/'www.$DOMAIN_INTERNET'/g" "$TEMP_FILE"

# Move the temporary file to the final configuration file
sudo mv "$TEMP_FILE" ~/"$CONFIG_FILE"
echo
echo -e "${GREEN}Trusted Domains are ready for copy in:${NC} $CONFIG_FILE"
echo
sleep 1 # delay for 1 seconds

# Search for tmp.config.php in the home directory and assign the path to TMP_FILE
TMP_FILE=$(find ~/ -type f -name "tmp.config.php" 2>/dev/null)

# Check if TMP_FILE is not empty
if [ ! -z "$TMP_FILE" ]; then
    echo -e "${GREEN}File found:${NC} $TMP_FILE"
else
    echo -e "${RED}File not found."
fi

# Define path to the file
CONFIG_FILE="/var/www/nextcloud/config/config.php"

# Backup original config file
sudo cp "$CONFIG_FILE" "$CONFIG_FILE.bak"

# The pattern to match the block to be replaced and its ending
START_PATTERN="'trusted_domains' =>"
END_PATTERN="),"

# Use awk to replace the block between START_PATTERN and END_PATTERN with new content from TMP_FILE
# Skip printing lines between START_PATTERN and END_PATTERN, and insert the new content in place
sudo awk -v start="$START_PATTERN" -v end="$END_PATTERN" -v file="$TMP_FILE" '
BEGIN {skip=0} 
$0 ~ start {skip=1; system("cat " file)} 
$0 ~ end && skip {skip=0; next} 
!skip' "$CONFIG_FILE.bak" | sudo tee "$CONFIG_FILE" > /dev/null

echo
sleep 0.5 # delay for 0.5 seconds
echo -e "${GREEN} The${NC} config.php ${GREEN}file has been updated. ${NC}"

# Configuring Trusted domains in Apache

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
safe_sed_replace "DOMAIN_INTERNET" "$DOMAIN_INTERNET" "$APACHE_CONFIG_FILE"
safe_sed_replace "WWW_DOMAININTERNET" "www.$DOMAIN_INTERNET" "$APACHE_CONFIG_FILE"
safe_sed_replace "LOCAL_IP" "$LOCAL_IP" "$APACHE_CONFIG_FILE"
safe_sed_replace "HOSTNAME_DOMAIN_LOCAL" "$HOSTNAME_DOMAIN_LOCAL" "$APACHE_CONFIG_FILE"

echo
echo -e "${GREEN} Apache configuration updated successfully. ${NC}"
sudo systemctl reload apache2
echo

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
#execute_command app:enable richdocumentscode

# Enable Nextcloud Office App
execute_command app:enable richdocuments
echo

# Set default app to Files
execute_command config:system:set defaultapp --value="files"
execute_command config:system:set maintenance_window_start --type=integer --value=1

# Disable specific apps
echo
execute_command app:disable dashboard
execute_command app:disable firstrunwizard
execute_command app:disable recommendations

echo
echo -e "${GREEN} All commands executed successfully. ${NC}"
echo

sudo systemctl reload apache2


######################################
# Configuring Nextcloud to Use Redis #
######################################

echo -e "${GREEN} Configuring Nextcloud to Use Redis... ${NC}"
sleep 0.5 # delay for 0.5 seconds

###

# Define the Redis configuration file and it's backup
REDISCONFIG_FILE="/etc/redis/redis.conf"
REDISBACKUP_FILE="/etc/redis/redis.conf.bak"

# Attempt to copy the Redis configuration file to a backup file
if ! sudo cp "$REDISCONFIG_FILE" "$REDISBACKUP_FILE"; then
  echo "Error: Failed to copy $REDISCONFIG_FILE to $REDISBACKUP_FILE."
  exit 1
fi

echo
echo "Backup of Redis configuration file created successfully at $REDISBACKUP_FILE"
echo

# Check if REDIS_PASSWORD is set
if [ -z "$REDIS_PASSWORD" ]; then
  echo "Error: Redis password is not set."
  exit 1
fi

# Check if the Redis configuration file exists using sudo
if ! sudo test -f "$REDISCONFIG_FILE"; then
  echo "Error: Redis configuration file does not exist at $REDISCONFIG_FILE."
  exit 1
fi

# Attempt to update the Redis configuration file with the password
if ! sudo sed -i 's/# requirepass foobared/requirepass '"$REDIS_PASSWORD"'/' "$REDISCONFIG_FILE"; then
  echo "Error: Failed to update Redis configuration file."
  exit 1
fi

echo
echo "Redis configuration file updated successfully."
echo

###

# Define temporary configuration file
CONFIGREDIS_FILE="tmp2.config.php"

echo -e "${GREEN} Creating file:${NC} $CONFIGREDIS_FILE"

# Temporary file to hold intermediate results
TEMP_FILE="$(mktemp)"

# Write the configuration to a temporary file first
cat <<EOF > "$TEMP_FILE"
  'memcache.local' => '\\OC\\Memcache\\Redis',
  'memcache.locking' => '\\OC\\Memcache\\Redis',
  'redis' =>
  array (
    'host' => 'localhost',
    'port' => 6379,
    'password' => 'REDIS_PASSWORD',
  ),
EOF

# Replace placeholders in the temporary file
if ! sed -i "s/'REDIS_PASSWORD'/'$REDIS_PASSWORD'/g" "$TEMP_FILE"; then
    echo -e "${RED}Error replacing REDIS_PASSWORD in $TEMP_FILE.${NC}"
    exit 1
fi

# Move the temporary file to the final configuration file
if ! sudo mv "$TEMP_FILE" ~/"$CONFIGREDIS_FILE"; then
    echo -e "${RED}Error moving $TEMP_FILE to $CONFIGREDIS_FILE.${NC}"
    exit 1
fi

echo
echo -e "${GREEN}Redis configuration is ready for copy in:${NC} $CONFIGREDIS_FILE"
echo
sleep 1 # delay for 1 seconds

###

# Search for tmp2.config.php in the home directory and assign the path to TMP_FILE
TMP2_FILE=$(find ~/ -type f -name "tmp2.config.php" 2>/dev/null)

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
echo -e "${GREEN}The config.php file has been updated.${NC}"
echo


###########################
# Securing sensitive data #
###########################

echo -e "${GREEN} Securing sensitive data... ${NC}"
echo
sleep 0.5 # delay for 0.5 seconds

# Change ownership and permissions
sudo chown -R root:root ~/.secrets/
if [ $? -ne 0 ]; then
    echo -e "${RED}Error changing ownership of secrets directory. ${NC}"
    exit 1
fi

sudo chmod -R 600 ~/.secrets/
if [ $? -ne 0 ]; then
    echo -e "${RED}Error changing permissions of secrets directory. ${NC}"
    exit 1
fi

echo -e "${GREEN} Operation completed successfully. ${NC}"
echo


######################
# Info before reboot #
######################

HOST_IP=$(hostname -I | awk '{print $1}')
HOST_NAME=$(hostname --short)
DOMAIN_NAME=$(grep '^domain' /etc/resolv.conf | awk '{print $2}')

echo -e "${GREEN}REMEMBER: ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

echo
echo -e "${GREEN} You can find your${NC} Nexcloud server ${GREEN}instance at: ${NC}"
echo
echo -e " - http://$HOST_IP"
echo -e " - http://$HOSTNAME_DOMAIN_LOCAL"
echo
echo -e "${GREEN} If you have configured external access, at: ${NC}"
echo
echo -e " - $DOMAIN_INTERNET"
echo -e " - www.$DOMAIN_INTERNET"
echo
echo -e "${GREEN} Sensitive data will be stored in${NC} .secrets ${GREEN}folder ${NC}"
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
