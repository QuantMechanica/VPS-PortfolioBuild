---
ea_id: QM5_20023
slug: idx-macro-announce-day
type: strategy
strategy_id: SAVOR-WILSON-ANNDAY-2013_S01
source_id: SAVOR-WILSON-ANNDAY-2013
status: APPROVED
created: 2026-07-21
created_by: Claude
last_updated: 2026-07-21
g0_status: APPROVED
g0_approval_reasoning: "R1 tier-A JFQA peer-reviewed + verified live URLs; R2 fully mechanical day-flat calendar rule, locked params; R3 registered .DWX index routes + existing news-calendar infra; R4 calendar+ATR only, no ML"
source_citation: "Savor, P., & Wilson, M. (2013). How Much Do Investors Care About Macroeconomic Risk? Evidence from Scheduled Economic Announcements. Journal of Financial and Quantitative Analysis, 48(2), 343-375."
source_citations:
  - type: academic_paper
    citation: "Savor, Pavel and Mungo Wilson (2013), Journal of Financial and Quantitative Analysis 48(2), 343-375."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1312091; https://ideas.repec.org/a/cup/jfinqa/v48y2013i02p343-375_00.html"
    quality_tier: A
    role: primary
  - type: academic_paper
    citation: "Brusa, Francesca, Pavel Savor and Mungo Wilson (2020), One Central Bank to Rule Them All, Review of Finance 24(2), 263-304."
    location: "https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2658953"
    quality_tier: A
    role: supporting
sources: ["[[sources/SAVOR-WILSON-ANNDAY-2013]]"]
concepts: [macro-announcement-risk-premium, scheduled-event-day-return]
indicators: [atr]
strategy_type_flags: [calendar-event, day-flat, long-only, atr-hard-stop, time-stop, swap-free]
markets: [indices, us_equity_index]
timeframes: [H1]
period: H1
primary_target_symbols: [SP500.DWX]
target_symbols: [SP500.DWX, NDX.DWX, WS30.DWX]
single_symbol_only: false
expected_trade_frequency: "~40 scheduled US announcement days/year per symbol (NFP + CPI + PPI + FOMC decision, overlaps deduplicated to one package per broker day); Q02 floor of 5 completed trades/year clears trivially."
expected_trades_per_year_per_symbol: 40
expected_pf: 1.05
expected_dd_pct: 20.0
risk_class: medium
ml_required: false
r1_track_record: PASS
r1_reasoning: "Single source_id (SAVOR-WILSON-ANNDAY-2013) anchored by a tier-A peer-reviewed JFQA article with live SSRN/RePEc URLs, adversarially re-verified 2026-07-20 against mirrors (exists + effect magnitudes confirmed: 11.4bp announcement days vs 1.1bp other days, diff t=3.77, 1958-2009), plus the Review-of-Finance international FOMC extension as supporting citation."
r2_mechanical: PASS
r2_reasoning: "Entry (long at first H1 bar of a broker day carrying a scheduled whitelisted USD release, frozen 2.75*ATR(20,D1) stop), exit (time-flat at the last H1 bar of the same broker day), and the fixed ex-ante event whitelist are fully specified with locked parameters and no discretionary judgment."
r3_data_available: PASS
r3_reasoning: "SP500.DWX (backtest-only symbol; FTMO route requalifies on US500 later), NDX.DWX and WS30.DWX are registered .DWX instruments with H1/D1 history; announcement dates come from the existing QM news-calendar infrastructure (FF-weekly CSV in tester, native MT5 calendar live) — no new data dependency."
r4_ml_forbidden: PASS
r4_reasoning: "Rules use only the scheduled-event calendar, broker-day boundaries and ATR(20) for a frozen stop; one package per day per symbol, no grid/martingale/pyramid, no ML or adaptive fitting."
pipeline_phase: Q02
q01_status: PASS
q02_status: PENDING
review_focus: "Falsify the announcement-day premium at index level net of costs, with the post-2015 window as the decisive OOS test (documented FOMC-leg decay); portfolio overlap with live 13128 on FOMC days is an admission question, not a Q02 question."
modules_used: [no_trade, trade_entry, trade_management, trade_close]
target_modules: [Strategy_NoTradeFilter, Strategy_EntrySignal, Strategy_ManageOpenPosition, Strategy_ExitSignal, Strategy_NewsFilterHook]
hard_rules_at_risk: [risk_mode_dual, cfd_source_basis, multiple_comparisons, portfolio_correlation, news_filter_inversion]
---

# US-Index Macro-Announcement-Day Premium (day-flat)

## 1. Hypothesis and source

