# Development SOP — Emergency Dental Pros

## Repos & what lives where

| Repo | Branch model | CSS/JS? | Deployed by |
|---|---|---|---|
| `emergencydentalpros-com/` (root) | `main` only | No | Local only — Docker, Makefile, .env |
| `emergencydentalpros-theme/` | `dev` → `main` | **Yes** — `src/css`, `src/js` → `assets/dist/` (gitignored, built by CI) | GitHub Actions on push to `main` |
| `emergencydentalpros/` (plugin) | `dev` → `main` → feature branches | **Yes** — `src/css`, `src/js` → `assets/` (committed to git) | GitHub Actions on push to `main` |

**Both repos have CSS.** Theme CSS controls page layout and components. Plugin CSS controls city/state pages, admin UI, and front-end widgets injected by the plugin.

---

## Why local vs remote can look different

| Cause | How to catch it | Fix |
|---|---|---|
| **Browser cache** | Remote shows old styles after deploy | `Cmd+Shift+R` on remote after every deploy |
| **Viewport width** | Bug only visible at wide/narrow widths | Test at 800 / 1200 / 1440px before pushing |
| **DB content differs** | Missing menu items, settings, copy | `make sync` at session start |
| **CI builds differ from local** | Container queries compiled differently | `make theme-push` bypasses CI entirely |

---

## Makefile reference

```
make sync          Pull DB + media from remote → local (start of session)
make db-pull       Pull DB only
make db-push       Push local DB → remote (after content/settings changes)
make media-pull    Pull uploads from remote → local
make media-push    Push local uploads → remote
make theme-push    Build theme + rsync to remote instantly (bypass CI)
make plugin-push   Rsync plugin to remote instantly (bypass CI)
make url-fix       Fix hardcoded URLs in local DB after a db-pull
make up            Start Docker
make down          Stop Docker
make logs          Tail WordPress logs
make plugins       Install standard WP plugins in local Docker
```

---

## Workflows

### Start of session

```
make up            # start Docker if not running
make sync          # pull latest DB + media from remote
```

---

### Theme CSS / JS change (`emergencydentalpros-theme/`)

CSS lives in `src/css/`, JS in `src/js/`. Built output goes to `assets/dist/` (gitignored — never commit it).

```
cd emergencydentalpros-theme/
npm run dev              # watch mode — rebuilds on every save

# edit src/css/**  or  src/js/main.js

# test locally at http://localhost:8080
# resize browser: 800px → 1200px → 1440px — check all breakpoints

make theme-push          # build + rsync to remote, instant

# verify on https://dev.widev.pro with Cmd+Shift+R

git add src/
git commit -m "..."
git push origin dev
git switch main && git merge dev --no-edit && git push origin main && git switch dev
# GitHub Actions redeploys automatically (backup — theme-push already synced it)
```

---

### Plugin CSS / JS change (`emergencydentalpros/`)

CSS lives in `src/css/main.css`, JS in `src/js/main.js`. Built output goes to `assets/` — **this IS committed to git** (unlike the theme).

```
cd emergencydentalpros/
npm run dev              # watch mode

# edit src/css/main.css  or  src/js/main.js

npm run build            # build before committing
# test locally

make plugin-push         # rsync to remote instantly

# verify on https://dev.widev.pro with Cmd+Shift+R

git add assets/ src/
git commit -m "..."
git push origin <branch>
# if on main or merging to main → GitHub Actions deploys
```

---

### Plugin PHP change (`emergencydentalpros/`)

No build step. Edit → test → deploy.

```
# edit any .php file in emergencydentalpros/

# test locally at http://localhost:8080

make plugin-push         # rsync to remote instantly

# verify on https://dev.widev.pro with Cmd+Shift+R

git add <files>
git commit -m "..."
git push origin <branch>
```

**Branch rules for plugin:**
- Bug fixes → `dev` → merge to `main` → push `main` (deploys)
- New features → `feature/name` → merge to `dev` → test → merge to `main`

---

### Template / PHP change in theme (`emergencydentalpros-theme/`)

No build step for PHP files. Same flow as plugin PHP but using theme-push.

```
# edit any .php file in emergencydentalpros-theme/

make theme-push          # rsync to remote (no build needed for PHP-only changes)

git add <files>
git commit + push dev + merge main + push main
```

---

### Content / admin work (menus, settings, posts, copies)

Edit in **local WP admin** only. Never edit the same thing on both local and remote between syncs.

```
# edit in http://localhost:8080/wp-admin

make db-push             # push local DB → remote (fixes URLs automatically)

# verify on https://dev.widev.pro
```

---

### End of session

```
git push all uncommitted changes in each repo
make db-push             # if any content changed
```

---

## Git branch model

```
Theme repo:
  dev (daily work) → main (deploys to dev.widev.pro via GitHub Actions)

Plugin repo:
  feature/name → dev → main (deploys to dev.widev.pro)
  Hotfixes: directly on dev → main

Root project:
  main only (local — no remote, no deploy)
```

---

## Quick reference: which repo for what

| Task | Repo | Has build step? |
|---|---|---|
| Page layout, colors, typography, components | `emergencydentalpros-theme/` | Yes (`npm run build`) |
| Homepage, inner page templates (.php files) | `emergencydentalpros-theme/` | No |
| City/state page rendering, FAQ, schema | `emergencydentalpros/` | No (PHP) |
| Plugin front-end styles (city pages, widgets) | `emergencydentalpros/` | Yes (`npm run build`) |
| Admin panel UI and styles | `emergencydentalpros/` | No (admin/css/*.css — static) |
| WP rewrite rules, routing logic | `emergencydentalpros/` | No |
| Docker, Makefile, .env | root `emergencydentalpros-com/` | No |
