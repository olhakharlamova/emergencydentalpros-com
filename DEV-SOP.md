# Emergency Dental Pros — Developer SOP

## 1. Repository Overview

There are **two separate Git repos**. Both must be deployed to the same WordPress install on `widev`.

| Repo | Local path | Server path | Build step |
|---|---|---|---|
| **Plugin** | `~/Documents/Projects/emergencydentalpros/` | `/var/www/webim.space/public_html/wp-content/plugins/emergencydentalpros/` | None (PHP only) |
| **Theme** | `~/Documents/Projects/emergencydentalpros-theme/` | `/var/www/webim.space/public_html/wp-content/themes/emergencydentalpros-theme/` | `npm run build` (CSS/JS) |

---

## 2. Architecture — How the Plugin and Theme Connect

### Dynamic location pages (plugin-driven)

When a visitor hits a URL like `/locations/alabama/birmingham/`, WordPress never loads a real post. The plugin intercepts the request:

```
Browser → /locations/alabama/birmingham/
          ↓
EDP_Rewrite — registers virtual rewrite rules, sets query var edp_seo_view=city
          ↓
EDP_ViewController::render() — reads the query var, decides which view to render
          ↓
EDP_ViewController::build_view_data() — queries the DB, merges settings,
  runs template variable replacement via EDP_Template_Engine::replace()
  produces $edp_data array: h1, subtitle, body, zips, faq, other_cities,
  nearby_businesses, communities_h2, communities_body, etc.
          ↓
calls get_header()                    → theme/header.php
includes theme view file              → theme/emergencydentalpros/views/city.php
calls get_footer()                    → theme/footer.php
```

**Theme override pattern.** `EDP_ViewController::resolve_template()` checks whether a view file exists in the theme first, and falls back to the plugin's own copy only if it doesn't:

```
Priority 1: theme/emergencydentalpros/views/{view}.php   ← EDIT THIS
Priority 2: plugin/templates/views/{view}.php             ← fallback, do not edit
```

This is why the HTML files live in the **theme repo** — you can update markup without touching the plugin.

### Static city pages (WordPress posts)

In WP admin you can create a standard Page, assign the template **"City Landing Page"**, and write the content in the WordPress editor. That page uses a **completely different template file**:

```
theme/page-city-lp.php
```

This file has hardcoded demo variables (`$city_name = 'Birmingham'`, etc.) at the top. It uses `the_content()` for body copy and shares all the same CSS classes as the dynamic view, so visually they look identical.

Static pages are **not** driven by the plugin's DB or template engine. They are plain WordPress pages.

---

## 3. Complete File Map

### Template files — HTML structure

| URL pattern | Template file | Type |
|---|---|---|
| `/locations/` | `theme/emergencydentalpros/views/state-list.php` | Dynamic (plugin) |
| `/locations/{state}/` | `theme/emergencydentalpros/views/state.php` | Dynamic (plugin) |
| `/locations/{state}/{city}/` | `theme/emergencydentalpros/views/city.php` | Dynamic (plugin) |
| Any WP page with "City Landing Page" template | `theme/page-city-lp.php` | Static (WP post) |
| All pages — top bar | `theme/header.php` | Shared |
| All pages — footer | `theme/footer.php` | Shared |
| Hero section (inner pages) | `theme/template-parts/hero-inner.php` | Shared partial |

### CSS files — visual styles (theme/src/css/)

| Section on page | Source file |
|---|---|
| Header | `layout/header.css` |
| Hero | `components/hero-inner.css` |
| Page content block | `components/prose.css` |
| CTA mid-page section | `components/cta-bar.css` |
| ZIP / communities section | `components/city-lp.css` |
| **Business listing cards** | `components/businesses.css` |
| Nearby cities | `components/city-lp.css` |
| FAQ accordion | `components/city-lp.css` |
| State / states-index pages | `components/locations.css` |
| Shared utilities | `utilities/helpers.css`, `utilities/scroll-animations.css` |
| Design tokens (colors, spacing, type) | `base/variables.css` |

All source CSS is compiled into `assets/dist/main.css` via `npm run build`.

### Plugin files — data and logic

