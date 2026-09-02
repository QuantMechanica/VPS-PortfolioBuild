# Sleeve Execution Parity — DXZ Live Book (24 sleeves, account 4000090541)

Auditor dimension: execution parity of the live manifest against real T_Live attach + trade evidence.
Read-only. Every row file/DB-evidenced. Generated 2026-09-02 (audit window; pulse snapshot 2026-09-02T08:00:02Z).

## Sources of truth used
- Manifest: `D:\QM\reports\portfolio\portfolio_manifest_live_24sleeve_20260724.json` (sha256 `8c719b0…84eab6`; 24 sleeves; reconciles with deploy pointer, `match=true, sha_match`).
- Pulse: `D:\QM\reports\state\live_book_pulse.json` (verdict ALARM, 26 alarms; generated_at_utc `2026-09-02T08:00:02Z`).
- Active chart profile: `C:\QM\mt5\T_Live\MT5_Base\Config\common.ini` → `[Charts] ProfileLast=DarwinexZero_V2_LiveOps`.
- Chart files (UTF-16LE): `C:\QM\mt5\T_Live\MT5_Base\MQL5\Profiles\Charts\DarwinexZero_V2_LiveOps\chart01..25.chr` (25 charts = 24 sleeves + AccountMonitor).
- Per-EA event logs (JSON-lines, full live window): `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_<id>_ea-<id>.log`.
- Terminal journals (UTF-16LE, account Trades lines): `C:\QM\mt5\T_Live\MT5_Base\logs\2026*.log`.
- Deploy pointer: `D:\QM\reports\state\live_deployment_pointer.json` (`approved_by=null, signed=false`).

## Headline
- **The live book is fully attached and largely trading.** All **25 experts are attached with `expertmode=1`** (autotrade enabled) in the active profile, each with its preset inputs populated (26–44 inputs/chart). `live_presets.discovered_preset_count=24`, `preset_consistency.mismatch_count=0`, KS baselines `loaded_ok=23/24`. Book equity is moving (day_pnl +505.06, 4 open positions, USDJPY OCO orders placed today 04:59Z).
- **16 of 24 sleeves have placed ≥1 order since 2026-07-19; 8 have placed ZERO.** Of the 8, **3 are structurally dark** (cannot/does not trade for a real reason) and **5 are plausibly no-signal** (low frequency, filter simply has not opened; one is event-driven-by-design).
- **The `loaded_sleeve_count=0` / 24× `manifest_missing_loaded_sleeve` ALARM is a pulse parsing artifact, not a live-book fault. The fix is in the pulse.** All 26 alarms are WARN severity; the book's `health_contract`/`heartbeat` are green.

---

## 24-row parity table

Legend — Chart: chartNN.chr in DarwinexZero_V2_LiveOps. Preset: expertmode/`<inputs>` count. Heartbeat: newest event in the EA's own log. Orders≥0719: ENTRY_ACCEPTED count in `QM5_<id>_ea-<id>.log` with `ts_utc ≥ 2026-07-19`. All experts `expertmode=1`.

