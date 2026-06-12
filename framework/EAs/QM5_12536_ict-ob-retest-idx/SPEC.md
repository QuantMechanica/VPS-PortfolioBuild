# QM5_12536_ict-ob-retest-idx - Strategy Spec

**EA ID:** QM5_12536
**Slug:** ict-ob-retest-idx
**Source:** ict-2022-model-canonical-2026-06-12 (see `strategy-seeds/sources/ict-2022-model-canonical-2026-06-12/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades a New York AM M15 liquidity sweep on index CFDs. A closed M15 bar must sweep the nearest lower or upper liquidity pool and close back through it, then within eight M15 bars price must close beyond the most recent M15 pivot in the reversal direction. The entry is a limit order at the midpoint of the last opposing candle body before the displacement leg. The stop is beyond the order-block body far end plus 0.3 ATR(14), TP1 closes half at the opposite PDH/PDL or Asia pool capped at 2R, and the runner targets 3R or exits at broker 21:00.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| strategy_atr_period | 14 | 2-100 | ATR period used for stop buffer and risk cap. |
| strategy_atr_buffer_mult | 0.30 | 0.0-2.0 | ATR multiple placed beyond the order-block body far end for SL. |
| strategy_max_risk_atr_mult | 2.50 | 0.5-10.0 | Skip trades whose entry-to-stop risk exceeds this ATR multiple. |
| strategy_mss_max_bars | 8 | 1-32 | Maximum M15 bars from sweep to market-structure-shift close. |
| strategy_order_valid_bars | 8 | 1-32 | Pending order validity in M15 bars. |
| strategy_m15_pool_lookback | 96 | 16-256 | M15 pivot-pool scan equivalent to the card's last 24 H1 bars. |
| strategy_m15_pivot_lookback | 32 | 8-128 | Recent M15 pivot scan used for MSS confirmation. |
| strategy_max_spread_points | 120 | 0-1000 | Maximum allowed spread in points; 0 disables the spread gate. |

---

## 3. Symbol Universe

**Designed for:**
- NDX.DWX - Nasdaq 100 index CFD in the card's R3 PASS universe.
- WS30.DWX - Dow 30 index CFD in the card's R3 PASS universe.

**Explicitly NOT for:**
- SP500.DWX - available as a custom symbol, but not listed in this card's target universe or R3 reasoning.
- GDAXI.DWX - available index CFD, but not listed in this card's target universe or R3 reasoning.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | M15 |
| Multi-timeframe refs | D1 previous-day high/low; M15 Asia range 01:00-09:00; M15 pivots over 96 bars as the card's 24 H1-bar structural reference |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) (default framework entry gate) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 90 |
| Typical hold time | Card frontmatter not specified; intraday, flat by broker 21:00 and Friday close |
| Expected drawdown profile | expected_dd_pct 10; FTMO block states daily DD <=5% and total DD <=10% |
| Regime preference | Card frontmatter not specified; liquidity-sweep reversal with displacement confirmation |
| Win rate target (qualitative) | Not specified in card |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** ict-2022-model-canonical-2026-06-12
**Source type:** video / public ICT material
**Pointer:** `https://www.youtube.com/@InnerCircleTrader` and `artifacts/cards_approved/QM5_12536_ict-ob-retest-idx.md`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12536_ict-ob-retest-idx.md`

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
| v1 | 2026-06-12 | Initial build from card | eeebed60-2034-4e21-98c4-4571afbc31c0 |
