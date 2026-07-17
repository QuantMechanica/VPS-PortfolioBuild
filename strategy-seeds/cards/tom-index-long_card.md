---
strategy_id: MCCONNELL-XU-TOM-2008_S01
source_id: MCCONNELL-XU-TOM-2008
ea_id: TBD
slug: tom-index-long
status: REJECTED_DUPLICATE
created: 2026-07-17
created_by: Research
last_updated: 2026-07-17

strategy_type_flags:
  - intraday-day-of-month
  - time-stop
  - atr-hard-stop
  - friday-close-flatten
  - news-blackout
  - long-only

duplicate_status: EXACT_DUPLICATE_CONFIRMED_2026_07_17
build_eligibility: REJECTED_NO_NEW_EA_ID
review_state: TERMINAL_REJECTED_OWNER_DELEGATED_CEO_QUALITY_BUSINESS
---

# Strategy Card — Turn-of-Month Index Long

## 1. Source

source_citations:

  - type: paper
    citation: "McConnell, John J., and Wei Xu. 2008. Equity Returns at the Turn of the Month. Financial Analysts Journal 64(2): 49-64. DOI 10.2469/faj.v64.n2.11."
    location: "Complete article, pages 49-64; window definition and prior evidence on pages 49-51; U.S. results on pages 51-56; international evidence on pages 56-59; mechanism tests and conclusion on pages 61-63."
    quality_tier: A
    role: primary

Full-text PDF: https://business.purdue.edu/faculty/mcconnell/publications/Equity-Returns-at-the-Turn-of-the-Month.pdf

Canonical source record: `strategy-seeds/sources/MCCONNELL-XU-TOM-2008/source.md`.

Research read the full peer-reviewed article, including tables, figures, notes, conclusion, and references. The article has no appendix. The source is an empirical return study rather than a complete trading-system specification.

## 2. Concept

Broad equity-market returns were historically concentrated around the boundary between calendar months: the last trading day of the old month and the first three trading days of the new month. The paper leaves the cause unresolved and does not support treating pension, payroll, mutual-fund flow, or trading-volume pressure as established mechanism evidence. This rejected normalization card maps only the mechanically observable new-month portion to one conservative, long-only `NDX.DWX` implementation.

## 3. Markets & Timeframes

markets:

  - indices

timeframes:

  - D1

primary_target_symbols:

  - NDX.DWX

Source-universe note: McConnell and Xu test CRSP broad U.S. value- and equal-weighted market indices plus 34 non-U.S. country indices. They do not name or test the Nasdaq-100 or `NDX.DWX`; this symbol is the OWNER-requested QM proxy and must be evaluated as a modern transfer test.

Local-data note: `framework/registry/dwx_symbol_history_ranges.csv` lists `NDX.DWX,D1,2021,2026`, but `framework/registry/dwx_symbol_matrix.csv` still records `FAIL_tail_mid_bars` from 2026-04-27. The symbol is not build-ready until data governance resolves that contradiction.

## 4. Entry Rules

Source/implementation boundary:

- The source interval begins with the Day -1 daily return, where Day -1 is the last trading day of the old month, and ends with Day +3.
- The conservative MT5 baseline deliberately does not predict the last old-month exchange session. It starts on the first actual new-month session and therefore does not claim to capture the source's Day -1 return.

Mechanical entry pseudocode:

- run on `NDX.DWX` with D1 signal state and Model 4 real ticks;
- on each new D1 session, compare the current D1 bar month with the month of the last completed D1 bar;
- require a valid last completed D1 bar and at least 15 completed D1 bars for ATR initialization;
- require `current_bar_month != previous_closed_bar_month`, making the current bar the first observed D1 session of a new month;
- require no open position for this magic and symbol;
- require that the new month's `cycle_month_key` has not already been entered, skipped, stopped, or force-closed;
- require all framework entry gates to pass, including kill switch, quote validity, news pause, and one-position guard;
- then BUY once, at market, on the first executable tick of that first observed new-month D1 session;
- place a fixed catastrophic stop at `entry_price - 3.0 * ATR(14,D1)`, using ATR from the last completed D1 bar and freezing the distance at entry;
- if the first entry attempt is gated, rejected, ambiguous, or lacks an executable quote, mark the monthly cycle skipped and do not catch up later.

