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

### 2. How to Save Snapshots / Track Changes to HTML Locally
* The HTML learning trackers (`index.html`, `migration_learning_tracker.html`) are tracked strictly on your local machine on the dedicated `local-tracker` branch.
* Whenever updates are made to the HTML files and you want to save a Git version/checkpoint locally:
```bash
# 1. Switch to your local tracker branch
git checkout local-tracker

# 2. Commit your HTML updates
git add index.html migration_learning_tracker.html
git commit -m "docs(tracker): update autonomous sentinel agent section"

# 3. Switch back to main
git checkout main
```
* **STRICT ENFORCEMENT**: **NEVER** run `git push origin local-tracker`. The `local-tracker` branch is strictly offline and local-only.
