# QM5_1623 Gemini build — mandatory Codex review

Date: 2026-08-23 UTC

Router task: `9c4f7a27-e62e-41e4-8d21-1e74c7a05c33`

Source task: `8d8774bf-011a-4c1e-ab3b-544e290d6435` (`gemini`, build delivery only)

Reviewed artifact: `framework/EAs/QM5_1623_hopwood-bermaui-dss-h4/build_identity.json`

Verdict: **REQUEST_CHANGES — wrong strategy identity; do not promote to PIPELINE**

## Findings

### 1. Critical — the delivered indicator/band contract is not the approved strategy

The approved card requires all of the following:

- DSS parameters `(10, 5, 5)`.
- A 100-H4-bar rolling DSS window.
- Overbought/oversold bands equal to the 80th and 20th percentiles.

The EA instead defaults to DSS `(8, 5, 3)`, uses only 20 values, and calculates `mean ± 1.8 × population standard deviation`:

```mql5
strategy_dss_stoch_period = 8;
strategy_dss_inner_ema = 5;
strategy_dss_outer_ema = 3;
strategy_bermaui_lookback = 20;
strategy_bermaui_k = 1.8;
g_upper_thr = mean + k * std;
g_lower_thr = mean - k * std;
```

A percentile band is not equivalent to a mean/standard-deviation band. `SPEC.md` describes the substituted method and parameters, confirming that this is intentional strategy drift rather than a transcription typo. The current EX5 therefore does not implement the approved `QM5_1623` identity.

Required correction: implement exact rolling 80/20 percentiles over 100 completed H4 DSS(10,5,5) samples, or obtain a separately approved card and EA identity for the mean/standard-deviation variant.

### 2. Critical — risk and exit mechanics materially diverge from the card

The approved card specifies:

- initial SL `2.0 × ATR(14)`;
- no baseline ATR take-profit or break-even rule;
- time stop at 20 H4 bars;
- long exit when DSS crosses above the overbought percentile band, with the short mirror;
- exit on D1 EMA(200) regime flip;
- fresh opposite signal closes the current position before the opposite entry.

The EA instead uses SL `1.5 × ATR`, adds TP `1.5 × ATR`, adds break-even at `0.75 × ATR`, and uses a 10-bar time stop. `Strategy_ExitSignal()` checks only the opposite *entry* signal; it implements neither the overbought/oversold capture exit nor the D1-regime-flip exit.

These changes alter loss size, payoff distribution, holding horizon and exit timing. They cannot be accepted as implementation details under the current ID.

### 3. High — exit state is advanced after exits are evaluated

On a new H4 bar, `OnTick()` currently executes in this order:

1. `Strategy_ManageOpenPosition()`;
2. `Strategy_ExitSignal()`;
3. news entry gate;
4. `QM_IsNewBar()`;
5. `AdvanceState_OnNewBar()`;
6. entry evaluation.

Consequently management and exits see the signal state calculated on the preceding H4 boundary. A fresh opposite signal is not available when the existing position is checked. After state advances, `Strategy_HasOurPosition()` prevents the opposite entry; the position is only closed on a later tick, and the opposite entry cannot occur until another new bar. This contradicts the approved close-before-opposite-entry rule and delays other signal exits.

Required correction: atomically calculate closed-bar state first, then run exits and eligible entries from that same immutable snapshot.

### 4. High — the spread guard can be bypassed on the first eligible bar

`Strategy_NoTradeFilter()` runs before `AdvanceState_OnNewBar()` and relies on `g_atr_1`. Immediately after initialization `g_atr_1 == 0`, so the spread comparison is skipped. The same tick can then populate ATR/state and open a position without rechecking the spread. Later bars compare against the prior cached ATR rather than the current closed-bar ATR.

Required correction: compute the current closed-bar ATR/state before applying the spread filter, and fail closed when ATR, bid or ask is unavailable.

### 5. High — H4 scope is not enforced

The card is H4, but the EA has no `_Period == PERIOD_H4` fail-closed check. DSS, ATR and time-stop calculations use `_Period`, so attaching the binary to another chart silently changes the strategy horizon while retaining the same EA identity.

Required correction: reject non-H4 initialization or entry evaluation deterministically.

### 6. Medium — cooldown starts before an order succeeds

`g_bars_since_last_long/short` is reset inside `Strategy_EntrySignal()` before `QM_TM_OpenPosition()` reports success. A rejected order therefore starts a six-bar cooldown even though no entry occurred. Reset the direction-specific cooldown only after confirmed order acceptance, or bind it to the framework transaction result.

### 7. Low — SPEC risk value is malformed

`SPEC.md` renders the fixed-risk baseline as `,000 per trade`. The file has no control bytes, but the missing `$1` makes the durable specification ambiguous.

## Checks that passed

- Approved card exists with `g0_status: APPROVED`.
- EA registry row `1623 / hopwood-bermaui-dss-h4` is active.
- Thirteen active magic rows and thirteen corresponding setfiles exist.
- All 13 backtest setfiles use `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- `validate_build_guardrails.py framework/EAs/QM5_1623_hopwood-bermaui-dss-h4`: `PASS`, 14 files, zero findings, `max_news_stale_hours=336`.
- MQ5 SHA-256 matches `build_identity.json`: `7fbe2049a5cb85fdf94efe68969721f9bac17a34372f9ba2fa593a900a3a3070`.
- EX5 SHA-256 matches `build_identity.json`: `913e0fe6818410fcaa9aed753380509a1b76883f15e4aa451793fbfdb48d6144`.
- Direct first-on-tick MAE tracking and request zero-initialization are present.
- Friday close and strategy management occur before the news entry gate.
- The implementation is mechanical and contains no ML, martingale or grid logic.

These checks establish artifact consistency and baseline hardening only. They are not evidence that the correct strategy was built and are not a pipeline verdict.

## Disposition

No source, binary, registry, setfile, task verdict or trade stream was changed by this review. `T_Live` and AutoTrading were not touched. The task remains in `REVIEW` with `REQUEST_CHANGES`. Because the current EX5 embodies a different strategy, it must not be enqueued; corrected Gemini code requires a fresh mandatory Codex review.
