# QM5_12802_rapidfire-scalper — Strategy Spec

**EA ID:** QM5_12802
**Slug:** rapidfire-scalper
**Source:** hyonix-rapidfire-scalper-2026
**Author of this spec:** Codex
**Last revised:** 2026-06-30

---

## 1. Strategy Logic

This EA trades a M5 intraday trend-stack from the approved Hyonix RapidFire Scalper card. On each new M5 bar it opens long when the current ask is above SMA(60) and above Parabolic SAR(0.20, 0.20); it opens short when the current bid is below SMA(60) and below Parabolic SAR(0.20, 0.20). Gold uses a 0.4% stop and 0.4% target by default; index symbols use the fixed-points profile from the source setfiles. Open trades are force-closed outside the configured broker-time session and otherwise exit by SL, TP, optional fixed trailing, or framework Friday close.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_M5` | MT5 timeframe enum | Timeframe used for SMA and PSAR reads. |
| `strategy_sma_period` | `60` | `2+` | SMA period for the trend-stack filter. |
| `strategy_sar_step` | `0.20` | `>0` | Parabolic SAR acceleration step from the card. |
| `strategy_sar_maximum` | `0.20` | `>0` | Parabolic SAR maximum from the card. |
| `strategy_profile_mode` | `0` | `0 auto, 1 fixed, 2 percent` | Auto uses percent-of-price on XAU symbols and fixed-points on indices. |
| `strategy_fixed_sl_points` | `200` | `1+` | Fixed-points stop distance for index symbols. |
| `strategy_fixed_tp_points` | `200` | `1+` | Fixed-points take-profit distance for index symbols. |
| `strategy_percent_sl` | `0.40` | `>0` | Gold stop as percent of entry price. |
| `strategy_percent_tp` | `0.40` | `>0` | Gold take-profit as percent of entry price. |
| `strategy_session_start_hour_broker` | `8` | `0-23` | Broker-time hour when entries may begin. |
| `strategy_session_end_hour_broker` | `23` | `0-23` | Broker-time hour when entries stop and positions are flattened. |
| `strategy_allow_monday` | `true` | bool | Allows Monday entries. |
| `strategy_allow_tuesday` | `true` | bool | Allows Tuesday entries. |
| `strategy_allow_wednesday` | `true` | bool | Allows Wednesday entries. |
| `strategy_allow_thursday` | `true` | bool | Allows Thursday entries. |
| `strategy_allow_friday` | `true` | bool | Allows Friday entries until the session end or framework Friday close. |
| `strategy_allow_saturday` | `false` | bool | Blocks Saturday entries. |
| `strategy_allow_sunday` | `false` | bool | Blocks Sunday entries. |
| `strategy_trailing_mode` | `1` | `0 off, 1 fixed, 2 previous-candle, 3 fast-EMA` | Optional trailing stop mode; source setfiles use fixed trailing. |
| `strategy_trailing_trigger_points` | `20` | `1+` | Fixed-profile profit trigger before trailing starts. |
| `strategy_trailing_points` | `10` | `1+` | Fixed-profile trail distance. |
| `strategy_trailing_trigger_pct_of_sl` | `10.0` | `>0` | Percent-profile trigger as percent of initial SL distance. |
| `strategy_trailing_distance_pct_of_sl` | `5.0` | `>0` | Percent-profile trail distance as percent of initial SL distance. |
| `strategy_previous_candle_shift` | `1` | `1+` | Closed candle shift used only by previous-candle trailing mode. |
| `strategy_fast_ma_period` | `5` | `2+` | EMA period used only by fast-MA trailing mode. |

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — gold is explicitly named by the card and uses the 0.4%/0.4% price profile.
- `NDX.DWX` — Nasdaq 100 maps directly to the card's NDX index target.
- `GDAXI.DWX` — DWX DAX 40 custom symbol used for the card's GER40 target.
- `SP500.DWX` — canonical DWX S&P 500 custom symbol used for the card's US500 target.
- `WS30.DWX` — Dow 30 maps to the card's US30 target.

**Explicitly NOT for:**
- FX `.DWX` symbols — the card rejects FX because the 1:1 scalping profile is commission-killed.
- `SPX500.DWX`, `SPY.DWX`, `ES.DWX`, and GER40 name variants — not canonical DWX matrix symbols for this build.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M5` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the V5 skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `300` |
| Typical hold time | Intraday; positions are flat after the configured broker-time session end. |
| Expected drawdown profile | Around `10%` from card frontmatter estimate. |
| Regime preference | Intraday trend scalp on low-commission gold and index symbols. |
| Win rate target (qualitative) | Medium; 1:1 stop/target profile with thin edge. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** hyonix-rapidfire-scalper-2026
**Source type:** OWNER code collection
**Pointer:** `C:/Users/Administrator/Downloads/Hyonix/Hyonix/RapidFireScalper.mq5` plus `scalpgold.set` and `scalpforex.set`
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_12802_rapidfire-scalper.md`

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
| v1 | 2026-06-30 | Initial build from card | 4a5030c3-69b2-49b9-a12c-996b13f62dc1 |
