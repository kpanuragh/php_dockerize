#! /usr/bin/pwsh
$PROJECT_NAME = Read-Host -Prompt "Enter Project name"
$PHP_VERSION = Read-Host -Prompt "Enter PHP version (e.g. 7.4)"
$WEB_SERVER = Read-Host -Prompt "Enter web server type (e.g. apache, nginx)"
$PUBLIC_PATH = Read-Host -Prompt "Enter public path ( from root folder e.g. public)"
$DATABASE_OPTIONS = Read-Host -Prompt "Select database options (separate by comma, e.g. mysql,postgres,mongodb)"
$INCLUDE_REDIS = $false
$INCLUDE_REDIS_RESPONSE = Read-Host -Prompt "Include Redis? (y/n) "
$SERVER_NAME = Read-Host -Prompt "Enter server name (e.g. example.com)"
$VHOST_CONF = ""
$COMPOSE_FILE = ""
if ($INCLUDE_REDIS_RESPONSE -match "^(y|Y)$") {
  $INCLUDE_REDIS = $true
}
if ($WEB_SERVER -eq "apache" ) {
  $VHOST_CONF = "./conf/apache-vhost.conf:/etc/apache2/sites-enabled/000-default.conf"
  @"
    <VirtualHost *:80>
    ServerName $SERVER_NAME
    DocumentRoot /var/www/html/$PUBLIC_PATH
    ErrorLog /var/log/apache2/error.log
    CustomLog /var/log/apache2/access.log combined
  </VirtualHost>
"@ | Set-Content -Path  conf/apache-vhost.conf 
  Write-Host "Apache virtualhost configuration file generated:"
  $COMPOSE_FILE = @"
version: '3'
services:
  web:
    image: php:$PHP_VERSION-$WEB_SERVER
    container_name: $PROJECT_NAME-app
    ports:
      - '80:80'
    volumes:
      - ../:/var/www/html
      - ./logs:/var/log/$WEB_SERVER
      - $VHOST_CONF
    restart: always
  
"@
}
if ($WEB_SERVER -eq "nginx" ) {
  $VHOST_CONF = "./conf/nginx-vhost.conf:/etc/nginx/conf.d/default.conf"
  @"
  server {
    listen 80;
    server_name $SERVER_NAME;
    root /var/www/html/$PUBLIC_PATH;

    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;

    location / {
      try_files \`$uri /index.php?\`$args;
    }

    location ~ \.php$ {
      include fastcgi_params;
      fastcgi_param SCRIPT_FILENAME \`$document_root\`$fastcgi_script_name;
      fastcgi_pass $PROJECT_NAME-php:9000;
      fastcgi_index index.php;
    }
  }
"@ | Set-Content -Path conf/nginx-vhost.conf
  Write-Host "Nginx virtualhost configuration file generated:"
  $COMPOSE_FILE = @"
  version: '3'
  services:
    web:
      image: nginx:latest 
      container_name: $PROJECT_NAME-app
      ports:
        - '80:80'
      volumes:
        - ../:/var/www/html
        - ./logs:/var/log/$WEB_SERVER
        - $VHOST_CONF
      restart: always
    php:
      image: php:$PHP_VERSION-fpm
      container_name: $PROJECT_NAME-php
      ports:
        - ':9000'
      volumes:
          - ../:/var/www/html
    
"@
}
if ($DATABASE_OPTIONS -contains 'mysql') {
  $MYSQL_ROOT_PASSWORD = Read-Host -Prompt "Enter MySQL root password" 
  $MYSQL_DATABASE = Read-Host -Prompt "Enter MySQL database name" 
  $MYSQL_USER = Read-Host -Prompt "Enter MySQL username" 
  $MYSQL_PASSWORD = Read-Host -Prompt "Enter MySQL user password" 
  $COMPOSE_FILE += @"
  mysql:
    image: mysql:latest
    container_name: $PROJECT_NAME-mysql
    ports:
      - '3306:3306'
    environment:
      - MYSQL_DATABASE=$MYSQL_DATABASE
      - MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD
      - MYSQL_USER=$MYSQL_USER
      - MYSQL_PASSWORD=$MYSQL_PASSWORD
    volumes:
      - ./mysql-data:/var/lib/mysql
    restart: always
  
"@
}
# Add PostgreSQL service if selected
if ($DATABASE_OPTIONS -contains 'postgres') {
  $POSTGRES_PASSWORD =  Read-Host -Prompt "Enter PostgreSQL root password" 
  $COMPOSE_FILE+=@"
postgres:
    image: postgres:latest
    container_name: $PROJECT_NAME-postgres
    ports:
      - '5432:5432'
    environment:
      - POSTGRES_PASSWORD=$POSTGRES_PASSWORD
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    restart: always
  
"@
}
# Add MongoDB service if selected
if ($DATABASE_OPTIONS -contains 'mongodb') {
  $COMPOSE_FILE+=@"
mongodb:
    image: mongo:latest
    container_name: $PROJECT_NAME-mongo
    ports:
      - '27017:27017'
    volumes:
      - ./mongo-data:/data/db
    restart: always
  
"@
}
if($INCLUDE_REDIS -eq $true)
{
  $COMPOSE_FILE+=@"
redis:
    image: redis:latest
    container_name: $PROJECT_NAME-redis
    ports:
      - '6379:6379'
    restart: always
"@
}
$COMPOSE_FILE | Set-Content -Path docker-compose.yml
Write-Host "Done"