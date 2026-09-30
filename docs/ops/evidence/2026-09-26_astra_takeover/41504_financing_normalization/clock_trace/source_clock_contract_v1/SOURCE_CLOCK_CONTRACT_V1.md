# Source-Clock / Destination-Rollover Contract V1 (DRAFT — independent review required before activation)

Continues parent task `f42ee12a-ea92-469b-b25b-da7e2177fc9e`. This is the "typed
source-clock/destination-rollover contract" called for in
`clock_trace/FINDINGS.md` (sha256 `24717d614ba51bf21642d06141766880207f048cd4ebaacd78f0f38745248736`)
and `41504_financing_normalization/RESULT.md` (sha256
`f8b3ed197ea8d1c86560c0d4e0390b2513ae94fc6fb10a081ae91fde76815b23`). It is a
**specification + standalone reference implementation**, not a change to any
production pipeline, gate, financing library, KPI or roster file. Nothing in
`framework/`, `tools/strategy_farm/financing_lib_ftmo.py`, or any registry was
touched by this task.

## Why this exists

The approved FTMO financing library
(`docs/ops/evidence/task_07c373a8-41da-45ac-b0be-8f5b84e0635c/financing_lib_ftmo.py`,
sha256 `89723c362b7398f8524bc95926693846f417f49c17563e0bcdfc9186ff67cf77`) hardcodes:

```python
FTMO_SERVER_TIMEZONE = "Europe/Bucharest"
FTMO_TZ = ZoneInfo(FTMO_SERVER_TIMEZONE)
...
entry = dt.datetime.fromtimestamp(float(entry_raw), dt.timezone.utc)
close  = dt.datetime.fromtimestamp(float(close_raw), dt.timezone.utc)
```
(lines 31-32, 255-256). It treats every native MT5 row-integer timestamp as a
true UTC instant, then reprojects it onto `Europe/Bucharest` for rollover/swap
and daily-loss-reset accounting.

Two independent, previously-gathered pieces of primary-source evidence show
this is not always correct:

1. **FTMO's own published transition notices directly contradict the
   Europe/Bucharest mapping** for specific dated windows
   (`clock_trace/VENUE_CLOCK_OBSERVATIONS.json`, sha256
   `3eb98d6133222cff2838c21619962d99687fcdeff7910f415fc78fb78771f61e`):
   - FTMO's 02-Mar-2023 blog post states the platform moved to GMT+3 on
     **Sunday 12 Mar 2023, 09:00 platform time**, while EU DST (which would
     put Bucharest at UTC+3) did not start until **26 Mar 2023** — a
     ~2-week window where the hardcoded `Europe/Bucharest` mapping
     (UTC+2 during that window) disagrees with the actual platform offset
     (UTC+3).
   - FTMO's 31-Oct-2024 blog post states the platform stayed at GMT+3 through
     **2 Nov 2024** and only reverted to GMT+2 on **3 Nov 2024**, while EU DST
     ended **27 Oct 2024** (Bucharest would already be UTC+2). Same
     ~1-week disagreement in the opposite direction.
   - Both counterexamples are captured with fetched raw source URL, retrieval
     timestamp and sha256 in `VENUE_CLOCK_OBSERVATIONS.json`.
   - **Conclusion: `Europe/Bucharest` is not a universal historical mapping
     for the FTMO MT5 platform clock. It is REFUTED for at least these two
     windows, by FTMO's own primary source, not by inference.**

2. **Native-label parity is not proof of UTC.** `verify_native_clock.py`
   reconstructed all 207 round trips of the `10403:XAUUSD.DWX` stream from
   the authenticated native MT5 report bytes; every entry/exit time label,
   side, volume and price (within 2 ULPs) and every commission/swap/gross
   value match exactly
   (`clock_trace/NATIVE_CLOCK_RESULT_10403.json`, sha256
   `d995c673d40ce935adead12942105c7dae876554adaf8a42a85044a4bfc97ed3`). That
   proves the exported JSONL faithfully repeats the native report's printed
   labels. It says nothing about whether those printed labels are true UTC
   instants, broker-wall-clock values stored using UTC epoch arithmetic, or
   something else — the HCC reader's own documentation describes the latter,
   the financing library assumes the former, and no artifact in this task
   tree has authenticated which one the specific historical `10403` import
   actually used.

