# QM5_11174_weiss-7rev - Strategy Spec

**EA ID:** QM5_11174
**Slug:** weiss-7rev
**Source:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6 (see approved card)
**Author of this spec:** Codex
**Last revised:** 2026-06-07

---

## 1. Strategy Logic

The EA trades Weissman's seven-period reversal on completed H1 closes. A long signal appears when six consecutive completed closes fall from Close[8] through Close[2], then the newest completed close reverses up with Close[1] greater than Close[2]. A short signal is the mirror image: six consecutive completed closes rise from Close[8] through Close[2], then Close[1] turns down below Close[2]. Entries are market orders on the next bar with a fixed 1% stop and fixed 1% profit target; an open position also closes when the opposite reversal signal appears.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_sequence_closes | 6 | 1-20 | Number of consecutive completed closes required before the one-bar reversal. |
| strategy_stop_pct | 0.01 | 0.0-1.0 | Fixed stop distance as a fraction of entry price. |
| strategy_target_pct | 0.01 | 0.0-1.0 | Fixed profit target distance as a fraction of entry price. |
| strategy_enable_longs | true | true/false | Allows long entries from the falling-sequence reversal. |
| strategy_enable_shorts | true | true/false | Allows short entries from the rising-sequence reversal. |

Framework-level inputs are documented in `framework/V5_FRAMEWORK_DESIGN.md` and are not repeated here.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - matches the source's 60-minute Nasdaq 100 test context.
- `SP500.DWX` - broad US large-cap index exposure from the approved R3 basket.
- `WS30.DWX` - liquid US index exposure from the approved R3 basket.
- `EURUSD.DWX` - liquid FX symbol from the approved R3 basket.
- `XAUUSD.DWX` - liquid metal symbol from the approved R3 basket.

**Explicitly NOT for:**
- Non-DWX broker symbols - backtest symbols must be registered canonical `.DWX` instruments.
- Unregistered symbols - no magic row exists for this EA, so the framework resolver will reject them.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` via framework `OnTick` before `Strategy_EntrySignal` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 30 |
| Typical hold time | Variable, usually hours to several days depending on 1% target/stop or opposite signal. |
| Expected drawdown profile | Mean-reversion losses can cluster during persistent directional moves. |
| Regime preference | Short-term mean-reversion after seven-bar exhaustion. |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 3005c768-aa91-5daf-9dd7-500d7bfcb7a6
**Source type:** book
**Pointer:** Richard L. Weissman, Mechanical Trading Systems, Chapter 5, pp. 96-98, https://studylib.net/doc/28245153/richard-l.-weissman---mechanical-trading-systems
**R1-R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_11174_weiss-7rev.md`

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
| v1 | 2026-06-07 | Initial build from card | 2664e9dd-7645-4dd8-be6b-7bb443430e4a |
