# QM5_12545_katz-sma-support-resistance-stop-d1 — Strategy Spec

**EA ID:** QM5_12545
**Slug:** katz-sma-support-resistance-stop-d1
**Source:** katz-encyclopedia-2000-ch6 (see `strategy-seeds/sources/katz-encyclopedia-2000-ch6/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA trades a D1 simple moving average as support or resistance only when the average is sloping in the trade direction. A long setup requires the SMA(25) to rise while the latest closed bar crosses from above the SMA to at or below it; the EA then places a buy stop one tick above that bar's high. A short setup mirrors the rule with a falling SMA and a sell stop one tick below the touch bar low. Exits use Katz SES: 1 x ATR(50) stop, 4 x ATR(50) target, or a 10 D1-bar time exit.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_sma_period` | 25 | 15-35 P3 sweep | SMA length used for slope and touch detection |
| `strategy_atr_period` | 50 | >= 2 | ATR period for SES stop and target sizing |
| `strategy_stop_atr_mult` | 1.0 | > 0 | Stop distance in ATR multiples |
| `strategy_target_atr_mult` | 4.0 | > 0 | Profit target distance in ATR multiples |
| `strategy_pending_valid_bars` | 3 | >= 1 | Number of D1 bars a staged stop order remains valid |
| `strategy_max_hold_bars` | 10 | >= 1 | D1 bars before time exit if SL/TP has not closed the trade |

---

## 3. Symbol Universe

**Designed for:**
- `USDJPY.DWX` - best Katz FX market proxy from the card's R3 basket.
- `USDCHF.DWX` - Swiss franc proxy for the Deutschemark exposure named by the card.
- `EURUSD.DWX` - EUR proxy for Deutschemark/ECU exposure with DWX data.
- `GBPUSD.DWX` - British pound FX proxy from the approved market universe.
- `USDCAD.DWX` - additional liquid FX diversification listed in the card universe.

**Explicitly NOT for:**
- `SP500.DWX` - the card is a Katz FX support/resistance implementation, not an index strategy.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | D1 |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 15 |
| Typical hold time | Up to 10 D1 bars |
| Expected drawdown profile | About 15% expected drawdown from card frontmatter |
| Regime preference | Trend pullback / countertrend entry with trend-confirming stop fill |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** katz-encyclopedia-2000-ch6
**Source type:** book
**Pointer:** `D:/QM/strategy_farm/source_cache/katz-mccormick-encyclopedia-2000.txt`, Ch.6 pp. 139-146
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12545_katz-sma-support-resistance-stop-d1.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-06-13 | Initial build from card | 40b2ba5d-99fa-443f-86bf-0d42bb5f4e0a |