| # | key (magic) | Chart | Preset (mode/inputs) | Last EA-log event (UTC) | Orders since 07-19 | Last order | Status |
|---|-------------|-------|----------------------|-------------------------|--------------------|------------|--------|
| 1 | 10403\|XAUUSD (104030002) | 14 | 1 / 33 | 2026-09-01T22:01 | **34** | 08-31T22:01 | TRADING |
| 2 | 10440\|NDX (104400003) | 11 | 1 / 31 | 2026-09-01T22:00 | **4** | 08-19T13:59 | TRADING (KS baseline missing) |
| 3 | 10513\|XAUUSD (105130003) | 15 | 1 / 34 | 2026-09-01T22:01 | **2** | 08-02T22:01 | TRADING (slow) |
| 4 | 10706\|GBPUSD (107060001) | 07 | 1 / 36 | 2026-09-01T21:04 | **6** | 09-01T08:59 | TRADING |
| 5 | 10911\|GDAXI (109110003) | 09 | 1 / 36 | 2026-09-02T00:30 | **12** | 09-01T09:30 | TRADING |
| 6 | 10919\|XTIUSD (109190001) | 20 | 1 / 41 | 2026-09-01T22:00 | **0** | – | NO-SIGNAL (alive, 12/yr) |
| 7 | 10939\|GBPUSD (109390001) | 08 | 1 / 44 | 2026-09-01T21:04 | **2** | 08-25T08:59 | TRADING (started 08-21) |
| 8 | 11132\|SP500 (111320000) | 12 | 1 / 32 | 2026-09-01T22:00 | **3** | 08-18T22:00 | TRADING |
| 9 | 11165\|AUDCAD (111650002) | 01 | 1 / 32 | 2026-09-01T21:04 | **5** | 09-01T08:59 | TRADING |
| 10 | 11165\|EURUSD (111650000) | 04 | 1 / 32 | 2026-09-01T21:04 | **2** | 08-06T15:59 | TRADING (slow) |
| 11 | 11421\|AUDUSD (114210003) | 03 | 1 / 31 | 2026-09-01T21:04 | **12** | 08-27T21:04 | TRADING |
| 12 | 11421\|EURUSD (114210000) | 05 | 1 / 31 | 2026-09-01T21:04 | **17** | 08-30T21:05 | TRADING |
| 13 | 11708\|EURUSD (117080000) | 06 | 1 / 28 | 2026-09-01T21:04 | **6** | 08-20T21:04 | TRADING |
| 14 | 12567\|XAUUSD (125670003) | 16 | 1 / 32 | 2026-09-01T22:01 | **0** | – | NO-SIGNAL (alive, 15/yr) |
| 15 | 12567\|XNGUSD (125670002) | 19 | 1 / 32 | 2026-09-01T22:01 | **0** | – | NO-SIGNAL (alive, 15/yr; 0 chart trade-objects) |
| 16 | 12778\|AUDUSD (127780000) | 02 | 1 / 30 | **2026-08-23T08:29 (INIT_OK only)** | **0** | – | **STRUCTURALLY DARK** |
| 17 | 12969\|USDJPY (129690000) | 13 | 1 / 28 | **2026-08-28T17:59 (FRIDAY_CLOSE)** | **0** | – | **DARK / UNDER-TRADING ANOMALY** |
| 18 | 12989\|XAUUSD (129890003) | 17 | 1 / 44 | 2026-09-01T22:01 | **0** | – | NO-SIGNAL (alive, 24/yr — low) |
| 19 | 13117\|EURGBP (131170000) | 21 | 1 / 30 | **2026-08-23T08:29 (INIT_OK only)** | **0** | – | **STRUCTURALLY DARK** |
| 20 | 13128\|NDX (131280000) | 10 | 1 / 28 | 2026-09-01T22:00 | **0** | – | NO-SIGNAL BY DESIGN (FOMC-event, ~7/yr) |
| 21 | 13213\|USDJPY (132130000) | 23 | 1 / 31 | 2026-09-02T07:59 | **50** | 09-02T02:59 | TRADING (most active) |
| 22 | 13301\|GDAXI (133010010) | 22 | 1 / 34 | 2026-09-02T00:30 | **22** | 08-27T08:29 | TRADING |
| 23 | 1556\|XAUUSD (15560004) | 18 | 1 / 29 | 2026-09-01T22:01 | **4** | 08-13T04:47 | TRADING (slow) |
| 24 | 1567\|EURUSD (15670007) | 24 | 1 / 26 | 2026-08-28T17:59 | **1** | 08-26T13:00 | TRADING (started 08-26, low-freq) |

Evidence path per row: chart = `…\Charts\DarwinexZero_V2_LiveOps\chart{NN}.chr`; heartbeat + orders = `…\MQL5\Files\QM\QM5_{ea_id}_ea-{ea_id}.log`. Account-level ticket confirmation for today's USDJPY: `…\logs\20260902.log` (`Trades … order #3176073240 buy stop 0.26 USDJPY … done`).

Cross-checks: every manifest magic matches the registry (`manifest_reconcile.magic_mismatches=[]`, 18,200 rows loaded); deploy-pointer manifest sha equals the live manifest sha (`deploy_pointer_reconciliation.match=true`).

---

## Structurally dark sleeves (do not trade for a real reason)

### 1 & 2 — 12778\|AUDUSD and 13117\|EURGBP — basket warm-up loads 0 legs (CONFIRMED)
Both are multi-symbol **basket** EAs (`SYMBOL_GUARD_INIT mode=basket, n_symbols=4`). Their last log line, at the **2026-08-23 10:29 broker-time profile reload**, is:
```
BASKET_WARMUP {"requested":4,"loaded":0,"skipped":4,"warmup_bars":300,"tf":16408}  → INIT_OK
```
- 12778 legs requested: AUDUSD.DWX, EURJPY.DWX, EURUSD.DWX, (+1). 13117 legs: EURGBP.DWX, AUDJPY.DWX, GBPUSD.DWX, (+1).
- **loaded=0 of 4** → the basket has no history for its constituent legs → it can never compute a cointegration/pair signal → it cannot trade. Both have placed **0 orders across their entire live history** (not just since 07-19).
- They emit no heartbeat template (basket EAs log only on warm-up/entry), and have logged nothing since 2026-08-23. Cause is almost certainly that the non-charted `.DWX` legs (EURJPY, AUDJPY, EURUSD-as-leg, GBPUSD-as-leg) are not subscribed / lack loaded history on T_Live, so `CopyRates` returns 0.
- Evidence: `QM5_12778_ea-12778.log`, `QM5_13117_ea-13117.log` (tail); expected frequency SPEC `framework/EAs/QM5_12778_…/SPEC.md` = 4-8 trades/yr/basket (so even healthy they are very low-frequency, which is why this went unnoticed).

