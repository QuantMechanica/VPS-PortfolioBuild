# QM5_1567_demark-td-reverse-sequential-h4 - Strategy Spec

**EA ID:** QM5_1567
**Slug:** `demark-td-reverse-sequential-h4`
**Specification basis:** implementation as built
**Author of this spec:** Codex
**Last revised:** 2026-08-12

---

## 1. Strategy Logic

The EA evaluates a mechanical Reverse-Sequential pattern on completed H4 bars. A buy
setup is nine bars whose closes are each above the close four bars earlier; a sell setup
uses the mirrored below comparison. After a setup, qualifying buy-countdown bars have a
low below the low two bars earlier, while sell-countdown bars have a high above the high
two bars earlier. The thirteenth qualifying countdown bar must be the latest completed
bar and must extend beyond countdown bar 8's close: buy low below that close, or sell high
above it. The implementation scans setup endings over the configured timeout and accepts
the first completed direction (`QM5_1567_demark-td-reverse-sequential-h4.mq5:84-176`).

Entry is allowed only when no position for this EA's symbol and magic is open. A buy also
requires the last completed D1 close above D1 SMA(200); a sell requires it below. The
initial stop is countdown bar 13's extreme plus a 0.5 ATR buffer away from the trade and
is rejected when its distance exceeds 3 ATR. The target is 1.5 ATR from entry. There is
no trailing or partial close; the only discretionary exit is a 12-H4-bar time stop
(`QM5_1567_demark-td-reverse-sequential-h4.mq5:179-195`,
`QM5_1567_demark-td-reverse-sequential-h4.mq5:214-304`).

The spread filter blocks processing while spread exceeds 0.4 H4 ATR. Framework kill
switch, news blackout, Friday close, fixed-risk sizing, and magic resolution remain in
the common execution path; entries are evaluated once per new chart bar
(`QM5_1567_demark-td-reverse-sequential-h4.mq5:198-208`,
`QM5_1567_demark-td-reverse-sequential-h4.mq5:320-393`).

## 2. Parameters

| Parameter | Default | Implemented meaning |
|---|---:|---|
| `strategy_setup_bars` | 9 | Consecutive close-versus-close-four-bars-back comparisons in a setup. |
| `strategy_countdown_bars` | 13 | Number of qualifying low/high comparisons required in the countdown. |
| `strategy_countdown_timeout` | 24 | Countdown search bound; the setup-ending scan stops at this value plus one. |
| `strategy_atr_period` | 14 | H4 ATR period for spread, stop, and target calculations. |
| `strategy_sl_atr_buffer` | 0.5 | ATR buffer beyond countdown bar 13's low/high for the stop. |
| `strategy_sl_atr_cap` | 3.0 | Maximum permitted entry-to-stop distance in ATR units; a wider signal is skipped. |
| `strategy_tp_atr_mult` | 1.5 | Entry-to-target distance in ATR units. |
| `strategy_spread_atr_mult` | 0.4 | Maximum spread as a fraction of H4 ATR. |
| `strategy_regime_sma_period` | 200 | D1 close SMA period used as the direction filter. |
| `strategy_time_stop_h4_bars` | 12 | Maximum elapsed position age in H4-bar seconds. |

Defaults are declared in the implementation (`QM5_1567_demark-td-reverse-sequential-h4.mq5:66-76`).

## 3. Symbol Universe

The deterministic magic registry currently allocates the implementation to
`SP500.DWX`, `NDX.DWX`, `WS30.DWX`, `GDAXI.DWX`, `UK100.DWX`, `XAUUSD.DWX`,
`XTIUSD.DWX`, `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, and `XAGUSD.DWX`
(`framework/registry/magic_numbers.csv:1506-1515`,
`framework/registry/magic_numbers.csv:15049`). This specification does
not infer eligibility for symbols outside those registered rows.

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe reference | D1 SMA(200) direction filter |
| Signal inputs | Completed H4 bars; D1 shift 1 |
| Entry gate | Common `QM_IsNewBar()` gate; governed setfiles attach the EA to H4 |

The H4 and D1 reads are explicit in the signal implementation
(`QM5_1567_demark-td-reverse-sequential-h4.mq5:84-176`,
`QM5_1567_demark-td-reverse-sequential-h4.mq5:227-263`,
`QM5_1567_demark-td-reverse-sequential-h4.mq5:382-393`).

## 5. Expected Behaviour

| Aspect | As-built expectation |
|---|---|
| Trade frequency | Not asserted by the implementation; the 9-plus-13 bar sequence is mechanically selective. |
| Position concurrency | At most one open position per symbol and EA magic. |
| Typical maximum hold | 12 H4 bars unless SL, TP, Friday close, or the common kill switch resolves it first. |
| Regime preference | Directional pullback/exhaustion signal aligned with the completed D1 close versus SMA(200). |
| Exit shape | Fixed stop and target; no strategy trailing or partial close. |

No performance, profitability, or pipeline verdict is inferred by this document.

## 6. Source Citation

This is an implementation-of-record specification, not a fresh source-provenance
adjudication. The approved card of record is
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_1567_demark-td-reverse-sequential-h4.md`;
the executable mechanics documented here are taken from the checked-in MQL5 source,
whose identity is declared at `QM5_1567_demark-td-reverse-sequential-h4.mq5:1-5` and
whose complete setup/countdown implementation is at
`QM5_1567_demark-td-reverse-sequential-h4.mq5:84-176`. Where prose and code
ever differ, the code citations above describe the as-built behavior; source authority
and gate status remain with their governed records.

## 7. Risk Model

The EA defaults to `RISK_FIXED=1000` and `RISK_PERCENT=0`; framework initialization
receives those inputs and the portfolio weight unchanged
(`QM5_1567_demark-td-reverse-sequential-h4.mq5:45-48`,
`QM5_1567_demark-td-reverse-sequential-h4.mq5:320-336`). Backtest setfiles
must retain the fixed-risk contract. This specification authorizes no live setting,
deployment, or AutoTrading change.

---

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-08-12 | Document the checked-in implementation without changing strategy behavior. |
