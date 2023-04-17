#!/bin/bash

# Get user input for PHP version and web server type
read -p "Enter Project name: " PROJECT_NAME

read -p "Enter PHP version (e.g. 7.4): " PHP_VERSION
read -p "Enter web server type (e.g. apache, nginx): " WEB_SERVER
read -p "Enter public path ( from root folder e.g. public): " PUBLIC_PATH
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

# Generate Apache virtualhost configuration file
if [[ $WEB_SERVER == "apache" ]]; then
  read -p "Enter server name (e.g. example.com): " SERVER_NAME
  VHOST_CONF="./conf/apache-vhost.conf:/etc/apache2/sites-enabled/000-default.conf"
  echo "<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot /var/www/html/${PUBLIC_PATH}
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
  </VirtualHost>" > conf/apache-vhost.conf
  echo "Apache virtualhost configuration file generated:"
fi

# Generate Nginx virtualhost configuration file
if [[ $WEB_SERVER == "nginx" ]]; then
  read -p "Enter servername (e.g. example.com): " SERVER_NAME
  VHOST_CONF="./conf/nginx-vhost.conf:/etc/nginx/conf.d/default.conf"
  echo "server {
    listen 80;
    server_name ${SERVER_NAME};
    root /var/www/html/${PUBLIC_PATH};

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
      try_files \$uri /index.php?\$args;
    }

    location ~ \.php$ {
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
      fastcgi_pass ${PROJECT_NAME}-php:9000;
      fastcgi_index index.php;
    }
  }" > conf/nginx-vhost.conf
  echo "Nginx virtualhost configuration file generated:"
fi


if [[ $WEB_SERVER == "apache" ]]; then
# Define the Docker Compose file contents
COMPOSE_FILE="
version: '3'
services:
  web:
    image: php:${PHP_VERSION}-${WEB_SERVER}
    container_name: ${PROJECT_NAME}-app
    ports:
      - '80:80'
    volumes:
      - ../:/var/www/html
      - ./logs:/var/log/${WEB_SERVER}
      - ${VHOST_CONF}
    restart: always
"
fi
if [[ $WEB_SERVER == "nginx" ]]; then
# Define the Docker Compose file contents
COMPOSE_FILE="
version: '3'
services:
  web:
    image: nginx:latest 
    container_name: ${PROJECT_NAME}-app
    ports:
      - '80:80'
    volumes:
      - ../:/var/www/html
      - ./logs:/var/log/${WEB_SERVER}
      - ${VHOST_CONF}
    restart: always
  php:
    image: php:${PHP_VERSION}-fpm
    container_name: ${PROJECT_NAME}-php
    ports:
      - ':9000'
    volumes:
        - ../:/var/www/html
"
fi
# Add MySQL service if selected
if [[ $DATABASE_OPTIONS == *mysql* ]]; then
  read -p "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
  read -p "Enter MySQL database name: " MYSQL_DATABASE
  read -p "Enter MySQL username: " MYSQL_USER
  read -p "Enter MySQL user password: " MYSQL_PASSWORD
  COMPOSE_FILE+="
  mysql:
    image: mysql:latest
    container_name: ${PROJECT_NAME}-mysql
    ports:
      - '3306:3306'
    environment:
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
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
    container_name: ${PROJECT_NAME}-postgres
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
    container_name: ${PROJECT_NAME}-mongo
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
    container_name: ${PROJECT_NAME}-redis
    ports:
      - '6379:6379'
    restart: always
  "
fi

# Create the Docker Compose file
echo "$COMPOSE_FILE" > docker-compose.yml

echo "Docker Compose file generated:"
cat docker-compose.yml

echo "Done."
