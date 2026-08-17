# QM5_35007_inside-bar-momentum-breakout-system — Strategy Spec

**EA ID:** QM5_35007
**Slug:** `inside-bar-momentum-breakout-system`
**Source:** `inside-bar-momentum-breakout-system-official-source` (see `strategy-seeds/sources/inside-bar-momentum-breakout-system/`)
**Author of this spec:** auto-generated ex-post by gen_spec_md.py
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

Mechanical strategy implemented per the approved card
`artifacts/cards_approved/QM5_35007_inside-bar-momentum-breakout-system.md`. See that card's body for
the full entry/exit/stop/sizing rules; this SPEC summarises the
implementation surface.

Entry/exit logic is encoded in the five `Strategy_*` hooks in
`QM5_35007_inside-bar-momentum-breakout-system.mq5`. Framework wiring (risk, magic, news, Friday close)
is inherited from `QM_Common.mqh` and is not redocumented here.

The Inside Bar Momentum Breakout System captures momentum expansions following extreme price compression during inside bar consolidations on the H4 timeframe:
- Inside Bar Condition: Evaluated on completed bars (Shift=1 and Shift=2). High[1] < High[2] AND Low[1] > Low[2]. Mother Range = High[2] - Low[2].
- Long Entry: Place BUY_STOP order at Mother High (High[2]) + 2.0 pips (or BUY market order if already broken out on open).
- Short Entry: Place SELL_STOP order at Mother Low (Low[2]) - 2.0 pips (or SELL market order if already broken out on open).
- Stop Loss: Placed at 0.20 * Mother Range distance from entry (clamped to minimum 5 pips).
- Take Profit: Placed at 2.0 * Mother Range distance from entry (1:2.0 Risk:Reward ratio).
- Cancellation / Expiry: Cancel unfulfilled pending stop orders after 3 H4 bars.
- Break-Even / Trailing: Move SL to Entry + 1.0 pip when open profit reaches +1.0R.
- No-Trade Filter: Dynamic spread filter (Spread > 1.8 * ATR(14, H4)[1]) and rollover blackout 23:55–00:05 GMT.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_buffer_pips` | 2.0 | 1.0 - 5.0 | Entry buffer beyond mother bar high/low in pips |
| `strategy_sl_ratio` | 0.20 | 0.15 - 0.35 | Stop loss distance as ratio of mother range |
| `strategy_tp_rr_mult` | 2.00 | 1.5 - 3.0 | Take profit multiplier (1:2.0 Risk:Reward ratio) |
| `strategy_atr_period` | 14 | 10 - 20 | ATR period for spread filter |
| `strategy_spread_atr_mult` | 1.80 | 1.0 - 2.5 | Spread filter ATR multiplier |
| `strategy_pending_expiry_bars` | 3 | 2 - 6 | Expiration bars for pending orders |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
> qm_news_mode, qm_rng_seed, qm_stress_reject_probability,
> qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md` — not re-listed here.

---

## 3. Symbol Universe

**Designed for:**
- `EURUSD.DWX` — registered in magic_numbers.csv for this EA (slot 0)
- `GBPUSD.DWX` — registered in magic_numbers.csv for this EA (slot 1)
- `USDJPY.DWX` — registered in magic_numbers.csv for this EA (slot 2)

**Explicitly NOT for:** any symbol not in the list above (no implicit
universe expansion at runtime; the `QM_SymbolGuard` framework helper
rejects foreign symbols).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H4` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | 40 |
| Cadence note | "80-160 high-conviction trades per year" |
| Typical hold time | Swing (several H4 bars, up to 1-3 days) |
| Expected drawdown profile | bounded by RISK_FIXED + FTMO 10% total DD ceiling |
| Regime preference | Volatility compression followed by directional breakout expansion |
| Win rate target (qualitative) | high |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `inside-bar-momentum-breakout-system-official-source`
**Pointer:** `strategy-seeds/sources/inside-bar-momentum-breakout-system/`
**R1–R4 verdict (Q00):** all PASS — see
`artifacts/cards_approved/QM5_35007_inside-bar-momentum-breakout-system.md`

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 – Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (typically 0.3% – 0.5%) |

ENV→mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---
