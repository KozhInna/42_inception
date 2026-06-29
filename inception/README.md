*This project has been created as part of the 42 curriculum by ikozhina.*

# Inception

## Documentation

- [USER_DOC.md](USER_DOC.md) — starting/stopping the stack, accessing the site and admin panel, managing credentials, checking service health
- [DEV_DOC.md](DEV_DOC.md) — environment setup, building with Make/Compose, container and volume management, where data is stored

## Description

This project involves the setup of a small-scale infrastructure composed of multiple services configured according to a defined set of rules. The 
infrastructure is implemented within a virtual machine environment, 
with Docker Compose used to orchestrate and manage the services.

**Services:**
- **nginx** — TLS entrypoint, the only service reachable from outside
- **wordpress** — WordPress core + php-fpm, generates the site
- **mariadb** — database storing all WordPress content

## Instructions

**Prerequisites:** a Linux virtual machine with Docker and Docker Compose
installed.

```bash
git clone https://github.com/KozhInna/42_inception.git
cd 42_inception
```

Recreate the files that are intentionally excluded from the repository
(see `.gitignore`):

```
secrets/credentials.txt
secrets/db_password.txt
secrets/db_root_password.txt
srcs/.env
```

Then build and start everything:

```bash
make
```

This adds `ikozhina.42.fr` to `/etc/hosts`, creates the data directories, and builds/starts all three containers. 
Visit `https://ikozhina.42.fr` (self-signed certificate, browser warning is expected).

Other commands:

