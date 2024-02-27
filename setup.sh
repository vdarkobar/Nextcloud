#!/bin/bash

sudo hwclock --hctosys

#################################
#
#################################

echo "Creating database passwords and securing them"
sleep 0.5 # delay for 0.5 seconds
echo

# Generate ROOT_DB_PASSWORD
ROOT_DB_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo "Error generating ROOT_DB_PASSWORD."
    exit 1
fi

# Save ROOT_DB_PASSWORD
mkdir -p secrets && echo $ROOT_DB_PASSWORD > secrets/ROOT_DB_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo "Error saving ROOT_DB_PASSWORD."
    exit 1
fi

# Generate NEXTCLOUD_DB_PASSWORD
NEXTCLOUD_DB_PASSWORD=$(openssl rand -base64 32 | sed 's/[^a-zA-Z0-9]//g')
if [ $? -ne 0 ]; then
    echo "Error generating NEXTCLOUD_DB_PASSWORD."
    exit 1
fi

# Save NEXTCLOUD_DB_PASSWORD
# Fixed typo in variable name in the file path
mkdir -p secrets && echo $NEXTCLOUD_DB_PASSWORD > secrets/NEXTCLOUD_DB_PASSWORD.secret
if [ $? -ne 0 ]; then
    echo "Error saving NEXTCLOUD_DB_PASSWORD."
    exit 1
fi

# Change ownership and permissions
sudo chown -R root:root secrets/
if [ $? -ne 0 ]; then
    echo "Error changing ownership of secrets directory."
    exit 1
fi

sudo chmod -R 600 secrets/
if [ $? -ne 0 ]; then
    echo "Error changing permissions of secrets directory."
    exit 1
fi

echo "Operation completed successfully."
sleep 0.5 # delay for 0.5 seconds
echo

#################################
#
#################################

echo -e "${GREEN} ######################## ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Update and upgrade packages
sudo apt update && sudo apt upgrade -y


#################################
# domain name??
#################################

# Install Apache2
sudo apt install apache2 p7zip-full -y

# Configure Apache2 for Nextcloud
# first create/edit>move
#cat <<EOF | sudo tee nextcloud.conf ...

# Configure Apache2 for Nextcloud
cat <<EOF | sudo tee /etc/apache2/sites-available/nextcloud.conf
<VirtualHost *:80>
     ServerAdmin master@domain.com
     DocumentRoot /var/www/nextcloud/

     ServerName your_domain.com
     ServerAlias www.your_domain.com
     ServerAlias 192.168.30.121
     ServerAlias local_server_domain

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

     ErrorLog \${APACHE_LOG_DIR}/error.log
     CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

# Enable the site and required Apache modules
sudo a2ensite nextcloud.conf
sudo a2enmod rewrite headers env dir mime

# Restart Apache to apply changes
sudo service apache2 restart


#################################
# Install PHP 8.3 and necessary PHP modules
#################################

echo -e "${GREEN} ######################## ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Install the apt-transport-https package for HTTPS support
sudo apt install apt-transport-https -y
if [ $? -ne 0 ]; then
    echo "Error installing apt-transport-https. Exiting."
    exit 1
fi

# Add the GPG key for the Ondřej Surý PHP repository
sudo curl -sSLo /usr/share/keyrings/deb.sury.org-php.gpg https://packages.sury.org/php/apt.gpg
if [ $? -ne 0 ]; then
    echo "Error downloading the GPG key for PHP repository. Exiting."
    exit 1
fi

# Add the PHP repository to the sources list
sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://packages.sury.org/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list'
if [ $? -ne 0 ]; then
    echo "Error adding the PHP repository to sources list. Exiting."
    exit 1
fi

# Update apt sources
sudo apt update
if [ $? -ne 0 ]; then
    echo "Error updating apt sources. Exiting."
    exit 1
fi

# Install PHP 8.3 and required packages
sudo apt install -y \
php8.3 \
libapache2-mod-php8.3 \
php8.3-{zip,xml,mbstring,gd,curl,imagick,intl,bcmath,gmp,cli,mysql,apcu,redis,smbclient,ldap,bz2,fpm} \
php-dompdf \
libmagickcore-6.q16-6-extra \
redis-server \
ufw \
php-pear \
unzip
if [ $? -ne 0 ]; then
    echo "Error installing PHP 8.3 and required packages. Exiting."
    exit 1
fi

echo "PHP 8.3 and required packages have been installed successfully."

#################################
#
#################################

echo -e "${GREEN} ######################## ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

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

echo -e "${GREEN} ######################## ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

#################################
#
#################################

echo -e "${GREEN} ######################## ${NC}"
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


#################################
#
#################################

echo -e "${GREEN} ######################## ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Download Nextcloud
cd /tmp && wget https://download.nextcloud.com/server/releases/latest.zip
#install p7zip-full for progres bar (%)
7z x latest.zip
#unzip latest.zip > /dev/null
sudo mv nextcloud /var/www/


