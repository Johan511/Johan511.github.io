# CLAUDE.md

Hugo site using the hugo-coder theme (in `hugo-coder/` subdirectory). Deploys to GitHub Pages via Actions.

## Build

```bash
make build
# or: hugo
```

Output goes to `public/`.

## Run (dev server with live reload)

```bash
make demo
# or: hugo server -D --bind 0.0.0.0
```

Dev server runs at **http://localhost:1313/**.

## View / Access

- Dev server: **http://localhost:1313/** — open in a browser while `hugo server` is running
- For automated verification: use **Playwright** to load pages and check content/screenshots

```python
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    browser = p.chromium.launch()
    page = browser.new_page()
    page.goto("http://localhost:1313/")
    print(page.title(), page.locator("body").inner_text()[:300])
    page.screenshot(path="screenshot.png")
    browser.close()
```

## GitHub Pages

On push to `main`, `.github/workflows/github-pages.yml` builds with Hugo 0.148.2 and deploys. Enable in repo Settings → Pages → Source: "GitHub Actions".
