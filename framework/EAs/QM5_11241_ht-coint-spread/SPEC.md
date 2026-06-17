# QM5_11241_ht-coint-spread — Strategy Spec

**EA ID:** QM5_11241
**Slug:** `ht-coint-spread`
**Source:** `af021dd0-e07d-5f72-9933-de7a3533934e` (Hudson & Thames, Arbitrage Research "Mean Reversion" notebook)
**Author of this spec:** Claude
**Last revised:** 2026-06-17

---

## 1. Strategy Logic

Cointegration relative-value pairs (statistical-arbitrage) trade on two
cointegrated `.DWX` symbols, evaluated on completed D1 bars. On each new D1 bar
the EA fits a static Engle-Granger hedge ratio by OLS of the host close on the
partner close over a FORMATION window (`formation_bars` bars), forms the spread
`spread = host - (intercept + slope*partner)`, then standardises the latest
spread over a shorter trailing z-window (`z_window` bars) into a z-score
`z = (spread - mean) / std`.

The pair only trades once cointegration is qualified deterministically: the
spread std must be > 0, a bounded AR(1) fit of the spread must show negative
mean-reversion speed (`lambda < 0`), and the resulting half-life
`-ln(2)/lambda` must fall inside `[min_half_life, max_half_life]`. (No statistics
library exists in MQL5, so the card's ADF `p <= adf_p_max` intent is realised by
this bounded mean-reversion + half-life gate — the deterministic core of the
Chan / Engle-Granger half-life test. No external feed, no ML.)

Entry trades the SPREAD market-neutrally: when `z >= +entry_z` the spread is rich
so the EA SELLs the host leg and BUYs the partner leg (short-spread); when
`z <= -entry_z` the spread is cheap so it BUYs the host and SELLs the partner
(long-spread). Exit is the card's mean band: close both legs when `|z| <= exit_z`.
A safety stop closes the pair when `|z| >= stop_z`, and a time stop closes it
after `min(3*half_life, time_stop_cap)` D1 bars. The host leg is sent through the
framework magic (slot = `qm_magic_slot_offset`); the partner leg is sent on a
foreign `.DWX` symbol through the framework basket order path at its own
registered slot. One position per (magic, symbol); both legs open and close
together (partner opened first so a failed partner aborts the pair — no naked leg).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_partner_symbol` | `GBPUSD.DWX` | any registered partner `.DWX` | Leg-2 (partner) symbol read for the spread and traded opposite the host |
| `strategy_partner_slot` | 1 | 0-9999 | Partner leg's registered magic slot in `magic_numbers.csv` |
| `strategy_formation_bars` | 504 | 252-756 | OLS hedge-ratio formation window in D1 bars |
| `strategy_z_window` | 60 | 20-120 | Trailing window for spread mean/std z-score |
| `strategy_entry_z` | 2.0 | 1.5-2.5 | `\|z\|` entry threshold |
| `strategy_exit_z` | 0.25 | 0.0-0.5 | `\|z\|` mean-band exit threshold |
| `strategy_stop_z` | 4.0 | 3.0-5.0 | `\|z\|` safety stop threshold |
| `strategy_adf_p_max` | 0.10 | 0.05-0.15 | Documented card param; qualification proxy (see §1) |
| `strategy_min_half_life` | 2 | 1-10 | Minimum half-life (D1 bars) for cointegration qualification |
| `strategy_max_half_life` | 60 | 20-60 | Maximum half-life (D1 bars) |
| `strategy_time_stop_cap` | 90 | 30-120 | Hard cap on the `3*half_life` time stop (D1 bars) |
| `strategy_min_d1_bars` | 560 | >= formation+buffer | Skip until both legs have enough synced D1 history |
| `strategy_leg_risk_split` | 0.5 | 0.25-1.0 | Documentary share of RISK_FIXED notionally per leg (lots sized per-leg by framework) |

---

## 3. Symbol Universe

Pairs trade — registered as three economically-cointegrated host/partner pairs.
Host = leg1 (`qm_magic_slot_offset`), partner = leg2 (`strategy_partner_slot`).

**Designed for:**
- `EURUSD.DWX` (slot 0, host A) / `GBPUSD.DWX` (slot 1, partner A) — two USD majors driven by a common USD factor; classic tightly-cointegrated EUR/GBP relative-value pair (card primary candidate).
- `AUDUSD.DWX` (slot 2, host B) / `NZDUSD.DWX` (slot 3, partner B) — antipodean commodity-currency pair, the strongest persistent FX cointegration relationship (card primary candidate).
- `XAUUSD.DWX` (slot 4, host C) / `XAGUSD.DWX` (slot 5, partner C) — gold vs silver precious-metals pair; long-standing cointegrated real-asset relationship (card R3 candidate, both confirmed in `dwx_symbol_matrix.csv`).

All six legs are REAL `.DWX` symbols present in `dwx_symbol_matrix.csv` — no port
was needed (unlike GER40→GDAXI in the sibling QM5_11145).

**Explicitly NOT for:**
- `SP500.DWX` — backtest-only (broker routes no orders); a pairs EA whose legs must both be live-tradable cannot promote an SP500 leg.
- Single-symbol or uncorrelated symbols — the strategy is only meaningful on a cointegrated two-symbol pair.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | partner-symbol D1 closes (cross-symbol, same TF) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~30 (card: 20-45 trades/year/spread after formation filter) |
| Typical hold time | days to a few weeks (spread mean-reversion; time-stop ~ 3×half-life capped 90 D1 bars) |
| Expected drawdown profile | bounded; risk-fixed per leg, market-neutral, safety z-stop caps tail |
| Regime preference | mean-revert (spread reversion around its rolling mean) |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `af021dd0-e07d-5f72-9933-de7a3533934e`
**Source type:** forum/repo (GitHub notebook)
**Pointer:** `https://github.com/hudson-and-thames/arbitrage_research/blob/master/Cointegration%20Approach/mean_reversion.ipynb` (Hudson & Thames; primary reference Ernest P. Chan, "Algorithmic Trading")
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11241_ht-coint-spread.md`

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
| v1 | 2026-06-17 | Initial build from card | two-leg cointegration basket pairs EA; all 6 legs native `.DWX` (no port) |