The first executable tick may differ from the previous D1 close. That gap and the omitted Day -1 return must be reported as implementation slippage from the paper's empirical window, not silently treated as source parity.

## 5. Exit Rules

- Count only actual `NDX.DWX` D1 sessions whose bar month equals the active `cycle_month_key`; weekends and missing sessions do not increment the count.
- After the third actual D1 session of the new month has completed, close the position at market on the first executable tick that starts the next observed D1 session.
- If the V5 Friday-close rule flattens the position before that scheduled exit, mark the monthly cycle complete and do not re-enter.
- If the fixed `ATR(14,D1) * 3.0` catastrophic stop is hit, mark the cycle complete and do not re-enter.
- No take-profit, trailing stop, break-even move, partial close, or signal-reversal exit is authorized by the source.
- Spread, news, and entry gates may never block a required exit.
- On restart, reconstruct the cycle from the open position and deal history. If the scheduled exit has passed, flatten on the first executable tick before evaluating any new entry.

This exit approximates the source's Day +3 close with the first tradable tick after that close. The difference must be measured in pipeline evidence.

## 6. Filters (No-Trade module)

Framework gates:

- account kill switch and risk governor active;
- one position per magic and symbol;
- invalid or stale quote fails closed;
- framework news blackout applies to entry only;
- Friday close remains enabled at the framework default for this conservative FTMO adaptation;
- no external runtime market data or network calendar.

Strategy-specific gates:

- `NDX.DWX` only;
- first observed D1 session of the new month only;
- no catch-up entry after the one-shot boundary event;
- no new entry when a prior cycle position or unresolved exit exists;
- no entry with incomplete D1/ATR state or an ambiguous month transition;
- no SMA, volatility, January, quarter-end, country, volume, fund-flow, or momentum filter in the baseline.

## 7. Trade Management Rules

- Hold the single long position unchanged until the calendar exit, catastrophic stop, or framework emergency/Friday close.
- No grid, averaging, martingale, pyramiding, scale-in, direction flip, or re-entry.
- No trailing, break-even, partial close, or discretionary management.
- An early stop, Friday close, kill-switch close, or operator emergency close completes that month; the EA stays flat until a later calendar month.
- Structured logs must record the cycle key, previous/current D1 timestamps and month values, actual entry/exit tick time, D1 session count, ATR value, stop distance, and exit reason.

## 8. Parameters To Test (P3 Sweep)

Source-locked and OWNER-directed parameters:

| name | default | authorized test |
|---|---:|---|
| symbol | NDX.DWX | fixed |
| signal_timeframe | D1 | fixed |
| direction | long | fixed |
| entry_new_month_session | 1 | fixed conservative translation; no day-offset mining |
| exit_after_completed_new_month_sessions | 3 | fixed from source Day +3 boundary |
| one_entry_per_month | true | fixed |

Implementation-safety parameters, not source claims:

| name | proposed default | authorized test |
|---|---:|---|
| protective_stop_atr_period_d1 | 14 | fixed |
| protective_stop_atr_mult | 3.0 | documented proposal only; no sweep or build is authorized |
| friday_close_enabled | true | fixed conservative V5 default; report every truncated cycle |
| news_mode | framework default | P8 comparison only; no outcome-selected baseline |

No alpha-parameter sweep is authorized; the card is terminally rejected as a duplicate and NDX data validation also remains unresolved.

## 9. Author Claims (verbatim, with quote marks)

- "For large-cap stocks, the average daily turn-of-the-month return is 0.15 percent" (page 53).
- "higher volatility of returns does not explain higher turn-of-the-month returns" (page 56).

These are historical sample findings, not expected current FTMO performance and not claims about `NDX.DWX`.

## 10. Initial Risk Profile

expected_pf: TBD

expected_dd_pct: TBD

