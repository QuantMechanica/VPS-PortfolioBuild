# QM5_1626_hopwood-bermaui-stoch-h4 - Strategy Spec

**EA ID:** QM5_1626
**Slug:** hopwood-bermaui-stoch-h4
**Source:** 6e967762-b26d-59a3-b076-35c17f2e7c36 (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

The EA trades H4 closed-bar mid-line crosses of a double-smoothed Stochastic %K
oscillator (the "Bermaui" kernel: raw Stochastic %K(14,3) first passed through a
WilderMA(7), then through an HMA(7)). It enters long when the smoothed line
crosses up through 50 with a positive delta and D1 close is above D1 SMA(200);
it enters short on the mirror condition. Open trades exit on an opposite
mid-line cross with confirming delta sign, a time-stop, the framework ATR stop,
a break-even step at +1.0*ATR, and a 50% partial close at +2.0*ATR. Entries are
skipped when spread exceeds 0.3*ATR(14) or when H4 ATR(14) is below half of H4
ATR(50) (dead-flat range filter).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| strategy_stoch_k_period | 14 | >=2 | Raw Stochastic %K period. |
| strategy_stoch_d_period | 3 | >=1 | Raw Stochastic %D period (handle only, %K is used). |
| strategy_stoch_slowing | 3 | >=1 | Raw Stochastic slowing. |
| strategy_wilder_period | 7 | >=2 | WilderMA first-pass smoothing period. |
| strategy_hma_period | 7 | >=2 | HMA second-pass smoothing period. |
| strategy_mid_line | 50.0 | 0-100 | Smoothed-line midline crossing threshold. |
| strategy_sma_period | 200 | >=1 | D1 SMA period used as the directional regime filter. |
| strategy_atr_period | 14 | >=1 | ATR period used for stop/TP/spread-filter distance. |
| strategy_range_atr_period | 50 | >=1 | Slower ATR period used for the range-sanity filter. |
| strategy_range_sanity_mult | 0.5 | >0 | Minimum ATR(14)/ATR(50) ratio required to trade. |
| strategy_sl_atr_mult | 2.5 | >0 | ATR multiple for the initial stop loss. |
| strategy_tp_atr_mult | 2.0 | >0 | ATR multiple for the 50% partial-close profit target. |
| strategy_be_atr_mult | 1.0 | >0 | ATR multiple at which the stop moves to break-even+spread. |
| strategy_time_stop_bars | 30 | >=1 | H4 bars after which an open trade is force-closed. |
| strategy_cooldown_bars | 6 | >=0 | H4 bars of same-direction re-entry cooldown after a close. |
| strategy_max_spread_atr_mult | 0.3 | >=0 | Maximum spread as a fraction of ATR(14); zero disables trading. |
| strategy_sl_swing_anchor | false | bool | If true, anchor SL to the 14-bar swing extreme instead of ATR. |

---

## 3. Symbol Universe

**Designed for:**
- EURUSD.DWX - Major FX pair listed in the card's target_symbols.
- GBPUSD.DWX - Major FX pair listed in the card's target_symbols.
- NDX.DWX - Index CFD listed in the card's target_symbols.
- XAUUSD.DWX - Metal listed in the card's target_symbols.

**Explicitly NOT for:**
- SP500.DWX - not in the card's target_symbols; no T6 broker-routable parallel-validation planned for this EA.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | H4 |
| Multi-timeframe refs | D1 close + D1 SMA(200) regime gate |
| Bar gating | QM_IsNewBar(_Symbol, PERIOD_CURRENT) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (card estimate: 8-18/yr/symbol) |
| Typical hold time | Up to 30 H4 bars (~5 trading days) or an earlier opposite mid-line cross. |
| Expected drawdown profile | expected_pf 1.2 / expected_dd_pct 20.0 per card frontmatter. |
| Regime preference | Trend-following, gated by D1 SMA(200) and an H4 range-sanity filter. |
| Win rate target (qualitative) | Medium; 2.5R stop vs partial 2.0R target, slower double-smoothed signal reduces whipsaw entries. |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** 6e967762-b26d-59a3-b076-35c17f2e7c36
**Source type:** forum (forexfactory-trading-systems, Hopwood-archive Bermaui-family cluster)
**Pointer:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1626_hopwood-bermaui-stoch-h4.md`
**R1-R4 verdict (Q00):** R1 TIER_C (informational), R2 PASS, R3 PASS, R4 PASS / see card above.

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (card default 0.5%) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-10 | Initial build from card | capacity-spilled build_ea task, self-allocated registries per SOP 2 |
