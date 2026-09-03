# Q11/Q15 Portfolio Fit Report - 2026-09-03

Generated 2026-09-03T16:04:36+00:00 (UTC). **Read-only, analytic; application authority OWNER_ONLY, deployment/AutoTrading action NONE.** This report changes no book, weight, verdict, or live state.

Tool: `tools/strategy_farm/q15_fit_report.py` (closes runbook gap G2). Pool membership is exactly `book_build_guard`'s census; return streams are the sealed q08 daily-PnL streams `portfolio_correlation.py` uses.

## 1 - Qualified pool (book_build_guard census)

- Terminal requalification gate: `Q14`; venue `both`.
- `qualified_pairs = 5`, `distinct_eas = 5`, `strategy_families = 5`; guard `allowed = false`.
- Guard reasons:
  - `qualified_pairs_below_minimum: 5 < 25`
  - `owner_order_missing: venue=both order_dir=C:\QM\repo\.claude\worktrees\wf_8c3a9afe-b0f-2\decisions`

| EA:symbol | family | asset class | trades | active days | first | last |
|---|---|---|---:|---:|---|---|
| 1537:XAGUSD.DWX | aa | metals | 22 | 22 | 2024-01-17 | 2024-12-06 |
| 10706:GBPUSD.DWX | tv | fx | 366 | 366 | 2017-10-10 | 2025-12-30 |
| 11421:EURUSD.DWX | ohlc | fx | 92 | 92 | 2018-05-11 | 2025-12-11 |
| 11422:USDCAD.DWX | williams | fx | 197 | 197 | 2018-03-02 | 2025-12-26 |
| 13054:XTIUSD.DWX | brent | energy | 83 | 83 | 2018-03-02 | 2025-12-30 |

## 2 - Correlation matrix (daily net-of-cost P/L)

Pearson on co-active days (both members non-zero). Overlap floor `min_overlap_days = 60` (portfolio_correlation.py build_artifact default; docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 212-214 (Vault Q15 V4)). A pair below the floor is `NOT_EVALUABLE` (never a fabricated number).

| r \\ overlap | 1537:XAGUSD.DWX | 10706:GBPUSD.DWX | 11421:EURUSD.DWX | 11422:USDCAD.DWX | 13054:XTIUSD.DWX |
|---|---|---|---|---|---|
| 1537:XAGUSD.DWX | 1.0 | NE (ov=4) | NE (ov=2) | NE (ov=5) | NE (ov=1) |
| 10706:GBPUSD.DWX | NE (ov=4) | 1.0 | NE (ov=12) | NE (ov=27) | NE (ov=8) |
| 11421:EURUSD.DWX | NE (ov=2) | NE (ov=12) | 1.0 | NE (ov=26) | NE (ov=11) |
| 11422:USDCAD.DWX | NE (ov=5) | NE (ov=27) | NE (ov=26) | 1.0 | NE (ov=22) |
| 13054:XTIUSD.DWX | NE (ov=1) | NE (ov=8) | NE (ov=11) | NE (ov=22) | 1.0 |

- Union trading days: `656` (2017-10-10 -> 2025-12-30).
- Evaluable pairs: `0`; NOT_EVALUABLE pairs: `10` (overlap below floor).
- NOT_EVALUABLE pairs (overlap days):
  - 1537:XAGUSD.DWX x 10706:GBPUSD.DWX: `4` days
  - 1537:XAGUSD.DWX x 11421:EURUSD.DWX: `2` days
  - 1537:XAGUSD.DWX x 11422:USDCAD.DWX: `5` days
  - 1537:XAGUSD.DWX x 13054:XTIUSD.DWX: `1` days
  - 10706:GBPUSD.DWX x 11421:EURUSD.DWX: `12` days
  - 10706:GBPUSD.DWX x 11422:USDCAD.DWX: `27` days
  - 10706:GBPUSD.DWX x 13054:XTIUSD.DWX: `8` days
  - 11421:EURUSD.DWX x 11422:USDCAD.DWX: `26` days
  - 11421:EURUSD.DWX x 13054:XTIUSD.DWX: `11` days
  - 11422:USDCAD.DWX x 13054:XTIUSD.DWX: `22` days

## 3 - Effective number of bets (ENB)

