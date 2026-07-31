# QM5_20072_4h-box-frankfurt-london-r1-recovery — Strategy Spec

**EA ID:** QM5_20072
**Slug:** `4h-box-frankfurt-london-r1-recovery`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Codex
**Last revised:** 2026-07-31

---

## 1. Strategy Logic

On each enabled Monday-through-Thursday, the EA measures the high and low of the four closed H1 bars from 03:00 through 06:59 broker time. At the 07:00 H1 boundary it places a buy stop one current spread above the box high and a sell stop one current spread below the box low, provided the box is between 0.5 and 2.0 times the prior closed D1 ATR(14). The first filled leg causes the remaining pending leg to be cancelled; positions exit at the opposite box edge plus a one-pip buffer, at a target 1.5 box widths beyond the breakout edge, or at 22:00 broker time.

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | H1 | fixed H1 | Base timeframe used to build the four-bar box. |
| `strategy_box_start_hour_broker` | 3 | fixed four-hour window ending at 07:00 | Broker-time hour of the first box bar. |
| `strategy_box_end_hour_broker` | 7 | fixed four-hour window starting at 03:00 | Broker-time placement boundary and box end. |
| `strategy_pending_expiry_hour_broker` | 12 | 08–21 | Broker-time hour when unfilled bracket orders expire. |
| `strategy_eod_close_enabled` | true | true/false | Enables the card's end-of-day position close. |
| `strategy_eod_close_hour_broker` | 22 | 13–23 | Broker-time hour for the end-of-day close. |
| `strategy_atr_period` | 14 | 5–30 | Prior closed D1 ATR lookback used by the box-size sanity gate. |
| `strategy_min_box_atr_mult` | 0.5 | 0.25–1.0 | Minimum valid box size as a multiple of D1 ATR. |
| `strategy_max_box_atr_mult` | 2.0 | 1.0–3.0 | Maximum valid box size as a multiple of D1 ATR. |
| `strategy_take_profit_box_mult` | 1.5 | 1.0–2.5 | Profit-target distance in box widths from the breakout edge. |
| `strategy_sl_buffer_pips` | 1 | 0–5 | Pip buffer beyond the opposite box edge for the stop loss. |
| `strategy_max_spread_points` | 25 | 0–50 | Maximum positive spread allowed when the bracket is placed; zero modeled spread remains valid. |
| `strategy_trade_monday` | true | true/false | Enables Monday entries. |
| `strategy_trade_tuesday` | true | true/false | Enables Tuesday entries. |
| `strategy_trade_wednesday` | true | true/false | Enables Wednesday entries. |
| `strategy_trade_thursday` | true | true/false | Enables Thursday entries. |
| `strategy_trade_friday` | false | true/false | Enables Friday entries for the declared P3 toggle. |

> Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are intentionally not repeated here.

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid EUR/USD pair active through Frankfurt and London.
- `GBPUSD.DWX` — liquid GBP/USD pair with direct London-session participation.
- `EURGBP.DWX` — European cross concentrated in the Frankfurt/London overlap.
- `EURJPY.DWX` — EUR cross with European-session breakout participation.

**Explicitly NOT for:**
- Symbols absent from `framework/registry/dwx_symbol_matrix.csv` — they lack the canonical tester data required by the build contract.
- Non-European-session instruments — the card attributes the edge specifically to the Frankfurt pre-London range and London-open expansion.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` ATR(14), closed bar shift 1 |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` |

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 70 |
| Expected trade frequency | approximately 1.3 trades per week per symbol |
| Typical hold time | intraday; pending from 07:00 to 12:00, with any filled position flat by 22:00 broker time |
| Expected drawdown profile | card frontmatter expects approximately 20% drawdown; losses should cluster during false London-open breakouts |
| Regime preference | volatility expansion after a moderate Frankfurt pre-London range |
| Expected profit factor | 1.15 |
| Win rate target (qualitative) | not specified by the approved card; established in Q02 |

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** ForexFactory Trading Systems forum, “4 hour box Frankfurt breakout” thread cluster; source lineage `[[sources/forexfactory-trading-systems]]`.
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_20072_4h-box-frankfurt-london-r1-recovery.md`.

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
| v1 | 2026-07-31 | Initial build from card | 0ba076e1-5ea6-4e3f-bbfe-5d92e5c8ef46 |