### 3 — 12969\|USDJPY (gotobi-nakane-fix) — 36 trades/yr expected, 0 live orders ever
- SPEC `framework/EAs/QM5_12969_…/SPEC.md`: *"Executed trades / year / symbol: 35.5 observed; planning value 36; 213 trades over 2017-2022"*. At ~3/month this sleeve **should be the second-most-active in the book**, yet it has placed **0 orders in 7 weeks live** and 0 across its whole log.
- It re-inited on 2026-08-23, logged one `FRIDAY_CLOSE` on 2026-08-28T17:59, and nothing since. It does not emit the `EQUITY_SNAPSHOT` heartbeat template, so current liveness cannot be positively confirmed from logs — but the diagnostic red flag is the **complete absence of any entry against a 36/yr expectation**. This is an execution/entry-logic or symbol/DST defect, not low-frequency luck.
- Highest-value single-sleeve investigation of the three.

## No-signal (alive, plausibly correct)
- **13128\|NDX (pre-fomc-drift)** — **0 by design.** SPEC ~7/yr, one trade per FOMC decision. No FOMC in the 07-19→09-02 window (last decision ~July, next ~Sep 16-17). Alive, heartbeating 09-01T22:00. No action.
- **10919\|XTIUSD (12/yr)**, **12567\|XAUUSD & 12567\|XNGUSD (15/yr each)**, **12989\|XAUUSD (24/yr)** — all alive and heartbeating through 09-01T22:00 (EQUITY_SNAPSHOT). Expected trades in a ~6.5-week window: XTI ~1.5, each 12567 leg ~1.9, 12989 ~3. Zero is within Poisson plausibility for the first three; **12989 at 24/yr with 0 is on the weak side** and worth a second look, but there is no structural failure signature (it warms up, loads news, restores KS anchor). Also corroborating: the chart trade-object counts (drawn autotrade objects, per-symbol) are **0 on chart19 XNGUSD, chart20 XTIUSD, chart21 EURGBP** — those three symbols carry no live trades at all, consistent with 10919/12567-XNG never firing and 13117 being dark.

---

## Vault-claim reconciliation

- Vault `08_DXZ_Live_Book`: *"only 10 of 24 EAs traded in 7 days"* (snapshot ~2026-08-19). This is a **7-day rolling window** and is not contradicted: over the full live window 07-19→09-02, **16 of 24** have traded; in any single 7-day slice far fewer are active because most sleeves are D1/H4 low-frequency.
- TODO **QM-TODO-20260821-081**: *"5 sleeves never traded"*. This **undercounts**. Measured directly from the EA logs, as of 2026-08-21 **10 sleeve-keys (8 EA ids) had zero live orders**: 10919\|XTI, 10939\|GBP, 12567\|XAU, 12567\|XNG, 12778\|AUD, 12969\|JPY, 12989\|XAU, 13117\|EURGBP, 13128\|NDX, 1567\|EUR. Two of those (10939, 1567) have since traded, leaving **8 zero-order keys today**. Recommend the TODO be restated to the evidenced 8, split into the 3 structurally-dark + 5 no-signal buckets above.

---

## The `loaded_sleeve_count=0` alarm — root cause and where to fix

**What the pulse parses.** `tools/strategy_farm/live_book_pulse.py :: parse_terminal_journals()` counts live sleeves by scanning the terminal journals for the ephemeral phrase `EXPERT_LOADED_RE` = `"expert QM5_<id>_<slug> (SYMBOL,TF) loaded successfully"` (lines 87-90, 953). It reads only the **`--lookback-files` most recent journals** (default **10**, line 1819) and filters loaded-lines to `ts ≥ latest_terminal_start`.

**Why it finds none (proven).**
1. "Experts … loaded successfully" lines are written **only when the profile/terminal loads the experts** — i.e. on a reload, not continuously.
2. The last such reload was **2026-08-23 at 10:29** (`20260823.log` contains 25 `\tExperts\t … loaded successfully` lines — verified). The terminal has run continuously since, so no journal after 08-23 contains any expert-load line.
3. The 10 most-recent journal files are exactly `20260824.log … 20260902.log` — **precisely the 10 files newer than `20260823.log`** (verified: 10 files are newer than 08-23). So `20260823.log` sits one file outside the lookback window, its 25 load lines are never read, and `loaded_sleeve_count` collapses to **0**.
4. `latest_terminal_start=None` (the terminal started before the window too), so no start line is found either.
5. Downstream, `expected_keys (24 from manifest) − loaded_keys (0) = 24` → the 24 `manifest_missing_loaded_sleeve` WARNs (line ~1557).

