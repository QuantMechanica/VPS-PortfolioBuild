# QM5_1629 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `2f8bdfac-52e1-43b9-8c26-0f2564fcb0de`

Source task: `810145d0-5aeb-4a8f-9830-b0bdaadac57f` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_1629_ehlers-cybernetic-cycle-h4/build_identity.json`

Verdict: **REQUEST_CHANGES — do not promote to PIPELINE**

## Findings

### 1. High — the filter uses median price instead of the approved close price

The approved card's executable pseudocode defines the smoother as:

```text
smooth[t] = (close[t] + 2*close[t-1] + 2*close[t-2] + close[t-3]) / 6
```

Its R2 contract also names `iClose`. The EA instead feeds the IIR filter with `(high + low) / 2` at every sample. Median price and close price produce different waveforms, zero crossings, amplitudes, entries and exits. This is a strategy-identity change, not a numerical implementation detail.

Required correction: use completed H4 close values exactly as approved, then rebuild and rebind all identities.

### 2. High — the 20-H4-bar time stop is implemented as wall-clock time

The card requires exit after 20 H4 bars. The EA tests:

```mql5
TimeCurrent() - opened >= strategy_time_stop_bars * PeriodSeconds(PERIOD_H4)
```

This counts weekends, holidays and trading halts as if bars had formed. A Friday position can therefore reach the threshold with far fewer than 20 completed H4 bars. Required correction: count actual H4 bars from the position-open bar (with a fail-closed history result), not elapsed seconds.

### 3. High — break-even-plus-spread is implemented as raw break-even

The card specifies moving the stop to break-even **plus spread** after +1 ATR. The EA calls `QM_TM_MoveSL(ticket, open_price, "MOVE_TO_BE")`, which covers none of the entry/exit spread. This changes the approved risk mechanic and can turn the claimed protected exit into a net loss after transaction costs.

Required correction: calculate the direction-correct spread offset and normalize/validate the resulting stop against broker constraints.

### 4. High — H4 execution scope is not enforced

The signal data is explicitly H4, but `QM_IsNewBar()` follows the attached chart timeframe and no `_Period == PERIOD_H4` check exists. On a non-H4 chart the same completed H4 cross can be evaluated at each chart-bar boundary, while the time/cooldown state still assumes H4. Setfiles are H4, but the binary itself does not fail closed on a wrong chart.

Required correction: reject non-H4 initialization or gate the complete execution clock explicitly to `PERIOD_H4`.

### 5. Medium — cooldown state advances before order success

`g_last_trade_time` and `g_last_trade_dir` are assigned inside `Strategy_EntrySignal()` before `QM_TM_OpenPosition()` returns. A broker, stress, governor or risk rejection therefore starts a four-H4-bar cooldown even though no trade opened.

Required correction: update cooldown only after confirmed entry, preferably from the transaction/open result tied to the accepted ticket.

## Checks that passed

- Approved card exists with `g0_status: APPROVED`.
- EA registry row `1629 / ehlers-cybernetic-cycle-h4` is active.
- Fourteen active magic rows and fourteen corresponding H4 setfiles exist.
- All 14 backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0` and carry the card defaults.
- `validate_build_guardrails.py framework/EAs/QM5_1629_ehlers-cybernetic-cycle-h4`: `PASS`, 15 files, zero findings, `max_news_stale_hours=336`.
- MQ5 SHA-256 matches `build_identity.json`: `6a2e3ff5044180af4e9363df665fb533ef3f8fe32c3052778cf4373ef7c105d1`.
- EX5 SHA-256 matches `build_identity.json`: `b32130054b4c1226dbbb7ed7caed583649bec9e147e56c1f2867b061ab84e4f8`.
- Fixed alpha, amplitude threshold, D1 regime filter, ATR stop/target, opposite-cycle exit and entry-only news blackout otherwise match the card's mechanical outline.
- Direct first-on-tick MAE tracking and request zero-initialization are present.
- No ML, martingale or grid logic is present.

These checks establish artifact consistency and baseline hardening only. They do not cure the execution-contract deviations and are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict or trade stream was changed by this review. `T_Live` and AutoTrading were not touched. The task remains in `REVIEW` with `REQUEST_CHANGES`; corrected Gemini code requires a fresh mandatory Codex review before any acceptance or enqueue.
