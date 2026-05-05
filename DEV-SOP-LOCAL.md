# Emergency Dental Pros — Local Development SOP

## Architecture

```
emergencydentalpros-com/          ← Docker project (its own git repo)
  docker-compose.yml              — orchestrates WordPress + MySQL + phpMyAdmin + WP-CLI
  Makefile                        — shortcuts
  db-import/                      — gitignored: SQL dumps for import
  uploads/                        — gitignored: synced from server
  emergencydentalpros-theme/      ← theme repo (GitHub)
  emergencydentalpros/            ← plugin repo (GitHub)
```

| URL | What |
|---|---|
| `http://localhost:8080` | Local WordPress |
| `http://localhost:8081` | phpMyAdmin |
| `https://dev.widev.pro` | Staging server (auto-deployed via GitHub Actions) |

**The two repos are identical to before.** Docker just gives you a local preview before pushing.

---

## Daily dev flow

### 1. Start local environment (once — stays running across reboots until you stop it)

```bash
cd ~/Documents/Projects/emergencydentalpros-com
make up
```

### 2. Work in the theme repo

```bash
cd ~/Documents/Projects/emergencydentalpros-com/emergencydentalpros-theme
git switch dev
```

Edit files. If you changed CSS:
```bash
npm run build
```

Changes are visible at `http://localhost:8080` **immediately** — no push needed.

### 3. Review and commit

```bash
git diff --stat                   # which files changed
git diff                          # full diff
git add src/css/components/hero.css assets/dist/main.css
git commit -m "style: fix hero padding"
```

### 4. Deploy to staging

```bash
git switch main && git merge dev --no-edit && git push && git switch dev
```

GitHub Actions builds and deploys to `dev.widev.pro` automatically. Monitor:

```bash
gh run list --limit 5
gh run view $(gh run list --limit 1 --json databaseId -q '.[0].databaseId')
```

### 5. Work in the plugin repo (same flow, no build step)

```bash
cd ~/Documents/Projects/emergencydentalpros-com/emergencydentalpros
git switch dev
# edit files
git add .
git commit -m "feat: add new template variable"
git switch main && git merge dev --no-edit && git push && git switch dev
```

