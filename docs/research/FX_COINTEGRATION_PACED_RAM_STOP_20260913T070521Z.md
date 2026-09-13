# FX cointegration fallback: non-duplicate RAM-capacity stop

Recorded: `2026-09-13T07:05:21Z` (`09:05:21` Europe/Berlin)

Branch: `agents/board-advisor`

Observation head: `713adf6823a375eb64e1098400f6c34deb8800eb`

## Outcome

The frozen 66-pair FX cointegration screen has no eligible unbuilt pair. Its
two published positive-hedge survivors and five strict sign-aware additions
are already mechanized. Creating another card would duplicate a relationship
or weaken the preregistered screen rather than add a reputable sleeve.

Neither preferred anchor has a current Q02 infrastructure blocker:

| EA | Pair | Authenticated chain |
| --- | --- | --- |
| `QM5_12532` | AUDUSD.DWX / NZDUSD.DWX | Q02 PASS, Q04 PASS, Q05 FAIL |
| `QM5_12533` | EURJPY.DWX / GBPJPY.DWX | Q02 PASS, Q04 FAIL |

The concrete existing-forex fallback remains the low-frequency D1
EURGBP/EURAUD market-neutral basket `QM5_12712`. Its current-contract Q08
successor already exists exactly once:

| Field | Value |
| --- | --- |
| Work item | `b68d05cd-e52c-43a5-96aa-5e0306efa60f` |
| Logical symbol | `QM5_12712_EURGBP_EURAUD_COINTEGRATION_D1` |
| State | `pending`, unclaimed, attempt 0, verdict null |
| Priority | `priority_track=true` |
| Active holds | zero; the OWNER hold was released at `2026-09-13T04:09:14Z` |

Appending another Q08 would be duplicate work. Enqueuing a later phase before
this Q08 produces readable evidence would bypass the deterministic dependency.

## PACER capacity decision

Five whole-host CPU samples were taken two seconds apart:

```text
79.022292%
77.612884%
87.846125%
93.068869%
93.115968%
```

Average CPU was `86.133228%` and maximum CPU was `93.115968%`, so the mission's
97% CPU ceiling did not latch in this sample.

Memory admission did fail. Free physical memory was only `13.479 GiB` of
`63.120 GiB`. The pending basket payload records a `32 GiB` commit reservation;
with the previously evidenced `14 GiB` host safety floor it requires `46 GiB`
free. Starting or manually dispatching this basket would therefore violate the
paced capacity boundary.

The canonical database had six active factory work items: two Q07 rows and
four OPT_CENSUS rows. No queue, claim, dispatch, tester, or terminal action was
taken.

## PACER build guard

No `.mq5` source was generated or edited and no enqueue-compile command was
issued. The mandatory post-write/pre-compile input-pin audit boundary was not
entered. No framework input, stress probability default, RNG seed, news input,
or Friday-close input was pinned or changed.

## Safety

- No strategy card, EA source/binary, setfile, basket manifest, registry, magic
  row, work-item payload/status/verdict, queue priority, or backtest evidence
  was changed.
- No portfolio-admission, portfolio-KPI, Q08-contribution, or portfolio-gate
  surface was touched.
- No `T_Live` manifest, terminal, deploy artifact, AutoTrading state, or live
  artifact was touched.
- Existing unrelated shared-worktree changes were preserved and excluded from
  this evidence commit.

Machine-readable companion:
`artifacts/fx_cointegration_paced_ram_stop_20260913T070521Z_board_advisor.json`.
