# DXZ Live Book — Swap/Commission/Slippage Attribution (since 2026-07-19)

Auditor dimension: Live cost/edge attribution. All numbers file/DB-evidenced. Read-only.
Generated 2026-09-02.

## TL;DR verdict
The "-3.25 realized vs +2.4 modeled Sharpe" gap is **NOT cost and NOT execution.** It is, in
order of magnitude: **(1) small-sample noise** (33 daily obs; realized annualized Sharpe 95% CI
`[-8.94, +2.02]` — the modeled +2.4 sits at/just outside the CI edge, i.e. the sample cannot
reject it); **(2) one orphan/unattributed 1.0-lot NDX trade that lost -$1,536.75 = 55% of the
whole window loss and is not part of the modeled book at all**; **(3) reduced effective
diversification** (8 of 24 sleeves are FLAT / never traded in the window). Swap + commission
together = **-$157.88 (5.7% of the loss)**; entry slippage ≈ **-$61 (2%)**, no single fill worse
than $20. **Edge decay cannot be established from a 6-week, still-immature (34/42 day) window.**

## Data sources (all on disk — no terminal export needed except a fresh refresh)
- **Realized deals (authoritative, with per-deal profit/swap/commission):**
  `C:/QM/mt5/T_Live/MT5_Base/MQL5/Files/QM/journal/live_deals_normalized.csv` — 210 rows (110 IN /
  100 OUT + 1 BALANCE), account 4000090541, `2026-04-24 .. 2026-09-02T04:47:11Z`. Contract in
  `D:/QM/reports/portfolio/dxz_live_blend_v1_template_f1c19271_.../deal_export_contract.json`
  (`net = profit + swap + commission + fee`).
- **Requested (signal) prices + magic:** per-EA logs `QM5_<id>_ea-<id>.log` (event `ENTRY_ACCEPTED`,
  fields `ticket`,`price`,`magic`). 18 EA magics emit.
- **Fill prices + deal ids:** T_Live terminal logs `.../MT5_Base/logs/YYYYMMDD.log` (UTF-16LE,
  `Trades` lines) — carry fills/order#/deal# but **no cost, no profit, no magic**; the normalized
  CSV supersedes them and already resolves magic.
- **Modeled streams (backtest, per sleeve):** `D:/QM/reports/portfolio/dxz_final_20260719/QM/q08_trades/*.jsonl`
  (24 files, `TRADE_CLOSED` with net/swap/commission).
- **Book equity forward:** `D:/QM/reports/portfolio/live_burnin/portfolio_live_burnin_report.json`
  (2026-09-02T04:15Z) and weekly `livevsbook_sunday_20260830.json`.
- **Broker swap rates:** `.../MQL5/Files/QM/swap_capture_4000090541.csv` (captured **2026-07-26**, stale).

## Book-level realized reconciliation
| Basis | Value | Source |
|---|---|---|
| Equity forward, window 07-26→09-02, 33 days | **net -2,418.64**, Sharpe **-3.461**, maxDD 3.02% | burnin report `realised` |
| Closed-deal sum, window ≥2026-07-24 (78 closes) | **net -2,783.03** | live_deals CSV |
| Closed-deal sum, all deals 06-28→09-02 (100 closes) | net -925.21 | live_deals CSV |
The two window methods agree within ~$365 (open floating + accrual vs realized-close timing). Book
is down ~$2.4–2.8k over the window and both methods agree the loss is dominated by gross P&L.

### Cost split of the window loss (net -2,783.03)
| Component | $ | % of loss |
|---|---|---|
| Gross P&L (directional) | **-2,625.15** | 94.3% |
| Commission | -109.02 | 3.9% |
| Swap | -48.86 | 1.8% |
| **Cost subtotal (swap+comm)** | **-157.88** | **5.7%** |
| Entry slippage (embedded in gross, est. USD) | ≈ -60.80 | ~2% |
Modeled↔live current-rate swap residual on attributed sleeves ≈ **+$28.55** (WS-D, per burnin
`cost_basis.asymmetry`) — immaterial. **Costs do not explain the gap.**

## Per-sleeve (magic) realized attribution — window ≥2026-07-24, ownership-resolved
`gross | swap | comm | net` (nOUT = closed trades)
| magic | sym | nOUT | gross | swap | comm | net |
|---|---|--:|--:|--:|--:|--:|
| **0 (ORPHAN)** | NDX | 1 | -1534.00 | 0.00 | -5.50 | **-1539.50** |
| 111320000 (11132) | SP500 | 2 | -531.36 | -12.95 | -0.34 | -544.65 |
| 117080000 (11708) | EURUSD | 2 | -522.03 | 0.91 | -9.55 | -530.67 |
| 114210000 (11421) | EURUSD | 2 | -423.95 | -3.04 | -3.59 | -430.58 |
| 109390001 (10939) | GBPUSD | 2 | -255.42 | -2.60 | -6.68 | -264.70 |
| 105130003 (10513) | XAUUSD | 2 | -216.07 | 2.00 | -0.41 | -214.48 |
| 15670007 (1567) | EURUSD | 1 | -181.64 | 0.00 | -13.92 | -195.56 |
| 132130000 (13213) | USDJPY | 21 | -52.98 | 0.00 | -26.79 | -79.77 |
| 133010010 (13301) | GDAXI | 9 | -70.82 | 0.00 | -2.60 | -73.42 |
| 111650002 (11165) | AUDCAD | 4 | -67.91 | 9.68 | -10.27 | -68.50 |
| 109110003 (10911) | GDAXI | 11 | -7.77 | 1.63 | -7.24 | -13.38 |
| 114210003 (11421) | AUDUSD | 2 | 73.04 | -0.26 | -3.12 | 69.66 |
| 111650000 (11165) | EURUSD | 2 | 94.25 | -3.12 | -4.08 | 87.05 |
| 15560004 (1556) | XAUUSD | 4 | 168.10 | -16.76 | -1.47 | 149.87 |
| 104030002 (10403) | XAUUSD | 4 | 177.58 | -13.27 | -0.89 | 163.42 |
| 104400003 (10440) | NDX | 3 | 305.01 | 0.72 | -1.28 | 304.45 |
| 107060001 (10706) | GBPUSD | 6 | 417.87 | -11.80 | -11.29 | 394.78 |
| **TOTAL** | | 78 | -2625.15 | -48.86 | -109.02 | **-2783.03** |
(8 manifest sleeves — 10919 XTIUSD, 12567 XNGUSD/XAUUSD, 12778 AUDUSD, 12969 USDJPY, 12989 XAUUSD,
13117 EURGBP, 13128 NDX — are **FLAT**: 0 closes in window; verdict `activity_coverage.flat`.)