expected_trade_frequency: up to 12 entries/year before skipped, stopped, or Friday-truncated cycles

risk_class: medium

gridding: false

scalping: false

ml_required: false

Source silent — defer to V5 default RISK_FIXED $1k backtest, RISK_PERCENT 0.25 live. The proposed ATR stop is an implementation-only loss bound and must not be attributed to McConnell and Xu.

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical and requires no discretionary judgment.
- [x] No Machine Learning required.
- [x] No grid, martingale, averaging, or pyramiding.
- [x] Source citation is reproducible to the complete paper and journal pages.
- [x] Darwinex-native price/time data only in the proposed EA.
- [ ] Friday-close source fidelity unresolved: the conservative default can truncate a Day +3 hold, and reviewer acceptance is required.
- [ ] NDX data readiness unresolved: the symbol matrix has a current recorded failure despite a registered history range.
- [ ] Near-duplicate check does not pass for a new EA identity: exact and semantic predecessors already exist.
- [x] OWNER-delegated CEO + Quality-Business terminal verdict: reject a new identity as an exact same-source/semantic duplicate; `ea_id` remains `TBD`.

## 12. Framework Alignment

modules_used:

  no_trade:
    used: true
    notes: "Month-transition validity, D1/ATR readiness, quote/news/kill-switch gates, reconstructed cycle state, one-position guard, and no-catch-up behavior."
  trade_entry:
    used: true
    notes: "One market BUY on the first executable tick of the first observed new-month NDX.DWX D1 session, with a frozen ATR catastrophic stop."
  trade_management:
    used: false
    notes: "No source-authorized trailing, break-even, partial close, grid, pyramid, or re-entry."
  trade_close:
    used: true
    notes: "First tick after three completed new-month D1 sessions, or earlier catastrophic/framework/Friday close; restart recovery flattens overdue positions."

hard_rules_at_risk:

  - friday_close
  - risk_mode_dual
  - model4_every_real_tick
  - enhancement_doctrine
  - one_position_per_magic_symbol
  - news_pause_default

at_risk_explanation: |
  Friday close can shorten the source window and must be reported cycle by cycle. The paper gives no stop or sizing rule, so dual-mode risk needs the explicitly labeled ATR safety overlay. First-tick entry and exit ordering make Model 4 mandatory. Changing the calendar offsets, adding an SMA/filter, or restoring Day -1 exposure changes entry logic and invalidates prior evidence. One-shot monthly state must survive restart without duplicate positions. A news pause can skip the only monthly entry event and may never delay an exit.

## 13. Implementation Notes (CTO fills in at APPROVED stage)

target_modules:

  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD

estimated_complexity: TBD

estimated_test_runtime: TBD

data_requirements: TBD — `NDX.DWX` D1 Model 4 history must first receive a current data-governance verdict; the present registry records 2021-2026 history but a `FAIL_tail_mid_bars` symbol-matrix state.

Terminal handoff: do not scaffold or build this card. The same-source/semantic duplicate verdict is binding, `ea_id` remains `TBD`, and the NDX data state also remains failed/contradictory. Existing predecessor evidence is not transferred or relabeled.

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-07-17 | full-source re-extraction and conservative MT5 translation | G0 | DRAFT_DUPLICATE_REVIEW_REQUIRED |
| _v2 | 2026-07-17 | terminal manual same-source/semantic duplicate adjudication | G0 | REJECTED_DUPLICATE |

