# QM5_33004_kevin-davey-3bar-momentum-expansion — Strategy Spec

**EA ID:** QM5_33004
**Slug:** `kevin-davey-3bar-momentum-expansion`
**Source:** `kevin-davey-3bar-momentum-expansion-official-source`
**Author of this spec:** Codex
**Last revised:** 2026-08-17

---

## 1. Strategy Logic

On each closed H1 bar, the EA looks for three consecutive bars with rising closes,
rising highs, and higher tick volume on the latest bar than on the prior bar. It
places a buy stop one tick above the latest setup high, with the stop at the lowest
low of the setup and a 2.5R target. The explicit sell-stop rule is implemented as
the directional mirror: falling closes and lows, the stop above the setup high,
and the same volume confirmation. At +1R the position begins a 2.5 ATR trail; any
position still open after 96 H1 periods is closed by the time stop.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---:|---|
| `strategy_setup_bars` | 3 | 2–5 | Consecutive closed bars in the momentum setup. |
| `strategy_atr_period` | 14 | 10–30 | ATR lookback used by the trailing stop and spread cap. |
| `strategy_atr_trail_mult` | 2.50 | 1.5–3.5 | ATR distance of the trail after +1R. |
| `strategy_reward_r` | 2.50 | 1.0–4.0 | Take-profit distance in initial-risk multiples. |
| `strategy_entry_offset_ticks` | 1 | 1–3 | Pending-entry offset beyond the setup extreme. |
| `strategy_pending_expiry_bars` | 1 | 1–4 | H1 bars before an unfilled setup order expires. |
| `strategy_max_hold_bars` | 96 | 24–120 | Maximum holding period in H1-equivalent hours. |
| `strategy_max_spread_atr` | 1.80 | 0.5–2.0 | Blocks positive spreads wider than this ATR multiple. |
| `strategy_daily_loss_limit_pct` | 2.00 | 0.5–2.5 | Stops new entries after this broker-day realized loss. |

---

## 3. Symbol Universe

**Designed for:**

- `XTIUSD.DWX` — primary liquid energy market from the approved card.
- `XAUUSD.DWX` — card-authorized commodity portability check.
- `EURUSD.DWX` — card-authorized liquid cross-asset control.

**Explicitly NOT for:**

- Symbols outside `framework/registry/dwx_symbol_matrix.csv` — no governed Model-4 history exists for them.
- Monthly charts — the approved mechanic and data contract are H1-native.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | none |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` through the framework skeleton |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | approximately 70 (ordering prior; Q02 measures reality) |
| Typical hold time | intraday to four trading days; hard cap 96 H1 periods |
| Expected drawdown profile | card prior 15% maximum drawdown, subject to pipeline measurement |
| Regime preference | directional momentum and volatility expansion |
| Win rate target (qualitative) | medium; payoff is designed around 2.5R winners |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `kevin-davey-3bar-momentum-expansion-official-source`
**Source type:** book
**Pointer:** Davey, Kevin J. (2014), *Building Winning Algorithmic Trading Systems*, John Wiley & Sons
**R1–R4 verdict (Q00):** R1 lineage recorded and R2–R4 PASS per `artifacts/cards_approved/QM5_33004_kevin-davey-3bar-momentum-expansion.md`

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
| v1 | 2026-08-17 | Initial build from card | build task `bd9df2df-ddcc-47a3-b822-95c6e4866e9e` |
