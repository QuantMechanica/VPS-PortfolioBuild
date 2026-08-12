# QM5_13301_balke-minute-range-breakout - Strategy Spec

**EA ID:** QM5_13301
**Slug:** `balke-minute-range-breakout`
**Specification basis:** implementation as built
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

The EA projects broker time through UTC into a fixed GMT+3-equivalent clock. On the M5
bar at the configured range end, it scans closed M5 bars from the same GMT+3 day and
requires the complete five-minute range window. The default window is 03:00 through
06:00 and the default flat time is 18:00. The clock conversion and minute inputs are
implemented at `QM5_13301_balke-minute-range-breakout.mq5:92-136`; range construction
and completeness checks are at `QM5_13301_balke-minute-range-breakout.mq5:217-247`.

If the completed range is between 0.4 and 2.5 times H1 ATR(14), the EA submits a buy
stop at the range high with stop at the range low, then returns a sell stop at the range
low with stop at the range high for common-framework submission. Both orders have no
fixed take profit. It submits at most one two-sided order set per GMT+3 day and skips a
day whose range fails the ATR bounds (`QM5_13301_balke-minute-range-breakout.mq5:287-341`).

When one side triggers, the opposite pending order is removed. After price advances at
least 1R, the stop may improve to the more conservative of the prior two completed H1
lows for a buy or highs for a sell. At or after the configured flat minute, pending
orders are removed and open positions close. An open buy also exits on a bid touch of
the original range low; a sell exits on an ask touch of the range high
(`QM5_13301_balke-minute-range-breakout.mq5:344-445`).

The common tick path enforces the kill switch, two-axis news filter, Friday-close guard,
and closed-bar entry gate before order submission (`QM5_13301_balke-minute-range-breakout.mq5:462-548`).

## 2. Parameters

| Parameter | Default | Implemented meaning |
|---|---:|---|
| `strategy_range_start_hour` | 3 | GMT+3-equivalent hour at which range collection starts. |
| `strategy_range_start_minute` | 0 | Minute component of range start. |
| `strategy_range_end_hour` | 6 | GMT+3-equivalent hour at which range collection ends and orders may be submitted. |
| `strategy_range_end_minute` | 0 | Minute component of range end. |
| `strategy_exit_hour` | 18 | GMT+3-equivalent hour for flat-and-cancel handling. |
| `strategy_exit_minute` | 0 | Minute component of flat-and-cancel handling. |
| `strategy_atr_period` | 14 | H1 ATR period used to validate range height. |
| `strategy_min_range_atr_mult` | 0.4 | Minimum completed-range height in H1 ATR units. |
| `strategy_max_range_atr_mult` | 2.5 | Maximum completed-range height in H1 ATR units. |
| `strategy_trail_trigger_r` | 1.0 | Profit in initial-risk units before the H1 two-bar structural trail may improve the stop. |
| `strategy_range_scan_bars` | 432 | Maximum closed M5 bars scanned when reconstructing the same-day range. |

Defaults are declared at `QM5_13301_balke-minute-range-breakout.mq5:75-104`. Governed
setfiles may override the time window per symbol; this document does not treat defaults
as evidence that every stored setfile uses the same times.

## 3. Symbol Universe

The deterministic magic registry currently allocates this EA to `XAUUSD.DWX`,
`USDCAD.DWX`, `USDCHF.DWX`, `GBPJPY.DWX`, `AUDUSD.DWX`, `AUDCAD.DWX`, `CADJPY.DWX`,
`NZDCAD.DWX`, `EURJPY.DWX`, `GBPUSD.DWX`, and `GDAXI.DWX`
(`framework/registry/magic_numbers.csv:15050-15060`). This specification makes no
eligibility claim for unregistered symbols.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Chart and range timeframe | M5 |
| Volatility reference | H1 ATR(14) |
| Trailing structure | Prior two completed H1 bars |
| Time basis | Broker time normalized to UTC, then projected to fixed GMT+3-equivalent time |
| Entry gate | Common `QM_IsNewBar()` gate; governed setfiles attach the EA to M5 |

The mixed-timeframe reads and bar gate are explicit at
`QM5_13301_balke-minute-range-breakout.mq5:217-247`, `:319-324`, `:394-410`, and
`:533-548`.

## 5. Expected Behaviour

| Aspect | As-built expectation |
|---|---|
| Order frequency | At most one two-sided pending-order set per GMT+3 day. |
| Position concurrency | When a position for the symbol/magic is observed, the opposite pending side is removed. |
| Typical hold | Intraday, from a post-range breakout until opposite-range touch or the configured flat minute. |
| Regime preference | Range expansion following a bounded pre-session range. |
| Profit target | None fixed; exit is structural, time-based, Friday close, kill switch, or broker stop. |

No expected trade count, win rate, profitability, or pipeline verdict is asserted by
the source implementation.

## 6. Source Citation

The implementation identifies itself as the minute-precision variant of QM5_13213 and
explains that minute inputs and M5 range bars were introduced to express non-hour
boundaries while retaining H1 ATR and structural trailing
(`QM5_13301_balke-minute-range-breakout.mq5:76-91`). The checked-in source survey records
the observed Balke windows and explicitly warns that windows are symbol-specific
(`docs/research/balke_windows_survey_2026-07-15.md:16-24`,
`docs/research/balke_windows_survey_2026-07-15.md:31-46`). Those records
support provenance and parameterization only; the as-built behavior in this spec is
bound to the cited MQL5 lines, not to an assumed universal Balke default.

## 7. Risk Model

The EA defaults to `RISK_FIXED=1000` and `RISK_PERCENT=0`
(`QM5_13301_balke-minute-range-breakout.mq5:45-48`). Framework initialization passes
those values together with a news stale ceiling of 336 hours and the two-axis news
contract (`QM5_13301_balke-minute-range-breakout.mq5:50-61`,
`QM5_13301_balke-minute-range-breakout.mq5:462-480`). Backtest
setfiles must retain fixed risk. This specification authorizes no live setting,
deployment, or AutoTrading change.

---

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-12 | Document the checked-in implementation without changing strategy behavior. |
