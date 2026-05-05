# Daily-flow alignment — session progress

Status as of pause: **Phase 1 (theme git reconcile), step 1.1 — pending your output.**

---

## Toolchain check (done — May 4, 2026)

```
Docker 29.4.1 + Compose v5.1.3, daemon UP, 3 containers running   OK
Node 25.9.0 / npm 11.12.1                                          OK (newer than CI; harmless locally)
git 2.54.0                                                         OK
lazygit 0.61.1                                                     OK
SSH to dev.widev.pro — key-based, passwordless                     OK
gh CLI                                                             MISSING — task #9
```

## Stack drift discovered (vs. SOP claims)

| Component | Local Docker | Staging (dev.widev.pro) | SOP said |
|---|---|---|---|
| PHP | 8.2 (image) | **8.0.30** | 8.2 (wrong) |
| DB  | mysql:8.0 | **MariaDB 10.5.29** | MariaDB 10.5 |
| wp-cli | n/a (wpcli profile) | `/usr/local/bin/wp` | `/root/wp-cli.phar` (wrong) |

**Note:** PHP 8.0 is EOL since Nov 2023 — staging needs a PHP 8.2 upgrade (task #11), not local downgrade. Decision: pin local Docker to `wordpress:php8.0-apache` for now to match staging exactly, then upgrade both together.

## Repo state

```
emergencydentalpros-theme    on main, behind origin/main by 6, package-lock.json modified, NO local dev
emergencydentalpros          on dev, clean, in sync with origin/dev                          OK
```

## Hidden PHP error in wp-admin

User reported "got a PHP error in admin and simply hid it" — task #10. Right approach when we resume:
- Keep `WP_DEBUG_DISPLAY = false` (correct for production)
- Keep `@ini_set('display_errors', 0)` (also fine)
- Turn `WP_DEBUG_LOG = true` ON so errors go to `wp-content/debug.log` (visible only via SSH)
- Reproduce the admin screen, `tail -f wp-content/debug.log`, find file+line, fix in repo, push via normal flow
- Remove any `@`-prefix suppression we added to silence specific calls
- Don't edit code directly on the server

---

## Task list (open items)

```
#1  [DONE]      Verify Mac toolchain
#2  [ACTIVE]    Reconcile theme git state                    ← we are here
#3  [pending]   Fix compose + Makefile (php8.0, mariadb, make sync, secret hygiene)
#4  [pending]   Bring up Docker and sync data from staging       (blocked by #3)
#5  [pending]   Theme: end-to-end edit → commit → deploy loop   (blocked by #2, #4, #9)
#6  [pending]   Plugin: end-to-end edit → commit → deploy loop  (blocked by #4, #9)
#7  [pending]   Playwright: add local profile + run on both     (blocked by #4)
#8  [pending]   Verification: smoke-check both deploys          (blocked by #5, #6, #7)
#9  [pending]   Install + auth GitHub CLI (`gh`)
#10 [pending]   Investigate + fix hidden PHP error on staging
#11 [pending]   Plan staging PHP upgrade 8.0 → 8.2              (blocked by #8, #10)
```

---

## Exact commands to run when we resume — Phase 1 (theme git reconcile)

### Step 1.1 — inspect package-lock.json diff before discarding
```bash
cd ~/Documents/Projects/emergencydentalpros-theme
git diff --stat package-lock.json
git diff package-lock.json | head -40
git diff package-lock.json | grep -E '^\+\s+"version"|^-\s+"version"' | head -20
```
Paste output. If only metadata/integrity churn → discard. If real version bumps → discuss.

### Step 1.2 — fetch and inspect remote shape
```bash
git fetch origin --prune
git log HEAD..origin/main --oneline
git log origin/main..origin/dev --oneline
git log origin/dev..origin/main --oneline
```

### Step 1.3 — discard lockfile diff (default path)
```bash
git checkout -- package-lock.json
git status -sb
```

### Step 1.4 — fast-forward main
```bash
git pull --ff-only origin main
```

### Step 1.5 — create local dev branch tracking origin/dev
```bash
git switch dev
```

### Step 1.6 — verify clean state
```bash
git status -sb              # expect: ## dev...origin/dev
git branch -vv
git log --oneline --graph --all -10
```

---

## Then Phase 2 (task #9) — install gh

```bash
brew install gh
gh auth login              # HTTPS, web browser, webimdeveloper account
gh auth status
gh repo view webimdeveloper/emergencydentalpros-theme
```

## Then Phase 3 (task #3) — compose + Makefile fixes (planned, not run yet)

- `docker-compose.yml`: `wordpress:php8.0-apache`, `mariadb:10.5`
- `Makefile`: add `sync` target using `wp-cli` at `/usr/local/bin/wp` on staging
- Move staging DB password out of `DEV-SOP-LOCAL.md` into a gitignored `.env.sync` file
- `docker compose down -v && make up` to rebuild with new images

## Then Phase 4–8: bring up Docker + sync, theme loop, plugin loop, Playwright, verification.

---

*Resume from Phase 1 step 1.1.*
