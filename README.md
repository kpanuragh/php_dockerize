# Bash script for setting up a PHP stack with Docker
This is a Bash script that allows users to set up a PHP stack with Docker. The script prompts the user to select which database they want to use (MySQL, PostgreSQL, or MongoDB), which web server they want to use (Apache or Nginx), and whether they want to include Redis as an optional cache layer.

The script then generates a Docker Compose file based on the user's selections, which includes containers for the web server, PHP, and the selected database. If Redis is selected, an additional container is added for Redis.

The script also prompts the user to configure the virtualhost file for their selected web server, which is then included as a volume in the Docker Compose file.

## Usage

To use this script, follow these steps:
1. Clone the repository in your project root
```bash
git clone https://github.com/kpanuragh/php_dockerize.git
```
2. Open your terminal
```bash
 cd php_dockerize
```
3. Run the following command to make the script executable:
```bash
chmod +x generate.sh

```
4. Run the script by typing the following command:
```bash
bash generate.sh
```
5. Follow the prompts to select your desired database, web server, and Redis configuration.
6. Review the generated Docker Compose file and virtualhost file.
7. Run the Docker Compose file using the following command:
```bash
docker-compose up -d
```
8. Verify that the containers are running by typing the following command:
```bash
docker-compose ps
```
## Requirements
 use this script, you will need to have Docker installed on your machine.
## Customization
This script can be customized to support additional databases or web servers by modifying the docker-compose.yml file and adding the necessary configuration files for the virtualhost and container volumes.

