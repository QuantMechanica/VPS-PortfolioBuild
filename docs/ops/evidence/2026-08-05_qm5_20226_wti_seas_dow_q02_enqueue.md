# QM5_20226 WTI Seasonal / Weekday Concordance Q02 Enqueue

Date: 2026-08-05 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency energy candidate was researched, approved,
allocated, built, strictly validated, and enqueued once at Q02:

- EA: `QM5_20226_wti-seas-dow`.
- Carrier: `XTIUSD.DWX`, D1, slot 0, magic `202260000`.
- Mechanic: buy a genuine Friday during the positive November-May WTI
  physical season; sell a genuine Monday during the negative June-October
  season.
- Genuine-session boundary: a Friday must follow a completed Thursday D1
  bar; a Monday must follow a completed Friday D1 bar. Entry is limited to
  five minutes after broker D1 open.
- Lifecycle: Friday longs use the framework broker-hour-21 close; Monday
  shorts close on the first following D1 boundary; wrong-side positions
  close immediately and a three-day stale guard remains.
- Risk: frozen `3.0 * ATR(20,D1)` server-side hard stop, no target,
  `RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`.
- Expected cadence: 42-50 completed packages/year after holidays; Q02 must
  retire the EA below five completed packages/year.

Q02 work item `f92e06a9-833a-42a7-941c-c3dcfb14c7f3` was created at
`2026-08-05T16:16:37Z` for `QM5_20226 / XTIUSD.DWX`. The immediate canonical
readback reported phase `Q02`, kind `backtest`, status `active`, claimant
`T5`, attempt count zero, and no verdict or evidence path yet. This document
records an enqueue, not a Q02 result or certification claim.

## Sources And Claim Boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-GORSKA-WTI-SEASDOW-2026/source.md`.

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), 121-126, supply positive November-May and
  negative June-October WTI physical-season directions.
- Gorska and Krawiec (2015), *Problems of World Agriculture* 15(4), 62-70,
  DOI `10.22630/PRS.2015.15.4.54`, supply negative Monday and positive
  Friday WTI weekday directions.

Both parent texts have durable complete-read repository records. Neither
tests their conjunction, a Darwinex continuous CFD, broker-open execution,
fixed cash risk, an ATR stop, costs, or portfolio correlation. No source
performance statistic is imported as a QM expectation. Q02 must establish
the candidate's own economics; the unchanged downstream portfolio gate alone
may establish realized overlap with XNG, XAU, SP500, or NDX.

## Non-Duplicate Boundary

The deterministic pre-allocation checker scanned 4,283 registry rows and 399
canonical cards. It found no exact identity and no fuzzy match above its
threshold. Manual review fixes the load-bearing boundary:

- `QM5_20029_wti-monfri-daily` trades both weekday directions year-round and
  has no physical-season agreement gate.
- unconditional WTI seasonal builds carry multi-week or monthly exposure
  rather than one signed weekday session;
- WTI weekday/trend builds condition on a completed price-trend state rather
  than a fixed physical-season direction;
- `QM5_20222_wti-seas-sign` is a monthly return-sign concordance rule; and
- `QM5_12567_cum-rsi2-commodity` is a two-day oscillator pullback.

The fixed season map, signed weekday map, genuine prior-day sequence, entry
grace, and one-session lifecycle are jointly load-bearing. Removing the
season gate recreates the year-round weekday parent; removing the weekday
clock recreates a seasonal parent.

## Allocation And Commits

- Source packet, durable G0 decision, and canonical card:
  `361bbe4b1`.
- EA/magic registry rows and regenerated resolver: `9161fa896` (shared
  factory artifact commit).
- EA source/binary, SPEC, approved/build card copies, and fixed-risk set:
  `f9b8695a4`.
- Final Q02 status and this evidence: the commit containing this document.
- EA registry: `20226,wti-seas-dow`.
- Magic registry: `XTIUSD.DWX`, slot 0, magic `202260000`.
- Generated resolver: 15,500 rows, registry SHA-256
  `0312A317DCBB4EA03530D3FDB8DCB773651985A90899F6EB1B05F6F07987A359`.