- Formula: ENB = (sum_i lambda_i)^2 / (sum_i lambda_i^2), where lambda_i are the eigenvalues of the N x N Pearson correlation matrix C. Because trace(C) = sum_i lambda_i = N, this equals N^2 / sum_i lambda_i^2, and sum_i lambda_i^2 = ||C||_F^2 = sum_{i,j} C_ij^2 (Frobenius identity). ENB = N when all members are mutually uncorrelated and ENB = 1 when all members are perfectly correlated.
- Reference: Meucci, A. (2009), 'Managing Diversification', Risk 22(5), 74-79 (diversification distribution / effective number of bets); the closed form used here is the inverse participation ratio (effective rank) of the correlation eigenvalue spectrum.
- **ENB = `NOT_EVALUABLE`** - 10 of 10 off-diagonal pairs are NOT_EVALUABLE (below the 60-day overlap floor); ENB requires a complete correlation matrix.

## 4 - Per-member marginal Sharpe (leave-one-out)

- Formula: Pool daily series P(d) = sum_k x_k(d) over the union of all members' trade days, where x_k(d) is member k's daily net-of-cost P/L (0 on days k did not close a trade) at equal unit weight (no per-sleeve risk weights exist pre-Q15). Sharpe_daily(S) = mean(S) / stdev(S) with sample stdev (ddof=1); non-annualized (the union grid is irregular, so no periods-per-year constant is invented). Marginal Sharpe of member m = Sharpe_daily(P) - Sharpe_daily(P - x_m) on the same fixed union grid (leave-one-out).
- Series units: daily net-of-cost P/L (account currency), equal unit weight, RISK_FIXED backtest scale.
- Pool daily Sharpe over `656` union days: `0.0781`.

| Member | leave-one-out Sharpe | marginal Sharpe |
|---|---:|---:|
| 1537:XAGUSD.DWX | 0.0764 | 0.0018 |
| 10706:GBPUSD.DWX | 0.0628 | 0.0153 |
| 11421:EURUSD.DWX | 0.0763 | 0.0019 |
| 11422:USDCAD.DWX | 0.0670 | 0.0112 |
| 13054:XTIUSD.DWX | 0.0744 | 0.0037 |

- Positive marginal Sharpe = the member raises the pooled daily Sharpe; negative = it lowers it. Non-annualized.

## 5 - Symbol / asset-class / family coverage

| Asset class | count | members |
|---|---:|---|
| energy | 1 | 13054:XTIUSD.DWX |
| fx | 3 | 10706:GBPUSD.DWX, 11421:EURUSD.DWX, 11422:USDCAD.DWX |
| metals | 1 | 1537:XAGUSD.DWX |

## 6 - Cap checks (all thresholds cited; none invented)

- **Correlation `|r| < 0.5`** (docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 213-214 (Vault Q15 hard rule)): `NOT_ASSERTABLE` - 0/10 pairs evaluable, 10 NOT_EVALUABLE.
- **Family `<= 3` members** (docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 202-203 (Vault Q15 hard caps)): `PASS` - 5 distinct families.
  - aa: `1` (PASS) [1537:XAGUSD.DWX]
  - brent: `1` (PASS) [13054:XTIUSD.DWX]
  - ohlc: `1` (PASS) [11421:EURUSD.DWX]
  - tv: `1` (PASS) [10706:GBPUSD.DWX]
  - williams: `1` (PASS) [11422:USDCAD.DWX]
- **Symbol `<= 2` members** (docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 202-203 (Vault Q15 hard caps)): `PASS` - 5 distinct symbols.
- **Book size `10-15` EAs** (docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md lines 202-203 (Vault Q15 hard caps)): `BELOW_BAND` - N=`5`.

## 7 - Risk-budget frame (OWNER decision, not applied here)

- No per-sleeve risk weight is proposed or applied by this tool. Weight allocation and the total-risk level are OWNER acts at runbook steps 6-7 (`docs/ops/BOOK_CEREMONY_RUNBOOK_2026-09.md` step list section 2; V6 line 219). The SP-C3 stop-risk concentration budget (symbol 40% / asset-class 60% / family 50% of the 2.5% stop-risk budget) is evaluated by `portfolio/concentration_tail.py` against a manifest with weights - out of scope until an OWNER weight vector exists.
- The DXZ builder default total-risk is `--total-risk-pct 9.75` (runbook V6, line 219); no change is proposed here.

## 8 - Provenance and read-only statement

- Farm DB: `D:\QM\strategy_farm\state\farm_state.sqlite` (read-only via rebaseline_census.open_ro (mode=ro)).
- Streams: `portfolio_common.load_streams (Common/Files/QM/q08_trades)` under `C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\Common\Files`.
- Commission basis: `worst_case_dxz_ftmo`; degraded: `false`.
- This report created no book, manifest, sleeve, weight, order file, live/T_Live state, gate threshold, verdict, trade stream, queue row, or DB change. Every application step remains a separate OWNER act.
