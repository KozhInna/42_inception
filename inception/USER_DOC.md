# User Documentation

## Services

The stack runs three services:

- **mariadb** — database storing all WordPress data (posts, users, settings)
- **wordpress** — WordPress site and PHP executor
- **nginx** — web server, the only entry point, handles HTTPS on port 443

## Start and stop

```bash
make          # build images and start all containers
make up       # start containers using already-built images
make down     # stop containers, data is kept
make fclean   # stop and remove everything including data
```

To restart a single service without rebuilding:

```bash
docker restart nginx
docker restart wordpress
docker restart mariadb
```

## Access

- Website: `https://ikozhina.42.fr`
- Login page: `https://ikozhina.42.fr/wp-login.php`
- Admin panel: `https://ikozhina.42.fr/wp-admin`

The browser will show a security warning — this is expected for a self-signed
certificate. Accept it to continue.

## Credentials

Passwords are stored in the `secrets/` folder at the project root:

| File | Contains |
|---|---|
| `secrets/credentials.txt` | WordPress admin and second user password |
| `secrets/db_password.txt` | WordPress database user password |
| `secrets/db_root_password.txt` | MariaDB root password |

Usernames and emails are defined in `srcs/.env`:

| Account | Username | Role |
|---|---|---|
| Administrator | `main_user` | full access |
| Second user | `ikozhina` | author |

These files are not included in the repository and must be created manually
before running `make` for the first time.

## Check services are running

```bash
docker ps
```

All three containers (`mariadb`, `wordpress`, `nginx`) should show as `Up`.
`mariadb` and `wordpress` should show `(healthy)`.

To see logs for a specific service:

```bash
docker logs mariadb
docker logs wordpress
docker logs nginx
```

Confirm the site is reachable and returns HTTP 200:

```bash
curl -Ik https://ikozhina.42.fr
```

Check NGINX configuration is valid:

```bash
docker exec nginx nginx -t
```

Check WordPress can connect to the database:

```bash
docker exec wordpress wp db check --allow-root
```
