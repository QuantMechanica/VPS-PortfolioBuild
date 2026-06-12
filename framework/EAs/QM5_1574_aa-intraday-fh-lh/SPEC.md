# QM5_1574_aa-intraday-fh-lh — Strategy Spec

**EA ID:** QM5_1574
**Slug:** `aa-intraday-fh-lh`
**Source:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7` (see `strategy-seeds/sources/ede348b4-0fa7-5be1-baa8-09e9089b67b7/`)
**Author of this spec:** Claude
**Last revised:** 2026-06-13

---

## 1. Strategy Logic

The EA mechanises the Gao-Han-Zhou intraday momentum finding published by Alpha Architect (Jack Vogel, PhD, 2014). The rule is deterministic: compute the return of the first 30-minute bar of the equity-index cash session (close/open − 1). At the opening of the final 30-minute window before session close, enter long if the first-half return was positive, short if negative, and hold cash if zero. The position is closed at the hard session-close time with no overnight holding. A day-key guard enforces the one-trade-per-symbol-per-session limit required by the card.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_session_open_hhmm` | 1630 | 0–2359 | HHMM of first M30 bar open in broker time (NY-close convention) |
| `strategy_entry_hhmm` | 2230 | 0–2359 | HHMM of last-half-hour entry bar in broker time |
| `strategy_session_close_hhmm` | 2300 | 0–2359 | Hard exit time in broker time |
| `strategy_atr_period` | 14 | 5–50 | ATR period on M30 for initial stop distance |
| `strategy_atr_sl_mult` | 1.5 | 0.5–5.0 | ATR multiplier for initial stop |
| `strategy_max_spread_points` | 250 | 0–2000 | Skip entry if spread exceeds this (0 = disabled) |

---

## 3. Symbol Universe

**Designed for:**
- `SP500.DWX` — S&P 500 cash index; primary research instrument; has reliable intraday tick coverage from OWNER-provided data 2018-07→2026-05; backtest-only (broker does not route orders)
- `NDX.DWX` — Nasdaq 100 cash index; same NY-close session; live-tradable; highest-correlation liquid alternative
- `WS30.DWX` — Dow Jones 30 cash index; same NY-close session; live-tradable; diversification across large-cap US indices

**Explicitly NOT for:**
- Forex pairs — intraday momentum effect documented on equity indices only
- `GDAXI.DWX` / `UK100.DWX` — different session windows require separate parameter sets (not registered in this build)

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `M30` |
| Multi-timeframe refs | `PERIOD_M30` only (session-bar lookup via iBarShift + QM_ATR) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~252 (one per trading session) |
| Typical hold time | ~30 minutes (one M30 bar) |
| Expected drawdown profile | Frequent small losses; edge from statistical momentum skew |
| Regime preference | Intraday momentum / index-timing |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

This card was mechanised from:

**Source ID:** `ede348b4-0fa7-5be1-baa8-09e9089b67b7`
**Source type:** blog / SSRN-linked paper
**Pointer:** Jack Vogel PhD, "Attention Prop Traders: The first half hour of trading predicts the last half hour...", Alpha Architect, 2014-08-21
**R1–R4 verdict (Q00):** all PASS per `artifacts/cards_approved/QM5_1574_aa-intraday-fh-lh.md`

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
| v1 | 2026-06-13 | Initial build from card | f35bd96d-a753-4ece-b967-fade70e39f78 |
