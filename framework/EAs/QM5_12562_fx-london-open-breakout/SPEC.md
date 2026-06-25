# QM5_12562_fx-london-open-breakout — Strategy Spec

**EA ID:** QM5_12562
**Slug:** `fx-london-open-breakout`
**Source:** `1c0f4b2e-7a3d-5e91-b8c4-2f6a9d5e1b03` (see `strategy-seeds/sources/1c0f4b2e-7a3d-5e91-b8c4-2f6a9d5e1b03/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-25

---

## 1. Strategy Logic

At the London session open (08:00 London local, DST-aware broker time), the EA records the high and low of the first four M15 bars (the Opening Range, 60 min). For the following three hours (entry window), it watches for a completed M15 bar that closes above OR_high (long) or below OR_low (short), provided the breakout bar's range is at least 0.5 × ATR(14, M15) and the OR width is at least 0.6 × ATR(14, D1)/4. The SL is placed just beyond the opposite OR extreme (± 0.2 × ATR buffer), capped at 1.6 × ATR(14, M15). The TP is at 2R; the stop moves to breakeven once price reaches 1R in profit. Any open position is closed at 17:00 London, or earlier if the position has not reached 0.5R within 10 M15 bars (time-stop).

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_or_bars` | 4 | 2–8 | M15 bars that form the Opening Range (4 = 60 min) |
| `strategy_entry_window_h` | 3 | 1–5 | Hours after OR forms during which entries are valid |
| `strategy_atr_period` | 14 | 7–20 | ATR lookback used for confirmation, SL sizing, and cap |
| `strategy_bb_atr_mult` | 0.5 | 0.2–1.0 | Breakout bar range must be >= mult × ATR(14, M15) |
| `strategy_or_width_atr_mult` | 0.6 | 0.2–1.0 | OR width must be >= mult × ATR(14, D1)/4 |
| `strategy_sl_buffer_atr` | 0.2 | 0.0–0.5 | Additional SL buffer beyond OR extreme in ATR(14, M15) multiples |
| `strategy_sl_cap_atr` | 1.6 | 1.0–3.0 | Maximum allowed SL distance in ATR(14, M15) multiples |
| `strategy_tp_rr` | 2.0 | 1.5–4.0 | Take-profit as R-multiple of SL distance |
| `strategy_be_r` | 1.0 | 0.5–2.0 | R-multiple at which SL moves to breakeven |
| `strategy_time_stop_bars` | 10 | 5–20 | Exit if not at target R within this many M15 bars |
| `strategy_time_stop_r` | 0.5 | 0.25–1.0 | Minimum R profit required to survive time-stop |

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — slot 0; EUR/USD is the most liquid London-session FX pair; large ATR coverage of the London open surge
- `GBPUSD.DWX` — slot 1; GBP/USD has the highest volatility at London open; natural home of the ORB edge
- `USDJPY.DWX` — slot 2; USD/JPY spans Asian and London overlap; London open often establishes the day's range

**Explicitly NOT for:**
- Equity indices — the London ORB window and timing parameters are calibrated for FX majors; indices use a separate sleeve (QM5_12561)
- Cross pairs (EURUSD-derived crosses) — correlated but with wider spreads; not in the card basket

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M15` |
| Multi-timeframe refs | `PERIOD_D1` (ATR(14, D1) for OR-width confirmation) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~130 |
| Typical hold time | 30 min – 3 hours (session-flat; no overnight hold) |
| Expected drawdown profile | Low per-trade DD (~1R max); intraday only |
| Regime preference | Breakout / volatility-expansion at session open |
| Win rate target (qualitative) | medium (~45–55%; positive expectancy via 2R TP) |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `1c0f4b2e-7a3d-5e91-b8c4-2f6a9d5e1b03`
**Source type:** book / trading literature
**Pointer:** Opening-range breakout lineage: Crabel, "Day Trading with Short Term Price Patterns and Opening Range Breakout" (1990); applied to the London FX session open.
**R1–R4 verdict (Q00):** all PASS / see `artifacts/cards_approved/QM5_12562_fx-london-open-breakout.md`

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
| v1 | 2026-06-25 | Initial build from card | bd8ddfc1-5416-4352-a31a-e12a583fbc37 |
