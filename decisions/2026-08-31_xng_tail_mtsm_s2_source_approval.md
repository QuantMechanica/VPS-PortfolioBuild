# XNG Tail-Managed Time-Series Momentum S2 Port — Source Approval

Date: 2026-08-31

Decision: `APPROVED_SOURCE` for one bounded XNG carrier-port Strategy Card,
deterministic EA-ID and one-slot magic allocation, one branch-only non-live
build, strict Q01 validation, and one paced Q02 enqueue only while the governed
whole-host CPU ceiling remains clear. This decision does not authorize a
manual tester run.

Authority: the current explicit OWNER commodity/energy portfolio mission on
branch `agents/board-advisor`. The mission requires one new structural,
low-frequency commodity/energy sleeve, reputable-source criteria, a
`RISK_FIXED` backtest preset, committed non-duplicate work, and one Q02
enqueue. It expressly permits a second `XNGUSD` edge when its logic differs
from `QM5_12567`, and it excludes live and portfolio-gate work.

## Candidate Identity

- proposed slug: `xng-tail-mtsm-s2`
- proposed strategy ID: `LIU-MTSM-2021_XNG_S02`
- approved bounded source: `strategy-seeds/sources/LIU-MTSM-2021/source.md`
- parent implementation used only as a locked logic reference:
  `QM5_13108_xti-mtsm-s2`
- host / slot 0: exact `XNGUSD.DWX`, D1
- signal: source-defined MTSM-S2 target map from 30 completed D1 returns,
  five-return upper/lower partial moments, and separate no-lookahead 80th
  percentile references from 252 older observations
- lifecycle: evaluate on each new D1 bar, close a flat/opposed/unknown state,
  retain a same-side state, apply the frozen broker stop, and let framework
  Friday closure end the weekly package

The deterministic registry process owns the EA ID. This source decision
neither reserves nor predicts an ID.

## Approved Source Basis And Complete-Read Boundary

The bounded source read completely for this decision is the governed packet
`strategy-seeds/sources/LIU-MTSM-2021/source.md`. It records the complete-read
review of:

Liu, Zhenya; Lu, Shanglin; and Wang, Shixuan (2021), "Asymmetry, tail risk and
time series momentum," *International Review of Financial Analysis* 78,
article 101938, DOI `10.1016/j.irfa.2021.101938`.

The packet preserves the institutional accepted-manuscript identity, source
sample, exact 30-day base-momentum construction, five-day upper/lower partial
moments, recursive 80th-percentile regions, MTSM-S2 action map, robustness
scope, and material limitations. It also records that the study covers a
diversified Chinese commodity-futures universe rather than WTI, natural gas,
or Darwinex CFDs; omits transaction costs; and uses volatility targeting that
is incompatible with the V5 fixed-risk backtest contract.

The external Liverpool, Reading, and EIA URLs considered during this session
were classified by the deterministic source router as
`DEFERRED:SOURCE_POLICY`. No claim retrieved from those deferred URLs is used
here. The already governed local complete-read packet is the sole bounded
source of record for this extraction.

## Locked Port Mechanic

On every new exact `XNGUSD.DWX` D1 bar, using completed data only:

1. Sum the latest 30 simple close-to-close D1 returns. Strictly positive is
   base long; zero or negative is base short, matching the approved parent
   implementation.
2. Over the latest five completed returns, calculate upper partial moment as
   the mean of squared positive returns with other observations contributing
   zero, and lower partial moment as the mean of squared negative returns with
   other observations contributing zero.
3. Build 252 older upper- and lower-partial-moment observations, each from its
   own five-return window. The current observation is excluded; no future
   close is permitted. Calculate separate nearest-rank 80th percentiles.
4. Apply the MTSM-S2 map exactly:

   ```text
   UPM tail and LPM tail: flat
   LPM tail only:         long
   UPM tail only:         short
   neither tail:          base momentum direction
   ```

5. Repair malformed owned exposure before entry. Close an owned position when
   history/state is unknown, the target is flat, the target opposes the owned
   side, or the position reaches eight calendar days. A same-bar reverse may
   occur only after confirmed closure; same-side state is held.