3. **A candidate alternative (NY-close/US-DST) is itself unauthenticated and
   materially different from the Bucharest/EU-DST candidate.** The
   conditional exposure check
   (`clock_trace/CONDITIONAL_DST_EXPOSURE_10403.json`, sha256
   `5c7ed89509104f0366fb52e0ce927864f05e1a61e9a170879e4ec8be7be28312`)
   found 26 of 414 checked endpoints (14 of 207 trades, 6.8%) where the
   EU-DST-rule label and the US/NY-close-DST-rule label disagree by one hour
   on the same native timestamp. That disagreement is concentrated exactly
   around historical DST boundary dates (2018-03-23, 2020-03-12/13,
   2020-10-28/30, 2021-11-05, 2022-11-03/04, 2023-03-15/17/20/21,
   2023-11-03, 2024-03-21/22/28, 2024-10-29/11-01, 2025-03-13/14/18/21/27/28).
   Neither rule has been authenticated against a primary source for this
   specific `10403` stream's actual historical broker/import chain; the
   Bucharest rule is additionally known-wrong for two windows above.

4. **Build identity is not yet reconciled.** The August original stream's
   bound EX5 (`2e77dc2d9593afdb3267a8e3e029f5d8d437ee8fbdfd1ab4cba0c139babed89e`)
   differs from the September bundle's recorded EX5 identity for the
   byte-identical stream content
   (`f927f07f46579bbb9a1bdcfdb7caa9b246e9d7555935fbb878f7fc01afbf7ab3`)
   (`clock_trace/BUNDLE_VS_NATIVE_IDENTITY_10403.json`, sha256
   `7fc8792fb07591a5fea6209b6fcb9326c27ebd5e5f708e8a799a7d1043788755`,
   disposition `SAME_STREAM_CONTENT_DIFFERENT_RECORDED_BUILD_IDENTITY`).
   This contract treats an unreconciled identity mismatch as another reason
   to refuse, not to silently rebind.

Given (1)-(4), any consumer that computes financing, repricing, or a
marginal-book cost delta from a source stream **must not silently default**
to either the Bucharest/EU-DST arm or the NY-close/US-DST arm, and must not
treat native-label parity as UTC authentication. It must refuse unless the
specific source/window has been separately, explicitly authenticated.

## Contract

### Clock states (per source stream + historical window)

| State | Meaning | Permitted use |
|---|---|---|
| `UNKNOWN` | No classification has been asserted for this source/window. | None. Refuse. |
| `NATIVE_LABEL_PARITY_ONLY` | Exported labels verified identical to the native MT5 report's printed labels (round-trip checked), but the instant those labels represent relative to UTC is not authenticated. | Replay / no-op identity checks only. Refuse for financing, repricing, cost, or marginal-book use. |
| `CANDIDATE_OFFSET_UNAUTHENTICATED` | A specific offset/DST rule has been proposed (e.g. "NY-close/US-DST", "Europe/Bucharest/EU-DST") but not proven against a primary, dated broker source for this window. | Sensitivity/diagnostic exposure calculations only, explicitly labeled as such (as `41504_financing_normalization/RESULT.md` already does). Refuse for canonical cost or admission use. |
| `REFUTED` | A specific offset/DST rule has been positively disproven by a primary, dated source for part or all of the window. | Must never be selected, even as a fallback, for the disproven sub-window. |
| `AUTHENTICATED_UTC` | Every instant in the window has been proven against a primary, dated, authoritative source, including any irregular transition dates that diverge from generic tzdata DST rules. | Only state that permits financing/repricing/canonical cost computation. |

Every record also carries:
- `source_id` (e.g. `"10403:XAUUSD.DWX"`), `window_start`, `window_end` — native label bounds.
- `evidence_paths` — list of `{path, sha256}` backing the state.
- `offset_table` — nullable; only populated when `state == AUTHENTICATED_UTC`.
  Must be a **dated transition table**, never a single fixed IANA zone name,
  because FTMO's own transition dates are proven (above) to diverge from
  `Europe/Bucharest` around DST boundaries by up to ~2 weeks.
- `rollover_time_role` — one of `SWAP_PLATFORM_MIDNIGHT` or
  `DAILY_LOSS_RESET`. These are kept as **separate typed fields, never
  merged**, per standing instruction: FTMO's daily-loss reset time is not
  necessarily the same clock instant as swap/platform midnight, and this
  contract must not assume they coincide without separate authentication.

### Known seed classifications (frozen facts from existing evidence; not new claims)

| source_id | window | state | basis |
|---|---|---|---|
| `10403:XAUUSD.DWX` | 2017-08 .. 2025-11 (207 trades) | `NATIVE_LABEL_PARITY_ONLY` | `NATIVE_CLOCK_RESULT_10403.json` |
| `Europe/Bucharest` generic EU-DST rule, FTMO MT5 platform | 2023-03-12 .. 2023-03-26 | `REFUTED` | FTMO 02-Mar-2023 blog post |
| `Europe/Bucharest` generic EU-DST rule, FTMO MT5 platform | 2024-10-27 .. 2024-11-03 | `REFUTED` | FTMO 31-Oct-2024 blog post |
| `NY-close/US-DST` rule, `10403:XAUUSD.DWX` | full window | `CANDIDATE_OFFSET_UNAUTHENTICATED` | `CONDITIONAL_DST_EXPOSURE_10403.json` |

