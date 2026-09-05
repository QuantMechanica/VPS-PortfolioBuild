# M10 position attribution and burn-in advisory — REVIEW

Task `b94b61c5-0629-4626-8077-5bd35491eb44`. Captured 2026-09-05 11:55:27 UTC.
The offline projection resolves all 18 magic-0 deals in 225 native export rows,
covering 108 positions. Burn-in remains **UNKNOWN / non-binding**. The original
deployment epoch, risk thresholds, runtime pointer and production report remain
unchanged. This is an additive report for review; it does not certify readiness.

## Attribution correction

The complete per-position table, opening/closing deal IDs, cashflow rows and
classification are in [result.json](2026-09-05_m10_burnin_attribution/result.json).
The native export is frozen at [deals.csv](2026-09-05_m10_burnin_attribution/inputs/deals.csv:1).
`reproduce.py:38` joins native position IDs and opening **deal_magic**, including
opening and closing costs; it deliberately ignores precomputed logical magic.
Conflicting identities, incomplete opening evidence and complex reversal
lifecycles remain unresolved. All-zero positions remain unattributed without an
independent actor record; a zero closing magic alone does not establish manual
origin.

| Position | Native opening → closing deal | Attribution | Full lifecycle net USD |
|---|---|---|---:|
| 3168177717 / EURUSD | 148992255 → 149285977 | EA 11421, magic 114210000; closing deal alone has magic 0 | -262.00 |
| 3169151197 / NDX | 149374382 → 149390277 | Both deals magic 0; no EA identified | -1,539.50 |

The EURUSD closing deal is -260.77; its opening commission is -1.23. The older
readiness prose treating this lifecycle as a manual exclusion is contradicted by
the native opening record. Seven zero-magic closing deals bind to nonzero opening
EA identities (one is a pre-epoch non-roster EA); two zero-magic NDX trade deals
belong to the single unattributed position; nine rows are account cashflows.
Cashflow comments do not identify an EA.

For **2026-07-24 06:42 UTC through this capture**, realized deal cash reconciles:

| Component | USD |
|---|---:|
| Current-roster EA deal cash | -1,434.82 |
| Unattributed NDX position | -1,539.50 |
| Account dividends | +6.56 |
| Account total, excluding the earlier initial deposit | **-2,967.76** |

Closed current-roster **whole-position** net is -1,436.59. Its -1.77 difference
from in-window EA deal cash reflects the different accounting scopes: lifecycle
net includes opening costs even when the opening predates the epoch. Both views
are retained, with exact deal IDs and timestamps. Account equity also contains
unrealized exposure and therefore is not this realized-cash series.

## Equity and unchanged window

`reproduce.py:115` constructs chronological UTC day records from captured,
identity-matched account EQUITY_SNAPSHOT events. It retains the last observed
sample, its lag from midnight, the sampled minimum, the largest unsampled gap,
and the old median for comparison. Last samples differ from medians on **21 of
36 observed days**. The latest observed equity is **98,972.85**, and the minimum
observed equity is **98,517.42**. Neither number proves an exact EOD or true
intraday low. Those two fields explicitly remain null: the lowest sampled equity
is an **upper bound on the true minimum**, and losses between samples cannot be
bounded by these logs. Missing equity dates are not filled with zero returns.

The deployment epoch stays **2026-07-24T06:42:00Z**. At capture it is 43.22 elapsed
days old, covering 44 UTC dates, with 36 observed dates and 8 missing dates. A
fixed 42-elapsed-day endpoint is **2026-09-04T06:42:00Z**; the production comparator
instead tests `n_days_observed >= 42` (`portfolio_live_forward_from_logs.py:811`).
This mismatch is reported for adjudication; this artifact changes neither
definition and does not restart or extend a success window after losses.

The current book fingerprint is
`e8bc34e619a0c530bfd5c0156e27aef27abd41cff43f79f633b25c148672a07c`.
The configured [MC reference](2026-09-05_m10_burnin_attribution/inputs/mc_reference.json:1)
is dated 2026-07-01, describes **13 sleeves at flat 0.75% risk**, and carries
neither this fingerprint nor a manifest hash. It cannot support the current
24-sleeve comparison. The manifest also has no backtest Sharpe. Its declared
approval and the runtime pointer's `signed=false` are reported separately.
The advisory remains UNKNOWN; no reference is relabeled or substituted.

