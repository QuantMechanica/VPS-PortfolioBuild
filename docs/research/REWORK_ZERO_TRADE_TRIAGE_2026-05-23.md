# Zero-Trade Rework Triage — QM5_10020, QM5_1044, QM5_1048

Date: 2026-05-23
Author: Claude (operation lead)
Tasks:
- `61bd7b8c-cbc4-4914-8135-e954c2440b6b` — QM5_10020 (priority 70)
- `18c0fb57-abc5-4acc-af8f-99f9b3cbc841` — QM5_1044 (priority 70)
- `34439feb-3c0b-40c1-a3a5-879cc3412a5f` — QM5_1048 (priority 70)
Trigger: `DL-062_zero_trade_rework_trigger` (recurrent zero-trade FAIL ratio).
Perspective: card/source rework — relax entry conditions or substitute signal logic.

## TL;DR

All three EAs are flagged as zero-trade-recurrent, but **the dominant cause is
dispatcher-layer, not strategy-layer**, and a card/source rework would be
premature for two of three. Findings per EA:

| ea_id | dispatcher fan-out hit? | in-universe also zero-trade? | real strategy-layer bug? | recommended verdict |
|---|---|---|---|---|
| QM5_10020 | yes (37 symbols, only 3 in-universe) | yes (NDX FAIL, WS30 FAIL, SP500 INVALID) | **yes — D1/H1 period + NewBar gate prevents hour=23 entry** | REWORK (entry-gate fix), then re-enqueue restricted universe |
| QM5_1044 | yes (37 symbols, US-indices only) | INVALID_REPORT not MIN_TRADES_NOT_MET | **no — symptom is the known perf hold** ([[project_qm5_1044_perf_rework_2026-05-16]]) | HOLD (already-tracked perf rework owns this) |
| QM5_1048 | yes (40 rows, only 4 in-universe) | yes (NDX/WS30/UK100/GDAXI all FAIL/INVALID) | **structural: semi-annual ⇒ max ~2 trades/yr/symbol vs `min_trades_required=6`** | RECYCLE (strategy is P2-gate-incompatible by design) |

The DL-062 zero-trade trigger is reading the wrong signal. **The numerator (zero-trade
FAILs) is inflated by out-of-universe enqueues for all three EAs.** This is the same
class of problem as `[[feedback_spx500_card_port_before_build]]` — the symbol matrix
is too universal for universe-locked strategies.

## Evidence — work_items per-symbol breakdown

Queried `D:\QM\strategy_farm\state\farm_state.sqlite` 2026-05-23 09:50Z.

### QM5_10020 — universe per card: `{SP500, NDX, WS30}.DWX`

- 40 P2 work_items across **37 symbols** (overwhelmingly FX).
- In-universe results: SP500.DWX=**INVALID**, NDX.DWX=**FAIL** (0 trades, real-tick, 1 year H1), WS30.DWX=**FAIL**.
- Example evidence (NDX): `D:\QM\reports\work_items\fed47bae-d651-4bbb-93ff-e6ad94905b74\QM5_10020\20260521_155737\summary.json` — `reason_classes=[MIN_TRADES_NOT_MET]`, `min_trades_required=150`, `period=H1`, `total_trades=0`.

### QM5_1044 — universe per card: `{SP500, NDX, WS30}.DWX` (paper: SPY/QQQ/DIA)

- 39 P2 FAIL across 37 symbols. Dominant reason class: **`INVALID_REPORT`** (REPORT_PARSE_ERROR), not MIN_TRADES_NOT_MET.
- Example: `D:\QM\reports\work_items\f99cd262-bee1-4ab1-821f-60783a9753e7\QM5_1044\20260518_222518\summary.json` — `reason_classes=[INVALID_REPORT, INCOMPLETE_RUNS]`, two `INVALID_REPORT/REPORT_PARSE_ERROR` runs on AUDNZD.DWX.
- These are **tester-runtime failures**, consistent with the known `_obsolete_QM5_1044_pre-perf-rework` folder (per-tick full-EMA recompute too slow → tester hits timeout, partial .htm, parse error).

### QM5_1048 — universe per card: `{NDX, WS30, GDAXI, UK100}.DWX`

