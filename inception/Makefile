NAME=inception

all:
	@if ! grep -q ikozhina /etc/hosts; then \
		echo 127.0.0.1	ikozhina.42.fr | sudo tee -a /etc/hosts; \
	fi
	@if [ ! -d "/home/ikozhina/data/mariadb" ]; then \
		mkdir -p /home/ikozhina/data/mariadb; \
	fi
	@if [ ! -d "/home/ikozhina/data/wordpress" ]; then \
		mkdir -p /home/ikozhina/data/wordpress; \
	fi
	docker compose -f srcs/docker-compose.yml --env-file srcs/.env up --build

down:
	docker compose -f srcs/docker-compose.yml down --remove-orphans

fclean:
	docker compose -f srcs/docker-compose.yml --env-file srcs/.env down --rmi local --volumes --remove-orphans
	@if [ -d "/home/ikozhina/data" ]; then rm -rf /home/ikozhina/data; fi
	sudo sed -i '/ikozhina.42.fr/d' /etc/hosts

re: fclean all
