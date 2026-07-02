# QM5_12605_cme-oilgold-brk - Strategy Spec

**EA ID:** QM5_12605
**Slug:** `cme-oilgold-brk`
**Source:** `CME-OIL-GOLD-RATIO-2024` (see `strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/`)
**Author of this spec:** Claude
**Last revised:** 2026-07-02

---

## 1. Strategy Logic

This EA implements a low-frequency structural commodity relative-value sleeve as
a two-leg basket on `XTIUSD.DWX` and `XAUUSD.DWX`. It computes the D1 log spread
`ln(XTIUSD) - beta * ln(XAUUSD)`, enters long-ratio when that spread breaks
above its 120-day channel, enters short-ratio when it breaks below its 120-day
channel, and exits on a 40-day opposite channel break. Each leg carries an
ATR(20) * 3.0 hard stop.

The strategy is intentionally not a duplicate of `QM5_12604_cme-oilgold-ratio`:
this is channel-breakout continuation, not z-score mean reversion. It is also
not `QM5_12578_eia-oilgas-ratio`, because this hedge leg is gold rather than
natural gas.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_entry_lookback_d1` | 120 | 90-252 | D1 spread-channel lookback for breakout entries |
| `strategy_exit_lookback_d1` | 40 | 20-60 | D1 spread-channel lookback for channel exits |
| `strategy_beta` | 1.0 | 0.6-1.2 | Hedge coefficient in the log spread |
| `strategy_atr_period_d1` | 20 | 14-30 | ATR stop period |
| `strategy_atr_sl_mult` | 3.0 | 2.0-4.0 | Per-leg stop multiplier |
| `strategy_xti_max_spread_pts` | 1000 | 700-1500 | XTI entry spread cap |
| `strategy_xau_max_spread_pts` | 500 | 300-800 | XAU entry spread cap |
| `strategy_deviation_points` | 20 | 10-50 | Broker deviation points for market legs |

---

## 3. Symbol Universe

**Designed for:**
- `XTIUSD.DWX` - host chart and oil numerator, magic slot 0.
- `XAUUSD.DWX` - hedge leg and gold denominator, magic slot 1.

**Explicitly NOT for:**
- `XNGUSD.DWX` - covered by separate XNG and XTI/XNG sleeves.
- `XAGUSD.DWX` - covered by the separate XAU/XAG metals ratio.
- Equity indices and FX pairs - different economic exposure from the CME oil/gold ratio source.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | D1 state refresh on `QM_IsNewBar`; entry and exit eval on new D1 bar only |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `7` |
| Typical hold time | `Weeks to months` |
| Expected drawdown profile | `High; channel breakouts can whipsaw in sideways oil/gold regimes` |
| Regime preference | `oil/gold relative-value continuation` |
| Win rate target (qualitative) | `low-medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `CME-OIL-GOLD-RATIO-2024`
**Source type:** `exchange article`
**Pointer:** `https://www.cmegroup.com/articles/2024/through-the-lens-of-gold.html`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12605_cme-oilgold-brk_card.md`

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
| v3 | 2026-07-02 | Full rebuild: 2026-07-02 OnTick order, QM_IsNewBar latch, remove non-card params | Claude; fixes news-before-management violation |
| v2 | 2026-06-28 | Delay basket entry until XAU trade session is open | avoids one-leg XTI packages at the D1 bar open |
| v1 | 2026-06-27 | Initial build from card | pending commit |
