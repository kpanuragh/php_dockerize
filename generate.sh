#!/bin/bash


RED="31"
GREEN="32"
YELLOW="93"
BOLDGREEN="\e[1;${GREEN}m"
ITALICYELLOW="\e[3;${YELLOW}m"
BOLDRED="\e[1;${RED}m"
ENDCOLOR="\e[0m"
echo -e "${BOLDRED}"
cat << "EOF"

.______    __    __  .______       _______   ______     ______  __  ___  _______ .______       __   ________   _______ 
|   _  \  |  |  |  | |   _  \     |       \ /  __  \   /      ||  |/  / |   ____||   _  \     |  | |       /  |   ____|
|  |_)  | |  |__|  | |  |_)  |    |  .--.  |  |  |  | |  ,----'|  '  /  |  |__   |  |_)  |    |  | `---/  /   |  |__   
|   ___/  |   __   | |   ___/     |  |  |  |  |  |  | |  |     |    <   |   __|  |      /     |  |    /  /    |   __|  
|  |      |  |  |  | |  |         |  '--'  |  `--'  | |  `----.|  .  \  |  |____ |  |\  \----.|  |   /  /----.|  |____ 
| _|      |__|  |__| | _|         |_______/ \______/   \______||__|\__\ |_______|| _| `._____||__|  /________||_______|
                                                                                                                       

EOF
echo -e "${ENDCOLOR}"

yellow_message(){
  echo -e "${ITALICYELLOW} $1 ${ENDCOLOR}"
}

green_prompt() {
  read -ep "$(echo -e "${BOLDGREEN} $1 ${ENDCOLOR}")" $2
}

# Get user input for PHP version and web server type
green_prompt "Enter Project name:"  PROJECT_NAME

green_prompt "Enter PHP version (e.g. 7.4): " PHP_VERSION
green_prompt "Enter web server type (e.g. apache, nginx): " WEB_SERVER
green_prompt "Enter public path ( from root folder e.g. public): " PUBLIC_PATH
green_prompt "Enter server name (e.g. example.com): " SERVER_NAME
# Prompt user to select database options
green_prompt "Select database options (separate by comma, e.g. mysql,postgres,mongodb):" DATABASE_OPTIONS

# Check if Redis should be included
INCLUDE_REDIS=false
green_prompt "Include Redis? (y/n)" INCLUDE_REDIS_RESPONSE
if [[ $INCLUDE_REDIS_RESPONSE =~ ^[Yy]$ ]]; then
  INCLUDE_REDIS=true
fi
generate_virtualhos_apache() {
  VHOST_CONF="./conf/apache-vhost.conf:/etc/apache2/sites-enabled/000-default.conf"
  echo "<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot /var/www/html/${PUBLIC_PATH}
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
  </VirtualHost>" >conf/apache-vhost.conf
  yellow_message "Apache virtualhost configuration file generated"

}
generate_virtualhos_nginx() {
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
  }" >conf/nginx-vhost.conf
  yellow_message "Nginx virtualhost configuration file generated:"
}
generate_docker_apache() {
  echo "
FROM php:${PHP_VERSION}-${WEB_SERVER}
RUN apt-get update && apt-get install -y \
    curl \
    g++ \
    git \
    libbz2-dev \
    libpq-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libonig-dev \
    libzip-dev \
    libmcrypt-dev \
    libpng-dev \
    libreadline-dev \
    sudo \
    unzip \
    zip \
 && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install \
    bcmath \
    bz2 \
    calendar \
    iconv \
    intl \
    pdo \
    pdo_pgsql \
    mbstring \
    opcache \
    pdo_mysql \
    zip
RUN docker-php-ext-enable \
    bcmath \
    bz2 \
    calendar \
    iconv \
    intl \
    mbstring \
    pdo \
    pdo_pgsql \
    opcache \
    pdo_mysql \
    zip
RUN apt-get update && apt-get upgrade -y
" >Dockerfile
  # Define the Docker Compose file contents
  COMPOSE_FILE="
version: '3'
services:
  web:
    build:
       context: .
       dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}-app
    ports:
      - '80:80'
    volumes:
      - ../:/var/www/html
      - ./logs:/var/log/${WEB_SERVER}
      - ${VHOST_CONF}
    restart: always
"

}
generate_docker_nginx() {
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
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}-php
    ports:
      - '9000:9000'
    volumes:
        - ../:/var/www/html
"
  echo "
FROM php:${PHP_VERSION}-fpm
RUN apt-get update && apt-get install -y \
    curl \
    g++ \
    git \
    libbz2-dev \
    libpq-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg-dev \
    libonig-dev \
    libzip-dev \
    libmcrypt-dev \
    libpng-dev \
    libreadline-dev \
    sudo \
    unzip \
    zip \
 && rm -rf /var/lib/apt/lists/*
RUN docker-php-ext-install \
    bcmath \
    bz2 \
    calendar \
    iconv \
    pdo \
    pdo_pgsql \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    zip
RUN docker-php-ext-enable \
    bcmath \
    bz2 \
    calendar \
    iconv \
    pdo \
    pdo_pgsql \
    intl \
    mbstring \
    opcache \
    pdo_mysql \
    zip

RUN apt-get update && apt-get upgrade -y
" >Dockerfile

}
generate_docker_mysql() {
  green_prompt "Enter MySQL root password: " MYSQL_ROOT_PASSWORD
  green_prompt "Enter MySQL database name: " MYSQL_DATABASE
  green_prompt "Enter MySQL username: " MYSQL_USER
  green_prompt "Enter MySQL user password: " MYSQL_PASSWORD
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
}
generate_docker_postgres() {
  green_prompt "Enter PostgreSQL root password: " POSTGRES_PASSWORD
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
}
generate_docker_mongodb() {
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
}
# Generate Apache virtualhost configuration file
if [[ $WEB_SERVER == "apache" ]]; then
  generate_virtualhos_apache
  generate_docker_apache
fi

# Generate Nginx virtualhost configuration file
if [[ $WEB_SERVER == "nginx" ]]; then
  generate_virtualhos_nginx
  generate_docker_nginx
fi

# Add MySQL service if selected
if [[ $DATABASE_OPTIONS == *mysql* ]]; then
  generate_docker_mysql
fi

# Add PostgreSQL service if selected
if [[ $DATABASE_OPTIONS == *postgres* ]]; then
  generate_docker_postgres
fi

# Add MongoDB service if selected
if [[ $DATABASE_OPTIONS == *mongodb* ]]; then
  generate_docker_mongodb
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
echo "$COMPOSE_FILE" >docker-compose.yml

yellow_message "Docker Compose file generated:"