No source in this repository currently qualifies for `AUTHENTICATED_UTC`.
That is the honest current state, not a defect of this contract draft.

### Refusal policy (fail-closed)

A reference implementation, `source_clock_contract.py`, is provided in this
directory. It:
- Exposes `classify(source_id, window) -> ClockState` reading from an
  explicit, committed seed table (the four rows above).
- Exposes `require_authenticated(source_id, window)` which raises
  `ClockContractRefusal` unless `classify(...)` returns `AUTHENTICATED_UTC`
  with a populated dated `offset_table` — this is the function any future
  financing/repricing/marginal-book consumer must call before doing
  timestamp-to-wall-clock conversion.
- Keeps `rollover_time_role` as a required, separate argument wherever a
  daily boundary is computed, so swap-midnight logic cannot silently stand
  in for daily-loss-reset logic or vice versa.
- Does **not** modify `financing_lib_ftmo.py` or any production code path.
  Wiring this contract into that library is a separate, reviewed step after
  the remaining prerequisites below are closed.

### Test matrix (`test_source_clock_contract.py`, all passing — see VERIFICATION below)

1. **Wednesday triple-rollover** — a window crossing a Wednesday swap date;
   confirms the refusal wrapper raises for `NATIVE_LABEL_PARITY_ONLY` /
   `CANDIDATE_OFFSET_UNAUTHENTICATED` sources rather than silently applying a
   single-day swap multiplier.
2. **Friday/weekend** — entry Friday evening, exit Sunday/Monday; confirms no
   weekend financing days are fabricated for an unauthenticated source
   (refusal), and that an authenticated source's position-hours computation
   would exclude weekend closure (holding-time change, not a new idle-day
   claim — consistent with `RESULT.md`'s existing caveat).
3. **Server-vs-UTC encoding** — the same epoch integer decoded once as naive
   UTC and once via an explicit dated offset table yields different instants;
   confirms the contract requires an explicit decoder choice and never
   defaults to one.
4. **DST boundary using FTMO's own proven irregular dates** — confirms the
   `REFUTED` Bucharest rule is rejected at 2023-03-13T12:00Z and
   2024-10-28T12:00Z specifically (the two dated counterexamples), and that
   absent an authenticated per-window table the wrapper still refuses.
5. **No-op repricing invariant** — when a source is `AUTHENTICATED_UTC` and
   the offset table reproduces the identical instant as the original native
   label (identity mapping), repriced cost must equal original cost exactly
   (zero-diff), guarding against the contract introducing drift even in the
   trivial case.
6. **Cost symmetry** — refusal state is a function of `(source_id, window)`
   only; swapping trade side (buy/sell) must not change which state applies.

## What this does NOT do

- Does not select, endorse, or activate either the `APPROVED_FTMO_V2_WITH_INHERITED_UTC_TIMEZONE_ASSUMPTION`
  or `SEALED_STAGE2_CORRECTED_SERVER_WALLCLOCK_FINANCING` arm from
  `41504_financing_normalization/RESULT.md`. Both remain qualified
  diagnostics only.
- Does not authenticate any D2g6 sleeve other than `10403:XAUUSD.DWX`, nor the
  modern `41504`/`41470` inputs referenced in the parent task. Those remain
  `UNKNOWN` under this contract until separately classified with cited
  primary-source evidence.
- Does not touch `framework/registry/`, any `.set` file, any gate verdict,
  DSR selection, roster, or KPI.
- Does not authorize any new governed marginal-book simulation.

## Remaining prerequisites before activation (unchanged from prior evidence, restated as contract gaps)

1. Authenticate the actual historical DWX broker-feed clock encoding for
   `10403:XAUUSD.DWX` and every other D2g6 sleeve and the `41504`/`41470`
   modern inputs against a primary source (broker statement, exporter log
   with documented clock semantics, or equivalent) — not inference from
   native-label parity.
2. Build a dated offset table per source covering its entire historical
   window, including irregular platform-transition dates proven above (FTMO
   MT5 does not follow generic EU DST exactly around transitions).
3. Reconcile the August-vs-September EX5 identity mismatch for `10403`
   before treating the stream as a stable, single-identity input.
4. Independent technical/statistical review of this contract and its
   reference implementation (same standing requirement the parent task and
   `independent_review/ACCEPTANCE.md` already impose) before any code in
   this directory is wired into `financing_lib_ftmo.py` or any canonical
   repricing/marginal-book path.

No OWNER gate is newly invoked by this artifact. No AutoTrading, T_Live, or
roster action is implied or requested.