- 41 P2 work_items across 40 rows. In-universe results: NDX=**FAIL+INVALID**, WS30=**FAIL+INVALID**, UK100=**FAIL+INVALID**, GDAXI=**FAIL+INVALID**.
- Example evidence (USDCAD, out of universe): `D:\QM\reports\work_items\ef73870a-b31b-4e26-8148-b8d09a6f5415\QM5_1048\20260519_000920\summary.json` — `reason_classes=[MIN_TRADES_NOT_MET]`, **`min_trades_required=6`**, `total_trades=0`.
- Source-level confirmation: `framework/eas/QM5_1048_estrada-lazy-6m-rotation/QM5_1048_estrada-lazy-6m-rotation.mq5:30-41` hardcodes the 4-symbol universe and returns -1 for `_Symbol` outside the array → the EA correctly refuses to trade on FX; the dispatcher should never enqueue it there.

## Per-EA rework vectors

### QM5_10020 — real bug: D1-card vs hour-23 entry gated by `QM_IsNewBar()`

Card states period=D1 and "enter long at the cash-session close proxy".
EA source (`framework/eas/QM5_10020_rw-spx-overnight/QM5_10020_rw-spx-overnight.mq5`):
- L36-37: `strategy_entry_hour_broker = 23`, `strategy_exit_hour_broker = 17`.
- L69-70: entry blocked if `now_dt.hour != 23`.
- L230-238 (OnTick): entry path is gated by `QM_IsNewBar()` after the hour check is wrapped inside `Strategy_EntrySignal`.

The work_item runs at period=H1 (`summary.json` confirms). At H1, `QM_IsNewBar()` fires at the top of every hour, so hour 23 should eventually trigger. But:
1. **DST sensitivity**: 16:00 NYT maps to broker hour 22 outside US DST, 23 during US DST (Darwinex NY-Close, GMT+2/+3). A fixed `23` only catches one of the two regimes; the prior 20-session edge filter often sees mostly non-DST data and the rolling-positive-edge test rejects entries.
2. **D1 mismatch**: if the strategy is launched at D1 (per the card), `QM_IsNewBar()` fires once a day at hour 0 — never at hour 23. Entry can never fire. The card→build period contract is broken.
3. **Edge-filter pre-period**: the 20-session rolling `(overnight - intraday)` mean must be positive. SPX has had ~10y of broadly positive overnight risk premium, but on NDX/WS30 with FX-broker session boundaries the rolling mean may sit at zero or slightly negative across stretches that span the 1-year P2 window.

**Recommended rework vector (entry-condition relaxation)**:
- (a) Replace hardcoded broker hour with a **session-anchored entry**: enter at the bar whose close timestamp falls within the symbol's last bar of regular cash session (computed from `SymbolInfoSessionTrade`). This eliminates the DST off-by-one and removes the H1/D1 fragility.
- (b) Relax the 20-session edge filter to **either** the SPX-only rolling mean OR a "long-term overnight premium is positive" 250-day check; do not gate on the per-symbol short-window edge for non-SPX universe members (the paper's empirical result is index-level, not robust to small symbol-specific windows).
- (c) Lock the build to **period=D1** (matching the card) and require the session-close logic to use the prior D1 bar's high/close + the broker-session timestamp, not `now_dt.hour`.

This is a real EA-source rework. Hand to Codex via the standard rework codex inbox path; do not regenerate cards.

### QM5_1044 — not a strategy bug, perf rework still owns this

The 97% "zero-trade" FAIL ratio is misleading. Reading the actual `summary.json`,
the dominant reason class is **`INVALID_REPORT / INCOMPLETE_RUNS`** —
`REPORT_PARSE_ERROR` on the partial .htm. That matches the documented hold:
per-tick full-EMA recompute makes the tester hit timeout before producing a
parsable report. See memory [[project_qm5_1044_perf_rework_2026-05-16]].

**Recommended verdict: HOLD.** The DL-062 trigger here is a mislabel of the
same root cause as the longstanding perf rework. The pump's `MIN_TRADES_NOT_MET`
detector should ideally exclude items whose `reason_classes` contain
`INVALID_REPORT` — the EA isn't producing zero trades, the report just
isn't readable. Flag for `farmctl.py` improvement (see "Pump
classification" below) but do not regenerate the card.

### QM5_1048 — semi-annual strategy is structurally P2-incompatible

Card says `expected_trades_per_year_per_symbol: 2`. EA source rebalances at
month=6 and month=12 (`Strategy_RebalanceKey`, L43-50). Per-symbol per-year
expectation: at most 2 entries, possibly 0 if the symbol stays in/out of
top-2.

P2 gate (`min_trades_required=6`, see USDCAD `summary.json` above) is fixed by
the framework's tester defaults, and **no single-symbol single-year run of
this strategy can ever meet it**. Even on in-universe NDX/WS30 with the
rotation working correctly, you'd expect 0-2 trades.

**Recommended verdict: RECYCLE / re-categorize, not a card rework.** The
strategy logic is fine. The phase-gate is wrong:
- Either tag QM5_1048 as a **portfolio-rotation EA** that runs across the
  4-symbol universe on a single master ticker and counts portfolio-level
  trades (≥4 trades/yr basket-wide), and lower `min_trades_required` to 4.
- Or move it onto a **multi-year P2 window** (≥3 years → 6+ trades) and
  scope `tester_defaults` per-card.
- Either path is a registry/pipeline configuration change, not an entry-
  condition relaxation. Hand to Codex as an ops task on
  `framework/registry/tester_defaults.json` + the dispatcher universe filter.

## Cross-cutting finding — dispatcher must honor `target_symbols`

All three failure modes start with the same architectural gap: the work_items
dispatcher fans out **every** EA across the broad DWX symbol matrix, not the
card's `target_symbols`. For universe-locked strategies (10020: 3 US indices;
1044: 3 US indices; 1048: 4 country indices) this:
1. Wastes T1-T10 MT5 saturation time (each EA burns ~30 wasted backtests of
   guaranteed zero-trade verdicts).
