# QM5_11505_goodwin-hourly-breakout-h1 - Strategy Spec

**EA ID:** QM5_11505
**Slug:** `goodwin-hourly-breakout-h1`
**Source:** `2a126283-6905-5bb7-903a-cccd5f2b533f` (see `strategy-seeds/sources/2a126283-6905-5bb7-903a-cccd5f2b533f/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

The EA checks the most recently completed D1 bar at the H1 entry window. If that daily bar closed above its open, it places a BuyStop one pip above the recent H1 session high; if it closed below its open, it places a SellStop one pip below the recent H1 session low. Each pending order uses a fixed 150-pip stop loss, a 2R take profit, and an expiry at the configured broker-time session end. Any open position is closed once the session-end time is reached.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `ENTRY_HOUR_GMT2` | 0 | 0-23 | Broker-time entry hour during GMT+2 season. |
| `ENTRY_MINUTE` | 5 | 0-59 | Source entry minute; H1 tests use the containing hour bar. |
| `ENTRY_WINDOW_END_MINUTE` | 15 | 0-59 | End minute for lower-timeframe entry windows. |
| `EXIT_HOUR_GMT2` | 2 | 0-23 | Broker-time session exit hour during GMT+2 season. |
| `EXIT_MINUTE` | 30 | 0-59 | Broker-time session exit minute. |
| `DST_OFFSET` | 0 | 0-1 | Manual broker-hour offset for US DST season. |
| `SESSION_RANGE_BARS` | 1 | 1-24 | Number of closed H1 bars used for the session high/low box. |
| `SL_PIPS` | 150 | 1-500 | Fixed stop-loss distance in pips. |
| `TP_RR` | 2.0 | 0.1-10.0 | Take-profit multiple of the stop distance. |
| `BREAKOUT_BUFFER_PIPS` | 1 | 0-50 | Pending-stop buffer beyond the session high or low. |
| `SKIP_FRIDAY_ENTRY` | true | true/false | Blocks fresh Friday entries. |
| `SPREAD_CAP_PIPS` | 15.0 | 0.0-100.0 | Blocks entries only when modeled spread is genuinely wider than this cap. |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - source-specified Goodwin FX instrument with H1 and D1 DWX history.
- `GBPUSD.DWX` - card-approved FX expansion for the same NY-session breakout behavior.

**Explicitly NOT for:**
- `SP500.DWX` - the approved card is FX-specific and does not assign equity-index session mechanics.
- `XAUUSD.DWX` - the approved card does not specify metal-specific hours or stop scaling.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_D1` prior-bar open/close for directional bias |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `60` |
| Typical hold time | Card body: intraday NY-session hold until broker-time session end; frontmatter does not specify exact hold-time metric. |
| Expected drawdown profile | Card frontmatter does not specify; wide fixed 150-pip SL implies episodic breakout losses. |
| Regime preference | Card concepts: session-breakout and daily-directional-filter; volatility-expansion / momentum continuation. |
| Win rate target (qualitative) | Card frontmatter does not specify. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `2a126283-6905-5bb7-903a-cccd5f2b533f`
**Source type:** `book`
**Pointer:** `Jarrod Goodwin, "Beat the Markets - Strategy Guidebook", self-published / The Transparent Trader, ~2014`
**R1-R4 verdict (Q00):** all R1-R4 PASS per `artifacts/cards_approved/QM5_11505_goodwin-hourly-breakout-h1.md`

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
| v1 | 2026-06-25 | Initial build from card | efdac816-9ca7-4ce2-9899-767f5ef7e112 |