Plugin deploys via its own GitHub Actions workflow (or rsync — check that repo's workflow).

---

## Keeping local data in sync with the server

Run this whenever you want fresh content from `dev.widev.pro`:

```bash
cd ~/Documents/Projects/emergencydentalpros-com

# 1. Export DB from server
ssh root@dev.widev.pro "mysqldump -u wpuser -p'!87412951Srg' wp_widev > /tmp/edp-dump.sql"

# 2. Download dump
scp root@dev.widev.pro:/tmp/edp-dump.sql db-import/dump.sql

# 3. Sync uploads
rsync -avz --progress root@dev.widev.pro:/var/www/dev.widev.pro/public_html/wp-content/uploads/ uploads/

# 4. Re-import DB (destroys local DB and reimports)
docker compose down -v          # removes db_data volume
docker compose up -d            # starts fresh, auto-imports dump.sql

# 5. Fix URLs
sleep 30 && make url-fix
```

Add this as a `make sync` target in Makefile for convenience:

```makefile
sync:
	ssh root@dev.widev.pro "mysqldump -u wpuser -p'!87412951Srg' wp_widev > /tmp/edp-dump.sql"
	scp root@dev.widev.pro:/tmp/edp-dump.sql db-import/dump.sql
	rsync -avz root@dev.widev.pro:/var/www/dev.widev.pro/public_html/wp-content/uploads/ uploads/
	docker compose down -v
	docker compose up -d
	sleep 30
	make url-fix
```

---

## Playwright

### Setup (one time, inside theme repo)

```bash
cd ~/Documents/Projects/emergencydentalpros-com/emergencydentalpros-theme
npm install -D @playwright/test
npx playwright install chromium
```

### Create `playwright.config.js` in theme repo root

```js
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testDir: './tests',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:8080',
  },
  projects: [
    { name: 'local', use: { baseURL: 'http://localhost:8080' } },
    { name: 'staging', use: { baseURL: 'https://dev.widev.pro' } },
  ],
});
```

### Run tests

```bash
# Against local Docker
npx playwright test

# Against staging server
npx playwright test --project=staging

# With UI
npx playwright test --ui
```

### Example test `tests/homepage.spec.js`

```js
import { test, expect } from '@playwright/test';

test('homepage loads with hero', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('.ws_hero')).toBeVisible();
});

test('nav opens on mobile', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 812 });
  await page.goto('/');
  await page.click('.ws_nav__burger');
  await expect(page.locator('.ws_header__panel')).toBeVisible();
});
```

---

## Quick reference

| Task | Command |
|---|---|
| Start local env | `cd emergencydentalpros-com && make up` |
| Stop local env | `make down` |
| Build CSS/JS | `cd emergencydentalpros-theme && npm run build` |
| Fix URLs after DB import | `make url-fix` |
| Sync DB + uploads from server | `make sync` |
| Deploy theme to staging | `git switch main && git merge dev --no-edit && git push && git switch dev` |
| Watch deploy | `gh run list --limit 5` |
| Run Playwright tests | `npx playwright test` |
| phpMyAdmin | `http://localhost:8081` |
| WP Admin local | `http://localhost:8080/wp-admin` |

---

## What changed vs. the old flow

| Before | Now |
|---|---|
| Edit → push → wait for deploy → check on server | Edit → check on `localhost:8080` instantly → push when happy |
| No local WordPress | Full local WordPress with real DB content |
| Test only on `dev.widev.pro` | Test locally first, then staging |
| No Playwright | Playwright runs against localhost or staging |

**Everything else is identical** — same repos, same branches, same GitHub Actions, same deployment target.

---

## How the setup works and portability to another Mac

### What Docker actually does here

Docker runs a self-contained WordPress environment on your Mac. Nothing is installed globally — PHP, MySQL, Apache all run inside containers. The two repos (`emergencydentalpros-theme` and `emergencydentalpros`) are **mounted** into the container as live folders, not copied. Saving a file in VS Code is immediately live at `localhost:8080`.

```
Your Mac filesystem                    Inside Docker container
──────────────────────────────────     ───────────────────────────────────────
emergencydentalpros-theme/         →   /var/www/html/wp-content/themes/edp-v2/
emergencydentalpros/               →   /var/www/html/wp-content/plugins/emergencydentalpros/
emergencydentalpros-com/uploads/   →   /var/www/html/wp-content/uploads/
```

WordPress core files, the database, and other plugins live inside Docker volumes (invisible to Finder). Only the two repos and uploads are on your actual filesystem.

### Setting up on another Mac — exact same steps

```
1. Install Docker Desktop
2. Install Node.js (brew install node)
3. Clone edp-local repo (or copy the emergencydentalpros-com/ folder)
4. Clone both repos inside it:
   cd emergencydentalpros-com
   git clone git@github.com:webimdeveloper/emergencydentalpros-theme.git
   git clone git@github.com:webimdeveloper/emergencydentalpros.git
5. cd emergencydentalpros-theme && npm install && npm run build
6. cd .. && make sync   (exports DB + uploads from server, starts Docker, fixes URLs)
```

That's it. The environment is identical on every Mac because Docker guarantees the same PHP version, MySQL version, and WordPress version everywhere.

### What lives where

| Location | What | Backed up by |
|---|---|---|
| `emergencydentalpros-com/` | Docker config | Its own git repo |
| `emergencydentalpros-theme/` | Theme code | GitHub |
| `emergencydentalpros/` | Plugin code | GitHub |
| `emergencydentalpros-com/uploads/` | Images | Synced from server (gitignored) |
| `emergencydentalpros-com/db-import/` | DB dumps | Synced from server (gitignored) |
| Docker volumes (`db_data`, `wp_core`) | MySQL data, WP core | Recreated from dump on `make sync` |

**Uploads and DB are not in git** — they come from the server via `make sync`. Git only tracks code.

---

## Moving the site to a live domain (dev.widev.pro → emergencydentalpros.com)

### Does dev.widev.pro use Docker?

**Docker is installed on the server but is not used.** WordPress runs on a traditional stack managed by **Virtualmin** (a server control panel):

| Component | What's running |
|---|---|
| Web server | Apache (httpd) |
| PHP | PHP-FPM 8.2 |
| Database | **MariaDB 10.5** |
| Control panel | Virtualmin |
| WP-CLI | `/root/wp-cli.phar` |

Docker was installed but never used for WordPress. The professional recommendation is to **keep it that way** — Virtualmin manages vhosts, SSL, and DNS cleanly. Dockerizing the server adds complexity (SSL termination, volume management) without meaningful benefit for a WordPress site.

> **Important:** Your local Docker was set to `mysql:8.0` which differs from the server's `MariaDB 10.5`. Update `docker-compose.yml` to use `mariadb:10.5` to match exactly and avoid subtle SQL compatibility issues.

In `emergencydentalpros-com/docker-compose.yml`, change:
```yaml
image: mysql:8.0
```
to:
```yaml
image: mariadb:10.5
```

### What the live server needs

- Apache or Nginx
- PHP 8.2+
- MariaDB 10.5+ (or MySQL 8.0+ — compatible)
- Virtualmin (optional but recommended — manages vhosts + SSL automatically)
- WordPress installed

### Migration process

**Step 1 — Export everything from dev.widev.pro**

```bash
# On server (SSH terminal in VS Code):
mysqldump -u wpuser -p'!87412951Srg' wp_widev > /tmp/edp-live-dump.sql

# On local Mac:
scp root@dev.widev.pro:/tmp/edp-live-dump.sql ~/Desktop/edp-live-dump.sql
rsync -avz root@dev.widev.pro:/var/www/dev.widev.pro/public_html/wp-content/uploads/ ~/Desktop/edp-uploads/
```

**Step 2 — Install WordPress on the new server**

Install a fresh WordPress at the new server's document root (via Softaculous, WP-CLI, or manually). Note the new DB credentials.

**Step 3 — Import DB and uploads**

```bash
# Upload dump to new server and import:
scp ~/Desktop/edp-live-dump.sql root@NEW_SERVER:/tmp/
ssh root@NEW_SERVER "mysql -u NEW_DB_USER -pNEW_DB_PASS NEW_DB_NAME < /tmp/edp-live-dump.sql"

# Upload uploads:
rsync -avz ~/Desktop/edp-uploads/ root@NEW_SERVER:/var/www/emergencydentalpros.com/public_html/wp-content/uploads/
```

**Step 4 — Deploy theme and plugin to new server**

```bash
# Theme:
rsync -avz --delete ~/Documents/Projects/emergencydentalpros-com/emergencydentalpros-theme/ \
  root@NEW_SERVER:/var/www/emergencydentalpros.com/public_html/wp-content/themes/edp-v2/ \
  --exclude='.git' --exclude='node_modules' --exclude='src' --exclude='.DS_Store'

# Plugin:
rsync -avz --delete ~/Documents/Projects/emergencydentalpros-com/emergencydentalpros/ \
  root@NEW_SERVER:/var/www/emergencydentalpros.com/public_html/wp-content/plugins/emergencydentalpros/ \
  --exclude='.git' --exclude='.DS_Store'
```

**Step 5 — Fix URLs in the new server's DB**

```bash
ssh root@NEW_SERVER "wp --path=/var/www/emergencydentalpros.com/public_html \
  search-replace 'https://dev.widev.pro' 'https://emergencydentalpros.com' --allow-root"
ssh root@NEW_SERVER "wp --path=/var/www/emergencydentalpros.com/public_html \
  search-replace 'http://widev.pro' 'https://emergencydentalpros.com' --allow-root"
```

**Step 6 — Update GitHub Actions to also deploy to live**

Add a second deploy job in `.github/workflows/deploy-theme.yml` that triggers on push to `main` and rsyncs to the live server. Update `SSH_HOST` secret in GitHub → Settings → Secrets.

**Step 7 — Point DNS**

Update the domain's A record to the new server IP. SSL certificate via Let's Encrypt (`certbot --apache`).

### Summary: professional flow

```
Your Mac (Docker)           →  localhost:8080             local dev
     ↓ git push to main
GitHub Actions (rsync)      →  dev.widev.pro              staging  (Apache + MariaDB, Virtualmin)
     ↓ DB export + rsync
New server (same stack)     →  emergencydentalpros.com    production (Apache + MariaDB, Virtualmin)
```

**Docker is local-only.** Both servers run traditional stacks managed by Virtualmin. This is the standard professional setup for WordPress — simple, proven, and Virtualmin handles SSL renewals, vhost config, and backups automatically.

### Why not Docker on the server?

| | Docker on server | Traditional (Virtualmin) |
|---|---|---|
| SSL management | Manual (Traefik/Caddy) | Automatic (Let's Encrypt via Virtualmin) |
| Multiple sites | Complex routing | Built-in vhosts |
| DB backups | Manual volume management | Virtualmin scheduled backups |
| Deployment | `docker pull` + restart | rsync via GitHub Actions |
| Complexity | High | Low |

The only real benefit of Docker on the server is portability between servers — but with Virtualmin you can export/import a full virtual server (DB + files + config) in one click anyway.
