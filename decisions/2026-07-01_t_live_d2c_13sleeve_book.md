# T_Live decision — D2-c 13-sleeve book (LIVE; retroactive record, 2026-07-01)

## Decision
The **13-sleeve D2-c book is LIVE on Darwinex-Live** (account `4000090541`, terminal
`C:\QM\mt5\T_Live\MT5_Base`). This record is written **retroactively** on 2026-07-01 to close a
governance-trail gap: the live book was grown 8 → 11 → 13 sleeves after the last recorded decision
(`decisions/2026-06-27_t_live_d2a_8sleeve_book.md`, 8-sleeve) **without** a corresponding go-live
record for the D2-b (11) and D2-c (13) generations. The terminal itself is the source of truth
(filesystem > notes); this record reconciles the paperwork to the live reality.

**Go-live moment:** 2026-06-28 11:12 (first load of all 13 experts in the T_Live terminal log,
`Logs/20260628.log`; GDAXI + 12567/XAUUSD attached 11:13). First live deals from 2026-06-29.

**Supersedes:** the 8-sleeve D2-a (2026-06-27) and the never-recorded 11-sleeve D2-b. D2-c is a
**strict superset** of D2-a.

Binding DD cap = **6%** (MC-p95 basis), account risk = **2%** (risk-parity, inverse-vol).

## The 13 live sleeves (T_Live chart profile `DarwinexZero_V1`, chart01–chart13)

| slot | EA | symbol | TF | magic (registry) |
|---|---|---|---|---|
| 0 | QM5_10440 mql5-ohlc-mtf | NDX | H1 | 104400003 |
| 1 | QM5_10513 mql5-ichimoku | XAUUSD | D1 | 105130003 |
| 2 | QM5_10692 tv-ls-ms | NDX | H1 | 106920005 |
| 3 | QM5_10715 tv-asian-box | USDJPY | M15 | 107150004 |
| 4 | QM5_10911 grimes-complex-pb | GDAXI | H1 | 109110003 |
| 5 | QM5_10939 grimes-context-pb | GBPUSD | H4 | 109390001 |
| 6 | QM5_10940 grimes-nested-pb | XAUUSD | H4 | 109400003 |
| 7 | QM5_11132 tm-cum-rsi2 | SP500 | D1 | 111320000 |
| 8 | QM5_11165 weiss-rsi-ma | AUDCAD | H1 | 111650002 |
| 9 | QM5_11421 ohlc-daily-squeeze-reversal-d1 | AUDUSD | D1 | 114210003 |
| 10 | QM5_11421 ohlc-daily-squeeze-reversal-d1 | EURUSD | D1 | 114210000 |
| 11 | QM5_12567 cum-rsi2-commodity | XAUUSD | D1 | 125670003 |
| 12 | QM5_12567 cum-rsi2-commodity | XNGUSD | D1 | 125670002 |

**Delta vs the recorded D2-a 8-book (the 5 additions = the "8→~12 uncorrelated" breadth push the
D2-a record named as the lever to mission-grade):**
- **10911 GDAXI H1** — index breadth (German index; no prior DAX sleeve).
- **11165 AUDCAD H1**, **11421 AUDUSD D1**, **11421 EURUSD D1** — FX anti-corr diversifiers,
  admitted via **DL-078** (standalone regime-catastrophe no longer hard-rejects; each lowers book DD
  in the greedy sequence). Mild AUD/EUR FX concentration; each within the corr≤0.30 cap.
- **12567 XAUUSD D1** — cum-RSI2 MR, 2nd symbol of the XNG EA (gold MR).

