# QM5_9724_ff-alien-adx-bbs-h1 — Strategy Spec

**EA ID:** QM5_9724
**Slug:** `ff-alien-adx-bbs-h1`
**Source:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Author of this spec:** Claude
**Last revised:** 2026-06-11

---

## 1. Strategy Logic

Long when the last completed H1 bar closes above its Bollinger Bands (20, 2.0) upper band, following a Bollinger width squeeze (at least 5 of the prior 8 bars had BB width below the 20-bar median), with all five ADX speeds (7, 21, 42, 89, 144) rising versus two bars prior and at least three above 20, RSI(14) above 50 and rising (or above 80), Stochastic(21,10,10) K above D and above 50, and the M15 close above its M15 BB(20) midline. Short mirrors these conditions below the lower band. Stop is placed at the breakout bar's extreme minus (long) or plus (short) 0.30×ATR(14). Take-profit is 2R. Position closes early on two consecutive bars of ADX(42/89/144) decline, an RSI(14) cross back through 50 against the trade, or after 18 bars.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_bb_period` | 20 | 10–50 | Bollinger Bands MA period |
| `strategy_bb_dev` | 2.0 | 1.5–3.0 | Bollinger Bands deviation |
| `strategy_adx_p1` | 7 | 5–20 | ADX speed 1 (fastest) |
| `strategy_adx_p2` | 21 | 14–30 | ADX speed 2 |
| `strategy_adx_p3` | 42 | 30–60 | ADX speed 3 (also exit) |
| `strategy_adx_p4` | 89 | 60–120 | ADX speed 4 (also exit) |
| `strategy_adx_p5` | 144 | 100–200 | ADX speed 5 (also exit) |
| `strategy_adx_threshold` | 20.0 | 15–30 | Min ADX value for 3-of-5 gate |
| `strategy_rsi_period` | 14 | 7–21 | RSI period (RSIOMA proxy) |
| `strategy_stoch_k` | 21 | 14–30 | Stochastic K period |
| `strategy_stoch_d` | 10 | 3–14 | Stochastic D period |
| `strategy_stoch_slow` | 10 | 3–14 | Stochastic slowing |
| `strategy_sl_atr_mult` | 0.30 | 0.1–1.0 | ATR multiplier for SL buffer beyond bar extreme |
| `strategy_tp_r` | 2.0 | 1.0–4.0 | Take-profit in R multiples |
| `strategy_time_stop_bars` | 18 | 8–40 | Max H1 bars before forced exit |
| `strategy_atr_pct_lookback` | 60 | 20–120 | ATR percentile lookback bars |
| `strategy_atr_pct_floor` | 20.0 | 5–40 | Skip if ATR below this percentile |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — liquid FX major with strong volatility-expansion regimes; H1 BB squeeze patterns are common
- `GBPUSD.DWX` — volatile FX major; volatility expansion / breakout behaviour consistent with strategy edge
- `AUDUSD.DWX` — risk-correlated FX pair; strong trending regimes support multi-speed ADX expansion
- `XAUUSD.DWX` — gold; high ATR and strong directional trends make it suitable for this breakout approach

**Explicitly NOT for:**
- Equity indices (SP500/NDX/WS30) — card specifies FX/metals basket only

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `PERIOD_M15` (midline directional filter) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~40 |
| Typical hold time | 3–18 H1 bars (3–18 hours) |
| Expected drawdown profile | Volatility-expansion drawdowns; single-digit % with 2R TP |
| Regime preference | volatility-expansion / trend |
| Win rate target (qualitative) | medium (~40–55% with 2R reward) |

---

## 6. Source Citation

**Source ID:** `6e967762-b26d-59a3-b076-35c17f2e7c36`
**Source type:** forum
**Pointer:** forexalien, "Alien's Extraterrestrial Visual Systems", ForexFactory 2013, https://www.forexfactory.com/thread/463573-aliens-extraterrestrial-visual-systems
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_9724_ff-alien-adx-bbs-h1.md`

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
| v1 | 2026-06-11 | Initial build from card | 5bd12607-4ba7-426c-9d6f-05bf21b8e252 |