| File | Responsibility |
|---|---|
| `includes/class-edp-rewrite.php` | Registers `/locations/*` URL rules |
| `includes/class-edp-view-controller.php` | Picks view, builds `$edp_data`, renders page |
| `includes/class-edp-database.php` | All DB queries (cities, states, businesses) |
| `includes/class-edp-template-engine.php` | `{variable}` replacement in text templates |
| `includes/class-edp-settings.php` | Reads/writes `edp_seo_settings` WP option |
| `admin/views/settings-templates.php` | Admin panel HTML (SEO templates tab) |
| `admin/css/edp-admin.css` | Admin panel styles |

---

## 4. Template Variables — How They Flow

The admin panel at `/wp-admin/admin.php?page=edp-seo` stores all configurable text. When a dynamic page renders, the controller calls `EDP_Template_Engine::replace()` which swaps `{variable}` tokens with real values.

### Available tokens by page type

| Token | states-index | state page | city page |
|---|:---:|:---:|:---:|
| `{site_name}` | ✓ | ✓ | ✓ |
| `{phone_number}` | ✓ | ✓ | ✓ |
| `{ws_featured_img}` | ✓ | ✓ | ✓ |
| `{opening_hours}` | ✓ | ✓ | ✓ |
| `{state_name}` | — | ✓ | ✓ |
| `{state_short}` | — | ✓ | ✓ |
| `{state_slug}` | — | ✓ | ✓ |
| `{city_name}` | — | — | ✓ |
| `{county_name}` | — | — | ✓ |
| `{main_zip}` | — | — | ✓ |
| `{list_of_related_zips}` | — | — | ✓ |

Tokens are replaced in: meta title, meta description, H1, subtitle, body, communities H2, communities body, FAQ H2, FAQ intro, FAQ items.

**Static pages do not use token replacement.** Text is whatever you type in the WP editor.

---

## 5. Task Scenarios

---

### Scenario A — Adjust CSS on the city page (e.g. business card layout)

**Repo:** Theme only  
**Build required:** Yes

```bash
cd ~/Documents/Projects/emergencydentalpros-theme

# 1. Create dev branch if it doesn't exist yet
git switch -c dev        # first time only
git switch dev           # subsequent times

# 2. Edit the relevant CSS file
# Business cards  → src/css/components/businesses.css
# Communities/ZIP → src/css/components/city-lp.css
# Hero            → src/css/components/hero-inner.css
# Tokens          → src/css/base/variables.css
code src/css/components/businesses.css

# 3. Build
npm run build

# 4. Review changes before committing
git diff --stat                         # which files changed
git diff src/css/                       # your source edits
git diff assets/dist/main.css           # compiled output (confirm it updated)

# 5. Stage and commit
git add src/css/components/businesses.css assets/dist/main.css
git commit -m "style: improve business card layout spacing"

# 6. Merge to main
git switch main
git merge dev
git push origin main

# 7. Deploy theme
rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/themes/emergencydentalpros-theme/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

---

### Scenario B — Edit HTML on the dynamic city page

Affects every URL `/locations/{state}/{city}/` — thousands of pages at once.

**Repo:** Theme only  
**Build required:** Only if you also change CSS

```bash
cd ~/Documents/Projects/emergencydentalpros-theme
git switch dev

# Edit the dynamic view
code emergencydentalpros/views/city.php

# No build needed — PHP deploys as-is
git diff emergencydentalpros/views/city.php   # review

git add emergencydentalpros/views/city.php
git commit -m "feat: add badge to business listing header"

git switch main && git merge dev && git push origin main

rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/themes/emergencydentalpros-theme/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

**Important:** changes here affect ALL dynamic city pages simultaneously. If you need to test safely, deploy to a staging URL first or edit a single static page instead to validate the markup.

---

### Scenario C — Edit HTML on the state page or states index

Same flow as Scenario B — only the file changes.

| Page | File to edit |
|---|---|
| `/locations/` (states list) | `emergencydentalpros/views/state-list.php` |
| `/locations/alabama/` (single state) | `emergencydentalpros/views/state.php` |