**Conclusion: the fix is in the PULSE, not the manifest.** The book is fully loaded — independently confirmed by (a) 24 chart `<expert>` blocks with `expertmode=1` + populated inputs, (b) `live_presets.discovered_preset_count=24` / `preset_consistency.mismatch_count=0`, (c) KS baselines 23/24, (d) 16 sleeves actively placing orders with live tickets in `20260902.log`. `loaded_sleeve_count` is measuring "was the profile reloaded within the last 10 journal days", which is not the same question.

**Recommended pulse fix (any one; combine 1+3):**
1. Set `latest_terminal_start` and the load-line scan to include the journal that contains the most recent terminal-start / last profile-load, regardless of the 10-file cap (walk back until a start/load line is found, or key the lookback on uptime rather than file count).
2. Fall back to the authoritative **current attach state** — parse the active `*.chr` `<expert>` blocks in `Config/common.ini`→`ProfileLast` — when no load line is in-window. This is what actually reflects live attach and already reads correct (24/25).
3. Treat "no load line since a terminal-start that is itself outside the window" as **UNKNOWN/OK-by-continuity**, not `0`. A 0 should require evidence of a *removal*, not merely the absence of a (stale) load line.

**Secondary, cosmetic (manifest side):** every manifest sleeve carries `live_preset_path: null` and `timeframe_norm: ""`. This does not cause the 0 (identity/magics reconcile fine) but it starves any preset-path-based reconciliation and should be back-filled from the discovered presets when the pointer is (re)signed.

---

## Recommended disposition per dark sleeve (no live action taken)

| Sleeve | Disposition | Owner | Zone |
|--------|-------------|-------|------|
| 12778\|AUDUSD (basket, 0 legs loaded) | Investigate `.DWX` leg subscription / history on T_Live; if legs cannot be provisioned, **flag for REMOVE from book at next OWNER roster review (MNT-036, due 09-06)** — it has never contributed. | claude-interactive diag → owner | live roster = ROT |
| 13117\|EURGBP (basket, 0 legs loaded) | Same as 12778 (identical failure signature). Same MNT-036 disposition. | claude-interactive diag → owner | live roster = ROT |
| 12969\|USDJPY (36/yr, 0 orders) | Root-cause the entry path in a **backtest of the exact live preset** (chart13 inputs) over the live window — is it symbol/DST, a filter never opening, or an entry-logic regression in the "gotobi-nakane-fix" v2? Report to OWNER with MNT-036. | claude-headless (backtest) → owner | GREEN diag / roster = ROT |
| 12989\|XAUUSD (24/yr, 0 orders) | Watch one more week; if still 0, add to the 12969 backtest batch. Not urgent. | claude-headless | GREEN |
| 10919 / 12567×2 / 13128 | No action — no-signal within design frequency (13128 is FOMC-by-design). Fold into the MNT-036 note as "expected quiet". | — | — |
| 10440\|NDX (KS baseline missing) | Its Q10 was FAIL (DD 31%, per brief) and its KS baseline file is the one `none` source in `loaded_ok=23/24`. It is trading (4 orders) but under a missing kill-switch baseline — **flag: a sleeve trading live without a KS baseline is a risk-control gap.** Provision the baseline or remove at MNT-036. | claude-interactive → owner | live risk = ROT |

**Note for the pulse fix itself:** GREEN/operational — it changes no sealed criterion; it corrects a false-negative liveness reconstruction. ~1-2h (claude-headless or codex). Until fixed, the 26-alarm ALARM verdict masks the two findings that actually matter (the 3 dark sleeves, the 10440 KS gap) behind 24 false WARNs.

## Why this matters for the money goal
The DXZ track record (the asset that earns DarwinIA/investor allocation) is being generated by **at most 21 of 24 sleeves** — 2 baskets have contributed nothing since inception, 1 high-frequency USDJPY sleeve is silent, and 1 sleeve trades without a kill-switch baseline. That is not a catastrophe (book DD 2.6%, positive day), but it means the live "diversification" is thinner than the manifest claims, and the realized-vs-modeled edge read (MNT-036, the audit's root gate) is being computed on a partially-dark book. Fixing the pulse removes the noise; the MNT-036 roster review is the right forum for the REMOVE/provision decisions — all of which are OWNER-authority (live roster/risk = ROT).
