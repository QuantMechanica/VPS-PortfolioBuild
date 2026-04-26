# GitHub Repo Plan

> **V5 Source:** Notion `GitHub Repo Plan` (id `34947da5-8f4a-81a0-9777-d378977ef0e8`)
> **Migrated to repo:** 2026-04-26

**Repo:** `https://github.com/QuantMechanica/VPS-PortfolioBuild`
**Visibility:** Public from day 1 (Build in Public commitment)
**Created:** 2026-04-21 by OWNER
**License:** TBD — default to All Rights Reserved on strategies, MIT on infra/tooling

## Why Fresh Repo (Not Continuation of `quantmechanica-ops`)

The old `quantmechanica-ops` private repo has 6 months of iterative history with deprecated decisions, dead branches, and private state. V5 is a clean start:

- Public from commit 1
- Story of the build readable in commit log
- New viewers land on a coherent narrative
- Old repo archived, referenced, not deleted — stays as historical record

## Current Repo Structure (as of 2026-04-26)

```text
VPS-PortfolioBuild/
├── README.md
├── CLAUDE.md                          # Board Member operating instructions
├── PROJECT_BACKLOG.md                 # cross-phase backlog with today's-owner labels
├── .gitignore
├── branding/
│   ├── QM_BRANDING_GUIDE.md           # V5 brand application
│   ├── brand_tokens.json              # machine-readable design tokens
│   └── assets/                        # favicon.svg, logos, README
├── checklists/
│   └── README.md                      # stub — Wave 0 fills
├── decisions/                         # ADRs (10+ entries)
├── deploy-manifests/
│   └── README.md
├── docs/
│   └── ops/                           # canonical operations docs (~25 files)
├── episodes/                          # YouTube artifact packs (empty until EP01 produced)
├── expenses/                          # public expense log
├── framework/
│   ├── README.md
│   └── V5_FRAMEWORK_DESIGN.md         # 25-step Codex implementation order
├── lessons-learned/                   # V4 archive + incident reports + policy
├── paperclip-prompts/                 # 13 agent prompts + README
├── processes/                         # 12 V4 processes migrated as basis
├── prompts/                           # bootstrap / onboarding prompts (Claude Code)
├── public-data/
│   └── README.md                      # public snapshot JSON destination
├── risks/                             # stub
├── scripts/
│   └── README.md                      # stub — DevOps fills with framework + dashboard scripts
├── seed_assets/
│   └── news_calendar/                 # MANIFEST + raw CSVs (V1-V5 calendar)
├── skills/                            # stub
└── strategy-seeds/
    ├── README.md
    ├── cards/
    │   └── _TEMPLATE.md               # V5 Strategy Card template
    ├── specs/                         # 5 V4 markdown specs (legacy reference)
    └── v5_locked_basket_2026-04-18.md # V4 historical snapshot, NOT a V5 input
```

## Notional Future Structure (per Notion plan, not all live yet)

```text
strategies/                            # NOT YET — produced by Wave 0+ research → V5 EAs
  SRC001_chan-alg-trading/
    source.md
    strategy-cards/SRC001_S01.yaml
    eas/QM5_1001_<slug>/
      QM5_1001_<slug>.mq5
      sets/
      results-baseline.md
infra/                                 # NOT YET — DevOps owns
  vps-setup.md
  paperclip-deploy.sh
  backup.ps1
dashboard/                             # NOT YET — frontend Astro/Tailwind
.github/workflows/                     # NOT YET — CI/CD
```

## Process / Skill Addendum

The fresh repo must also version the operating system, not only code and reports:

```text
processes/
  source-research.md
  strategy-card.md
  ea-build.md
  baseline-backtest.md
  quality-review.md
  deploy-manifest.md
  website-snapshot-export.md
  episode-publishing.md
  lessons-learned.md

skills/
  frontend-dashboard.md
  mt5-liveops.md
  strategy-research.md
  backtest-evidence.md
  quality-tech-review.md
  quality-business-review.md

checklists/
  t6-deploy.md
  public-dashboard-release.md
  episode-publish.md
  live-risk-halt.md

public-data/
  public-snapshot.schema.json
  process-roadmap.schema.json
  redaction-rules.md
```

These files are part of the company operating system. Agents execute against them, update evidence, and propose changes through review rather than silently changing how the company works. (Status 2026-04-26: laptop processes migrated to `processes/` per P0-24; the rest is Wave-0+ work.)

## Branching Strategy

- `main` — always publishable, protected, requires PR review
- `episode/EPnn-slug` — per-episode development branch
- `strategy/SRCnnn-Sxx` — per-strategy-card branch
- `infra/*` — infrastructure changes

## Commit Discipline

- Commit messages follow `<type>: <subject>` (type = episode | strategy | infra | docs | fix)
- Every significant decision = a commit with descriptive body
- Co-Authored-By footer for Claude-Assistant / Codex contributions
- Sign commits with GPG (OWNER's key) — Phase 1+

## CI/CD (GitHub Actions, Wave 0+ work)

1. **Lint MQL5** on every strategy PR (basic syntax check)
2. **Export Notion pages to docs/** nightly (sync mirror)
3. **Validate public snapshot schemas** for dashboard/process-roadmap JSON before publish
4. **Rebuild website** on any `dashboard/`, `public-data/`, `processes/`, or `expenses/` change
5. **Generate strategy index** when a new `strategies/**/source.md` is added

## Issue Tracker Use

GitHub Issues = user-facing bug reports, feature requests, community questions. Paperclip internal tasks stay in Paperclip. Do NOT cross-post — causes confusion.

## Release Cadence

No traditional "releases" — this is a continuous-build repo. But we tag monthly: `v5-m1`, `v5-m2`, ... matching month-number of the build. Each tag cuts a snapshot of `docs/` + `strategies/` + `expenses/` for reference.

## V5 Restart Boundary

Do not import old QUAA issues, heartbeats, or agent IDs into the fresh public repo. Existing strategies enter only through `strategy-seeds/` and must re-earn V5 gates before Demo/Live. (V4 framework patterns and learnings ARE inherited per `lessons-learned/V4_LEARNINGS_ARCHIVE_2026-04-21.md`.)