```bash
cd ~/Documents/Projects/emergencydentalpros-theme
git switch dev
code emergencydentalpros/views/state.php     # or state-list.php

git add emergencydentalpros/views/state.php
git commit -m "feat: add city count to state page header"
git switch main && git merge dev && git push origin main
# rsync (same command as above)
```

---

### Scenario D — Edit a static city page (created via WP admin)

Static pages are regular WordPress pages with the **"City Landing Page"** page template applied. They use `page-city-lp.php` and `the_content()` for body copy.

**Two parts to edit:**

**Part 1 — Page content:** go to WP Admin → Pages → find the page → edit with the WordPress editor. No code change needed.

**Part 2 — Surrounding HTML structure** (hero, ZIP section, nearby cities, etc.):

```bash
cd ~/Documents/Projects/emergencydentalpros-theme
git switch dev
code page-city-lp.php
```

At the top of `page-city-lp.php` you'll see hardcoded variables:
```php
$city_name  = 'Birmingham';
$state_name = 'Alabama';
$state_abbr = 'AL';
$zip_codes  = ['35211', '35215', ...];
$other_cities = [['name' => 'Montgomery', 'slug' => 'montgomery'], ...];
```

These must be updated manually for each static page if you need different values — or connected to ACF custom fields later.

```bash
git add page-city-lp.php
git commit -m "feat: add FAQ section to static city template"
git switch main && git merge dev && git push origin main
# rsync
```

**When to use static vs dynamic:**
- **Dynamic** (`city.php`): the standard production path — all DB-driven pages, scales to thousands of cities automatically.
- **Static** (`page-city-lp.php` + WP page): use when a specific city needs unique content that can't come from the DB — custom written copy, unique images, special layout. A static page mapped to a DB city row will redirect to the canonical `/locations/` URL, so typically static pages are standalone with their own slugs.

---

### Scenario E — Change configurable text / SEO templates (no code)

Go to `/wp-admin/admin.php?page=edp-seo`.

- **Meta title / description / H1 / subtitle / body / FAQ items** — edit in the template tabs, use `{variable}` tokens.
- **Global variables** (phone number, featured image, opening hours, rating) — edit in the right-hand Global Variables panel.
- Click **Save**.

No code changes, no deploy needed.

---

### Scenario F — Add a new template variable (e.g. `{business_tagline}`)

Requires plugin changes first, then optionally theme changes.

**Step 1 — Plugin repo: add to settings defaults**

```bash
cd ~/Documents/Projects/emergencydentalpros
git switch dev    # or git switch -c dev

code includes/class-edp-settings.php
# In defaults() → add: 'business_tagline' => '' under global_settings
# In sanitize() → add sanitize_text_field() for the new field
```

**Step 2 — Plugin repo: expose as a token**

```bash
code includes/class-edp-template-engine.php
# In base_vars() → add:
# 'business_tagline' => esc_html($gs['business_tagline'] ?? ''),
```

**Step 3 — Plugin repo: add admin form field**

```bash
code admin/views/settings-templates.php
# Add an <input> with name="edp_seo[global_settings][business_tagline]"
```

**Step 4 — Deploy plugin**

```bash
git add includes/class-edp-settings.php \
        includes/class-edp-template-engine.php \
        admin/views/settings-templates.php
git commit -m "feat: add {business_tagline} template variable"
git switch main && git merge dev && git push origin main

rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/plugins/emergencydentalpros/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

**Step 5 — Optionally use it in the theme view**

```bash
cd ~/Documents/Projects/emergencydentalpros-theme
git switch dev
code emergencydentalpros/views/city.php
# $edp_data will now contain the rendered value if you add it to build_view_data()
# OR use it only in admin template fields with {business_tagline}

git add emergencydentalpros/views/city.php
git commit -m "feat: render business_tagline in city hero"
git switch main && git merge dev && git push origin main
# rsync theme
```

---

### Scenario G — Change admin panel UI (layout, new fields, styles)

**Repo:** Plugin only  
**Build required:** None

```bash
cd ~/Documents/Projects/emergencydentalpros
git switch dev

# HTML of admin panel
code admin/views/settings-templates.php

# Styles of admin panel  
code admin/css/edp-admin.css

git diff --stat
git add admin/views/settings-templates.php admin/css/edp-admin.css
git commit -m "style: improve global aside layout in SEO admin"
git switch main && git merge dev && git push origin main

rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/plugins/emergencydentalpros/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

---

### Scenario H — Both repos change in the same feature

Example: add a "badge" field to global settings (plugin) and render it in the city card (theme).

**Always do plugin first** — the theme depends on data the plugin provides.

```bash
# ── Plugin ──────────────────────────────────────────────────
cd ~/Documents/Projects/emergencydentalpros
git switch dev
# edit settings, template engine, admin view
git add ...
git commit -m "feat: add badge field to global settings"
git switch main && git merge dev && git push origin main
rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/plugins/emergencydentalpros/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'

# ── Theme ────────────────────────────────────────────────────
cd ~/Documents/Projects/emergencydentalpros-theme
git switch dev
# edit city.php and/or businesses.css
npm run build   # only if CSS changed
git add ...
git commit -m "feat: render badge in city business card"
git switch main && git merge dev && git push origin main
rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/themes/emergencydentalpros-theme/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

---

## 6. Git Branch Flow — Reference

### First-time setup (both repos)

```bash
# Create dev branch in theme repo
cd ~/Documents/Projects/emergencydentalpros-theme
git switch -c dev
git push -u origin dev

# Create dev branch in plugin repo
cd ~/Documents/Projects/emergencydentalpros
git switch -c dev
git push -u origin dev
```

### Normal working cycle

```bash
git switch dev              # start working on dev

# ... make changes ...

git diff --stat             # summary: which files
git diff                    # full diff: every changed line
git add <files>             # stage specific files (never git add -A blindly)
git commit -m "type: short description"

git switch main
git merge dev               # fast-forward merge (no merge commit if linear)
git push origin main        # push to GitHub
git switch dev              # back to dev for next task
```

### Commit message types

| Prefix | Use for |
|---|---|
| `feat:` | New feature or section |
| `fix:` | Bug fix |
| `style:` | CSS / visual changes only |
| `refactor:` | Restructuring without behaviour change |
| `chore:` | Build, config, dependency updates |

### Checking what's different from main

```bash
git log main..dev --oneline          # commits on dev not yet in main
git diff main..dev --stat            # files changed
git diff main..dev -- src/css/       # changes in a specific folder
```

---

## 7. Deploy Reference Commands

### Deploy theme

```bash
cd ~/Documents/Projects/emergencydentalpros-theme
npm run build    # always run before deploying if CSS changed

rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/themes/emergencydentalpros-theme/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

### Deploy plugin

```bash
cd ~/Documents/Projects/emergencydentalpros

rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/plugins/emergencydentalpros/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

### Deploy both (plugin first)

```bash
cd ~/Documents/Projects/emergencydentalpros
rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/plugins/emergencydentalpros/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'

cd ~/Documents/Projects/emergencydentalpros-theme
npm run build
rsync -avz --delete . \
  widev:/var/www/webim.space/public_html/wp-content/themes/emergencydentalpros-theme/ \
  --exclude='.git' --exclude='node_modules' --exclude='.DS_Store'
```

---

## 8. Quick Decision Tree

```
Need to change something on a location page?
│
├── Visual / CSS only?
│   └── Theme → src/css/components/… → npm run build → deploy theme
│
├── HTML structure?
│   ├── Dynamic pages (/locations/…)?
│   │   ├── City     → theme/emergencydentalpros/views/city.php
│   │   ├── State    → theme/emergencydentalpros/views/state.php
│   │   └── All states → theme/emergencydentalpros/views/state-list.php
│   │   Deploy theme (no build unless CSS also changed)
│   │
│   └── Static WP page?
│       ├── Body content → WP Admin editor (no code)
│       └── Surrounding structure → theme/page-city-lp.php → deploy theme
│
├── Configurable text / SEO template?
│   └── /wp-admin/admin.php?page=edp-seo → Save (no deploy)
│
├── New template {variable}?
│   └── Plugin → class-edp-settings.php + class-edp-template-engine.php
│       + admin/views/settings-templates.php → deploy plugin → then theme if needed
│
└── Admin panel UI?
    └── Plugin → admin/views/settings-templates.php + admin/css/edp-admin.css
        → deploy plugin
```
