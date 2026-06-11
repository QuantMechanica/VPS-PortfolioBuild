# QM5_9636_brooks-failed-ob-h4 — Strategy Spec

**EA ID:** QM5_9636
**Slug:** `brooks-failed-ob-h4`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

On each new H4 bar, the EA scans the last 1–3 closed bars (shifts 2–4) for a single outside bar whose range is between 1.2× and 3.5× ATR(14,H4) and whose close falls in the upper 35% (bull outside bar) or lower 35% (bear outside bar) of its range. A "failed breakout" is confirmed when the most recently closed bar (shift 1) probes beyond the outside-bar extreme by at least 0.05×ATR but then closes back inside that extreme. On confirmation, a market order is placed at the current bar open in the direction of the failure: short after a failed bull outside bar, long after a failed bear outside bar. The stop loss is set at the failed-breakout bar's extreme plus 0.25×ATR. The take-profit is fixed at 1.8×R from entry. Positions are also closed after 12 H4 bars (48 hours) via a time stop. An existing position in the opposite direction is closed before opening the new trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | 5–50 | ATR lookback on H4 for range and SL sizing |
| `strategy_ob_range_min` | 1.2 | 0.5–2.0 | Minimum outside-bar range as ATR multiple |
| `strategy_ob_range_max` | 3.5 | 2.0–6.0 | Maximum outside-bar range as ATR multiple (filters excessive spikes) |
| `strategy_ob_close_pct` | 0.65 | 0.55–0.80 | Close threshold fraction for bull/bear OB classification |
| `strategy_breakout_offset` | 0.05 | 0.01–0.20 | Minimum probe beyond OB extreme (ATR multiples) to qualify as attempted breakout |
| `strategy_sl_atr_buffer` | 0.25 | 0.10–0.50 | SL buffer beyond failed-breakout bar extreme (ATR multiples) |
| `strategy_tp_r_multiple` | 1.8 | 1.0–3.0 | Take-profit as a multiple of the initial risk (R) |
| `strategy_time_stop_bars` | 12 | 5–24 | Maximum H4 bars before time-stop close (12 bars = 48 hours) |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid major FX pair; H4 outside bars are well-formed and frequently respected
- `GBPUSD.DWX` — high-volatility major; generates clear outside bars with meaningful failed-breakout signals
- `USDJPY.DWX` — carries risk-off/on characteristics; failed outside bars mark session-transition reversals
- `XAUUSD.DWX` — gold; large directional moves create outside bars whose failures produce reliable mean-reversion entries

**Explicitly NOT for:**
- Index CFDs (NDX.DWX, WS30.DWX, SP500.DWX) — card basket is FX/gold only; indices were not evaluated

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~35 |
| Typical hold time | 4–48 hours (1–12 H4 bars) |
| Expected drawdown profile | Moderate; 1.8R TP limits winners; time stop limits losers |
| Regime preference | Mean-reversion / failed-breakout |
| Win rate target (qualitative) | Medium (~45–55%) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** Al Brooks price-action outside-bar discussion, ForexFactory Finance Book Club, https://www.forexfactory.com/thread/993609-the-finance-book-club?page=8
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_9636_brooks-failed-ob-h4.md`

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
| v1 | 2026-06-11 | Initial build from card | 892e7d21-99e4-4646-ab74-5b3d016ea806 |
