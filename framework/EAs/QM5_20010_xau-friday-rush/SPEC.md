# QM5_20010_xau-friday-rush — Strategy Spec

**EA ID:** QM5_20010
**Slug:** `xau-friday-rush`
**Source:** `INVESTUI_EFFECTS_SOURCING_2026-07-19` (see `artifacts/cards_approved/QM5_20010_xau-friday-rush.md`)
**Author of this spec:** Claude (headless build lane)
**Last revised:** 2026-07-19

---

## 1. Strategy Logic

Gold shows a systematically positive Friday weekday-bar return, driven by
jewellery-industry Friday physical buying (weekend/Monday delivery) plus
weekend safe-haven insurance demand. The EA is mechanically a pure calendar
rule: on the D1 bar whose weekday is Friday, it opens a long at the bar's
open (detected as the `QM_IsNewBar()` closed-D1-bar edge combined with a
`QM_Sig_DayOfWeek` check on the just-opened bar), protected by a
non-alpha `strategy_stop_atr_mult * ATR(D1,14)` catastrophe stop. The
position is held for exactly one D1 period and flattened at the close of
that same Friday bar (tracked via a `QM_CalendarPeriodKey(D1)` rollover
counter, so the exit is always before the weekend), never gridded, never
trailed, no take-profit. If Friday is a market holiday, no D1 bar with
`day_of_week==Friday` opens that week, so the strategy naturally sits out
— no separate holiday-skip code path is needed.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---|---|---|
| `strategy_atr_period` | 14 | fixed at 14 per card | ATR period for the protective catastrophe stop. |
| `strategy_stop_atr_mult` | 3.0 | 2.0-4.0 (card §6 P3 sweep) | Protective-stop ATR multiplier; not a fitted entry/exit parameter — the calendar rule itself has no fitting surface. |

> Framework-level inputs (RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT, qm_news_mode,
> qm_rng_seed, qm_stress_reject_probability, qm_friday_close_*) are documented in
> `framework/V5_FRAMEWORK_DESIGN.md`.

---

## 3. Symbol Universe

**Designed for:**
- `XAUUSD.DWX` — the card's single named symbol (`single_symbol_only: true`).
  Gold is explicitly the cheapest cost class in the card's cost math (round-trip
  ~$0.4-6.7 + ~20-30ct spread vs. the literature's ~5-10 bps Friday drift); the
  same day-of-week density on FX would die on costs, so no other symbol is
  registered.

**Explicitly NOT for:**
- Any FX pair — the card states the 50/yr trade density is only cost-viable on
  the cheap metals class; porting the rule to FX pairs is out of scope for this
  build (card §Cost math).

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `D1` |
| Multi-timeframe refs | none (ATR read on D1) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_CURRENT)` (default) |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~50 (one long per Friday D1 bar, holidays skipped, per card) |
| Typical hold time | 1 D1 bar (Thursday close → Friday close) |
| Expected drawdown profile | ~10% (card `expected_dd_pct`) |
| Regime preference | day-of-week seasonal / calendar flow; long-only |
| Win rate target (qualitative) | medium |

---

## 6. Source Citation

**Source ID:** `INVESTUI_EFFECTS_SOURCING_2026-07-19`
**Source type:** paper (primary) + vendor (tier C, secondary)
**Pointer:** Yu, Lee, Shih (2016) Banks and Bank Systems 11(2):33-44, DOI
10.21511/BBS.11(2).2016.04; Blose/Gondhalekar (2013) Accounting & Finance
53(3), DOI 10.1111/j.1467-629X.2012.00497.x; Draper/Faff/Hillier (2006) FAJ
62(2), DOI 10.2469/faj.v62.n2.4085; investui.com Friday-Gold-Rush page
(vendor, no numeric stats published)
**R1–R4 verdict (Q00):** all PASS — see `artifacts/cards_approved/QM5_20010_xau-friday-rush.md`

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
| v1 | 2026-07-19 | Initial build from card | task c6a84d19-6efa-4d35-b2df-8c4d709f4700 |