6. When flat with a nonzero target, enter one market position with exactly
   `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. Attach one
   frozen `3.0 * ATR(20,D1)` normalized broker hard stop and no target.
7. Reject crossed or negative quotes and a genuinely positive spread above
   1,500 points. Modeled zero spread remains valid.
8. Keep current news temporal/compliance behavior identical to the parent
   (`PRE30_POST30` / `DXZ`), legacy news mode OFF, and framework Friday close
   enabled at broker hour 21.

No parameter is refitted for natural gas. The 30/5/252/80 state, S2 map,
stop, stale horizon, spread cap, news settings, and Friday boundary are locked
port inputs. Q02 tests the unchanged port or retires it.

## Reputable-Source Criteria

- R1 `PASS_WITH_CARRIER_AND_SIZING_TRANSLATION`: the governed packet traces to
  a named-author, DOI-bearing, peer-reviewed 2021 paper and records a complete
  accepted-manuscript review. The paper supplies the partial-moment state
  machine but does not establish an XNG result. Natural-gas transport and V5
  fixed-risk sizing are disclosed tests, not author claims.
- R2 `PASS`: lookbacks, return arithmetic, partial moments, reference-sample
  exclusion, percentile convention, target map, state transitions, risk,
  stop, spread cap, and lifecycle are exact and mechanical.
- R3 `PASS_WITH_PORT_AND_CFD_RISK`: registered native `XNGUSD.DWX` D1 history,
  quotes, ATR, positions, deals, and terminal state supply every runtime
  input. Chinese-futures-to-natural-gas, futures-to-CFD, session-label,
  spread, gap, and Friday-packaging risks remain binding.
- R4 `PASS`: deterministic arithmetic and order statistics only; no trained
  output, banned signal indicator, external runtime feed, grid, martingale,
  scale-in, or pyramid.

## Non-Duplicate Decision

The canonical receipt
`artifacts/qm5_xng_tail_mtsm_s2_preallocation_dedup_20260831.json` scanned
4,743 registry rows, 1,381 cards, and 45 Strategy Wiki nodes. It found no exact
slug or strategy-ID identity. Its two fuzzy rows are the approved and flat
copies of `QM5_13108_xti-mtsm-s2`, the intended parent carrier.

Manual review resolves those expected fuzzy rows as a governed carrier port:

- `QM5_13108` trades exact `XTIUSD.DWX`; this candidate trades exact
  `XNGUSD.DWX`. Neither can open the other's carrier.
- The parent reached Q09 PASS before a later portfolio failure according to
  `D:/QM/reports/state/pipeline_state.json`; this is a parameter-locked
  survivor-port test, not a rescue edit to the WTI verdict.
- No registered XNG EA or approved XNG card contains upper/lower partial
  moments or the four-region MTSM-S2 map.
- Certified `QM5_12567_cum-rsi2-commodity` is a long-only two-day cumulative
  RSI pullback under a 200-D1 trend state. This candidate is symmetric,
  non-RSI, 30-D1 momentum plus asymmetric five-D1 squared-return tails and can
  target long, short, or flat.

Verdict:
`FUZZY_MATCH_RESOLVED_LOCKED_XNG_CARRIER_PORT_DISTINCT_FROM_QM5_12567`.

## Kill And Safety Boundary

Expected cadence is approximately 20-52 completed packages per full year,
inherited as a queue-ordering prior from the parent card and weekly Friday
packaging rather than an XNG result. Q02 retires the unchanged port on zero
positions, fewer than five positions in any full scored year, nonpositive
governed economics, invalid risk mode, future-data leakage, wrong partial-
moment arithmetic, wrong region action, missing stop, malformed lifecycle, or
nondeterminism. Failure may not be rescued by changing the carrier parameters,
percentile, target map, stop, spread ceiling, or hold behavior.

The XNG carrier is already represented by `QM5_12567`; only unchanged Q09 may
measure whether this different return driver is sufficiently decorrelated.
No low-correlation, profitability, certification, or portfolio-admission
claim is made by this approval.

This approval excludes a manual backtest; live, demo, shadow, stress, and
optimization presets; terminal control; AutoTrading; `T_Live`; deploy or
T_Live manifests; portfolio-gate changes; portfolio admission; decorrelation
claims; and correlation waivers. Q02 may be enqueued once only after strict
Q01 and only if the governed whole-host CPU check remains below the ceiling.
