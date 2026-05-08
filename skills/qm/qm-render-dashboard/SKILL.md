---
name: qm-render-dashboard
description: Use when DevOps needs to regenerate the Paperclip operations dashboard (current.html) or the strategy archive page (strategies.html) after pipeline state changes. Don't use during active backtest runs — wait for the run to complete. Don't use to modify dashboard code; that is CTO + DevOps work.
owner: DevOps
reviewer: CEO
last-updated: 2026-05-08
basis: paperclip/tools/ops/render_dashboard.py + paperclip/tools/ops/render_strategies.py
---

# qm-render-dashboard

Procedure for regenerating the local operations dashboard and strategy archive page. These are static HTML files used for daily status overview.

## When to use

- Kanban or pipeline state has changed and dashboard is stale
- New EA entered or exited a pipeline phase
- Strategy archive (`public-data/strategy-archive.json`) was updated
- OWNER or CEO requested a dashboard refresh

## When NOT to use

- Active backtest run in progress (wait for completion to get accurate counts)
- Modifying dashboard code (that is a CTO/DevOps code task, not a render task)

## Dashboard files

| File | Purpose |
|------|---------|
| `C:\QM\paperclip\dashboards\current.html` | Main ops dashboard: Kanban state, EA pipeline lifecycle, issue summary |
| `C:\QM\paperclip\dashboards\strategies.html` | Strategy archive: all researched strategies with results and symbol charts |

## Procedure

### Step 1: Regenerate main dashboard

```bash
cd C:/QM/paperclip/tools/ops
python render_dashboard.py
```

Output: `C:\QM\paperclip\dashboards\current.html`

### Step 2: Regenerate strategy archive (if strategy-archive.json changed)

```bash
cd C:/QM/paperclip/tools/ops
python render_strategies.py
```

Output: `C:\QM\paperclip\dashboards\strategies.html`

### Step 3: Verify output

Open in browser (or check file size > 10 KB as a minimum sanity check):
```bash
ls -la C:/QM/paperclip/dashboards/current.html
ls -la C:/QM/paperclip/dashboards/strategies.html
```

Check for obvious rendering errors by looking at the file head:
```bash
head -5 C:/QM/paperclip/dashboards/current.html
```

### Step 4: No commit needed

Dashboard HTML files are generated artifacts — they are not committed to git.  
`public-data/` JSON files (the source data) ARE committed when updated.

## Key paths

- Dashboard renderer: `C:\QM\paperclip\tools\ops\render_dashboard.py`
- Strategy renderer: `C:\QM\paperclip\tools\ops\render_strategies.py`
- Kanban source: `C:\QM\paperclip\kanban\company_kanban.csv`
- Strategy data: `C:\QM\repo\public-data\strategy-archive.json`
- EA pipeline reports: `D:\QM\reports\pipeline\`
- Dashboard output: `C:\QM\paperclip\dashboards\`

## References

- `C:\QM\paperclip\tools\ops\render_dashboard.py` — dashboard renderer source
- `C:\QM\paperclip\tools\ops\render_strategies.py` — strategy archive renderer source
- `public-data/strategy-archive.json` — strategy feed (public data, committed to git)
- `public-data/public-snapshot.json` — ops snapshot (committed to git)