####################
# Prepare firewall #
####################
echo
echo -e "${GREEN} Preparing firewall ${NC}"

sleep 0.5 # delay for 0.5 seconds
echo

sudo ufw allow 80/tcp comment "Nextcloud Local Access"
sudo systemctl restart ufw


#################################
#       save user name/pass ???
#################################

# Initialize variables
NEXTCLOUD_ADMIN_USER=""
NEXTCLOUD_ADMIN_PASSWORD=""

# Function to ask for the Nextcloud admin user
ask_admin_user() {
    read -p "Enter Nextcloud admin user: " NEXTCLOUD_ADMIN_USER
    if [[ -z "$NEXTCLOUD_ADMIN_USER" ]]; then
        echo "The admin user cannot be empty. Please enter a valid user."
        ask_admin_user
    fi
}

# Function to ask for the Nextcloud admin password
ask_admin_password() {
    read -p "Enter Nextcloud admin password: " NEXTCLOUD_ADMIN_PASSWORD
    if [[ -z "$NEXTCLOUD_ADMIN_PASSWORD" ]]; then
        echo "The admin password cannot be empty. Please enter a valid password."
        ask_admin_password
    fi
}

# Call functions to get user input
ask_admin_user
ask_admin_password


#################################
#
#################################

echo -e "${GREEN} Creating data folder ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

NEXTCLOUD_DATA_DIR="/home/data/"

sudo mkdir /home/data/
sudo chown -R www-data:www-data /home/data/
sudo chown -R www-data:www-data /var/www/nextcloud/
sudo chmod -R 755 /var/www/nextcloud/


#################################
#
#################################

echo -e "${GREEN} Installing Nexcloud... ${NC}"
sleep 0.5 # delay for 0.5 seconds
echo

# Use the NEXTCLOUD_DATA_DIR variable for the data directory location in the occ command
sudo -u www-data php /var/www/nextcloud/occ maintenance:install --database "mysql" --database-name "nextcloud" --database-user "nextclouduser" --database-pass "$NEXTCLOUD_DB_PASSWORD" --admin-user "$NEXTCLOUD_ADMIN_USER" --admin-pass "$NEXTCLOUD_ADMIN_PASSWORD" --data-dir "$NEXTCLOUD_DATA_DIR"

sleep 01 # delay for 1 seconds

#################################
#
#################################

# Create or overwrite the tmp.config.php file, using sudo for permissions

# Define the file
CONFIG_FILE="tmp.config.php"

echo
echo -e "${GREEN}Creating file:${NC} $CONFIG_FILE"

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
echo "Configuration file created: $CONFIG_FILE"
echo "Local IP: $LOCAL_IP"
echo "Hostname: $HOSTNAME"
echo "Local Domain: $DOMAIN_LOCAL"
echo "Local Hostname and Domain Name: $HOSTNAME_DOMAIN_LOCAL"
echo

# Prompt for DOMAIN_INTERNET with error handling for empty input
while true; do
    read -p "Please enter Domain Name for your Nextcloud instance: (e.g., domain.com or subdomain.domain.com): " DOMAIN_INTERNET
    if [ -z "$DOMAIN_INTERNET" ]; then
        echo "Error: Domain Name cannot be empty. Please try again."
    else
        break
    fi
done

echo
echo "Domain name: $DOMAIN_INTERNET"
echo

# Replace placeholders in the temporary file
sed -i "s/'LOCAL_IP'/'$LOCAL_IP'/g" "$TEMP_FILE"
sed -i "s/'HOSTNAME_DOMAIN_LOCAL'/'$HOSTNAME_DOMAIN_LOCAL'/g" "$TEMP_FILE"
sed -i "s/'DOMAIN_INTERNET'/'$DOMAIN_INTERNET'/g" "$TEMP_FILE"
sed -i "s/'WWW_DOMAIN_INTERNET'/'www.$DOMAIN_INTERNET'/g" "$TEMP_FILE"

# Move the temporary file to the final configuration file
sudo mv "$TEMP_FILE" ~/"$CONFIG_FILE"
echo
echo "Trusted Domains are ready: $CONFIG_FILE"
echo
sleep 1 # delay for 1 seconds
echo -e "${GREEN}Done. ${NC}"


#################################
#                                           radi !!!!!!!!!!!!!
#################################

# Search for tmp.config.php in the home directory and assign the path to TMP_FILE
TMP_FILE=$(find ~/ -type f -name "tmp.config.php" 2>/dev/null)

# Check if TMP_FILE is not empty
if [ ! -z "$TMP_FILE" ]; then
    echo "File found: $TMP_FILE"
else
    echo "File not found."
fi

# Define paths to the files
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

echo "The config.php file has been updated."



####################################################################################################
