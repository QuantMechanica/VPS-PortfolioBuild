# QM5_11012_the5ers-strength-pair — Strategy Spec

**EA ID:** QM5_11012
**Slug:** `the5ers-strength-pair`
**Source:** `1d445184-7c47-57da-9856-a123682a932d` (see `strategy-seeds/sources/1d445184-7c47-57da-9856-a123682a932d/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-18

---

## 1. Strategy Logic

Currency-strength momentum on H1 with a D1 strength ranking. On each closed H1 bar
the EA computes the strength of the 8 currencies (USD, EUR, GBP, JPY, AUD, CHF, NZD,
CAD) as the mean signed `strategy_strength_lookback`-day percentage return across all
28 major/minor pairs that contain each currency (a pair's return adds to its base
currency and subtracts from its quote currency). It ranks the currencies and picks
the strongest (rank 1) and weakest (rank 8). The EA runs on a host symbol and only
trades when that host symbol IS exactly the rank1-vs-rank8 pair: long if the strong
currency is the host base, short if it is the host quote. The host must then confirm
on H1 — long needs close>EMA50, positive EMA50 slope, and a positive last-bar return
(mirror for short). Exit on momentum reversal (H1 close crosses to the wrong side of
EMA50), on the host no longer being the rank1-vs-rank8 pair in the held direction, on
a 48 H1-bar time stop, on the 1.8R take-profit, or on the 1.5×ATR(H1,14) stop. A
strength spread filter (rank1 minus rank8 must be >= 0.35%) and a liquid-session
(broker-time London/NY) window gate entries while leaving existing-position exits active.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_strength_lookback` | 5 | 3-10 | D1 bars for the percentage-return strength window (P3 sweep {3,5,10}) |
| `strategy_ema_period` | 50 | 20-100 | H1 confirmation/exit EMA period (P3 sweep {20,50,100}) |
| `strategy_atr_period` | 14 | 7-28 | ATR period for the stop and spread cap |
| `strategy_atr_sl_mult` | 1.5 | 1.0-2.0 | Stop distance = mult × ATR(H1) (P3 sweep {1.0,1.5,2.0}) |
| `strategy_tp_rr` | 1.8 | 1.2-2.5 | Take-profit in R multiples (P3 sweep {1.2,1.8,2.5}) |
| `strategy_min_spread_pct` | 0.35 | 0.0-2.0 | Skip if rank1−rank8 strength spread is below this percent |
| `strategy_spread_pct_of_atr` | 20.0 | 5-50 | Skip if host bid/ask spread exceeds this % of ATR(H1) |
| `strategy_time_stop_bars` | 48 | 12-120 | Close the position after this many H1 bars held |
| `strategy_session_start_brk` | 9 | 0-23 | Liquid-session start hour, broker time (London ≈ 09:00) |
| `strategy_session_end_brk` | 21 | 0-23 | Liquid-session end hour, broker time (through NY) |
| `strategy_min_d1_bars` | 60 | 30-300 | Skip a pair / the host until this much history is available |

---

## 3. Symbol Universe

This is a BASKET EA: it reads all 28 model pairs for the strength computation but
only opens a position on the host symbol when the host is the rank1-vs-rank8 pair.

**Designed for (tradable hosts, per the card's target list):**
- `EURUSD.DWX` — major; can be the strong/weak pair for EUR/USD extremes.
- `GBPUSD.DWX` — major; GBP/USD strength swings.
- `USDJPY.DWX` — major; USD/JPY strength swings.
- `AUDUSD.DWX` — major; AUD/USD risk-driven strength.
- `USDCAD.DWX` — major; USD/CAD strength swings.
- `USDCHF.DWX` — major; USD/CHF strength swings.
- `NZDUSD.DWX` — major; NZD/USD strength swings.
- `EURJPY.DWX` — cross; EUR/JPY strength extremes.
- `GBPJPY.DWX` — cross; GBP/JPY strength extremes.

**Read-only strength universe (not host-traded directly unless registered):**
- The remaining DWX majors/minors among the 28 pairs (e.g. EURGBP, AUDNZD, CADCHF…)
  feed the per-currency strength average only.

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the strength model is FX-only; the host
  must decompose into two of the 8 tracked currencies or no trade ever fires.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1 currency-strength reads across the 28-pair universe` |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default; H1) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~80` |
| Typical hold time | `hours to a few days (≤ 48 H1 bars)` |
| Expected drawdown profile | `moderate; trend-following with R-multiple TP and momentum exit` |
| Regime preference | `trend / momentum (strongest-vs-weakest divergence)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1d445184-7c47-57da-9856-a123682a932d`
**Source type:** `blog` (broker/educational blog — The5ers)
**Pointer:** `https://the5ers.com/forex-strength-meter/`
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11012_the5ers-strength-pair.md`

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
| v1 | 2026-06-18 | Initial build from card | dc228327-39b4-47ed-ad4e-94f1fd417be8 |
