#!/bin/bash

# Function to handle errors
handle_error() {
    echo "An error occurred. Exiting..."
    exit 1
}

# Trap any error
trap 'handle_error $LINENO' ERR

# Dialog Section to define variable using echo and read

# Prompt to choose web server (Apache / Nginx)
echo "Select your web server (1 for Apache, 2 for Nginx):"
read SERVER

# Prompt for the current running configuration
if [ "$SERVER" -eq 1 ]; then
    echo "Enter the current running Apache config file name (without path):"
    read CURRENT_CONF
    CURRENT_CONF_PATH="/etc/apache2/sites-enabled/$CURRENT_CONF"
elif [ "$SERVER" -eq 2 ]; then
    echo "Enter the current running Nginx config file name (without path):"
    read CURRENT_CONF
    CURRENT_CONF_PATH="/etc/nginx/sites-enabled/$CURRENT_CONF"
else
    echo "Invalid input. Please enter 1 or 2."
    exit 1
fi

# Prompt for the server name
echo "Enter the server name (e.g., example.com):"
read SERVER_NAME

# Prompt for the location of SSL keys and certificates
echo "Enter the path to your Private Key SSL:"
read SSL_KEY

echo "Enter the path to your SSL Certificate:"
read SSL_CERT

echo "Enter the path to your CA Certificate:"
read CA_CERT

# Prompt for the DocumentRoot location
echo "Enter the DocumentRoot for the web app:"
read DOC_ROOT

# Prompt for the database name and root password
echo "Enter the database name:"
read DB_NAME

echo "Enter the database root password:"
read -s DB_PASSWORD  # Using -s flag to hide password input

#--------------End of Input section------------------------------

# Get the hostname of the server
HOSTNAME=$(hostname)

# Step 1: Check if /var/www/maintenance exists, if not, create it
if [ ! -d "/var/www/maintenance" ]; then
    mkdir -p /var/www/maintenance
fi

# Step 2: Check if user www-data exists, if not, create it
if ! id -u www-data >/dev/null 2>&1; then
    useradd -r -s /bin/false www-data
fi
# Step 3: Create an index.html template
cat <<EOF > /var/www/maintenance/index.html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Under Maintenance</title>
    <style>
        body {
        ¦   font-family: Arial, sans-serif;
        ¦   background: linear-gradient(45deg, #ff9a9e, #fad0c4, #ffecd2);
        ¦   height: 100vh;
        ¦   margin: 0;
        ¦   display: flex;
        ¦   justify-content: center;
        ¦   align-items: center;
        ¦   overflow: hidden;
        }
        .container {
        ¦   text-align: center;
        ¦   background-color: rgba(255, 255, 255, 0.8);
        ¦   padding: 40px;
        ¦   border-radius: 20px;
        ¦   box-shadow: 0 0 20px rgba(0, 0, 0, 0.1);
        }
        h1 {
        ¦   color: #ff6b6b;
        ¦   font-size: 3em;
        ¦   margin-bottom: 20px;
        ¦   text-shadow: 2px 2px 4px rgba(0, 0, 0, 0.1);
        }
        p {
        ¦   color: #4a4a4a;
        ¦   font-size: 1.2em;
        ¦   line-height: 1.6;
        }
        .icon {
        ¦   font-size: 5em;
        ¦   margin-bottom: 20px;
        ¦   color: #ff9a9e;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🛠️ </div>
        <h1>Server Under Maintenance</h1>
        <p>We're currently performing some updates to improve your experience.</p>
        <p>Please check back soon!</p>
    </div>
</body>
</html>
EOF

# Step 4: Change ownership of /var/www/maintenance to www-data recursively
chown -R www-data:www-data /var/www/maintenance

# Step 5: Configure maintenance page
if [ "$SERVER" -eq 1 ]; then
    # Apache Configuration
    MAINTENANCE_CONF="/etc/apache2/sites-available/maintenance.conf"
    cat <<EOF > $MAINTENANCE_CONF
<VirtualHost *:443>
    ServerName $SERVER_NAME
    DocumentRoot /var/www/maintenance
    SSLEngine on
    SSLCertificateFile $SSL_CERT
    SSLCertificateKeyFile $SSL_KEY
    SSLCertificateChainFile $CA_CERT
</VirtualHost>
EOF
    a2ensite maintenance.conf
    systemctl reload apache2
elif [ "$SERVER" -eq 2 ]; then
    # Nginx Configuration
    MAINTENANCE_CONF="/etc/nginx/sites-available/maintenance"
    cat <<EOF > $MAINTENANCE_CONF
server {
    listen 443 ssl;
    server_name $SERVER_NAME;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_trusted_certificate $CA_CERT;

    root /var/www/maintenance;
    index index.html;
}
EOF
    ln -s $MAINTENANCE_CONF /etc/nginx/sites-enabled/maintenance
    systemctl reload nginx
fi

# Step 6: Stop the previous running configuration
if [ "$SERVER" -eq 1 ]; then
    a2dissite "$CURRENT_CONF"
    systemctl reload apache2
elif [ "$SERVER" -eq 2 ]; then
    rm "$CURRENT_CONF_PATH" || true
    systemctl reload nginx
fi

# Step 7: Backup DocumentRoot
BACKUP_DIR="$PWD/backup"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
BACKUP_FILE="$BACKUP_DIR/backup_${HOSTNAME}_$TIMESTAMP.tar.gz"
tar --exclude="/var/www/maintenance" -czvf $BACKUP_FILE -C "$DOC_ROOT" .

# Step 9: Backup SSL Certificates
SSL_BACKUP_FILE="$BACKUP_DIR/ssl_backup_${HOSTNAME}_$TIMESTAMP.tar.gz"
tar -czvf $SSL_BACKUP_FILE -C "$(dirname "$SSL_KEY")" "$(basename "$SSL_KEY")" -C "$(dirname "$SSL_CERT")" "$(basename "$SSL_CERT")" -C "$(dirname "$CA_CERT")" "$(basename "$CA_CERT")"

# Step 9: Backup database
DB_BACKUP_FILE="$BACKUP_DIR/db_backup_${HOSTNAME}_$TIMESTAMP.sql"
mysqldump -u root -p"$DB_PASSWORD" "$DB_NAME" > $DB_BACKUP_FILE

echo "Backup completed successfully. Files saved to $BACKUP_DIR."
