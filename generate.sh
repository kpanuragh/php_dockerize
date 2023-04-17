#!/bin/bash

# Get user input for PHP version and web server type
read -p "Enter PHP version (e.g. 7.4): " PHP_VERSION
read -p "Enter web server type (e.g. apache): " WEB_SERVER

# Prompt user to select database options
echo "Select database options (separate by comma, e.g. mysql,postgres,mongodb):"
read DATABASE_OPTIONS

# Check if Redis should be included
INCLUDE_REDIS=false
echo "Include Redis? (y/n)"
read INCLUDE_REDIS_RESPONSE
if [[ $INCLUDE_REDIS_RESPONSE =~ ^[Yy]$ ]]; then
  INCLUDE_REDIS=true
fi

# Prompt user to select virtualhost type
echo "Select virtualhost type (e.g. apache, nginx):"
read VIRTUALHOST_TYPE

# Define the Docker Compose file contents
COMPOSE_FILE="
version: '3'
services:
  web:
    image: php:${PHP_VERSION}-${WEB_SERVER}
    ports:
      - '80:80'
    volumes:
      - ./src:/var/www/html
      - ./logs:/var/log/${WEB_SERVER}
    restart: always
"

# Add MySQL service if selected
if [[ $DATABASE_OPTIONS == *mysql* ]]; then
  read -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
  COMPOSE_FILE+="
  mysql:
    image: mysql:latest
    ports:
      - '3306:3306'
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
    volumes:
      - ./mysql-data:/var/lib/mysql
    restart: always
  "
fi

# Add PostgreSQL service if selected
if [[ $DATABASE_OPTIONS == *postgres* ]]; then
  read -p "Enter PostgreSQL root password: " POSTGRES_PASSWORD
  COMPOSE_FILE+="
  postgres:
    image: postgres:latest
    ports:
      - '5432:5432'
    environment:
      - POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    restart: always
  "
fi

# Add MongoDB service if selected
if [[ $DATABASE_OPTIONS == *mongodb* ]]; then
  COMPOSE_FILE+="
  mongodb:
    image: mongo:latest
    ports:
      - '27017:27017'
    volumes:
      - ./mongo-data:/data/db
    restart: always
  "
fi

# Add Redis service if selected
if [[ $INCLUDE_REDIS == true ]]; then
  COMPOSE_FILE+="
  redis:
    image: redis:latest
    ports:
      - '6379:6379'
    restart: always
  "
fi

# Generate Apache virtualhost configuration file
if [[ $VIRTUALHOST_TYPE == "apache" ]]; then
  read -p "Enter server name (e.g. example.com): " SERVER_NAME
  APACHE_VHOST_CONF="
  volumes:
    - ./apache-vhost.conf:/etc/apache2/sites-enabled/000-default.conf
  "
  echo "<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot /var/www/html
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
  </VirtualHost>" > apache-vhost.conf
  echo "Apache virtualhost configuration file generated:"
  echo "$APACHE_VHOST_CONF"
fi

# Generate Nginx virtualhost configuration file
if [[ $VIRTUALHOST_TYPE == "nginx" ]]; then
  read -p "Enter servername (e.g. example.com): " SERVER_NAME
  NGINX_VHOST_CONF="
  volumes:
    - ./nginx-vhost.conf:/etc/nginx/conf.d/default.conf
  "
  echo "server {
    listen 80;
    server_name ${SERVER_NAME};
    root /var/www/html;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
      try_files \$uri /index.php?\$args;
    }

    location ~ \.php$ {
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_pass web:9000;
      fastcgi_index index.php;
    }
  }" > nginx-vhost.conf
  echo "Nginx virtualhost configuration file generated:"
  echo "$NGINX_VHOST_CONF"
fi

# Add virtualhost configuration volumes to the Docker Compose file
if [[ $VIRTUALHOST_TYPE == "apache" ]]; then
  COMPOSE_FILE+="$APACHE_VHOST_CONF"
elif [[ $VIRTUALHOST_TYPE == "nginx" ]]; then
  COMPOSE_FILE+="$NGINX_VHOST_CONF"
fi

# Create the Docker Compose file
echo "$COMPOSE_FILE" > docker-compose.yml

echo "Docker Compose file generated:"
cat docker-compose.yml

echo "Done."
