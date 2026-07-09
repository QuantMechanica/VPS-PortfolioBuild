# QM5_13080_xcu-donchian55 - Strategy Spec

**EA ID:** QM5_13080
**Slug:** `xcu-donchian55`
**Source:** `SZAKMARY-CME-USGS-XCU-TREND-2026`
**Author of this spec:** Codex
**Last revised:** 2026-07-09

---

## 1. Strategy Logic

This EA trades `XCUUSD.DWX` D1 as a solo copper trend-following sleeve. On each
new D1 bar it enters long when the prior close breaks above the prior 55-close
Donchian channel and ADX(14) is at least 22, and enters short on the symmetric
downside breakout. Positions carry a 2.25 * ATR(20) hard stop and exit on the
opposite 20-close channel or after 90 D1 bars.

The sleeve is deliberately not XAU, XAG, XTI, XNG, Brent, an index, a
commodity-RSI rule, or a market-neutral spread package. It targets copper/base
metal trend exposure because `XCUUSD.DWX` exists in the DWX registry but had no
existing V5 card or EA.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_donchian_entry_period` | 55 | 40-65 | D1 close-channel lookback for breakout entry |
| `strategy_donchian_exit_period` | 20 | 10-20 | D1 close-channel lookback for contra-channel exit |
| `strategy_adx_period` | 14 | 14 | ADX period used for the trend-regime filter |
| `strategy_adx_threshold` | 22.0 | 18.0-26.0 | Minimum ADX required for new entries |
| `strategy_atr_period` | 20 | 14-30 | ATR period used for the hard stop |
| `strategy_atr_stop_mult` | 2.25 | 1.75-2.75 | ATR multiple for the hard stop |
| `strategy_max_hold_bars` | 90 | 60-120 | Stale-position exit in D1 bars |
| `strategy_max_spread_points` | 1000 | 600-1600 | Maximum allowed entry spread in points |

---

## 3. Symbol Universe

**Designed for:**
- `XCUUSD.DWX` - solo copper/base-metal commodity exposure, magic slot 0.

**Explicitly NOT for:**
- `XAUUSD.DWX` and `XAGUSD.DWX` - precious-metal and silver sleeves already have
  separate V5 logic.
- `XTIUSD.DWX`, `XBRUSD.DWX`, and `XNGUSD.DWX` - energy sleeves use different
  supply and calendar drivers.
- Index CFDs - equity-index exposure is outside the source lineage.

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
| Trades / year / symbol | 14 |
| Typical hold time | Days to months |
| Expected drawdown profile | Medium-high; copper trend systems can whipsaw around macro shocks |
| Regime preference | Base-metal commodity trend / breakout |
| Win rate target (qualitative) | Low-medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `SZAKMARY-CME-USGS-XCU-TREND-2026`
**Source type:** `academic_paper` plus official exchange/government references
**Pointer:** `https://doi.org/10.1016/j.jbankfin.2009.10.012`
**R1-R4 verdict (Q00):** all PASS / see
`strategy-seeds/cards/xcu-donchian55_card.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio |

ENV->mode validation is enforced by `QM_FrameworkInit`
(`EA_INPUT_RISK_MODE_MISMATCH`). The committed Q02 setfile uses
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-07-09 | Initial build from approved card | Mission-directed XCU Donchian-55 trend sleeve |

