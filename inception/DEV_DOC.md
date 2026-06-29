# Developer Documentation

## Environment setup from scratch

### Prerequisites

- A Linux virtual machine with sudo access
- Docker Engine and Docker Compose v2 installed
- Git

### 1. Clone the repository

```bash
git clone <repository-url> inception 
cd inception
```

### 2. Create the secrets files

These files are excluded from the repository and must be created manually:

```bash
echo "your_root_password"   > secrets/db_root_password.txt
echo "your_db_password"     > secrets/db_password.txt
echo "your_admin_password"  > secrets/credentials.txt
chmod 644 secrets/*.txt
```

### 3. Create the environment file

Create `srcs/.env` with the following content, substituting your own login:

```
DOMAIN_NAME=ikozhina.42.fr

MYSQL_ROOT_PASSWORD_FILE=/run/secrets/db_root_password
MYSQL_DATABASE=wordpress
MYSQL_USER=wp_user
MYSQL_PASSWORD_FILE=/run/secrets/db_password

WORDPRESS_DB_HOST=mariadb
WORDPRESS_DB_NAME=wordpress
WORDPRESS_DB_USER=wp_user
WORDPRESS_DB_PASSWORD_FILE=/run/secrets/db_password

WP_ADMIN_USER=main_user
WP_ADMIN_PASSWORD_FILE=/run/secrets/credentials
WP_ADMIN_EMAIL=admin@ikozhina.42.fr
WP_SITE_TITLE=Inception42

WP_SECOND_USER=ikozhina
WP_SECOND_PASSWORD_FILE=/run/secrets/credentials
WP_SECOND_EMAIL=ikozhina@42.fr
WP_SECOND_ROLE=author
```

### 4. Add the domain to /etc/hosts

`make` does this automatically, but if you want to do it manually:

```bash
echo "127.0.0.1 ikozhina.42.fr" | sudo tee -a /etc/hosts
```

---

## Build and launch

```bash
make          # build images, create volumes/network, start all containers
make up       # start already-built containers (no rebuild)
make down     # stop containers, keep data
make fclean   # stop and remove everything including images, volumes, data, /etc/hosts entry
make re       # fclean + all (full rebuild from scratch)
```
## Docker Compose commands called by Makefile

```bash
make          # docker compose -p inception -f srcs/docker-compose.yml --env-file srcs/.env up --build
make up       # docker compose -p inception -f srcs/docker-compose.yml --env-file srcs/.env up -d
make down     # docker compose -p inception -f srcs/docker-compose.yml down --remove-orphans
make fclean   # docker compose -p inception -f srcs/docker-compose.yml --env-file srcs/.env down --rmi local --volumes --remove-orphans
```

### What happens on first `make`:

1. Makefile creates `/home/ikozhina/data/mariadb` and `/home/ikozhina/data/wordpress` — empty directories on the VM disk that Docker will bind-mount as persistent volume storage for MariaDB and WordPress data
2. Docker Compose builds three images from their Dockerfiles (`alpine:3.22` base)
3. MariaDB container starts — `init.sh` initializes the database, creates the `wordpress` database and `wp_user` (the dedicated database user WordPress uses to connect), then `exec`s `mariadbd` as PID 1
4. WordPress container waits for MariaDB to be healthy, then `init.sh` creates `wp-config.php`, installs WordPress, creates the administrator account (`main_user`) and a second author account (`ikozhina`), then `exec`s `php-fpm83` as PID 1
5. NGINX container starts — `init.sh` generates a self-signed TLS certificate from `$DOMAIN_NAME`, then `exec`s `nginx` as PID 1

On subsequent runs, each `init.sh` detects existing data and skips setup — only starts the service.

---

## Managing containers and volumes

### Containers

```bash
docker ps                          # list running containers
docker ps -a                       # include stopped containers
docker logs mariadb                # view logs for a service
docker logs -f wordpress           # follow live logs
docker exec -it mariadb sh         # open a shell inside a container
docker restart nginx               # restart a single service
docker inspect mariadb             # full container details
```

### Verify PID 1 (no shell wrappers or infinite loops):

```bash
docker exec -it mariadb ps aux     # PID 1 should be mariadbd
docker exec -it wordpress ps aux   # PID 1 should be php-fpm83
docker exec -it nginx ps aux       # PID 1 should be nginx
```

### Volumes

```bash
docker volume ls                              # list volumes
docker volume inspect mariadb_data            # inspect a volume
ls /home/ikozhina/data/mariadb               # view MariaDB files on host
ls /home/ikozhina/data/wordpress             # view WordPress files on host
```

### Network

```bash
docker network ls                             # list networks
docker network inspect inception_inception    # see connected containers and IPs
```

### TLS certificate

```bash
docker exec nginx openssl x509 -in /etc/nginx/ssl/tls.crt -noout -subject -dates
```

### Verify TLS version (subject requires TLSv1.2 or TLSv1.3 only):

```bash
openssl s_client -connect ikozhina.42.fr:443
```

---

## Data storage and persistence

All persistent data lives outside the containers on the VM's disk, mounted
via named volumes with a local bind driver:

| Volume | Host path | Mounted at (inside container) | Contains |
|---|---|---|---|
| `mariadb_data` | `/home/ikozhina/data/mariadb` | `/var/lib/mysql` | MariaDB database files |
| `wordpress_data` | `/home/ikozhina/data/wordpress` | `/var/www/html` | WordPress files, uploads, themes |

The `wordpress_data` volume is shared between two containers:
- **wordpress** — read/write (installs plugins, handles uploads)
- **nginx** — read-only (serves static files directly without involving PHP)

Data survives `make down` (containers removed, volumes kept).
Data is deleted only by `make fclean` (`docker compose down --volumes` + `sudo rm -rf /home/ikozhina/data`).

### Inspect the database directly

```bash
docker exec -it mariadb mariadb -u wp_user -p
# enter password from secrets/db_password.txt

USE wordpress;
SHOW TABLES;
SELECT user_login, user_email FROM wp_users;
```

### Inspect WordPress content via WP-CLI

```bash
docker exec -it wordpress wp user list --allow-root   # list all WordPress users
docker exec -it wordpress wp post list --allow-root   # list all posts
docker exec -it wordpress wp db check --allow-root    # verify database integrity
```

---

## After a VM reboot

Docker containers do not restart automatically after a VM reboot. After
rebooting, start the stack again with:

```bash
sudo reboot         # reboot the VM
# after reboot, log back in and run:
make up             # start containers using already-built images
```

---

## Changing ports

All three services communicate on fixed ports. If a port needs to change,
both sides of the connection must be updated, then the stack rebuilt with
`make re`.

### PHP-FPM port (default: 9000)

| File | What to change |
|---|---|
| `srcs/requirements/wordpress/conf/www.conf` | `listen = 0.0.0.0:9000` |
| `srcs/requirements/nginx/conf/default.conf` | `fastcgi_pass wordpress:9000` |

### MariaDB port (default: 3306)

| File | What to change |
|---|---|
| `srcs/requirements/mariadb/conf/my.cnf` | `port=3306` |
| `srcs/requirements/wordpress/tools/init.sh` | port in `mariadb-admin ping` check |
| `srcs/.env` | `WORDPRESS_DB_HOST=mariadb:NEWPORT` if needed |

### NGINX port (default: 443)

| File | What to change |
|---|---|
| `srcs/docker-compose.yml` | `"443:443"` → `"NEWPORT:NEWPORT"` |
| `srcs/requirements/nginx/conf/default.conf` | `listen 443 ssl` |

After any port change:

```bash
make re
```
