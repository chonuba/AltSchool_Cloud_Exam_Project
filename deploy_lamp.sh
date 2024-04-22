#!/bin/bash

# To make this script modular and reusable tasked are performed with funcrions
# To aid readability of the script as instructed, lots of comments are used

########################################################
# CREATING SOME FUNCTIONS FOR CODE REUSABILITY
########################################################

# Function to update apt cache and system application 
sysUpdate () {
     # Updates and upgrades package index, where such update hasn't been run in 30 days 
    if [ -z "$(find /var/cache/apt -maxdepth 0 -mtime -30)" ]; 
        then
            echo "Updating package index and Upgrading packages......."
            sudo apt update -y && sudo apt upgrade -y
        else
            sudo apt update -y
    fi
}

#Function to install any package and dependecies
ubuntuAppInstaller () {
    for arg in "$@"; do
        echo "Installing $arg"
        if sudo apt install -y "$arg"; then
        # checks to see if package installs succesfully, and exits if not.
            echo "$arg has been installed successfully, continuing with the process"
        else
            echo "$arg Installation failed. Investigate the issue and try again"
            exit 1
        fi
    done
}

# Function to add PPA repo outside later than ubuntu index
addPPA () {
    for arg in "$@"; do
        sudo add-apt-repository "$arg" -y
        echo "$@ has been added to package index"
        sleep 2
        echo "Upadating apt cache index.."
        sudo apt update -y
    done
}

# Function to install PHP modules and extensions
phpModulesInstall () {
    for arg in "$@"; do
        echo "Installing php8.2-$arg..."
        sudo apt install -y php8.2-"$arg"
        echo "php8.2-$arg installed"
    done
}

# Function to start or restart services.
serviceRestart () {
    for arg in "$@"; do
        if systemctl is-active --quiet "$arg"; 
            then 
                echo "$arg is actively running"
                echo "Restarting $arg" && sudo systemctl restart "$arg" && echo "$arg restarted succesffully"
            else
                sudo systemctl start "$arg"
                echo "$arg service now started"
        fi
      #systemctl is-active --quiet $arg && echo "$arg is already active" || sudo systemctl restart $arg 
    done
}

# Function to clone any given repository to a specified local directory
cloneRepo () {
    # Checks for instance of git in local machine and installs git if not present
    echo "Checking for presence of git..."
    
    if git --version 2>&1 >/dev/null; 
        then
            echo "Git available, continuing with git git clone..."
        else
            echo "Installng Git..."
            sudo apt install -y git
    fi

    cd $2
    sudo git clone $1 && echo "Your project has been successfully cloned into $2" || echo "Cloning failed to complete, try again"
}

# Functin to create DB, User with password and privileges 
# This function would take 3 parameters; $1;DB,  $2; User, $3;user-password
createDB () {
        sudo mysql -uroot -e "CREATE DATABASE $1;"
        sudo mysql -uroot -e "CREATE USER '$2'@'localhost' IDENTIFIED BY '$3';"
        sudo mysql -uroot -e "GRANT ALL PRIVILEGES ON $1.* TO '$2'@'localhost';"
        #sudo mysql -uroot -e "FLUSH PRIVILEGES;"
}  

# Function to prepare the site config file
createSiteConfig() {
    local serv_name=$1
    local doc_root=$2
    local serv_alias=$3

    echo "<VirtualHost *:80>
    ServerName $serv_name
    DocumentRoot $doc_root
    ServerAlias $serv_alias

    <Directory $doc_root>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/$serv_name-error.log
    CustomLog \${APACHE_LOG_DIR}/$serv_name-access.log combined
</VirtualHost>" | sudo sh -c "cat > /etc/apache2/sites-available/$serv_name.conf"
}

# Function to install and setup composer.
installComposer () {
    # Check if the correct number of arguments are provided
    if [ "$#" -ne 1 ]; then
        echo "Provide the path of installation; Syntax: installComposer <path>"
        return 1
    fi

    # Check if the specified directory exists
    if [ ! -d "$1" ]; then
        echo "Error: Directory '$1' not found."
        return 1
    fi

    # Change to the specified directory
    cd "$1" || return 1

    # Download and install Composer
    if curl -sS https://getcomposer.org/installer | sudo php -q; then
        sudo mv composer.phar composer
        echo "Composer installed successfully in $1"
    else
        echo "Failed to download and install Composer."
        return 1
    fi
}

