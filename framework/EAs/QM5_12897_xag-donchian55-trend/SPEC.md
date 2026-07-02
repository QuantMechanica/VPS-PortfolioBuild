# QM5_12897_xag-donchian55-trend - Strategy Spec

**EA ID:** QM5_12897
**Slug:** `xag-donchian55-trend`
**Source:** `SZAKMARY-COMM-TREND-2010` (see `strategy-seeds/sources/SZAKMARY-COMM-TREND-2010/`)
**Author of this spec:** Codex
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

This EA trades `XAGUSD.DWX` D1 as a solo silver trend-following sleeve. On each
new D1 bar it enters long when the prior close breaks above the prior 55-close
Donchian channel and ADX(14) is at least 25, and enters short on the symmetric
downside breakout. Positions carry a 2.0 * ATR(20) hard stop and exit on the
opposite 20-close channel or after 90 D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_donchian_entry_period` | 55 | 40-65 | D1 close-channel lookback for breakout entry |
| `strategy_donchian_exit_period` | 20 | 10-20 | D1 close-channel lookback for contra-channel exit |
| `strategy_adx_period` | 14 | 14 | ADX period used for the trend-regime filter |
| `strategy_adx_threshold` | 25.0 | 20.0-30.0 | Minimum ADX required for new entries |
| `strategy_atr_period` | 20 | 14-30 | ATR period used for the hard stop |
| `strategy_atr_stop_mult` | 2.0 | 1.5-2.5 | ATR multiple for the hard stop |
| `strategy_max_hold_bars` | 90 | 60-120 | Stale-position exit in D1 bars |
| `strategy_max_spread_points` | 300 | 200-500 | Maximum allowed entry spread in points |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAGUSD.DWX` - solo silver commodity exposure, magic slot 0.

**Explicitly NOT for:**
- `XAUUSD.DWX` - the book already has heavy XAU exposure; this sleeve targets silver.
- `XNGUSD.DWX` and `XTIUSD.DWX` - separate energy sleeves and different market drivers.
- XAU/XAG, oil/silver, or gas/silver logical baskets - this EA is not a spread package.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 18 |
| Typical hold time | Days to months |
| Expected drawdown profile | Medium-high; silver trend systems whipsaw but are positively skewed |
| Regime preference | Commodity trend / breakout |
| Win rate target (qualitative) | Low-medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `SZAKMARY-COMM-TREND-2010`
**Source type:** `academic_paper`
**Pointer:** `https://doi.org/10.1016/j.jbankfin.2009.10.012`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12897_xag-donchian55-trend.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% - 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-02 | Initial build from approved card | build task 5188178a-5424-4299-94b3-4fc07d56ab63 |
