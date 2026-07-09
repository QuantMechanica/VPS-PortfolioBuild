# QM5_13081_xcu-4w-reversal - Strategy Spec

**EA ID:** QM5_13081
**Slug:** `xcu-4w-reversal`
**Source:** `YANG-CME-USGS-XCU-REVERSAL-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades a weekly D1 overreaction reversal on `XCUUSD.DWX`. On the first
D1 bar of the trading week, it measures the prior closed D1 close against the
close 20 D1 bars earlier. If copper has fallen at least 4 percent, it buys. If
copper has risen at least 4 percent, it sells. Positions exit after 21 calendar
days or via a fixed ATR stop.

This is deliberately different from `QM5_13080_xcu-donchian55`, which follows
copper trends through channel breakouts. This card fades short-horizon copper
overreactions on a weekly cadence.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_lookback_days` | 20 | 15-30 | D1 bars used for the short-term overreaction return |
| `strategy_atr_period` | 14 | 10-20 | ATR period for the hard stop |
| `strategy_min_abs_return_pct` | 4.0 | 3.0-7.0 | Minimum absolute lookback return needed for a reversal setup |
| `strategy_atr_sl_mult` | 2.5 | 2.0-3.5 | Hard stop distance in ATR units |
| `strategy_max_hold_days` | 21 | 14-28 | Calendar-day time stop |
| `strategy_max_spread_points` | 1200 | 800-1800 | Entry spread cap |

---

## 3. Symbol Universe

**Designed for:**

- `XCUUSD.DWX` - copper/base-metal CFD available in the DWX symbol matrix.

**Explicitly NOT for:**

- `XAUUSD.DWX` and `XAGUSD.DWX` - precious-metal and silver sleeves have
  separate logic.
- `XTIUSD.DWX`, `XBRUSD.DWX`, and `XNGUSD.DWX` - separate energy sleeves.
- Equity indices and FX pairs - outside this commodity-reversal card.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar()` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 12 |
| Typical hold time | 1-21 calendar days |
| Expected drawdown profile | Medium-high; fades copper extremes with fixed ATR loss control |
| Regime preference | Short-term base-metal mean reversion after large 4-week moves |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `YANG-CME-USGS-XCU-REVERSAL-2026`
**Source type:** academic paper plus official exchange/government references
**Pointer:** `https://papers.ssrn.com/sol3/papers.cfm?abstract_id=3069253`
**R1-R4 verdict (Q00):** all PASS / see
`strategy-seeds/cards/xcu-4w-reversal_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV-mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). The committed Q02 setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | Mission-directed XCU four-week reversal sleeve |

