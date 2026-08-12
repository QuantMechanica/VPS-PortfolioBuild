# QM5_20004_turn-of-month-index-long — Strategy Spec

**EA ID:** QM5_20004
**Slug:** `turn-of-month-index-long`
**Source:** `fx_edge_army_A3_2026-07-16` (see `artifacts/cards_approved/QM5_20004_turn-of-month-index-long.md`)
**Author of this spec:** Claude (headless build lane)
**Last revised:** 2026-07-19

---

## 1. Strategy Logic

Around the turn of the month, equity indices face non-discretionary, date-fixed buy
pressure (pension/401(k)/payroll-deferral inflows and calendar-locked fund rebalancing).
The EA goes long the index once per month, mechanically detected as the
`QM_IsNewCalendarPeriod(PERIOD_MN1)` edge (the D1 bar that just opened is the new
month's first trading day, so the prior closed D1 bar was the last trading day of the
old month) and filled at the framework's market price on that tick. An optional filter
skips the entry if the index closed the prior month below its N-day SMA (hard downtrend).
The position carries a protective ATR(20) stop and is flattened once it has held through
`strategy_exit_day_n` trading days of the new month (a trading-day counter, not a
calendar-day threshold, per the card's "trading-day counting" requirement). No fixed
profit target — the edge is the calendar window, not a price level.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_exit_day_n` | 3 | discrete, ±1 lattice step | Trading days held into the new month before flattening. |
| `strategy_trend_filter_enabled` | true | true/false | Skip entry if last month closed in a hard downtrend. |
| `strategy_trend_sma_period` | 50 | 20-100 | SMA period used by the trend filter (card names "50-day"). |
| `strategy_atr_period` | 20 | fixed at 20 per card | ATR period for the protective stop, "k*ATR(20)". |
| `strategy_sl_atr_mult` | 3.0 | 1.5-5.0 | Protective-stop ATR multiplier ("wide -- this is a flow trade"); no numeric default given in the card, see open_questions. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode,
> qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `GDAXI.DWX` — port of the card's primary symbol `DE40.DWX` (DAX 40), which is not a
  registered `.DWX` Custom Symbol; `GDAXI.DWX` is the canonical DAX symbol in
  `dwx_symbol_matrix.csv` and is the symbol used by every other DAX-targeting EA in the
  farm. Deliberately preferred per the card: the US turn-of-month effect is
  partially arbitraged away, so the less-crowded European index is the higher-prior bet.
- `NDX.DWX` — card's secondary/robustness symbol (Nasdaq 100), live-tradable, present in
  the matrix.

**Explicitly NOT for:**
- `DE40.DWX` / `DE30.DWX` — neither exists in `dwx_symbol_matrix.csv`; ported to
  `GDAXI.DWX` (see open_questions).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (SMA/ATR both read on D1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~12 (one turn-of-month event/month per card) |
| Typical hold time | ~3 trading days (`strategy_exit_day_n`) |
| Expected drawdown profile | ~12% (card `expected_dd_pct`) |
| Regime preference | non-discretionary calendar flow; long-only, regime-dependent in sustained bear markets |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `fx_edge_army_A3_2026-07-16`
**Source type:** paper
**Pointer:** McConnell & Xu (2008) Financial Analysts Journal 64(2):49-64 DOI
10.2469/faj.v64.n2.11; Lakonishok & Smidt (1988) Review of Financial Studies 1(4):403-425
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_20004_turn-of-month-index-long.md`

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
| v1 | 2026-07-19 | Initial build from card | task 4037c3a6-b21e-4670-9ab6-2eef1c5810b6 |
