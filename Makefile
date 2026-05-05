-include .env.sync

up:
	docker compose up -d

down:
	docker compose down

url-fix:
	docker compose --profile tools run --rm wpcli wp search-replace 'https://dev.widev.pro' 'http://localhost:8080' --allow-root
	docker compose --profile tools run --rm wpcli wp search-replace 'http://widev.pro' 'http://localhost:8080' --allow-root
	docker compose --profile tools run --rm wpcli wp search-replace 'https://widev.pro' 'http://localhost:8080' --allow-root

plugins:
	docker compose --profile tools run --rm wpcli wp plugin install classic-editor tablepress wordpress-importer query-monitor --activate --allow-root

sync:
	ssh root@dev.widev.pro "mysqldump -u wpuser -p'$(DB_SYNC_PASS)' wp_widev > /tmp/edp-dump.sql"
	scp root@dev.widev.pro:/tmp/edp-dump.sql db-import/dump.sql
	rsync -avz root@dev.widev.pro:/var/www/dev.widev.pro/public_html/wp-content/uploads/ uploads/
	docker compose down -v
	docker compose up -d
	sleep 30
	docker compose exec wordpress mkdir -p /var/www/html/wp-content/upgrade && docker compose exec wordpress chmod 777 /var/www/html/wp-content/upgrade /var/www/html/wp-content/plugins
	make url-fix
	make plugins

logs:
	docker compose logs -f wordpress