```bash
make down     # stop containers
make fclean   # stop, remove containers/images/volumes, clean /etc/hosts
make re       # fclean + all
```

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [WP-CLI documentation](https://wp-cli.org/)
- [MariaDB documentation](https://mariadb.com/kb/en/documentation/)
- [NGINX documentation](https://nginx.org/en/docs/)
- [Let's Encrypt — how TLS/certificates work](https://letsencrypt.org/docs/)
- [github.com/RychkovIurii/inception](https://github.com/RychkovIurii/inception)
- [github.com/TanjaMenkovic/inception](https://github.com/TanjaMenkovic/inception)

**AI usage:** An AI assistant (Claude) was used throughout this project as a
learning and debugging aid.

## Project structure

```
inception/
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/
│   ├── credentials.txt
│   ├── db_password.txt
│   └── db_root_password.txt
└── srcs/
    ├── .env
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/my.cnf
        │   └── tools/init.sh
        ├── wordpress/
        │   ├── Dockerfile
        │   ├── .dockerignore
        │   ├── conf/www.conf
        │   └── tools/init.sh
        └── nginx/
            ├── Dockerfile
            ├── .dockerignore
            ├── conf/default.conf
            └── tools/init.sh
```

## Project description

The project uses three Dockerfiles, one per service, each starting from
`alpine:3.22`. Configuration is injected through a `.env` file and Docker 
secrets; each container's `init.sh` performs first-run setup (creating 
the database/users, installing WordPress, generating a self-signed TLS 
certificate) and then `exec`s the real service so it runs as PID 1, with 
no shell-wrapper or infinite-loop hack keeping the container alive.

### Virtual Machines vs Docker

A virtual machine behaves like a separate computer. It has its own operating system, kernel, and init system. In this project, a complete Debian system is installed inside the virtual machine.

Docker containers are different because they do not have their own kernel. All containers share the kernel of the host operating system. In this project, the containers share the Linux kernel of the Debian virtual machine.

Containers usually contain only the files and libraries required to run a specific service. For example, a container can use a minimal image such as Alpine Linux. The application running inside the container is often the main process and runs as PID 1, whereas in a virtual machine the init system is PID 1 and manages all other processes.

As a result, virtual machines provide complete operating system isolation, while containers provide lightweight process isolation and share the host kernel.

### Secrets vs Environment Variables

Passwords can be stored in a `.env` file, which keeps them out of the Docker image during the build process. However, they are still accessible when the container is running. Commands such as `docker inspect` or `docker exec env` can reveal environment variables, and if the `.env` file is accidentally committed to Git, the passwords remain visible in the repository history.

Docker secrets provide a safer way to store sensitive information. Each secret is stored in a separate file inside the `secrets/` directory, and `docker-compose.yml` defines which containers can access each secret. This means that only the containers that need a specific password are able to read it.

When a container starts, Docker mounts the secret as a file in `/run/secrets/<name>`. The container's `init.sh` script reads the value directly from this file. Because of this, secrets are not exposed through environment variables, `docker inspect`, or the `.env` file.

In this project, the `.env` file is used only for non-sensitive settings such as the domain name, usernames, and database name. All passwords and other sensitive data are stored using Docker secrets.

### Docker Network vs Host Network

Docker provides different networking modes for containers. One option is the host network, where a container directly uses the network interface of the host machine. In this case, the container does not have its own network isolation and behaves like a normal process running on the VM.

For example, if the MariaDB container used host networking, it would bind directly to port 3306 on the VM, just as if MariaDB had been installed directly on the operating system instead of inside Docker.

Using the host network has several disadvantages. There is no network isolation between the containers and the host system, which reduces the benefits of containerization. Port conflicts can also occur because only one process can use a specific port on the host at a time. In addition, every service could become directly accessible through the VM network, increasing the attack surface.

This project uses a custom bridge network:

```yaml
networks:
  inception:
    driver: bridge
```

A bridge network creates a private virtual network that is shared only by the containers connected to it. Each container receives its own internal IP address and can communicate with other containers on the same network while remaining isolated from the VM's external network.

Docker also provides an internal DNS service on the bridge network. Containers can communicate using their service names instead of IP addresses. For example, WordPress can connect to MariaDB using `WORDPRESS_DB_HOST=mariadb`, and NGINX can communicate with WordPress using `wordpress:9000`.

Only NGINX exposes a port to the outside:

```yaml
ports:
  - "443:443"
```

This creates a controlled entry point between the VM network and the internal container network. MariaDB and WordPress do not publish any ports, so they cannot be reached directly from outside the Docker network.

As a result, the bridge network provides isolation, internal communication between containers, and controlled access from outside the system. This matches the project requirement that NGINX must be the only entry point and that communication should occur only through port 443.

### Docker Volumes vs Bind Mounts

Both Docker volumes and bind mounts solve the same core problem: containers are temporary. When a container is removed, everything written to its internal filesystem is lost. This would be a serious issue for services like MariaDB (database files) and WordPress (uploads, themes, plugins), since all data would disappear whenever the stack is restarted or rebuilt.

To prevent this, data is stored outside the container on the VM's disk, so it persists even if containers are recreated.

**Option 1 — Bind mounts**

Bind mounts map a specific path on the host machine directly into the container:

```yaml
volumes:
  - /home/ikozhina/data/mariadb:/var/lib/mysql
```

In this case, Docker does not manage the host path at all. The directory `/home/ikozhina/data/mariadb` must already exist, and the user is fully responsible for its creation, structure, and maintenance. Docker simply uses it as-is and mounts it inside the container.

**Option 2 — Named volumes (used in this project)**

Named volumes are defined and managed by Docker:

```yaml
volumes:
  mariadb_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /home/ikozhina/data/mariadb
```

Here, Docker creates a volume with a name (`mariadb_data`) and manages it as a resource. It can be inspected, listed, and removed using Docker commands such as `docker volume ls` and `docker volume inspect`.

Even though this is a named volume, it is configured to use a bind-style setup under the hood, pointing to the specific host path `/home/ikozhina/data/mariadb`.

**Why this approach matters**

This setup is a hybrid solution. It combines both approaches:

- From Docker's perspective, it is a named volume, meaning it is manageable and visible as a Docker resource.
- From the system's perspective, it still uses a specific host directory, satisfying the requirement that all persistent data must be stored in `/home/<login>/data`.

A pure bind mount would also work and satisfy the path requirement, but it would not provide the same level of Docker-managed visibility and lifecycle control. This hybrid approach gives both: explicit host storage location and Docker-managed volume behavior.
