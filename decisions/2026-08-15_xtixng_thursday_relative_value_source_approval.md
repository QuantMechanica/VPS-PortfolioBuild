# XTI/XNG Thursday Relative-Value — Source Approval

Date: 2026-08-15

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced non-live Q02 enqueue. Enqueue authority is not authority to dispatch
a tester or exceed the active factory resource ceiling.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on the
`agents/board-advisor` branch. The mission requests one genuinely new,
structural, low-frequency commodity edge outside the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and `RISK_FIXED`
backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `xtixng-thu-rv`
- proposed strategy ID: `MEEK-HOELSCHER-XTIXNG-THU-2026_S01`
- proposed source ID: `MEEK-HOELSCHER-XTIXNG-THU-2026`
- host/traded slot 0: `XTIUSD.DWX`, D1, long
- paired slot 1: `XNGUSD.DWX`, D1, short
- decision clock: first executable tick of a genuine Thursday D1 bar whose
  immediately prior completed D1 bar is Wednesday
- lifecycle: one consumed broker-week attempt, approximately equal absolute
  USD notionals, one combined fixed-risk budget, Thursday 21:00 broker-time
  flatten, next-D1 and three-day stale repair

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The bounded source packet
`strategy-seeds/sources/MEEK-HOELSCHER-WTI-DOW-2023/source.md` was read
completely before this decision. It records an end-to-end review of Meek and
Hoelscher (2023), "Day-of-the-week effect: Petroleum and petroleum products,"
*Cogent Economics & Finance* 11(1), article 2213876, DOI
`10.1080/23322039.2023.2213876`, using the complete open 21-page EconStor
copy.

The paper studies synchronized front-/second-month futures from 2002 through
2021. Its WTI Table 2 reports Thursday coefficients from `-0.000189` to
`+0.000270` in the four asymmetric-variance models. Its natural-gas Table 6
reports negative Thursday coefficients from `-0.001323` to `-0.001432` in
those models, each reported significant at the 10% or 5% level. The raw
long-WTI/short-natural-gas Thursday coefficient differential is therefore
approximately 11-17 basis points across those four models.

The authors establish heterogeneous energy weekday effects but do not test
this two-leg package, its covariance, equal-notional sizing, combined fixed
risk, Darwinex continuous CFDs, transaction-cost profitability, or QM book
correlation. The paired carrier is a QM falsification translation and no
source return, significance, density, drawdown, cost, neutrality, or
decorrelation claim transfers.

## Locked Mechanic

On the first executable tick of each genuine broker Thursday D1 bar:

1. Require the immediately prior completed host bar to be Wednesday and both
   current XTI/XNG D1 bars to be synchronized to the same broker date.
2. Persist the Monday-anchored broker-week attempt before history, quote,
   spread, sizing, news, or order gates. Never retry the week.
3. Open one package only: BUY `XTIUSD.DWX` and SELL `XNGUSD.DWX`.
4. Split one `RISK_FIXED=1000` package budget across frozen `3.5 * ATR(20,D1)`
   hard stops while targeting equal absolute USD notionals within a locked
   tolerance. Signal magnitude never scales risk.
5. Repair immediately if the package is orphaned, duplicated, same-sided,
   wrong-symbol, wrong-magic, or materially imbalanced.
6. Flatten both legs at broker Thursday 21:00. A first non-Thursday D1 bar
   and three-calendar-day limit are stale repair exits only.
7. Use fixed XTI/XNG spread ceilings, no target, no partial close, no scale-in,
   and no runtime source or event feed.

The Thursday clock, directions, simultaneous two-leg object, equal-notional
target, joint fixed-risk sizing, package repair, and same-session exit are
load-bearing.

## Reputable-Source Criteria

- R1 `PASS`: one named peer-reviewed open paper, DOI, complete-paper review
  evidence, exact table locations, and explicit translation gap.
- R2 `PASS`: weekday boundary, directions, attempt, two-leg sizing, stops,
  spread caps, composition repair, and exits are deterministic and locked.
- R3 `PASS`: registered synchronized `XTIUSD.DWX` and `XNGUSD.DWX` D1 history
  supplies every runtime input.
- R4 `PASS`: native calendar, price, ATR, quote, symbol metadata, deal,
  position, and framework state only; no trained output, banned signal
  indicator, external feed, grid, martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical checker scanned 4,501 EA-registry rows and 597 root-card files.
It found no exact slug or strategy-ID duplicate. Its sole fuzzy hit was
`xtixng-ecm-rv`, caused by the shared carrier tokens; that EA estimates a
252-D1 trend-augmented OLS error-correction residual and is mechanically
unrelated.

Manual review separates:

- `QM5_20110_xti-xng-fri-rv`: Friday long-XTI/short-XNG differential from
  different source coefficients and a different weekly information clock;
- `QM5_20016_xti-xng-mon-rv`: Monday short-XTI/long-XNG, the opposite package
  direction and weekday;
- `QM5_12819_xng-thu-fade`: outright XNG Thursday short without an XTI hedge,
  joint risk budget, equal-notional contract, or package invariant;
- `QM5_12608`, `QM5_12733`, `QM5_12813`, and `QM5_20237`: price-state ratio,
  momentum, seasonal-window, or error-correction baskets rather than a locked
  Thursday return differential; and
- `QM5_12567`: short-horizon cumulative-RSI commodity pullback logic.

Verdict: `CLEAN_THURSDAY_XTI_XNG_SOURCE_DIFFERENTIAL_AFTER_MANUAL_REVIEW`.

## Kill And Safety Boundary

Expected cadence is approximately 45-52 completed logical packages per full
year before holidays and execution gates. Q02 must retire on zero packages,
fewer than five completed packages per year, wrong-day entries, non-atomic or
imbalanced composition, or nonpositive governed economics. Equal dollar
notional is not beta neutrality; Q09 alone may establish realized correlation.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. Q02 may
be enqueued once. If the factory resource ceiling is binding, do not dispatch,
reserve, stop, reap, reprioritize, or otherwise control a tester.
