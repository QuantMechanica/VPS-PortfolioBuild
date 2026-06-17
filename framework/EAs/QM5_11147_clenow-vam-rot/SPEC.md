# QM5_11147_clenow-vam-rot — Strategy Spec

**EA ID:** QM5_11147
**Slug:** `clenow-vam-rot`
**Source:** `2b7435de-4a8d-5fb9-a03d-a032f026fd6b` (Andreas F. Clenow, *Stocks on the Move*, 2015, ISBN 9781511466141)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Long-only cross-sectional volatility-adjusted momentum rotation on a fixed
10-symbol DWX universe (US/EU indices, metals, oil, FX majors), evaluated weekly
on the Wednesday D1 close. Every week the EA ranks all universe members by a
volatility-adjusted momentum score: it fits an ordinary-least-squares line to the
last 90 daily `ln(close)` values, annualises the slope, and multiplies by the
regression R² (so steady, high-fit trends rank above noisy ones). A member is
eligible only if its close is above its 100-day SMA and no single-day return in
the 90-bar window exceeds 15%. A market-regime filter blocks all new longs while
SP500.DWX is below its 200-day SMA. The EA runs one instance per host symbol and
opens a BUY only when the host is itself eligible, ranks in the top 6, has a
positive score, and the regime is not bearish. It exits the host when the host
loses eligibility, leaves the top 6+2 (buffer) ranks, its score turns
non-positive, or the regime stays bearish for two consecutive weekly evaluations.
A catastrophic 3.0× ATR(20, D1) stop bounds gap risk; the rank/rebalance exit is
the primary close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_rank_lookback` | 90 | 60-120 | D1 bars for the OLS slope/R² and the outlier scan |
| `strategy_elig_sma` | 100 | 80-120 | Eligibility SMA period (close must be above) |
| `strategy_market_sma` | 200 | 150-250 | SP500.DWX regime-filter SMA period |
| `strategy_outlier_pct` | 15.0 | 10-20 | Reject member if any 1-day \|return\| in window exceeds this % |
| `strategy_top_n` | 6 | 3-6 | Basket size — host must rank inside this to ENTER |
| `strategy_rank_buffer` | 2 | 0-4 | Hold tolerance beyond top-N before a rank-based EXIT |
| `strategy_atr_period` | 20 | 10-30 | Catastrophic-stop ATR period (D1) |
| `strategy_stop_atr_mult` | 3.0 | 2.5-3.5 | Emergency stop distance = mult × ATR |
| `strategy_min_warmup_bars` | 120 | 120-300 | Min D1 bars required per member |
| `strategy_min_universe_active` | 4 | 4-8 | Min members with valid rank data for a usable rank |
| `strategy_rebalance_weekday` | 3 | 0-6 | Broker-time weekday of the weekly eval (3 = Wednesday) |
| `strategy_spread_pct_of_stop` | 20.0 | 10-50 | Skip if host spread > this % of stop distance |

---

## 3. Symbol Universe

The cross-sectional universe is fixed inside the EA; every instance reads all ten
members on D1 to rank them, and trades only the host.

**Designed for (all 10 are rankable members AND tradable hosts except SP500):**
- `SP500.DWX` — S&P 500; backtest-only regime proxy (200-day SMA) and rankable member. NOT a live host (not broker-routable).
- `NDX.DWX` — Nasdaq 100; liquid US index, live-tradable host.
- `WS30.DWX` — Dow 30; liquid US index, live-tradable host.
- `GDAXI.DWX` — DAX 40; EU index host (card GER40 → GDAXI nearest-matrix port).
- `UK100.DWX` — FTSE 100; EU index host (card FTSE100 → UK100 nearest-matrix port).
- `XAUUSD.DWX` — Gold; metal trend member/host, low common beta with indices.
- `XTIUSD.DWX` — WTI crude; commodity trend member/host.
- `EURUSD.DWX` — FX major; diversifying member/host.
- `GBPUSD.DWX` — FX major; diversifying member/host.
- `USDJPY.DWX` — FX major; diversifying member/host.

**Explicitly NOT for:**
- Individual S&P 500 stocks — the native Clenow universe; not available as DWX CFDs, so the card ports to the liquid index/metal/oil/FX basket above.
- `SPX500.DWX` / `SPY.DWX` / `ES.DWX` — not canonical DWX symbols; only `SP500.DWX` exists.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (all reads on D1 across the 10-symbol universe) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default), rank advanced only on the rebalance weekday |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (card: 8-18 entries/year/symbol on the reduced DWX basket) |
| Typical hold time | Weeks to months (weekly rank/rebalance system) |
| Expected drawdown profile | Medium-high; smaller, more macro-correlated universe than native S&P 500 basket — concentration/common-beta risk |
| Regime preference | Trend (cross-sectional momentum; gated off when SP500 below its 200-day SMA) |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2b7435de-4a8d-5fb9-a03d-a032f026fd6b`
**Source type:** book
**Pointer:** Andreas F. Clenow, *Stocks on the Move: Beating the Market with Hedge Fund Momentum Strategies* (2015, ISBN 9781511466141); official page https://www.followingthetrend.com/stocks-on-the-move/ ; public rule summary https://www.turingtrader.com/portfolios/clenow-stocks-on-the-move/
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11147_clenow-vam-rot.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-17 | Initial build from card | basket EA; GER40→GDAXI, FTSE100→UK100 ports flagged |
