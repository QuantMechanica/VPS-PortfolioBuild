# QM5_11483_williams-l-outside-bar-exhaustion-d1 - Strategy Spec

**EA ID:** QM5_11483
**Slug:** williams-l-outside-bar-exhaustion-d1
**Source:** 729c9425-1ec7-5842-a8b8-3db326d892e5
**Author of this spec:** Codex
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

This EA trades Larry Williams' daily outside-bar exhaustion reversal. A long signal occurs when the last completed D1 bar makes a higher high and lower low than the prior D1 bar, then closes below that prior low; the EA buys at the next D1 open unless the signal bar was Friday. A short signal mirrors the rule: the last completed D1 bar is outside the prior bar and closes above the prior high, so the EA sells at the next D1 open. Each trade uses a 200-pip hard stop, exits on the next D1 open if that one-bar profit check is positive, and otherwise exits after five D1 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_stop_pips` | 200 | 1-1000 | Fixed stop distance in pips from the market entry price. |
| `strategy_max_hold_bars` | 5 | 1-20 | Maximum number of D1 bars to hold before a strategy exit. |
| `strategy_spread_cap_pips` | 25.0 | 0.1-100.0 | Blocks new entries when current spread exceeds this pip cap. |
| `strategy_direction_mode` | 0 | 0, 1, 2 | Direction setting for P3 sweeps: 0 trades both directions, 1 long only, 2 short only. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed DWX major FX pair with daily OHLC coverage.
- `GBPUSD.DWX` - card-listed DWX major FX pair with daily OHLC coverage.
- `USDJPY.DWX` - card-listed DWX major FX pair with daily OHLC coverage.
- `AUDUSD.DWX` - card-listed DWX major FX pair with daily OHLC coverage.
- `USDCAD.DWX` - card-listed DWX major FX pair with daily OHLC coverage.

**Explicitly NOT for:**
- Non-FX indices, metals, energies, and equities - the approved card specifies a D1 DWX FX basket only.
- FX symbols outside the registered five-symbol basket - not part of this P2 saturation registration.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via the framework entry path |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 |
| Typical hold time | 1-5 D1 bars |
| Expected drawdown profile | Wide fixed stop with low trade frequency; losses are bounded by the 200-pip stop and HR4 risk sizing. |
| Regime preference | mean-revert / exhaustion reversal after failed continuation |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 729c9425-1ec7-5842-a8b8-3db326d892e5
**Source type:** book
**Pointer:** Larry Williams, Long-Term Secrets to Short-Term Trading (John Wiley & Sons, 1999), via Goodwin's Beat the Markets Strategy Guidebook attribution.
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11483_williams-l-outside-bar-exhaustion-d1.md`

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
| v1 | 2026-06-11 | Initial build from card | 9feb0a4e-16eb-43b3-aa21-6ec16d71b102 |