#installComposer () {
#    cd $1 #path to install composer
#    curl -sS https://getcomposer.org/installer | sudo php
#    sudo mv composer.phar composer
#}

# Function to remove comments (uncomment) lines.
unCommentLines () {
    sudo sed -i "$1,$2 s/^#//g" $3 #$1-$2 is line range; $3 is the file edit
} 
# Function to remove spaces for proper formating of files
removeSpaces () {
    sudo sed -i "$1,$2 s/ //g" $3
}
# Function to delete values from a range of lines
deleteValue () {
    sudo sed -ie "$1,$2 s/=.*$/=/" $3
}
# Function to append value at the end of a specified line
appendValue () {
    sudo sed -i "$1 s/$/$2/" $3
}
##########################################################################
#                                   END OF FUNCTIONS
##########################################################################


#########################################################################
# NOW, TO BEGIN THE TASKS THIS SCRIPT IS TO ACCOMPLISH,
# WE CALL THE PREPARED FUNCTIONS FOR THEIR SPECIFIC TASKS WHERE NECESSARY
#########################################################################

#Updating apt index and Upgrading applications as a pre-task"
sysUpdate

#echo "Installing system dependencies..."
#ubuntuAppInstaller lsb-release gnupg2 ca-certificates apt-transport-https zip unzip

echo "Installing WebServer applications..."
ubuntuAppInstaller software-properties-common apache2 mysql-server

sysUpdate
echo "Adding PPA for latest PHP..."
addPPA ppa:ondrej/php

echo "Installing PHP for apache..."
ubuntuAppInstaller php8.2 libapache2-mod-php8.2

#sysUpdate
echo "Installing PHP moudles and extensions for Laravel dependencies..."
phpModulesInstall bcmath dom curl fpm xml mysql zip intl ldap gd cli bz2 curl mbstring pgsql cgi sqlite3
 
# Enable URL rewriting 
echo "enabling apache rewrite module"
sudo a2enmod rewrite

# Download the project to server
echo "Cloning project repo to document root..."
cloneRepo https://github.com/laravel/laravel.git /var/www/

echo "Installing composer in your specified PATH"
installComposer /usr/bin


# First take ownership of the project to avoid permission issues
sudo chown -R $USER:$USER /var/www/laravel
cd /var/www/laravel

#install composer autoloader
#composer install --optimize-autoloader --no-dev
composer update --no-interaction

# Genereating and populating APP_KEY into the .env file
cd /var/www/laravel
sudo php artisan key:generate

echo "Granting ownership of storage and bootstrap/cache to www-data user"
sudo chown -R www-data storage
sudo chown -R www-data bootstrap/cache

# Set site config by calling the function the required info as parameters.
#echo "Now configuring the site..."
createSiteConfig "laravelexam.com" "/var/www/laravel/public" "www.laravelexam.com"

# Enable new site and disable default site
echo "Disabling default site"
sudo a2dissite 000-default.conf
# sudo rm /etc/apache2/sites-enabled/*

echo "Enabling new site..."
sudo a2ensite laravelexam.com.conf

echo checking for syntax erors on apache config...
sudo apache2ctl

# Restart Apache
echo "Restarting Apache"
serviceRestart apache2

# Create Database and user for our project by calling the right function
echo "Creating lar_exam_db Database for lar_exam_user with set password..."
createDB lar_exam_db lar_exam_user lar_exam_pass 

# Project enviroment settings
echo "Setting the environment configurations..."
[ "$(pwd)" = "/var/www/laravel" ] && echo "Right dir; continue" || cd /var/www/laravel
sudo cp .env.example .env

# Genereating and populating APP_KEY into the .env file
sudo php artisan key:generate
sudo php artisan storage:link

# Update .env with database credentials by calling the functions with parameters
unCommentLines 23 27 /var/www/laravel/.env
removeSpaces 23 27 /var/www/laravel/.env
deleteValue 22 27 /var/www/laravel/.env
appendValue 22 mysql /var/www/laravel/.env
appendValue 23 127.0.0.1 /var/www/laravel/.env
appendValue 24 3306 /var/www/laravel/.env
appendValue 25 lar_exam_db /var/www/laravel/.env
appendValue 26 lar_exam_user /var/www/laravel/.env
appendValue 27 lar_exam_pass /var/www/laravel/.env

# Integrating Database, checking connections and updating table with migration
sudo php artisan migrate
# Fill tables with sample data
sudo php artisan db:seed

# Restarting apache to have all config effect
echo "Starting and restarting web services..."
serviceRestart apache2 mysql