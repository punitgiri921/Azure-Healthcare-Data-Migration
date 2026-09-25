# Apex Health Lakehouse — Agent Workspace Rules

This repository follows the permanent learning and development rules codified in:
👉 [.agents/rules/migration-coaching-rule.md](.agents/rules/migration-coaching-rule.md)

---

## Core Repository & Git Workflow Rules

### 1. Day-to-Day Development (Always on `main`)
* Stay on the `main` branch for all regular development (ADF pipelines, SQL scripts, PySpark notebooks, DAX/Power BI, Markdown documentation, tests, and Sentinel Agent code).
* Because `*.html` is in `.gitignore` on `main`, zero HTML files will ever be pushed to GitHub:
```bash
# Whenever you push code, ADF pipelines, or SQL to GitHub:
git push origin main
# ➔ Only code, ADF, SQL, and Markdown will be pushed. Zero HTML files will go to GitHub!
```

### 2. Permanent Workspace Presence for HTML Trackers
* **Always Keep on Disk**: `index.html` and `migration_learning_tracker.html` MUST ALWAYS remain physically present in the project root directory so you can open, double-click, and view them in your browser at any time.
* **No Branch Switching Purges**: NEVER switch branches to `local-tracker` during routine work. In Git, switching from a branch where files are tracked (`local-tracker`) back to `main` (where they are untracked) causes Git to automatically delete them from the user's disk.
* **Automatic Protection via `.gitignore`**: Because `*.html` is in `.gitignore`, Git completely ignores the HTML files on `main`. You can run `git add .`, `git commit`, and `git push origin main` with 100% confidence—the HTML files stay safely on your local hard drive and are NEVER pushed to GitHub.

