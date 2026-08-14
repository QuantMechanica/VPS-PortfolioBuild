# WTI/Gold Divergence Trend — Source Approval

Date: 2026-08-14

Decision: `APPROVED_SOURCE` for one bounded V5 Strategy Card, deterministic
EA-ID allocation, one branch-only non-live build, strict Q01 validation, and
one paced Q02 handoff if the factory CPU ceiling permits.

Authority: OWNER commodity/energy portfolio mission delivered to Codex on
the `agents/board-advisor` branch. The mission requests one new structural,
low-frequency commodity edge that is genuinely different from the certified
XAU/SP500/NDX/XNG book, requires reputable-source criteria and
`RISK_FIXED` backtests, and forbids live and portfolio mutations.

## Candidate Identity

- proposed slug: `wti-xau-div-tr`
- proposed strategy ID: `MOP-CME-WTI-XAU-DIV-2026_S01`
- canonical source ID: `MOP-CME-WTI-XAU-DIV-2026`
- traded symbol: `XTIUSD.DWX`, D1, slot 0
- read-only state symbol: `XAUUSD.DWX`, D1
- decision clock: first processed WTI D1 bar after a genuine broker-month
  transition
- active rule: follow the exact prior-twelve-completed-month WTI return sign
  only when the synchronized gold return over the same endpoints has the
  strict opposite sign

The deterministic allocator owns the EA ID. This record does not reserve or
predict an ID.

## Approved Source Basis

The following complete governed repository packets were read before this
decision:

1. Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
   Financial Economics* 104(2), 228-250. The complete published-paper review,
   DOI lineage, retrieval receipt, and explicit WTI membership are recorded at
   `strategy-seeds/sources/MOP-TSMOM-2012/source.md`, SHA-256
   `C8B07ECD62C1D5EF9E3D7975EEE6A3B6C46C1C566D0B20B42237613D9B3A7042`.
2. CME Group (2024), "Through the Lens of Gold." The governed exchange-source
   packet establishes oil/gold as an economically meaningful relative-value
   lens and distinguishes energy supply/growth exposure from monetary and
   safe-haven gold exposure. It is recorded at
   `strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/source.md`, SHA-256
   `71BDFA8A8D291655AC44EC2B3F12CB1ED21D08763C540C32687238579A279CDE`.

The source-reader router was run against the CME URL on 2026-08-14 and
returned `PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY`; its exact receipt is
preserved at
`strategy-seeds/sources/CME-OIL-GOLD-RATIO-2024/retrieval_route_20260814.json`.
No fresh page text, proxy, cache, authentication, or inferred quotation is
used. The already committed governed packet is the sole CME content evidence.

Moskowitz, Ooi, and Pedersen supply only the WTI twelve-month own-return sign
and monthly cadence. CME supplies only the structural oil-through-gold lens.
The opposite-sign conjunction, synchronized continuous-CFD endpoints,
WTI-only execution, fixed-dollar risk, hard stop, spread ceiling, and restart
ledger are transparent QM hypotheses. No source return, alpha, significance,
drawdown, trade count, cost, CFD equivalence, decorrelation, or portfolio
result transfers.

## Locked Mechanic

At each genuine broker-month transition, after closing prior-month owned WTI
exposure and consuming the new month before every fallible gate:

1. Load bounded completed `XTIUSD.DWX` and `XAUUSD.DWX` D1 histories, intersect
   exact timestamps, and derive exactly thirteen consecutive common
   broker-month endpoints ending in the immediately completed month.
2. Require positive finite closes, exact chronological order, consecutive
   broker months, and a newest common endpoint no more than ten calendar days
   stale.
3. Calculate
   `wti_trend_12m = ln(WTI_latest / WTI_12_months_older)` and
   `xau_trend_12m = ln(XAU_latest / XAU_12_months_older)`.
4. Require each endpoint return to equal the sum of its twelve component
   monthly log returns within `1e-10`.
