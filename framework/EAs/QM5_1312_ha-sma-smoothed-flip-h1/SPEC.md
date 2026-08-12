# QM5_1312_ha-sma-smoothed-flip-h1 — Strategy Spec

**EA ID:** QM5_1312
**Slug:** `ha-sma-smoothed-flip-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36` (see `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/`)
**Author of this spec:** Claude
**Last revised:** 2026-08-10

---

## 1. Strategy Logic

Double-SMA-smoothed Heiken-Ashi color-flip trend trigger. OHLC is first
pre-smoothed with `SMA(6)` (`O'/H'/L'/C'`), then transformed into a Heiken-Ashi
candle via the standard recurrence (`HAClose=(O'+H'+L'+C')/4`,
`HAOpen=(HAOpen_prev+HAClose_prev)/2`), then the resulting `HAOpen`/`HAClose`
line is itself post-smoothed with `SMA(2)` (`HAO''`/`HAC''`) to produce the
discrete bull/bear color. A BUY fires on H1 close when the color flips
bullish after a confirmed 2-bar bear streak (`color[0]=bull, color[1]=bear,
color[2]=bear`), the signal bar has no meaningful lower wick
(`HAO''-HALow <= 0.35*(HAHigh-HALow)`), and price closes above `EMA(200,H1)`
(macro bias). SELL mirrors. Exit is the color flip against the position, a
genuine `EMA(200)` cross against the position, or (implicitly via the
framework) Friday close; stop loss sits at the 2-bar HA extremum plus/minus a
`0.5*ATR(14,H1)` buffer. Sibling of QM5_1313 (EMA pre-smoothing, no
streak/no-wick gate) — this card is the SMA-smoothed, confirmation-gated
variant. Trades only within the 06:00–21:00 broker session and only when the
current spread is not more than `1.5x` the trailing 20-bar median spread.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_pre_smooth_period` | 6 | 4-10 | OHLC pre-smoothing SMA period |
| `strategy_post_smooth_period` | 2 | 2-4 | HA line post-smoothing SMA period |
| `strategy_macro_ema_period` | 200 | 150-250 | H1 macro-bias EMA period |
| `strategy_ha_seed_bars` | 120 | 20+ | Bounded recursion seed depth for the smoothed-HA computation |
| `strategy_wick_max_fraction` | 0.35 | 0.0-1.0 | No-wick gate: shadow <= this fraction of the HA candle range |
| `strategy_atr_period` | 14 | 5-100 | ATR period (stop / target scale) |
| `strategy_sl_atr_buffer` | 0.5 | 0.0-3.0 | SL = 2-bar HA extremum -/+ buffer * ATR |
| `strategy_tp_atr_mult` | 2.0 | 0.5-5.0 | TP distance = mult * ATR(14,H1) from entry |
| `strategy_session_start_hour` | 6 | 0-23 | Broker-time session open (inclusive) |
| `strategy_session_end_hour` | 21 | 0-23 | Broker-time session close (exclusive) |
| `strategy_spread_median_mult` | 1.5 | 0.5-5.0 | Block if spread > this * trailing median spread |
| `strategy_spread_median_bars` | 20 | 5-20 | Rolling window (closed bars) for the median-spread guard |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX` — FX majors with clean H1 trend
  structure suited to smoothed-HA color-flip triggers
- `XAUUSD.DWX` — gold; strong H1 trend character

**Explicitly NOT for:**
- Ultra-low-liquidity exotics — the double-smoothed HA computation needs a
  clean, gap-free H1 series with a deep enough bounded lookback.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | None — single-TF (H1); the "smoothing" is an input/output SMA filter, not a separate anchor timeframe |
| Bar gating | Entry/exit evaluated on the framework's H1 `QM_IsNewBar()` gate |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | `~18` |
| Typical hold time | `hours to a few days` |
| Expected drawdown profile | `~18% max DD; single position per symbol` |
| Regime preference | `trend-following (smoothed-HA color-flip trades WITH the emerging trend, gated by macro EMA(200) bias)` |
| Win rate target (qualitative) | `medium` |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** `forum`
**Pointer:** `strategy-seeds/sources/6e967762-b26d-59a3-b076-35c17f2e7c36/` — ForexFactory "SmoothedHeikenAshi" community cluster (mladen/igorad indicator lineage, late-2000s), paired with an EMA-bias filter.
**R1–R4 verdict (Q00):** R1 TIER_C / R2–R4 PASS per `artifacts/cards_approved/QM5_1312_ha-sma-smoothed-flip-h1.md`

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
| v1 | 2026-08-10 | Initial build from card | 525ec19f-b7ac-413d-90ee-478435ca107c |
