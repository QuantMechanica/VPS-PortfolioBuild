# QM5_12534_nnfx-canonical-d1-fullstack - Strategy Spec

**EA ID:** QM5_12534
**Slug:** `nnfx-canonical-d1-fullstack`
**Source:** `nnfx-vp-canonical-2026-06-12` (see `strategy-seeds/sources/nnfx-vp-canonical-2026-06-12/`)
**Author of this spec:** Codex
**Last revised:** 2026-06-12

---

## 1. Strategy Logic

The EA trades the doctrine-faithful NNFX daily stack on closed D1 bars. A long trade requires a recent close cross above Kijun-sen(26), current close still within 1 ATR(14) of that baseline, SSL Channel(10) long, Aroon(25) Up greater than Down, and Waddah Attar Explosion momentum above its explosion/dead-zone threshold. Shorts mirror the same conditions below the baseline. The initial stop is 1.5 ATR(14); half the position is closed after a 1 ATR move and the runner exits when price crosses back through Kijun-sen(26) or SSL flips.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_kijun_period` | 26 | 2+ | Kijun-sen baseline period. |
| `strategy_ssl_period` | 10 | 2+ | SSL Channel high/low SMA period. |
| `strategy_aroon_period` | 25 | 2+ | Aroon lookback for up/down confirmation. |
| `strategy_atr_period` | 14 | 1+ | ATR period for proximity, stop, and partial trigger. |
| `strategy_atr_proximity_mult` | 1.0 | 0.1+ | Maximum distance from close to Kijun in ATR units. |
| `strategy_sl_atr_mult` | 1.5 | 0.1+ | Initial stop distance in ATR units. |
| `strategy_tp_half_atr_mult` | 1.0 | 0.1+ | Partial close trigger in ATR units. |
| `strategy_wae_fast` | 20 | 1+ | WAE MACD fast period. |
| `strategy_wae_slow` | 40 | 2+ | WAE MACD slow period. |
| `strategy_wae_signal` | 9 | 1+ | WAE MACD signal period. |
| `strategy_wae_sensitivity` | 150.0 | 1+ | WAE momentum scaling factor. |
| `strategy_wae_bb_period` | 20 | 2+ | WAE explosion Bollinger period. |
| `strategy_wae_bb_deviation` | 2.0 | 0.1+ | WAE explosion Bollinger deviation. |
| `strategy_wae_deadzone_pts` | 150 | 0+ | Minimum WAE dead-zone threshold in points. |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` - card-listed liquid FX pair with D1 history.
- `GBPUSD.DWX` - card-listed liquid FX pair with D1 history.
- `USDJPY.DWX` - card-listed liquid FX pair with D1 history.
- `AUDUSD.DWX` - card-listed liquid FX pair with D1 history.
- `NZDUSD.DWX` - card-listed liquid FX pair with D1 history.
- `USDCAD.DWX` - card-listed liquid FX pair with D1 history.
- `USDCHF.DWX` - card-listed liquid FX pair with D1 history.
- `EURJPY.DWX` - card-listed liquid FX cross with D1 history.
- `GBPJPY.DWX` - card-listed liquid FX cross with D1 history.

**Explicitly NOT for:**
- Non-FX `.DWX` symbols - the approved card defines a nine-pair FX universe only.

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
| Trades / year / symbol | `18` |
| Typical hold time | days to weeks, with trend runners held until Kijun or SSL reversal |
| Expected drawdown profile | streak-prone D1 FX trend drawdown clusters, card target DD about 12 percent |
| Regime preference | trend-following |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `nnfx-vp-canonical-2026-06-12`
**Source type:** public trading framework
**Pointer:** `https://nononsenseforex.com/`
**R1-R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12534_nnfx-canonical-d1-fullstack.md`

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
| v1 | 2026-06-12 | Initial build from card | 3ab6373d-e556-47f5-a494-13bf70474ae9 |