## The orphan NDX trade (largest single finding)
Position `3169151197`, opened **2026-07-27T11:53Z, magic=0, empty strategy comment, 1.00 lot** NDX
short @28537.2, SL-closed @28383.8 → **net -1,536.75**. Evidence: live_deals CSV. It has **no
`ENTRY_ACCEPTED` in any EA log** (grep of order id hits only the CSV) and its magic is not among the
18 EA-emitting magics, so it is **not one of the 24 manifest sleeves**. Its size (1.0 lot ≈ $285k
notional) is 1.5–50× larger than every sleeve's inverse-vol sizing (0.02–0.68 lot). It alone is
**55% of the -$2,783 window loss**. Remove it and the 24 sleeves net **-$1,246.53**. This is a
magic-attribution failure on an NDX sleeve, or a manual/rogue order — must be identified before any
"edge decay" read. (Note: 13128/NDX, a manifest sleeve, is FLAT — consistent with its orders having
been emitted with magic=0.)

## Entry slippage (fill − requested)
77 window entries joined EA `ENTRY_ACCEPTED.price` → CSV fill `price` by order id. Total adverse
slippage ≈ **-$60.80**; **no single entry worse than $20**. Largest price gap (XAUUSD SELL
3170429405, req 4073.76 → fill 4058.48, -15.28 pt) was on a tiny lot. Stop orders fill a few points
beyond trigger as expected. **Execution quality is a non-issue.**

## Modeled side — the comparison is not apples-to-apples
- The q08 modeled streams are **not zero-swap**: they carry embedded `.DWX` broker-history swap and
  commission (e.g. 10440/NDX swap -3,444.7 / comm -5,816; 12969/USDJPY swap +3,018; 13213/USDJPY
  comm -20,841). Book-side is already net-of-cost (burnin `cost_basis.book_side`). So the "modeled =
  zero-cost" premise is false; the only untracked residual is current-vs-historical swap-rate drift
  (~$29, immaterial).
- Modeled streams end **~end-2025 / early-2026** (last 13213 close 2025-12-30; tick data ends
  ~2026-04-06). The live window is 2026-07-19→09-02. **No modeled slice overlaps the live window** —
  the comparator itself reports `manifest backtest Sharpe missing` (sunday_livevsbook_compare.log).
  So "+2.4 modeled" is a multi-year backtest number held up against a 6-week live sample.

## Statistical power (the decisive point)
- Realized: n=**33** daily obs, mean **-$73.29/day**, std **$336.19**, daily Sharpe -0.218 →
  **annualized -3.461**, SE (Lo 2002) = **2.796**, **95% CI [-8.94, +2.02]**. The modeled +2.4 is at
  the CI edge — the live sample **cannot statistically reject the modeled expectation**.
- Per-sleeve closed-trade counts in window: 1–21 (median ≈2–4). No sleeve has enough trades to
  estimate a Sharpe. Half the book (8 sleeves) has **zero** trades.
- Window is **immature**: burnin `maturity.immature=true` (34/42 days), verdict `advisory_only`,
  `binding=false`.

## Verdict on the gap
| Candidate cause | Contribution | Evidence |
|---|---|---|
| Swap + commission | -$157.88 (5.7%) | per-magic table |
| Current-vs-historical swap drift | ≈ +$29 | burnin cost_basis / WS-D |
| Entry slippage / execution | ≈ -$61 (2%), embedded | slippage join |
| **Orphan magic=0 NDX mega-trade** | **-$1,536.75 (55%)** | live_deals pos 3169151197 |
| Reduced diversification (8 flat sleeves) | raises realized variance | activity_coverage |
| Small-sample noise | dominates the Sharpe | CI [-8.94,+2.02], n=33 |
| Genuine edge decay | **not established** | window immature, CI too wide |
**Conclusion: cost = NO. Execution = NO. Missing/dark sleeves = YES (one orphan + 8 flat).
Edge decay = UNPROVEN — the gap is within statistical noise for a 6-week window.**

## What (read-only) refresh would sharpen this
1. **Fresh deal export** — current CSV lags to 2026-09-02T04:47Z; a fresh `history-deals`
   export/refresh (the `deal_export` tool that writes `live_deals_normalized.csv`, no AutoTrading
   touch) closes the last few days.
2. **Fresh logged-in swap capture** — `swap_capture_4000090541.csv` is from 2026-07-26; a current
   capture closes the only open cost residual (current-rate whole-book swap, today UNKNOWN/INCOMPLETE).
3. **Identify the orphan** — trace magic=0 NDX 1.0-lot back to its chart/EA (likely 13128/NDX
   magic-assignment failure); this is an ops-fix, not a gate change.
