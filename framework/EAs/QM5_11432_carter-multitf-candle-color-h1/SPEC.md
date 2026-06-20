# QM5_11432_carter-multitf-candle-color-h1 — Strategy Spec

**EA ID:** QM5_11432
**Slug:** `carter-multitf-candle-color-h1`
**Source:** `96b1d6a2-d0af-5fa2-abbc-865a08f82ef2` (see `strategy-seeds/sources/96b1d6a2-d0af-5fa2-abbc-865a08f82ef2/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-20

---

## 1. Strategy Logic

Pure price-action multi-timeframe candle-direction alignment, no indicators. On
each closed H1 bar the EA reads the direction of the most recently completed
candle on M5, M15, M30, and H1, where direction is bullish if close > open and
bearish if close < open. A doji body below 1 pip on any timeframe voids the
signal.

The EA opens long when all four timeframes are bullish and the current ask is at
least 3 pips above the prior closed H1 close. It opens short when all four are
bearish and the current bid is at least 3 pips below the prior closed H1 close.
Stop-loss is a fixed 20 pips and take-profit is a fixed 35 pips from entry. The
optional early exit closes the position when the M30 or H1 closed candle flips
against the open trade.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_confirmation_pips` | 3 | 1-5 | Follow-through buffer past the prior H1 close required to confirm the alignment |
| `strategy_doji_threshold_pips` | 1 | 1-3 | Bodies smaller than this are doji and void the signal on that timeframe |
| `strategy_stop_loss_pips` | 20 | 15-25 | Stop-loss distance from entry |
| `strategy_take_profit_pips` | 35 | 25-45 | Take-profit distance from entry |
| `strategy_spread_cap_pips` | 15 | 5-30 | Maximum allowed spread; zero spread is allowed for .DWX tester symbols |
| `strategy_exit_on_higher_tf_flip` | true | true/false | Enable the M30/H1 candle-flip early exit |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — most liquid major; tight pip scaling fits the 3/20/35-pip thresholds
- `GBPUSD.DWX` — liquid major with cleaner intraday momentum runs
- `USDJPY.DWX` — JPY major; pip scaling handled scale-correctly via `QM_StopRulesPipsToPriceDistance`
- `AUDUSD.DWX` — liquid commodity major, lower volatility complement to the set

**Explicitly NOT for:**
- Index / metal / energy `.DWX` symbols — the fixed small-pip thresholds (3/20/35) are FX-calibrated and would mis-scale on index/commodity point structures.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | M5, M15, M30, H1 last-closed-bar candle direction (same symbol) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~150 |
| Typical hold time | hours |
| Expected drawdown profile | moderate fixed-stop FX intraday profile |
| Regime preference | momentum-continuation |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `96b1d6a2-d0af-5fa2-abbc-865a08f82ef2`
**Source type:** book
**Pointer:** John Carter, "20 Strategies Collection (H1)", local PDF in strategy archive (`strategy-seeds/sources/96b1d6a2-d0af-5fa2-abbc-865a08f82ef2/`)
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_11432_carter-multitf-candle-color-h1.md`

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
| v1 | 2026-06-20 | Initial build from card | 9eae72a4-78cf-47de-a17d-9529d651af67 |