## Verification (T_Live workflow step 3 — re-run 2026-07-01, read-only)
- ✅ **EA binaries SHA256-identical to framework** — all 11 distinct `.ex5` in
  `MQL5\Experts\Live EAs\` match `framework/EAs/<slug>/<slug>.ex5` (11 binaries → 13 sleeve
  attachments; 10440/10692 both NDX are distinct EAs, 11421 and 12567 each carry 2 symbols).
- ✅ **Magics registry-consistent** — each `ea_id*10000 + symbol_slot` matches
  `framework/registry/magic_numbers.csv`; no cross-symbol overlap.
- ✅ **Live presets present** — all 13 in `MQL5\Presets\` (`slot{0..12}_..._live.set` naming),
  ENV=live convention (RISK_FIXED=0 + RISK_PERCENT per inverse-vol weight).
- ✅ **D2c preflight PASS** — `C:\QM\deploy\GoLive_D2c_13sleeve_2026-06-28\D2C_PREFLIGHT_2026-06-28.json`
  (verdict PASS, 0 findings, 13 ex5_checks + 13 setfile_checks, news guardrail PASS).
- ⚠️ **XNGUSD timeframe fix (2026-07-01):** the XNG sleeve (12567) was attached to an **H1** chart
  in the live terminal (startup logs 06-28/07-01 show `XNGUSD,H1`), but the sleeve was validated on
  **D1** and its preset `slot12_XNGUSD_D1_...` is D1. **OWNER corrected the chart to D1 on
  2026-07-01.** The XAUUSD copy (slot11) was already correct (Daily). Terminal-log confirmation of
  the reattach will appear as `XNGUSD,Daily` on the next terminal restart (a chart-TF change does
  not emit its own "loaded successfully" line).

## Live evidence (account 4000090541, Darwinex-Live, "trading enabled — hedging mode")
Active trading confirmed across multiple sleeves (`Logs/2026062[89],20260630,20260701.log`):
- **11132 SP500** — buy 0.34 @ 7360.7 (06-29 00:00) → sell 0.34 @ 7449.1 (06-30 00:00): **+88.4 pts
  closed profit** (deals #145900211 / #146054123).
- **10940 XAUUSD** — sell 0.11 @ 4023.65 (06-29 18:59), SL trailed to BE (06-30 03:07) → buy 0.11 @
  4022.48 (06-30 08:32): **~breakeven closed** (deals #146031307 / #146117483).
- **10911 GDAXI** — buy 0.38 @ 25052.2, SL 24881.8 / TP 25307.8 (06-30 20:59, deal #146226519):
  **the 1 currently-open position** (07-01 08:45 sync = "1 positions, 0 orders").
- **11421 EURUSD** — sell-stop pending-order management active (06-28/06-29).

## KPIs
Manifest `manifest_d2c_13sleeve_2026-06-28.json` (canonical $100k, RISK_FIXED basis,
commission_basis=worst_case_dxz_ftmo, 1821 days):
- observed MaxDD **0.5126%**, MC-p95 DD **0.9223%**, Sharpe **1.6992**, net-of-cost **$6,659.76**,
  `cap_met=true` under the 6% cap.
- **These are risk-parity weighted-average (analysis) numbers, NOT the deployment.** The LIVE book
  runs each sleeve independently at flat RISK_PERCENT ~0.75% → the deployed book is the **SUM** of
  the sleeves: real ≈ **15.3%/yr, 17.4% 8yr MaxDD, 3.26% monthly VaR**, which Darwinex's D-Leverage
  normalizes to a ~30%/yr rating. Evidence: `docs/ops/DXZ_FTMO_BOOK_SIZING_REAL_0p75_2026-06-30.md`.
  **Do not raise raw risk — DXZ already fills the VaR target.**

## Governance notes
- This record is **retroactive**. Future D-generation go-lives must be recorded at flip time
  (Hard-Rule step 5), not after the fact.
- The generated manifest artifacts still carry `status=DRAFT_FOR_OWNER_APPROVAL`,
  `deployment_action=NONE` — that is the **default output of `portfolio_manifest.py`** and is not
  live-truth. The authority for "OWNER-approved + live" is **this decision record**. A live-status
  marker (`D2C_GO_LIVE_STATUS_2026-07-01.json`) is also written into the D2-c deploy folder.
- `D:\QM\reports\state\book_monitor_state.json` is a **stale 5-sleeve exploratory-pool** snapshot,
  not the live book — harmless (it tracks the FAIL_SOFT robust pool, not T_Live), do not read it as
  the live book.
- **No T_Live trading-state action was taken by Claude in this record** (read-only verification).
  The XNGUSD D1 chart correction was performed by OWNER.

## Forward
Deployment is done; at 13 sleeves the DXZ book is VaR-filled (don't scale risk). Book growth =
new *orthogonal* sleeves: the calendar-MR demonstrators **12836 (Turnaround Tuesday)** + **12847
(Turn-of-Month)** are at Q02 (near-zero expected corr). FTMO remains a separate book needing
intraday sprinters (the 1307-item intraday funnel + intraday-DD capture).