5. Buy WTI only when `wti_trend_12m > 1e-12` and
   `xau_trend_12m < -1e-12`. Sell WTI only when
   `wti_trend_12m < -1e-12` and `xau_trend_12m > 1e-12`.
6. Consume same-sign, zero/deadband, invalid, or unavailable states flat.
7. Open at most one WTI position with `RISK_FIXED=1000`,
   `RISK_PERCENT=0`, one frozen `3.5 * ATR(20,D1)` broker hard stop, no
   take-profit, and a 1,500-point entry-spread ceiling.
8. Close before monthly replacement or after forty calendar days. Friday
   close and both news axes are OFF for the source-aligned monthly hold.

`XAUUSD.DWX` is read-only. It receives no magic, order, position, package-PnL,
or risk-budget role. Same-sign confirmation, a ratio/z-score/channel signal,
two-leg execution, return magnitude sizing, an unsynchronized endpoint,
same-month retry, or a different carrier is outside this approval.

## Reputable-Source Criteria

- R1 `PASS_WITH_POLICY_DEFER`: one canonical composite source ID backed by a
  completely reviewed peer-reviewed JFE packet and a governed CME exchange
  packet. The fresh CME route is honestly deferred and supplies no new text.
- R2 `PASS`: exact synchronized endpoints, two strict signs, direction map,
  attempt ledger, fixed risk, hard stop, rollover, and stale guard are fixed.
- R3 `PASS`: both `XTIUSD.DWX` and `XAUUSD.DWX` are present in the canonical
  DWX symbol matrix; only WTI is ordered.
- R4 `PASS`: deterministic native arithmetic and framework state only; no
  trained output, banned signal indicator, external runtime feed, grid,
  martingale, scale-in, or pyramid.

## Non-Duplicate Decision

The canonical pre-allocation checker scanned 4,395 EA-registry rows and 491
root cards and returned `CLEAN` with no fuzzy match for the proposed slug,
strategy ID, authors, or full mechanic. Manual review fixes the closest
boundaries:

- `QM5_12604_cme-oilgold-ratio` fades an absolute daily oil/gold log-ratio
  z-score and orders both legs. This candidate forms no ratio or z-score,
  never orders gold, and trades only a monthly WTI trend in a strict sign-
  divergence state.
- `QM5_12605_cme-oilgold-brk` follows a daily ratio channel with a two-leg
  package. This candidate uses exact twelve-month endpoint signs and WTI-only
  execution.
- `QM5_12863_oilgold-rspread` fades short-horizon relative-return shocks with
  paired oil/gold orders. This candidate does not fade a spread or own a gold
  leg.
- `QM5_12603_wti-tsmom12m` is unconditional. `QM5_21516_wti-decoup-trend`
  gates on weak WTI/XNG daily correlation, `QM5_21518_wti-brent-cfm` requires
  same-sign Brent confirmation, and `QM5_21522_wti-lowdb-trend` compares two
  WTI/SP500 downside-beta blocks. None uses opposite WTI/gold monthly signs.
- `QM5_12567_cum-rsi2-commodity` is a short-horizon, long-only XNG oscillator
  pullback and shares neither carrier, state, direction map, nor clock.

Verdict: `CLEAN_WTI_TWELVE_MONTH_TREND_IN_STRICT_GOLD_DIVERGENCE_STATE`.

## Kill And Safety Boundary

Expected cadence is approximately five to eight completed positions per full
post-warm-up year; Q02 must retire below five positions/year or on nonpositive
governed economics. Q09 alone may establish realized correlation with the
certified XAU, SP500, NDX, and XNG book. No failure may change the endpoint
count, horizon, strict opposite-sign gate, traded/read-only roles, cadence,
fixed risk, stop, hold, spread, or retry policy.

This approval excludes manual backtests; live, demo, shadow, stress, and
optimization setfiles; AutoTrading; `T_Live`; deploy or T_Live manifests;
portfolio-gate changes; portfolio admission; and correlation waivers. If the
paced factory CPU ceiling is binding before enqueue, stop and record the
capacity state without starting, stopping, reserving, reaping, or
reprioritizing a terminal.
