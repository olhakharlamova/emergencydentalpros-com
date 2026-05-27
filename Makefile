-include .env
-include .env.sync

## ── Remote (staging) ─────────────────────────────────────────────────────────
REMOTE_SSH      := widev
REMOTE_WP       := /var/www/dev.widev.pro/public_html
REMOTE_DB_USER  := wpuser
REMOTE_DB_NAME  := wp_widev
REMOTE_URL      := https://dev.widev.pro
LOCAL_URL       := http://localhost:8080
REMOTE_THEME    := $(REMOTE_WP)/wp-content/themes/edp-v2/
REMOTE_PLUGIN   := $(REMOTE_WP)/wp-content/plugins/emergencydentalpros/
THEME_DIR       := ./emergencydentalpros-theme
PLUGIN_DIR      := ./emergencydentalpros

## ── Live (wpx.net) ───────────────────────────────────────────────────────────
LIVE_URL        := https://emergencydentalpros.com

## ── Local shortcuts ──────────────────────────────────────────────────────────
WP   := docker compose --profile tools run --rm wpcli wp --allow-root
DB   := docker compose exec -T db mariadb -u$(DB_USER) -p$(DB_PASS) $(DB_NAME)
DUMP := docker compose exec -T db mariadb-dump -u$(DB_USER) -p$(DB_PASS) $(DB_NAME)

.PHONY: up down logs url-fix plugins db-pull db-push media-pull media-push theme-push plugin-push webroot-push sync db-export-live

## ── Docker ───────────────────────────────────────────────────────────────────

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f wordpress

## ── WordPress ────────────────────────────────────────────────────────────────

url-fix:
	$(WP) search-replace '$(REMOTE_URL)' '$(LOCAL_URL)' --all-tables --skip-columns=guid
	$(WP) search-replace 'http://widev.pro'  '$(LOCAL_URL)' --all-tables --skip-columns=guid
	$(WP) search-replace 'https://widev.pro' '$(LOCAL_URL)' --all-tables --skip-columns=guid
	$(WP) rewrite flush

plugins:
	$(WP) plugin install classic-editor tablepress wordpress-importer query-monitor --activate

## ── DB sync ──────────────────────────────────────────────────────────────────

# Pull remote DB → import locally → fix URLs
db-pull:
	@echo "→ Exporting remote DB..."
	ssh $(REMOTE_SSH) "mysqldump -u $(REMOTE_DB_USER) -p'$(DB_SYNC_PASS)' $(REMOTE_DB_NAME) > /tmp/edp-sync.sql"
	@mkdir -p db-import
	scp $(REMOTE_SSH):/tmp/edp-sync.sql db-import/pull.sql
	ssh $(REMOTE_SSH) "rm /tmp/edp-sync.sql"
	@echo "→ Importing locally..."
	$(DB) < db-import/pull.sql
	@echo "→ Fixing URLs..."
	$(MAKE) url-fix
	@echo "✓ Remote DB is now local"

# Push local DB → remote → fix URLs
db-push:
	@echo "→ Exporting local DB..."
	@mkdir -p db-import
	$(DUMP) > db-import/push.sql
	@echo "→ Uploading to remote..."
	scp db-import/push.sql $(REMOTE_SSH):/tmp/edp-push.sql
	@echo "→ Importing on remote..."
	ssh $(REMOTE_SSH) "mysql -u $(REMOTE_DB_USER) -p'$(DB_SYNC_PASS)' $(REMOTE_DB_NAME) < /tmp/edp-push.sql && rm /tmp/edp-push.sql"
	@echo "→ Fixing URLs on remote..."
	ssh $(REMOTE_SSH) "wp --path=$(REMOTE_WP) --allow-root \
	  search-replace '$(LOCAL_URL)' '$(REMOTE_URL)' --all-tables --skip-columns=guid && \
	  wp --path=$(REMOTE_WP) --allow-root rewrite flush"
	@echo "✓ Local DB is now on remote"

## ── Theme / Plugin deploy (bypass CI — instant) ──────────────────────────────

# Build theme and rsync directly to remote (no GitHub Actions wait)
theme-push:
	@echo "→ Building theme..."
	cd $(THEME_DIR) && npm run build
	@echo "→ Deploying theme to remote..."
	rsync -avz --delete \
	  --exclude ".git/" \
	  --exclude ".github/" \
	  --exclude "node_modules/" \
	  --exclude "src/" \
	  --exclude "*.md" \
	  --exclude ".gitignore" \
	  --exclude ".prettierrc" \
	  $(THEME_DIR)/ $(REMOTE_SSH):$(REMOTE_THEME)
	@echo "✓ Theme deployed"

# Rsync plugin directly to remote (no GitHub Actions wait)
plugin-push:
	@echo "→ Deploying plugin to remote..."
	rsync -avz --delete \
	  --exclude ".git/" \
	  --exclude ".github/" \
	  --exclude "node_modules/" \
	  --exclude "src/" \
	  --exclude "*.md" \
	  --exclude "tests/" \
	  --exclude "test-results/" \
	  --exclude "playwright.config.ts" \
	  $(PLUGIN_DIR)/ $(REMOTE_SSH):$(REMOTE_PLUGIN)
	@echo "✓ Plugin deployed"

## ── Webroot extras (verification files, etc.) ────────────────────────────────

# Deploy files that live directly in the WordPress root (not inside wp-content).
webroot-push:
	@echo "→ Deploying webroot extras to remote..."
	rsync -avz $(PWD)/webroot/ $(REMOTE_SSH):$(REMOTE_WP)/
	@echo "✓ Webroot extras deployed"

## ── Media sync ───────────────────────────────────────────────────────────────

# Pull uploads from remote → local
media-pull:
	rsync -avz --progress $(REMOTE_SSH):/var/www/dev.widev.pro/public_html/wp-content/uploads/ uploads/

# Push local uploads → remote
media-push:
	rsync -avz --progress uploads/ $(REMOTE_SSH):/var/www/dev.widev.pro/public_html/wp-content/uploads/

## ── Live DB export (staging → live-ready SQL dump) ──────────────────────────

# Export staging DB with URLs already replaced → db-import/live-ready.sql
# Then import that file manually via PhpMyAdmin on wpx.net.
db-export-live:
	@echo "→ Exporting staging DB with URLs replaced..."
	ssh $(REMOTE_SSH) "mysqldump -u $(REMOTE_DB_USER) -p'$(DB_SYNC_PASS)' $(REMOTE_DB_NAME) > /tmp/edp-live-export.sql && \
	  wp --path=$(REMOTE_WP) --allow-root \
	    search-replace '$(REMOTE_URL)' '$(LIVE_URL)' --all-tables --skip-columns=guid --export=/tmp/edp-live-ready.sql"
	@mkdir -p db-import
	scp $(REMOTE_SSH):/tmp/edp-live-ready.sql db-import/live-ready.sql
	ssh $(REMOTE_SSH) "rm -f /tmp/edp-live-export.sql /tmp/edp-live-ready.sql"
	@echo "✓ db-import/live-ready.sql ready — import via PhpMyAdmin on wpx.net"

## ── Composite ────────────────────────────────────────────────────────────────

# Full pull: DB + media (use at start of session)
sync: db-pull media-pull
