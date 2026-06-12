# QM5_12539_ict-london-kz-cable-sweep - Strategy Spec

**EA ID:** QM5_12539
**Slug:** ict-london-kz-cable-sweep
**Source:** ict-2022-model-canonical-2026-06-12 (see `strategy-seeds/sources/ict-2022-model-canonical-2026-06-12/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

This EA trades the London killzone on GBPUSD.DWX and EURUSD.DWX using the card's sweep, structure-shift, and fair-value-gap sequence. It defines the Asia range from broker 01:00 through 09:00, then during broker 09:00 through 12:00 looks for a closed M15 sweep of the nearest downside or upside liquidity pool that closes back inside the pool. Within eight M15 bars, it requires a close through the most recent M15 pivot in the reversal direction and a three-candle FVG, then places a limit order at the FVG midpoint. The stop is beyond the sweep extreme by 0.3 x ATR(14), TP1 is the opposite pool capped at 2.0R with a 50% partial close, and the runner exits at 3.0R or broker 17:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_atr_period` | 14 | 2-100 | ATR period used for the sweep-extreme stop buffer. |
| `strategy_atr_buffer_mult` | 0.30 | 0.01-2.00 | ATR multiple added beyond the sweep extreme for the stop. |
| `strategy_max_risk_atr_mult` | 2.50 | 0.10-10.00 | Maximum allowed entry-to-stop distance as an ATR multiple. |
| `strategy_mss_max_bars` | 8 | 1-32 | Maximum M15 bars from sweep to market-structure-shift confirmation. |
| `strategy_order_valid_bars` | 8 | 1-32 | Pending limit validity in M15 bars. |
| `strategy_pivot_h1_bars` | 24 | 4-96 | H1 lookback window converted to M15 bars for pivot-pool discovery. |
| `strategy_m15_pivot_lookback` | 96 | 8-256 | Closed M15 bars scanned for the most recent pivot high/low. |
| `strategy_max_spread_points` | 35 | 0-500 | Maximum spread in points for new entries; 0 disables the spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- `GBPUSD.DWX` - Card primary cable target for London-killzone FX liquidity sweeps.
- `EURUSD.DWX` - Card secondary fiber target sharing London-session FX liquidity behavior.

**Explicitly NOT for:**
- `SP500.DWX` - This card is the FX London-killzone cell, not the NY-index cell.
- `NDX.DWX` - Index-session timing and pools belong to sibling card QM5_12535.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 previous-day high/low; M15 bars over the last 24 H1 bars for pivot pools |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 80 |
| Typical hold time | Intraday; limit valid up to 8 M15 bars, runner flat by broker 17:00 |
| Expected drawdown profile | Approximately 10% expected drawdown from card frontmatter |
| Regime preference | London-session liquidity sweep with displacement and FVG retrace |
| Win rate target (qualitative) | Medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ict-2022-model-canonical-2026-06-12
**Source type:** video
**Pointer:** https://www.youtube.com/@InnerCircleTrader and `artifacts/cards_approved/QM5_12539_ict-london-kz-cable-sweep.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12539_ict-london-kz-cable-sweep.md`

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
| v1 | 2026-06-12 | Initial build from card | 585153c8-409b-437d-bf5f-ab4b2a5d92c6 |
