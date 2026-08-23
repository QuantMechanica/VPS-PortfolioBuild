# QM5_41129_pre-fomc-drift-ndx-v2 - Strategy Spec

**EA ID:** QM5_41129
**Slug:** pre-fomc-drift-ndx-v2
**Source:** nyfed-sr512-pre-fomc-drift-v2
**Lineage:** fresh identity forked from QM5_13128 (OWNER 2026-08-23 chat, Question 2 = option b)
**Author of this spec:** Claude
**Last revised:** 2026-08-23

---

## 1. Strategy Logic

Event-driven capture of the **Pre-FOMC Announcement Drift** — the documented tendency of US
equity indices to drift up in the ~24 hours before a scheduled FOMC decision. On the trading day
BEFORE each regular FOMC decision, at broker hour 21:00 (~14:00–15:00 ET), the EA opens ONE market
LONG. On the decision day at broker hour 20:00 (~1 hour before the 14:00 ET statement) it closes the
position — **flat before the announcement by design**. A hard stop sits at 2 × the prior completed
D1 ATR(14) as a disaster guard; it is rarely hit. One position at a time; no TP, scaling, averaging,
trailing, grid, or directional bet on the decision itself. FOMC decision dates are a fixed table
(2018–2026) from the official Federal Reserve calendar.

**News handling (load-bearing design choice):** this EA runs with the framework news filter OFF
(`qm_news_temporal = QM_NEWS_TEMPORAL_OFF`, `qm_news_compliance = QM_NEWS_COMPLIANCE_NONE`). The
framework OnTick news gate returns BEFORE the exit logic, so a normal news blackout around the FOMC
time would block the strategy's own scheduled 20:00 exit. The strategy IS event-flat by construction
(it is out of the market before every statement), which is the news discipline for its one event
class. In this v2 identity the exemption is documented explicitly as the OWNER-ratified
event-anchored news exemption (`decisions/2026-07-24_news_blackout_exemptions.md`), with the
mandatory flat-before-statement exit named as the compensating control.

**The entry/exit predicate is unchanged versus QM5_13128.** This v2 identity exists because the
`.mq5` source was edited (commit `4112f5b07`) AFTER the QM5_13128 `.ex5` binary was compiled, so the
edited source no longer matches the QM5_13128 live binary. Rather than silently rebuild 13128 under
its existing identity (which carries verdict history bound to the old binary), the edited source
becomes this fresh identity that starts clean at Q02. See section 8 for the exact diff rationale.

---

## 2. Parameters

| Parameter | Default | Range | Meaning |
|---|---:|---|---|
| `strategy_timeframe` | `PERIOD_H1` | `PERIOD_H1` | Base bar for the 21:00/20:00 time triggers. |
| `strategy_entry_hour` | `21` | `0`–`23` | Broker hour to open the long the day before an FOMC decision. |
| `strategy_exit_hour` | `20` | `0`–`23` | Broker hour to close on the decision day (before the statement). |
| `strategy_atr_period` | `14` | `>= 1` | Daily ATR period for the disaster stop. |
| `strategy_stop_atr_mult` | `2.0` | `> 0` | Daily ATR multiple for the hard stop. |

FOMC decision dates are a compiled-in table (65 dates, 2018-09 … 2026-12), not a tunable input.
The execution contract declares coverage through `2026-12-31`. `OnInit` and the entry path fail
closed with `SETUP_DATA_STALE` after that date until the official calendar table and coverage
horizon are reviewed and rebuilt. Parameter defaults are identical to QM5_13128 — no parameter
search was performed for the fork.

---

## 3. Symbol Universe

**Designed for:**
- `NDX.DWX` - Nasdaq-100 proxy; the pre-FOMC drift is strongest on the rate-sensitive Nasdaq.
  Live-routable custom symbol. This is the sole Q02 symbol for the fresh identity.

**Validated but weaker / not primary:**
- `WS30.DWX` - Dow proxy; edge present but the early (DEV) window is negative — less rate-sensitive.
- `SP500.DWX` - original research symbol; **backtest-only, NOT live-routable** (broker routes no
  orders), which is why NDX is the deployment vehicle.

**Explicitly NOT for:** symbols outside `framework/registry/dwx_symbol_matrix.csv`.

---

## 4. Timeframe

| Aspect | Value |
|---|---|
| Base timeframe | `H1` |
| Multi-timeframe refs | `D1` (ATR only) |
| Bar gating | `QM_IsNewBar(_Symbol, PERIOD_H1)` |

---

## 5. Expected Behaviour

| Metric | Expected |
|---|---|
| Trades / year / symbol | ~7 (one per regular FOMC decision) |
| Typical hold time | ~24 hours (overnight, one swap) |
| Expected drawdown profile | very low; scheduled flat before every statement |
| Regime preference | event-driven (independent of trend/MR regime) |
| Win rate target (qualitative) | medium-high (~64% on NDX) |

**Low-frequency note:** at ~7 trades/yr this sits below the standard swing floor; it must be judged
under the pooled-OOS low-frequency track (DL-070 / DL-076 PASS_LOWFREQ), not the per-window minimums.
Because the entry predicate is identical to QM5_13128, the historical QM5_13128 evidence is a useful
prior but is NOT transferable as a verdict — the fresh identity must earn its own Q02+ verdicts.

