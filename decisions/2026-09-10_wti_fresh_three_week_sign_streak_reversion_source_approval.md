# WTI Fresh Three-Week Sign-Streak Reversion — Source Approval

- Date: 2026-09-10
- Decision owner: OWNER
- Recorded by: Codex
- Decision: `APPROVED_SOURCE`
- Scope: one structural low-frequency WTI card, deterministic allocation,
  branch-only non-live build, strict Q01, and one paced Q02 enqueue only below
  the hard CPU ceiling
- Proposed slug: `wti-wstreak3-fade`
- Strategy ID: `YANG-WTI-WSTREAK3-FADE-20260910_S01`
- Source packet:
  `strategy-seeds/sources/YANG-WTI-WSTREAK3-FADE-20260910/source.md`
- Dedup receipt:
  `artifacts/qm5_wti_wstreak3_fade_preallocation_dedup_20260910.json`

## Authority And Source Quality

The current OWNER PACER directive authorizes one reputable-source,
structural, low-frequency commodity/energy card and build. The bounded packet
preserves the complete local record for Moskowitz, Ooi, and Pedersen (2012),
*Time Series Momentum*, *Journal of Financial Economics* 104(2), 228–250,
DOI `10.1016/j.jfineco.2011.11.003`, including explicit NYMEX WTI universe
membership, and the academic commodity-reversal lineage of Yang, Goncu, and
Pantelous, SSRN 3069253. The exact weekly streak fade is disclosed as an
untested QM translation; no source efficacy or diversification claim transfers.

## Locked Mechanic

At each Monday-anchored broker-week boundary, reconstruct five consecutive
completed WTI week-ending closes and their four adjacent close-to-close log
returns. Require the newest three returns to share one strict sign and the
preceding return to have the strict opposite sign. Trade opposite the newest
three-week streak for one week. Consume the attempt before fallible gates.
Use `RISK_FIXED=1000`, `RISK_PERCENT=0`, one frozen
`3.5*ATR(20,D1)` hard stop, no target, no retry, and the governed native or
uniform `+1`-day energy-label convention.

No oscillator, moving average, fitted center, return-magnitude threshold,
volume state, external runtime feed, trained component, target, trail,
scale-in, pyramid, grid, or martingale is permitted.

## Duplicate Decision

The canonical checker covered 4,895 registry rows and 1,505 repository cards;
the configured Strategy Wiki root was unavailable and is not claimed as
checked. It found no exact identity and one expected fuzzy family match.
`QM5_41074` follows the identical fresh-streak state; this card fades it.
Direction is the complete economic hypothesis and is load-bearing, not a
parameter variant. `QM5_41412` requires strict `+,-,+` or `-,+,-`
alternation, while this card requires `-,+,+,+` or `+,-,-,-`; the admitted
states are disjoint. Unconditional one-week reversal and seasonal fades also
use different states. Verdict:
`DISTINCT_WTI_FRESH_THREE_WEEK_SIGN_STREAK_REVERSAL`.

## Authorization Boundary

Approval permits the approved card/G0 record, deterministic identity and magic
allocation, bounded V5 build, mandatory PACER framework-input-pin audit before
compile enqueue, strict Q01, one fixed-risk preset, and one paced Q02 enqueue
only below the CPU ceiling. It excludes manual backtests, optimization,
portfolio admission, correlation waivers, portfolio-gate edits, deployment,
live manifests, `T_Live`, AutoTrading, terminal control, and live use.
