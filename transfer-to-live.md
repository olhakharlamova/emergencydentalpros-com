# WordPress Site Migration & Deployment Brief

## PROJECT OVERVIEW
Migrating Emergency Dental Pros WordPress site from staging environment to live production server.
- **Staging:** https://dev.widev.pro (clean, tested version)
- **Live Current:** https://emergencydentalpros.com/ (has malware - needs complete replacement)
- **Live Target:** https://emergencydentalpros.com/ + https://www.emergencydentalpros.com/ (with www redirect)

---

## SERVER SPECIFICATIONS
**Client Server:** wpx.net (FTP-only access, no SSH)
- **Hosting:** WPX.net
- **Access:** FTP user only
- **Database:** PhpMyAdmin access
- **Current Status:** Infected with malware (needs clean wipe)
- **Domain Structure:** emergencydentalpros.com with www redirect

**Required Info to Clarify:**
- [ ] Exact PHP version on wpx.net server (check via PhpMyAdmin or FTP)
- [ ] MySQL version compatibility
- [ ] WordPress version in staging (ensure compatibility)
- [ ] Any custom PHP requirements for plugins/theme
- [ ] Database prefix (likely `wp_` but confirm)
- [ ] Current .htaccess structure (for www redirect)

---

## DEPLOYMENT STRATEGY

### Step 1: Clean Current Live Site
- [ ] Full database backup via PhpMyAdmin (save locally)
- [ ] Full file backup via FTP (save locally)
- [ ] **Delete all files from live server** (via FTP)
- [ ] **Drop all tables from database** via PhpMyAdmin
  - Keep only empty database structure
  - or create fresh database if possible

### Step 2: Create GitHub Actions Deployment Workflow
**File:** `.github/workflows/deploy-client.yml`

Workflow should:
1. **Trigger:** On push to `main` branch (or manual dispatch)
2. **Validate:**
   - PHP version compatibility check against target server
   - Code linting (PHP, WordPress standards)
   - Database export from staging (clean SQL dump)