---

## 6. Source Citation

**Source ID:** `nyfed-sr512-pre-fomc-drift-v2`
**Source type:** `academic_paper + official_calendar`
**Pointer:** Lucca & Moench, "The Pre-FOMC Announcement Drift", Federal Reserve Bank of New York
Staff Report 512 (https://www.newyorkfed.org/research/staff_reports/sr512.html). Decision dates from
the official FOMC calendar (https://www.federalreserve.gov/monetarypolicy/fomccalendars.htm).
**R1-R4 verdict (Q00):** PASS (inherited from QM5_13128 — same research source; R1 reputable
Federal Reserve research + official calendar, R2 mechanically specified fixed times + fixed date
table with no parameter search, R3 economic mechanism documented pre-announcement risk-premium /
uncertainty resolution, R4 out-of-sample holds 2024-2025 OOS positive on NDX at real cost).

**Research provenance:** ported from `.private/secret_strategy_lab/pre_fomc_flat` (theory-first,
no parameter search, chronological DEV/Validation/OOS). Model-4 real-tick validation on NDX.DWX at
real index commission ($4.4/trade): DEV +$285, Validation +$319, OOS +$221, full +$825, PF 2.41 —
all three windows positive (this validation was performed on the shared source predicate that both
QM5_13128 and this v2 identity implement).

---

## 7. Risk Model

| Phase | Risk mode | Value |
|---|---|---|
| Backtest (Q02 - Q10) | RISK_FIXED | $1,000 per trade (HR4) |
| Live burn-in (Q13) | RISK_PERCENT | Min-lot equivalent |
| Full live (post-Q13 PASS) | RISK_PERCENT | Allocated by Q11 portfolio (small, orthogonal diversifier) |

ENV->mode validation is enforced by `QM_FrameworkInit` (`EA_INPUT_RISK_MODE_MISMATCH`).

---

## 8. Identity Lineage & Diff Rationale vs QM5_13128

This EA is the **fresh identity** ruled by OWNER (2026-08-23 chat, Question 2 = option b) for the
strategy-logic drift on QM5_13128. Someone edited the QM5_13128 `.mq5` source in commit
`4112f5b07` ("dev: reconcile QM5_13128 event contract", 2026-08-22 14:15:14 UTC) AFTER the
QM5_13128 `.ex5` binary was compiled (2026-08-22 14:00:23 UTC). The live QM5_13128 binary and the
edited source diverged, so the edited source could not be rebuilt under the 13128 identity without
overwriting a binary that already carries verdict history. OWNER's ruling: the edited source becomes
this new identity, QM5_13128 keeps its old binary + verdict history, and 13128's checked-in `.mq5`
is reverted to match its binary.

**What commit `4112f5b07` actually changed** (63 lines: 56 insertions, 7 deletions), confirmed by
reading the diff — this is the source this v2 identity carries:

1. **Event/news contract documentation.** The `NEWS GATE DELIBERATELY DISABLED` header comment was
   rewritten as the OWNER-ratified event-anchored news exemption, naming
   `decisions/2026-07-24_news_blackout_exemptions.md` and the mandatory flat-before-statement exit
   as the compensating control. No runtime behavior change — comment only — but it changes the
   declared contract, and the `INIT_OK` / `ENTRY_GATE_READY` log payloads now emit
   `news_contract="OWNER_RATIFIED_EVENT_ANCHORED_EXEMPTION"` and `flat_before_statement=true`.
2. **Entry-path diagnostics.** New structured `QM_LogEvent` emissions were added:
   `ENTRY_GATE_DIAGNOSTIC` (broker time/hour, tomorrow_key, calendar_member, has_position),
   `ENTRY_GATE_ATR_INVALID`, `ENTRY_GATE_ASK_INVALID`, `ENTRY_GATE_STOP_INVALID`, and
   `ENTRY_GATE_READY`. The entry predicate itself (calendar membership → valid ATR → valid ask →
   valid stop distance → market BUY) is unchanged; only observability was added.
3. **Order-result handling.** `QM_TM_ClosePosition` and `QM_TM_OpenPosition` return values are now
   captured (`close_ok` / `open_ok`) and logged as `FOMC_FLAT_EXIT_RESULT` and
   `FOMC_ENTRY_ORDER_RESULT`. Previously the results were discarded.
4. **MAE-hook relocation.** `QM_FrameworkTrackOpenPositionMae()` was removed from
   `Strategy_ManageOpenPosition()` and made the first statement of `OnTick()` (direct, first on
   every tick) — the current-build hardening contract.
5. **Entry-request zero-init.** `ZeroMemory(req)` was added immediately after the
   `QM_EntryRequest req;` declaration, before `Strategy_EntrySignal(req)`.

The entry/exit trigger logic is intended to remain equivalent to QM5_13128; the diff is
diagnostics, order-result observability, MAE-hook hardening, request zero-init, and a documented
news-contract restatement. Because this was NOT a pure mechanical gate-only diff and the binary had
already been sealed, it is carried as a fresh identity rather than an in-place rebuild.

---

## Revision History

| Version | Date | Reason | Notes |
|---|---|---|---|
| v1 | 2026-08-23 | Fresh identity forked from QM5_13128 post-binary source drift (commit `4112f5b07`); OWNER 2026-08-23 Q2 option b | Claude |