## Q01 Evidence

- Canonical and approved card schema lints: PASS; no missing sections or
  prohibited-library hits.
- EA build authorization guard: PASS for EA ID 20226 and its directory.
- Seven-section SPEC validator: PASS.
- Magic-resolver strict-default and newline/hash regressions: PASS.
- P1 artifact validation: PASS; EA directory and EX5 are present.
- Strict MetaEditor compile: PASS, 0 errors and 0 warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260805_160700/QM5_20226_wti-seas-dow.compile.log`.
- Compile summary:
  `D:/QM/reports/compile/20260805_160700/summary.csv`.
- Strict V5 build check: PASS, 0 failures and 0 warnings:
  `D:/QM/reports/framework/21/build_check_20260805_160700.json`.
- P1 machine evidence:
  `D:/QM/reports/pipeline/QM5_20226/P1/P1_QM5_20226_result.json`.
- EX5 size: 369,956 bytes.

The build checker initially caught one direct `iTime` series call. The source
was corrected to the framework `QM_ReadBar` helper and the full strict build
check then passed. No exception annotation or performance waiver was used.

Artifact SHA-256 values after the Q02 status update:

| Artifact | SHA-256 |
|---|---|
| Source packet | `03CB63209CFE22F24A2712C81A0A485E9B7AA6B53F5E408F9344FA7BE5595FA7` |
| Canonical card | `4AEC504624B73CFD403D8226D2D6B857436F133E5976B9D7158CB0D5375B12C3` |
| Approved card | `4AEC504624B73CFD403D8226D2D6B857436F133E5976B9D7158CB0D5375B12C3` |
| MQ5 | `60BD25BB3B12364683A56E0D0F256E75E4EE05FC4FA386A2FD9053D7AD1E979C` |
| EX5 | `BCA0E9DD6E530618D6BB7F68C06046ECE7B84AD8876532128B22D2E243D03098` |
| SPEC | `289104C9B506073C94F9FC5E3D1A6F26C4A9F381BE23DD560016D813AC76E8CC` |
| Backtest set | `8B9AF3F30E1A2D61F16B5069EAFB1255C970D322B2BC0FDAE8E5A34031E692F1` |

## Paced Q02 Enqueue Evidence

The exact no-mutation dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_20226 --symbols XTIUSD.DWX --max-part2-per-run 0

It selected exactly one never-tested row, zero skipped rows, zero stranded
rows, and one priority-track item.

A read-only, exact-path process scan initially found six running factory
terminals against a binding ceiling of seven. Every subsequent apply attempt
rechecked only exact `D:\QM\mt5\T1..T10\terminal64.exe` paths and stopped
short of the ceiling. Initial one-shot attempts made no mutation because the
shared factory mutation lock was busy. The live holder was identified as a
normal terminal worker atomic-claim section; the lock was neither deleted nor
reaped.

At `2026-08-05T16:16:37Z`, the final bounded admission acquired the real
shared mutation lock, then found four factory terminals. While retaining that
lock it invoked the canonical one-shot apply:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20226 --symbols XTIUSD.DWX --max-part2-per-run 0

Apply reported one never-tested item enqueued, zero skipped, zero stranded,
and one priority-track item. Its machine evidence is
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` with `apply=true`,
target EA `QM5_20226`, and target symbol `XTIUSD.DWX`. The canonical
`farmctl.py work-items --ea QM5_20226` readback returned exactly the one Q02
work item recorded above.

## Safety Boundary

- No manual backtest or downstream phase was launched by this work.
- No live, demo, or shadow setfile or deploy artifact was created.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- No terminal was started, stopped, reserved, reaped, or altered.
- The real shared mutation lock remained held for the queue write; it was not
  deleted or stale-reaped.
- Capacity scans used only exact `D:\QM\mt5\T1..T10\terminal64.exe` paths;
  T_Live and unrelated terminals were excluded.
