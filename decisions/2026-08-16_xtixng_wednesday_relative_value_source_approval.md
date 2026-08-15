# XTI/XNG Wednesday Relative Value - Source Approval

Date: 2026-08-16

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue authority is not authority to dispatch
a manual tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requires one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, reputable-source criteria, `RISK_FIXED` backtests, and
no live or portfolio-gate mutation.

## Candidate Identity

- proposed slug: `xtixng-wed-rv`
- proposed strategy ID: `LI-BOROWSKI-XTIXNG-WED-2026_S01`
- proposed source ID: `LI-BOROWSKI-XTIXNG-WED-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, BUY
- paired slot 1: `XNGUSD.DWX`, D1, SELL
- decision clock: the first executable tick of a genuine broker Wednesday D1
  session whose immediately prior completed host bar is Tuesday
- lifecycle: one jointly risked, approximately equal-notional package,
  Wednesday 21:00 close, with next-D1 and stale orphan repair

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository evidence was read before this
decision:

1. Wenhui Li, Qi Zhu, Fenghua Wen, and Normaziah Mohd Nor (2022), "The
   evolution of day-of-the-week and the implications in crude oil market,"
   *Energy Economics* 106, article 105817, DOI
   `10.1016/j.eneco.2022.105817`. The bounded abstract/highlights review and
   its evidentiary limit are preserved at
   `strategy-seeds/sources/LI-WTI-DOW-2022.md`. It reports an abnormal positive
   Wednesday WTI return, connects the weekday concentration to the scheduled
   crude-inventory information shock, and also reports time-varying market
   efficiency.
2. Krzysztof Borowski (2016), "Analysis of Selected Seasonality Effects in
   Markets of Future Contracts with the Following Underlying Instruments:
   Crude Oil, Brent Oil, Heating Oil, Gas Oil, Natural Gas, Feeder Cattle,
   Live Cattle, Lean Hogs and Lumber," *Journal of Management and Financial
   Sciences*, issue 26, pages 27-44. The complete-paper review is preserved at
   `strategy-seeds/sources/BOROWSKI-COMM-DOW-2016/source.md`. It reports a
   `-0.2664%` Wednesday natural-gas mean and a mean-equality rejection at
   `p=0.0136` over 1990-2016.
3. Andrew C. Meek and Seth A. Hoelscher (2023), "Day-of-the-week effect:
   Petroleum and petroleum products," *Cogent Economics & Finance* 11(1),
   article 2213876, DOI `10.1080/23322039.2023.2213876`. The complete 21-page
   open-paper review is preserved at
   `strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md`. Its Tables 2
   and 6 are adverse modern evidence: WTI Wednesday is positive but significant
   only in the symmetric GARCH specification, while natural-gas Wednesday is
   positive and insignificant in all five models. This conflict is a binding
   Q02 kill risk, not evidence to suppress.

Li et al. supply the positive WTI Wednesday direction. Borowski supplies the
negative natural-gas Wednesday direction. Neither paper tests the cross-energy
pair, combined risk budget, equal-notional sizing, Darwinex CFDs, broker-day
mapping, hard stops, costs, or portfolio correlation. No source return,
coefficient, significance result, drawdown, density, CFD equivalence,
neutrality, decorrelation, or portfolio result transfers.

## Locked Mechanic

On every new `XTIUSD.DWX` D1 bar:

1. Repair or close any malformed, orphaned, duplicated, same-sided, materially
   imbalanced, stale, or expired owned package before applying entry-only
   gates.
2. Admit an entry decision only when the host bar is broker Wednesday, the
   immediately prior completed host bar is Tuesday, both symbols expose the
   same current D1 timestamp, and the first observed tick is within five
   minutes of the host D1 opening timestamp.
3. Persist one Monday-anchored broker-week attempt before history, news,
   spread, quote, ATR, sizing, or order gates. Never retry the week.
4. Open slot 0 BUY `XTIUSD.DWX` and slot 1 SELL `XNGUSD.DWX` as one logical
   package. Neither standalone component is authorized.
5. Solve both volumes jointly so frozen `3.5 * ATR(20,D1)` hard stops fit
   inside one `RISK_FIXED=1000` package budget and rounded absolute USD
   notionals target 1:1 within a fixed ten-percent relative tolerance. Signal
   or source magnitude never scales risk.
6. Use a 2,500-point entry-spread ceiling on each leg, no target, no scale-in,
   and immediate rollback if only one leg opens.
7. Close the full package at broker Wednesday 21:00. The first non-Wednesday
   D1 boundary and a three-calendar-day age limit are stale repair exits.
   Framework Friday close remains enabled at broker hour 21 as a fail-safe;
   both news axes remain OFF.

The exact weekday, prior-Tuesday continuity, paired directions, synchronized
bars, combined risk, notional tolerance, attempt ledger, atomicity, stops,
spread caps, and lifecycle are load-bearing.

## Reputable-Source Criteria

- R1 `PASS_WITH_CONFLICTING_MODERN_EVIDENCE`: one tier-A peer-reviewed energy-
  economics lineage with a bounded abstract/highlights receipt, one complete
  tier-B peer-reviewed commodity-calendar paper, and one complete open
  peer-reviewed adverse modern replication. The source disagreement,
  multiple testing, and time variation are explicit.
- R2 `PASS`: weekday, continuity, directions, synchronization, attempt state,
  joint risk/notional solve, hard stops, spreads, repair, and exits are locked
  before Q02.
- R3 `PASS`: registered `XTIUSD.DWX` and `XNGUSD.DWX` D1 histories supply
  every runtime input and an existing logical-basket route.
- R4 `PASS`: deterministic native calendar, bar, ATR, quote, symbol-metadata,
  position, deal-history, and framework state only; no trained output, banned
  signal indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-card checker scanned 4,505 EA-registry rows and 601 root
cards. It returned no exact match and three expected fuzzy family hits. Manual
review fixes the semantic boundaries:

- `QM5_20022_wti-wed-long` and `QM5_20018_xng-wed-short` are known standalone
  components. Neither owns a simultaneous logical package, one combined risk
  budget, equal-notional invariant, atomic rollback/repair, or paired return
  stream. Neither component is independently authorized by this extraction.
- `QM5_41014_xtixng-thu-rv` shares the BUY-XTI/SELL-XNG package direction but
  trades a disjoint Thursday coefficient object from a different paper and
  never owns the Wednesday session.
- `QM5_41015_xtixng-tue-rv` trades the opposite pair direction on Tuesday.
- `QM5_20016_xti-xng-mon-rv` trades SELL-XTI/BUY-XNG on Monday, and
  `QM5_20110_xti-xng-fri-rv` trades BUY-XTI/SELL-XNG on Friday.
- `QM5_20237_xtixng-ecm-rv` estimates a rolling trend-augmented OLS
  error-correction residual and has no fixed weekday information clock.
- `QM5_12567_cum-rsi2-commodity` is an outright two-day oscillator pullback,
  not a market-neutral calendar package.

Verdict:
`CLEAN_WEDNESDAY_XTI_XNG_JOINT_PACKAGE_WITH_KNOWN_COMPONENT_OVERLAP`.

The shared weekday component signals are disclosed. The new research object
is the jointly sized cross-energy differential, not a relabeling of either
standalone EA. Equal notional is not beta, volatility, factor, or realized
market neutrality.

## Kill And Safety Boundary

Expected cadence is approximately 45-52 completed packages per full year.
Q02 must retire on zero trades, below five packages/year, a non-Wednesday
entry, missing prior-Tuesday continuity, wrong leg direction, partial/orphaned
exposure, material notional imbalance, repeated weekly attempts, invalid risk
mode, or nonpositive governed economics. The adverse 2023 natural-gas result,
source-window conflict, multiple testing, broker-session mapping, futures/CFD
basis, legging, costs, and natural-gas tails are first-order kill risks. Q09
alone may establish realized portfolio correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
