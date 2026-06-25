NAME=inception

all:
	@if ! grep -q innakozhina /etc/hosts; then \
		echo 127.0.0.1	innakozhina.42.fr | sudo tee -a /etc/hosts; \
	fi
	@if [ ! -d "/home/innakozhina/data/mariadb" ]; then \
		mkdir -p /home/innakozhina/data/mariadb; \
	fi
	@if [ ! -d "/home/innakozhina/data/wordpress" ]; then \
		mkdir -p /home/innakozhina/data/wordpress; \
	fi
	docker compose -f srcs/docker-compose.yml --env-file srcs/.env up --build

down:
	docker compose -f srcs/docker-compose.yml down --remove-orphans

fclean:
	docker compose -f srcs/docker-compose.yml --env-file srcs/.env down --rmi local --volumes --remove-orphans
	@if [ -d "/home/innakozhina/data" ]; then sudo rm -rf /home/innakozhina/data; fi
	sudo sed -i '/innakozhina.42.fr/d' /etc/hosts

re: fclean all
