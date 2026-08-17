# QM5_36002_nnfx-kijunsen-absolute-strength-damiani — Strategy Spec

**EA ID:** QM5_36002
**Slug:** `nnfx-kijunsen-absolute-strength-damiani`
**Source:** `nnfx-kijunsen-absolute-strength-damiani-official-source` (see `strategy-seeds/sources/nnfx-kijunsen-absolute-strength-damiani/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_36002_nnfx-kijunsen-absolute-strength-damiani.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_36002_nnfx-kijunsen-absolute-strength-damiani.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The NNFX algorithmic framework on D1 combines Kijun-Sen (Baseline), Absolute Strength Oscillator (C1 Trigger), Aroon (C2 Confirmation), and Damiani Volatmeter (Volume/Volatility filter):
- Baseline: Ichimoku Kijun-Sen(26) evaluated on completed D1 bars (Shift=1).
- C1 Trigger: Absolute Strength Oscillator (ASO 10) comparing Bulls Power vs Bears Power.
- C2 Confirmation: Aroon(25) measuring periods since high/low with confirmation threshold 70.0.
- Volume Gate: Damiani Volatmeter (viscosity ATR 13 vs sedimentation ATR 40) confirming volatility expansion above anti-threshold.
- Long Entry: Close[1] > Kijun[1] AND ASO_Bulls[1] > ASO_Bears[1] AND AroonUp[1] >= 70.0 AND Damiani Trade == TRUE.
- Short Entry: Close[1] < Kijun[1] AND ASO_Bears[1] > ASO_Bulls[1] AND AroonDown[1] >= 70.0 AND Damiani Trade == TRUE.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Take Profit: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- Runner Exit: Close position when price re-crosses Kijun-Sen line (Close[1] < Kijun[1] for Long, Close[1] > Kijun[1] for Short).
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_kijun_period` | 26 | 20 - 35 | Kijun-Sen baseline lookback period |
| `strategy_tenkan_period` | 9 | 7 - 12 | Tenkan-Sen period |
| `strategy_senkou_period` | 52 | 40 - 60 | Senkou Span B period |
| `strategy_aso_period` | 10 | 7 - 14 | Absolute Strength Oscillator period |
| `strategy_aroon_period` | 25 | 14 - 30 | Aroon confirmation period |
| `strategy_aroon_threshold` | 70.0 | 60.0 - 80.0 | Aroon confirmation threshold |
| `strategy_damiani_vis_period` | 13 | 10 - 20 | Damiani Volatmeter viscosity ATR period |
| `strategy_damiani_sed_period` | 40 | 30 - 50 | Damiani Volatmeter sedimentation ATR period |
| `strategy_damiani_threshold` | 1.40 | 1.0 - 2.0 | Damiani Volatmeter threshold multiplier |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | 0.8 - 1.5 | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | 0.8 - 1.5 | Take profit distance as ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `GBPJPY.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `AUDCAD.DWX` — registered in magic_numbers.csv for this EA (slot 2)
- `NZDUSD.DWX` — registered in magic_numbers.csv for this EA (slot 3)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 25 |
| Cadence note | "80-160 high-conviction trades per year across 4 pairs" |
| Typical hold time | Daily swing (several D1 bars, up to 1-3 weeks) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Multi-indicator trend consensus with confirmed volatility expansion |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-kijunsen-absolute-strength-damiani-official-source`
**Pointer:** `strategy-seeds/sources/nnfx-kijunsen-absolute-strength-damiani/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_36002_nnfx-kijunsen-absolute-strength-damiani.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