Savor and Wilson (2013), Journal of Financial and Quantitative Analysis 48(2),
343-375 (SSRN: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=1312091),
document that the US equity market earns its risk premium disproportionately on
days with scheduled macroeconomic announcements: CRSP value-weighted
close-to-close excess return of 11.4bp on announcement days versus 1.1bp on
all other days (difference t=3.77, sample 1958-2009), robust per announcement
type and across sample halves. The interpretation is compensation for
scheduled macro-risk resolution — a risk premium, not a flow. Brusa, Savor and
Wilson (2020), Review of Finance 24(2), 263-304
(https://papers.ssrn.com/sol3/papers.cfm?abstract_id=2658953) extend the
FOMC-day component internationally.

This is a strict falsification candidate. The 2026-07-20 adversarial
verification (docs/research/SSRN_MINING_2026-07-20.md, rank 8) binds three
caveats into this card: (a) the paper's inflation leg is CPI to Jan-1971 and
PPI afterwards — this card fixes CPI AND PPI ex ante and cites the paper's
footnote-11 robustness to CPI inclusion; (b) the measured object is
close-to-close — our broker-day open-to-close on NY-close charts approximates
it and contains the 08:30 ET releases; (c) decay literature exists
(Kurov et al. 2021, SSRN 3134546: pre-FOMC drift gone post-2015;
Ernst-Gilbert-Hrdlicka, SSRN 3469703: selection critique) — therefore the
post-2015 sub-window is the decisive OOS test at Q02/Q04, and a pre-2015-only
edge retires the card.

## 2. Market, timeframe and frequency

Trade `SP500.DWX` (slot 0), `NDX.DWX` (slot 1), `WS30.DWX` (slot 2) on H1.
Approximately 40 whitelisted announcement days/year per symbol (about 12 NFP,
12 CPI, 12 PPI, 8 FOMC decisions, same-day overlaps collapse to one package).
Day-flat: no overnight hold, no swap — FTMO-compatible by construction.
SP500.DWX is a backtest-only symbol; any FTMO route requalifies on US500 later.

## 3. Non-duplicate boundary

`QM5_13128` (live) trades the PRE-FOMC drift window — a different mechanic on
an overlapping subset (~8 days/year); portfolio overlap is measured at
Q09/admission under DL-083 (announcement-cluster cap), not silently avoided
here. `QM5_12971/12972` are pre-announcement drift siblings. No repository
strategy holds long across the announcement day itself. `QM5_20004` is
turn-of-month; the calendar battery (20010-20018) is commodity day-of-month.

## 4. Entry Rules

- Maintain a fixed ex-ante event whitelist from the QM news calendar (tester:
  FF-weekly CSV; live: native MT5 calendar), USD currency, scheduled releases
  whose titles match exactly one of: Nonfarm Payrolls / Non-Farm Employment
  Change; CPI m/m; PPI m/m; FOMC Statement / Federal Funds Rate decision.
- On the FIRST completed H1 bar of a broker calendar day that carries at least
  one whitelisted scheduled event: BUY at market. One package per broker day
  per symbol, at most, including after rejection, stop-out or restart
  (persisted attempt state + deal history).
- Require no managed open position on the slot, nonnegative spread within the
  locked maximum, and a completed D1 ATR(20).
- Set a frozen `2.75 * ATR(20, D1)` broker stop, no take-profit.
- The framework news-avoidance gate is intentionally inverted for this
  strategy: entries occur at the broker-day open, hours away from the release
  minute, so the standard minute-window gates do not collide; the kill-switch
  gate remains fully authoritative.

## 5. Exit Rules

- Time-flat on the last H1 bar of the entry's broker calendar day (before the
  daily close); also flatten on the first bar of the next day as a stale
  guard if the timed exit was missed (restart safety).
- Keep the framework Friday-close behavior enabled.
- No short leg, no trailing, break-even, partial, scale, grid, martingale or
  pyramid.

## 6. Filters (No-Trade Module)

Fail closed unless symbol/timeframe/slot and all baseline values are exact.
If the calendar source is unavailable in the tester, the day is NOT tradable
(fail-closed — a missing calendar must produce zero trades, never unfiltered
trades). Invalid spread, price, ATR, history or stop arithmetic blocks entry.

## 7. Trade Management Rules

Manage only positions with the registered magic. Run the deterministic timed
exit before any new-entry evaluation. Never modify the frozen stop; never
re-enter the same broker day.

## 8. Locked parameters and risk

`strategy_event_whitelist=NFP,CPI,PPI,FOMC` (title match set, fixed ex ante;
comma-delimited for lossless MT5 tester serialization),
`strategy_atr_period=20`, `strategy_atr_sl_mult=2.75`,
`strategy_entry_bar=first_h1_of_event_day`,
`strategy_exit_bar=last_h1_of_event_day`, `strategy_max_spread_points=2500`.
There is no authorized sweep; the event set is fixed by citation, not fitted.

Backtest setfile only: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
`PORTFOLIO_WEIGHT=1`. Retire at Q02 below five completed trades/year/symbol,
for shifted/duplicated packages, nondeterminism, risk mismatch, calendar
fail-open behavior, or failure of governed net PF/DD thresholds. Q04 must
report the post-2015 sub-window explicitly (decisive OOS per the decay
literature). Later gates measure correlation; admission must respect the
DL-083 announcement-cluster cap against live 13128.

No live setfile, T_Live/AutoTrading action, deploy manifest, portfolio
admission, or portfolio-gate change is authorized.