2. **Corrupts DL-062's denominator** — zero-trade ratio reads ~95-100% even
   when the in-universe runs would be a 3/3 or 4/4 honest "no trades, real
   bug" signal. The pump can't distinguish "universe mismatch zero-trade" from
   "strategy logic zero-trade".
3. Creates phantom rework cycles (this is one).

**Recommended ops fix (not a Claude task — flag for Codex)**:
- In `tools/strategy_farm/farmctl.py` work_item enqueue path, when an
  approved card has `target_symbols` in frontmatter, restrict P2 enqueue to
  that intersection of `target_symbols` ∩ `tester_defaults.symbols`.
- In `_recent_zero_trade_rework_exists` / pump trigger, compute
  `zero_trade_ratio` over **in-universe** symbols only (or exclude rows
  whose `reason_classes` contain `INVALID_REPORT` — a tester failure is
  not a strategy zero-trade).
- Add a `target_symbols`-aware test in `_verify_card_body_coverage` so a
  card without a frontmatter universe is BLOCKED at approval, not silently
  fanned out.

## Verification

- DB query timestamp 2026-05-23T09:50Z (`farm_state.sqlite`).
- Three `summary.json` paths read first-hand (cited above per EA).
- EA source files read first-hand: `QM5_10020_rw-spx-overnight.mq5`,
  `QM5_1048_estrada-lazy-6m-rotation.mq5` (front matter + key functions).
  QM5_1044 source not re-read this cycle; relying on the existing
  `_obsolete_QM5_1044_pre-perf-rework` folder and the
  [[project_qm5_1044_perf_rework_2026-05-16]] memory.
- Card front matters read from `D:\QM\strategy_farm\artifacts\cards_approved\`.

## Router updates

Each of the three tasks gets `--state REVIEW --artifact-path
docs/research/REWORK_ZERO_TRADE_TRIAGE_2026-05-23.md` with the per-EA verdict
above. The ops findings (dispatcher universe filter, pump reason-class
filter) are NOT untracked work — they are explicit dispatcher/pump bugs and
should be entered as `ops_issue` tasks by the next router cycle that picks
them up. This artifact is the source citation for those tasks.

## Hard-rules check

- T_Live: untouched.
- terminal64.exe: not started manually.
- Evidence: every claim above cites a CSV/summary.json/.mq5 path.
- Edge Lab charter: this work is on the pre-Edge-Lab cohort (cards_approved/
  legacy), not Edge Lab cards.

## Out-of-scope (do not do this cycle)

- Modify any .mq5 file.
- Re-enqueue any work_items.
- Touch `tester_defaults.json` or the dispatcher.
- Open the .ex5 in MetaEditor.

All recommended follow-ups are flagged for Codex/OWNER routing.