## Silent sleeves and KS gap

All four silent sleeves have recent INIT_OK and other logger events. Therefore
their absence of equity snapshots is not evidence of a general logger outage or
missing attachment. The three with no deals cannot be called healthy telemetry
merely because no signals executed.

| Sleeve | Named defect/cause evidence | Practical limit / next step |
|---|---|---|
| 1567 / EURUSD | Missing snapshot call in captured source OnTick (`inputs/source_1567.mq5:348`); no `QM_EquityStreamOnNewBar` anywhere in that source. Native export shows one position and two in-window deals, despite no snapshot ever. | Equity instrumentation gap. Build an independently reviewed observation hook; no live replacement in this task. |
| 12778 / AUDUSD | Host-symbol filter uses `.DWX` names (`inputs/source_12778.mq5:95`, `:310`) before snapshot `:504`, while deployed log symbol is `AUDUSD`. Latest BASKET_WARMUP is loaded=0, skipped=4 (`QM5_12778_ea-12778.log:362`). | Native/custom-symbol contract mismatch is a supported source-level cause; no native deals. Exact deployed control flow still needs a bound build/isolated replay. |
| 12969 / USDJPY | Target check explicitly requires `USDJPY.DWX` (`inputs/source_12969.mq5:40`), returns before snapshot `:345`; actual log symbol is `USDJPY`. | Native/custom-symbol contract mismatch is the source-level cause; no native deals. Exact deployed control flow still needs bound build evidence. |
| 13117 / EURGBP | Host filter uses `EURGBP.DWX` / `AUDJPY.DWX` (`inputs/source_13117.mq5:44`, `:291`) before snapshot `:429`. Actual log symbol is `EURGBP`; latest warmup loaded=0, skipped=4 (`QM5_13117_ea-13117.log:343`). | Native/custom-symbol contract mismatch is a supported source-level cause; no native deals. Exact deployed control flow still needs a bound build/isolated replay. |

Paths prefixed `inputs/` in this table resolve within the accompanying M10
directory. Source hashes and deployed/canonical binary hashes are frozen in
[source_checks.json](2026-09-05_m10_burnin_attribution/inputs/source_checks.json:1).
**All five inspected canonical binaries differ from the deployed binaries.**
Source inspection is consequently not proof that those bytes execute the same
call path. The named causes above are explicitly scoped to observed telemetry
plus source evidence; exact runtime attribution of the defect remains unverified.

For **10440 / NDX**, the runtime emits `KS_BASELINE_ABSENT` and
`action=ks_killswitch_dormant` (`QM5_10440_ea-10440.log:451`, retained with its
source-line anchor in `inputs/events.jsonl`). The independent pulse also reports
one missing baseline, with 23/24 loaded. The table-level dormant count being zero
does not override that explicit EA event. The captured DB lineage includes a
later Q09 FAIL and a pending Q09_NEWS successor; no baseline was fabricated from
a convenient earlier row. A baseline must be regenerated from the applicable
qualified, bound evidence and pass separate deployment review. Nothing was
copied into the live or FILE_COMMON baseline paths.

## Verification and boundaries

Run `python C:/QM/repo/docs/ops/evidence/2026-09-05_m10_burnin_attribution/reproduce.py`
for an offline JSON replay. `--out <new-file>` exclusively creates a new version
and refuses overwrite. Frozen inputs and extracted-event bytes are hash checked
before replay. The original source hashes and line numbers are in `capture.json`;
54 source lines failed JSON parsing and remain an explicit capture limitation.

Focused tests cover opening-identity attribution, both cost legs, all-zero
positions, conflicting/partial/reversal lifecycles, duplicate deals, arithmetic
errors, unsorted samples, missing-day handling and the actual captured known
answers. Test and replay receipts are in `verification.json`. No terminal was
launched or stopped, no trading state changed, and no existing report, verdict,
pointer, risk setting or evidence file was overwritten. The G: audit was
unavailable to the scheduled account; the routed specification and captured
local evidence supplied this review.

Remaining acceptance limits: exact EOD/intraday-loss evidence, matching MC/Sharpe
reference, authoritative window semantics and deployed-build proof for the
silent-sleeve source causes. REVIEW means those limitations are visible to the
reviewer; it does not convert them into operational verification.