3. **Exclude (DO NOT DEPLOY):**
   - `.env` files
   - `wp-config.php` (keep server's version)
   - `/node_modules`
   - `.git` directories
   - Staging-specific configs
   - `debug.log`
   - `/wp-content/cache/*`
4. **Deploy:**
   - All theme files → `/wp-content/themes/`
   - All custom plugins → `/wp-content/plugins/`
   - Database SQL dump (to import manually)
   - Use `SamKirkland/FTP-Deploy-Action`
5. **Post-Deploy:**
   - Generate deployment report
   - List all deployed files
   - Verify checksums

---

## DOMAIN & STRUCTURE REQUIREMENTS

### Current Structure (to Maintain)
- Primary: `emergencydentalpros.com`
- With www: `www.emergencydentalpros.com` (redirect to primary)
- Current `.htaccess` likely contains:
```apache
  RewriteEngine On
  RewriteCond %{HTTP_HOST} ^www\.
  RewriteRule ^(.*)$ https://emergencydentalpros.com/$1 [R=301,L]
```

### New Site Should Have:
- [ ] Identical `.htaccess` rules (preserved from current)
- [ ] WordPress site URL set to `https://emergencydentalpros.com/`
- [ ] WordPress home URL set to `https://emergencydentalpros.com/`
- [ ] SSL certificate active (verify in browser)
- [ ] Both emergencydentalpros.com AND www.emergencydentalpros.com work
- [ ] www redirects to non-www (verify in browser)

---

## FILES TO PREPARE & EXCLUDE

### Include in Deployment:
- `/wp-content/themes/[custom-theme]/` (entire theme)
- `/wp-content/plugins/[custom-plugins]/` (only active plugins)
- `wp-config-sample.php` (reference only, don't overwrite live wp-config.php)
- `.htaccess` (if custom rules exist)

### Exclude from Deployment:
- `wp-config.php` (server-specific, keep existing)
- `.env` (development only)
- `wp-config-local.php`
- `/wp-admin/` (keep server version)
- `/wp-includes/` (keep server version)
- `index.php` (keep server version)
- `/wp-content/cache/`
- `/wp-content/backup-*`
- `debug.log`
- `.git/`
- `/node_modules/`
- `.DS_Store`, `Thumbs.db`
- Any development config files

### Database to Deploy:
- Export clean database dump from staging: `staging-clean.sql`
- Import to live via PhpMyAdmin (after files deployed)
- Update all URLs from dev.widev.pro → emergencydentalpros.com using Search & Replace

---

## DEPLOYMENT CHECKLIST

### Pre-Deployment
- [ ] Local Docker environment verified & tested
- [ ] All changes committed to GitHub `main` branch
- [ ] Staging (dev.widev.pro) fully tested & approved
- [ ] Database backup from staging created (`staging-clean.sql`)
- [ ] Live server files fully backed up locally
- [ ] Live database fully backed up locally
- [ ] GitHub secrets configured:
  - `FTP_HOST`: wpx.net
  - `FTP_USERNAME`: [your FTP user]
  - `FTP_PASSWORD`: [your FTP password]
  - `FTP_FOLDER`: `/public_html/` (confirm path)

### Deployment
- [ ] GitHub Actions workflow created & tested
- [ ] Manual trigger test on staging branch first
- [ ] Deploy to live via GitHub Actions (main branch)
- [ ] FTP deployment completes successfully
- [ ] Review GitHub Actions logs for errors
- [ ] Verify file checksums match expected

### Post-Deployment
- [ ] SSH into server (if available) or use PhpMyAdmin
- [ ] Import `staging-clean.sql` to database
- [ ] Run WordPress Search & Replace: `dev.widev.pro` → `emergencydentalpros.com`
- [ ] Clear all caches (plugins, server-level)
- [ ] Verify wp-config.php still has correct credentials
- [ ] Check database prefix matches in wp-config.php

---

## VERIFICATION TESTS (After Deployment)

### Functionality Tests
- [ ] Visit https://emergencydentalpros.com/ - loads without errors
- [ ] Visit https://www.emergencydentalpros.com/ - redirects to non-www
- [ ] All pages load (home, about, contact, services)
- [ ] Contact forms submit successfully
- [ ] Mobile responsive design works
- [ ] Search functionality works
- [ ] Admin login works: `/wp-admin/`
- [ ] All plugins active and working
- [ ] Custom theme displays correctly

### Security Tests
- [ ] Run Wordfence scan (via admin)
- [ ] Check for any remaining malware indicators
- [ ] Verify SSL certificate (green lock in browser)
- [ ] Test .htaccess redirects (www handling)
- [ ] Verify wp-config.php is not accessible via browser
- [ ] Check `/wp-admin/` access (should require login)

### Performance Tests
- [ ] Page load speed acceptable
- [ ] Images loading correctly
- [ ] CSS/JS files loading (no 404 errors)
- [ ] Check browser console for errors
- [ ] Database queries performing normally

### SEO & DNS Tests
- [ ] Google Search Console updated to new domain
- [ ] DNS records point to wpx.net correctly
- [ ] Sitemap generates correctly
- [ ] robots.txt is present and valid

---

## SENSITIVE FILES - NEVER DEPLOY

Create `.ftpignore` or explicitly exclude:

wp-config.php
.env
.env.local
.env.staging
.htpasswd
debug.log
.git/
node_modules/
.vscode/
.DS_Store
wp-content/backup-*/
wp-content/cache/
wp-content/updraft/

and any other files folder that should not be in deploy 

---

## GITHUB SECRETS SETUP

In GitHub repo settings → Secrets and variables → Actions, add:

FTP_HOST = wpx.net
FTP_USERNAME = [actual FTP username]
FTP_PASSWORD = [actual FTP password]
FTP_FOLDER = /public_html/ (or correct path)
TARGET_PHP_VERSION = 7.4 (or actual version on wpx.net)


---

## ROLLBACK PLAN

If deployment fails:
1. [ ] Stop GitHub Actions workflow
2. [ ] Restore files via FTP from local backup
3. [ ] Restore database via PhpMyAdmin from local backup
4. [ ] Review GitHub Actions logs for error cause
5. [ ] Fix issue in code
6. [ ] Retry deployment

---

## CLARIFICATIONS NEEDED

Before creating the workflow, please confirm:

1. **Server Info:**
   - [ ] PHP version on wpx.net?
   - [ ] MySQL version?
   - [ ] FTP root folder path? (likely `/public_html/`)
   - [ ] Any server-specific requirements?

2. **Current Setup:**
   - [ ] WordPress version in staging?
   - [ ] Database prefix (wp_ or custom)?
   - [ ] Active custom plugins (list names)?
   - [ ] Custom theme name?

3. **Staging Verification:**
   - [ ] dev.widev.pro fully tested & stable?
   - [ ] All content correct & complete?
   - [ ] All functionality working?

4. **htaccess:**
   - [ ] Current www redirect rule? (to preserve)
   - [ ] Any other custom rewrite rules?

---

## NEXT STEPS

1. Clarify above items
2. Create `.github/workflows/deploy-client.yml` workflow
3. Test workflow on staging/dev branch
4. Configure GitHub secrets
5. Execute deployment to live