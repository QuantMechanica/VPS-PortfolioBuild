# QM5_36001_nnfx-classic-mcginley-ssl-wae — Strategy Spec

**EA ID:** QM5_36001
**Slug:** `nnfx-classic-mcginley-ssl-wae`
**Source:** `nnfx-classic-mcginley-ssl-wae-official-source` (see `strategy-seeds/sources/nnfx-classic-mcginley-ssl-wae/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_36001_nnfx-classic-mcginley-ssl-wae.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_36001_nnfx-classic-mcginley-ssl-wae.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The official NNFX 5-indicator algorithmic framework on D1 combines McGinley Dynamic (Baseline), SSL Channel (C1 Trigger), Vortex (C2 Confirmation), Waddah Attar Explosion (Volume), and DeMarker (Exit):
- Baseline: McGinley Dynamic(14) evaluated on completed D1 bars (Shift=1).
- C1 Trigger: SSL Channel(10) (High SMA vs Low SMA comparison).
- C2 Confirmation: Vortex(14) (VI+ vs VI- comparison).
- Volume Gate: Waddah Attar Explosion (MACD(12,26,9) momentum exceeding Bollinger Bands(20,2.0) explosion threshold or deadzone).
- Long Entry: Close[1] > McGinley[1] AND SSL Crossover == UP (+1) AND Vortex+ > Vortex- AND WAE > ExplosionLine.
- Short Entry: Close[1] < McGinley[1] AND SSL Crossover == DOWN (-1) AND Vortex- > Vortex+ AND WAE > ExplosionLine.
- Stop Loss: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Take Profit: Placed at 1.0 * ATR(14, D1)[1] from entry.
- Break-Even: Move SL to Entry + 1.0 pip when open profit reaches +1.0R (1.0x ATR).
- NNFX Indicator Exit: Close position when DeMarker(14) crosses opposite extreme (> 0.70 for Long, < 0.30 for Short) or SSL flips against position.
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, D1)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_mcginley_period` | 14 | 10 - 24 | McGinley Dynamic baseline period |
| `strategy_ssl_period` | 10 | 7 - 14 | SSL Channel C1 trigger period |
| `strategy_vortex_period` | 14 | 10 - 20 | Vortex C2 confirmation period |
| `strategy_wae_fast` | 12 | 8 - 16 | WAE MACD fast EMA period |
| `strategy_wae_slow` | 26 | 20 - 32 | WAE MACD slow EMA period |
| `strategy_wae_signal` | 9 | 5 - 12 | WAE MACD signal SMA period |
| `strategy_wae_bb_period` | 20 | 14 - 26 | WAE Bollinger Bands period |
| `strategy_wae_bb_deviation` | 2.0 | 1.5 - 2.5 | WAE Bollinger Bands deviation |
| `strategy_wae_sensitivity` | 150 | 100 - 200 | WAE sensitivity multiplier |
| `strategy_wae_deadzone_pts` | 150 | 100 - 200 | WAE deadzone in points |
| `strategy_demarker_period` | 14 | 10 - 20 | DeMarker exit indicator period |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for stop loss and spread filter |
| `strategy_sl_atr_mult` | 1.00 | 0.8 - 1.5 | Stop loss distance as ATR multiplier |
| `strategy_tp_atr_mult` | 1.00 | 0.8 - 1.5 | Take profit distance as ATR multiplier |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |
| `strategy_warmup_bars` | 150 | 100 - 250 | Warmup lookback bars for McGinley recursion |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `AUDUSD.DWX` — registered in magic_numbers.csv for this EA (slot 2)
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA (slot 3)
- `USDCAD.DWX` — registered in magic_numbers.csv for this EA (slot 4)

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
| Cadence note | "80-160 high-conviction trades per year across 5 pairs" |
| Typical hold time | Daily swing (several D1 bars, up to 1-3 weeks) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Multi-indicator trend consensus with confirmed volume expansion |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-classic-mcginley-ssl-wae-official-source`
**Pointer:** `strategy-seeds/sources/nnfx-classic-mcginley-ssl-wae/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_36001_nnfx-classic-mcginley-ssl-wae.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
