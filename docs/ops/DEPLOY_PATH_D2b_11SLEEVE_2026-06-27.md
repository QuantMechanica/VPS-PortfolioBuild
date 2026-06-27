# Deploy Path — D2b 11-Sleeve Live Book (2026-06-27)

How the live book is stored (intentionally in **four** places) and how it flows to the live
terminal. Written because OWNER directed: files live in multiple locations on purpose; the
deploy path must be documented. Supersedes the D2a 8-book deploy.

## The four storage locations (by design)

| # | Location | Role | Git | Naming |
|---|---|---|---|---|
| 1 | `framework/EAs/QM5_{id}_{slug}/sets/*_live.set` + `…/{dir}.ex5` | **Source of truth** (canonical live setfile + compiled EA) | tracked | `QM5_{id}_{slug}_{SYM}.DWX_{TF}_live.set` |
| 2 | `D:\QM\reports\portfolio\sleeve_streams\QM\q08_trades\{id}_{SYM}_DWX.jsonl` | Durable Q08 trade streams (portfolio math; survives Q08 re-runs) | no (D: runtime) | per (id,symbol) |
| 3 | `C:\QM\deploy\GoLive_D2b_11sleeve_2026-06-27\` | **Deploy packet** (operator bundle: EAs/ + SetFiles/ + manifest + preflight + README) | no (deploy artifact) | `slot{N}_{SYM}_{TF}_QM5_{id}_{slug}_magic{M}.{ex5,set}` |
| 4 | `C:\QM\mt5\T_Live\MT5_Base\MQL5\Presets\QM\*.set` + `…\Experts\QM\*.ex5` | **Live terminal** (what MT5 actually loads) | no (live) | canonical `_live.set` / `QM5_{id}_{slug}.ex5` |

Locations 1, 3, 4 carry **byte-identical** setfile content (verified by SHA256); the filename
differs (3 uses operator slot-names, 1 & 4 use canonical names). The deploy packet (3) is the
human-facing bundle; T_Live (4) is the runtime; framework (1) is the git source of truth.

## The flow (framework → packet → T_Live)

```
[1] framework _live.set / .ex5   (git source of truth)
        │  build_d2b_packet.py     (writes canonical _live.set from backtest set + 11-book manifest weights;
        │                           copies .ex5; stages byte-identical operator-named copies)
        ▼
[3] C:\QM\deploy\GoLive_D2b_…\    (EAs/ + SetFiles/ + manifest_d2b_11sleeve + README + preflight)
        │  deploy_to_tlive.py      (copies framework canonical _live.set + .ex5 → T_Live; SHA256-verifies each)
        ▼
[4] T_Live\MQL5\Presets\QM + Experts\QM   (live terminal; loaded when EA attached / AutoTrading on)
```

Generation of the live setfile (per sleeve): take the EA's **backtest** setfile (strategy + filter
params), then for live set `RISK_FIXED=0`, `RISK_PERCENT=<manifest, risk-parity, capped 1%/trade>`,
`PORTFOLIO_WEIGHT=<manifest>`, `qm_filter_news_enabled=1`, header `environment: live`, and a real
`card_defaults_source` (Hard Rule: never `RISK_FIXED` live, never `not_found`).

## Validation gate (fail-closed)

`python -m tools.strategy_farm.validate_golive_package C:\QM\deploy\GoLive_D2b_11sleeve_2026-06-27`

Checks, fail-closed: build guardrails on every setfile (ENV=live, RISK_FIXED=0, RISK_PERCENT>0,
news on, card source present), **package == framework `_live.set` (SHA256)**, **package == T_Live
preset (SHA256)**, and `.ex5` hashes match framework. Pre-flip it FAILs on T_Live divergence; that
divergence IS the deploy step.

## Status (2026-06-27)

- ✅ Locations 1–4 all populated and **SHA256-consistent** for all **11 setfiles + 10 EAs**
  (11421 serves AUDUSD + EURUSD with one `.ex5`).
- ✅ `validate_golive_package` → **VERDICT: PASS, 0 findings** (evidence:
  `…\GoLive_D2b_11sleeve_2026-06-27\D2B_PREFLIGHT_2026-06-27.json`).
- ✅ Manifest `cap_met=True` (MC-p95 DD < 6%); book Sharpe 1.74 / risk-parity MaxDD 4.50%.
- ⏳ **T_Live terminal is NOT running and AutoTrading is OFF.** Files are staged only — no live
  trading yet. Starting the terminal + flipping AutoTrading is the **OWNER+Claude-only** final step
  (Hard Rule). Nothing here started the terminal or changed AutoTrading.

## The remaining OWNER+Claude step (not yet done)

1. OWNER approves the 11-sleeve manifest in writing.
2. Start T_Live terminal (interactive), attach the 11 EAs to their charts with the matching
   `_live.set` preset (slot/magic per the table in the packet README), confirm magic-number registry
   + news calendar current.
3. **OWNER or Claude** flip AutoTrading on T_Live.
4. Record `decisions/2026-06-27_t_live_d2b_11sleeve_book.md` with the verification evidence.

## Reproduce / re-sync

- Rebuild packet from framework + manifest: `scratchpad/build_d2b_packet.py`
- Re-sync framework → T_Live with SHA256 verify: `scratchpad/deploy_to_tlive.py`
- Re-validate: `validate_golive_package` (above)

(The two scratchpad scripts are one-shot generators kept with this session; the durable record is
this doc + the committed framework `_live.set` + the deploy packet.)