## 15. Pipeline Phase Status

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-07-17 | REJECTED_DUPLICATE | OWNER-delegated CEO + Quality-Business manual adjudication; exact predecessors QM5_1049 and QM5_20004 |
| P1 Build Validation | 2026-07-17 | NOT_AUTHORIZED | terminal duplicate rejection; no EA ID |
| P2 Baseline Screening | TBD | NOT_STARTED | TBD |
| P3 Parameter Sweep | TBD | NOT_STARTED | no alpha sweep authorized |
| P3.5 CSR | TBD | NOT_STARTED | TBD |
| P4 Walk-Forward | TBD | NOT_STARTED | TBD |
| P5 Stress | TBD | NOT_STARTED | TBD |
| P5b Calibrated Noise | TBD | NOT_STARTED | first-tick/gap timing required if approved |
| P5c Crisis Slices | TBD | NOT_STARTED | TBD |
| P6 Multi-Seed | TBD | NOT_STARTED | TBD |
| P7 Statistical Validation | TBD | NOT_STARTED | TBD |
| P8 News Impact | TBD | NOT_STARTED | news skip versus source replication |
| P9 Portfolio Construction | TBD | NOT_STARTED | same-family concentration review required |
| P9b Operational Readiness | TBD | NOT_STARTED | TBD |
| P10 Shadow Deploy | TBD | NOT_STARTED | OWNER-signed manifest required |
| Live Promotion | TBD | PROHIBITED | terminal duplicate rejection; no EA ID or deploy authority |

## 16. Lessons Captured

- 2026-07-17: The paper documents an anomaly but does not provide a broker-executable trading system or support the commonly repeated pension/payday-flow mechanism.
- 2026-07-17: Entering after the last old-month D1 bar is observable is conservative and no-lookahead, but it omits the published Day -1 return and must not be called a full replication.
- 2026-07-17: Exact string dedup can return clean while semantic/source duplicates remain; manual adjudication is binding.

## 17. Duplicate Adjudication

The canonical helper command for candidate slug/strategy ID returned `CLEAN` because neither exact string exists in its limited registry/root-card scan. Manual inspection of approved farm cards, EA artifacts, registries, and mechanics yields the binding Research verdict below.

| Existing identity | Relationship | Material difference | Research verdict |
|---|---|---|---|
| `QM5_1049_mcconnell-turn-of-month` | Exact same paper, long equity-index family, D1, NDX target | Legacy card enters at last-day close, adds an optional SMA variant, cites an unreproduced SSRN ID, and is mislinked to `SRC08_S05` in the EA registry | Exact same-source predecessor; preferred lineage candidate, not justification for a new ID |
| `QM5_20004_turn-of-month-index-long` | Exact same paper and near-identical last-day/Day +3 long rule | Uses a different internal source label, unsupported pension-flow causality, noncanonical `DE40.DWX`, and a longer slug | Exact duplicate; cannot justify another EA ID |
| `QM5_12847_turn-of-month-sp500` | Same equity-index calendar family and Day +3 exit | Enters fifth-last day and uses SMA(200) | Parameter/filter variant, not a new family |
| `QM5_9931_bandy-turn-of-month-overlay-index` | Same long D1 index TOM family | Last-three/first-two window, SMA(200), ATR stop, bad-month skip | Engineered variant; high correlation risk |
| `QM5_10023_rw-eom-flow` | Same long index month-boundary family | T-3 to Day +1 and realized-volatility gate | Timing/filter variant |
| `QM5_10888_risk-tom-index` | Same long index month-boundary family | T-2 to Day +2, Risk.net source, volatility skip | Different source but semantic family duplicate |
| `QM5_12904_uk100-tom-pension` | Registry name indicates the same family | Canonical card not found in this audit | Unresolved registry-only near-duplicate; requires owner follow-up |

Terminal adjudication by OWNER-delegated CEO + Quality-Business:

1. Treat this card as source normalization, not as a newly discovered edge.
2. Reject a new EA identity as a duplicate; existing lineage remains separate and unchanged.
3. Do not allocate a new EA ID; Research correctly left it `TBD`.
4. Do not transfer prior pipeline evidence automatically. The first-new-month-tick entry, forced-Friday behavior, and one-shot skip contract differ materially from predecessor builds.
5. Do not retire, rename, or edit any predecessor, registry, magic row, framework file, or binary from this rejected normalization card. Those are separate owner decisions.

Non-duplicates: the Van Hemert WTI/XNG/Brent TOM-momentum cards use commodity symbols and a momentum-direction condition; monthly 10-month-SMA timing cards use a different signal horizon. They stay outside this consolidation request.
