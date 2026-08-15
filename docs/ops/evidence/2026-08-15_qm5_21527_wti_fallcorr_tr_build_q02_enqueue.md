# QM5_21527 WTI Falling-Correlation Trend Build And Q02 Enqueue

Date: 2026-08-15 (Europe/Berlin)

Branch: `agents/board-advisor`

Status: Q01 PASS; exactly one XTIUSD.DWX D1 Q02 item enqueued and initially
pending

## Outcome

`QM5_21527_wti-fallcorr-tr` mechanizes one new structural, low-frequency WTI
candidate. On each genuine broker-month transition it follows the sign of
WTI's exact twelve-completed-month log return only when the absolute Pearson
correlation of WTI and SP500 returns is strictly lower in the newest
63-return block than in the immediately preceding disjoint 63-return block.

The host and only traded symbol is `XTIUSD.DWX` D1, slot 0, magic
`215270000`. `SP500.DWX` is a read-only factor with no magic or order path.
The candidate is directionally symmetric, consumes each monthly attempt
before fallible signal and execution gates, closes before monthly
replacement or after forty calendar days, and uses a frozen
`3.5 * ATR(20,D1)` hard stop with no target.

The Q02 contract is `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
`PORTFOLIO_WEIGHT=1`. No live, demo, shadow, stress, or optimization setfile
was created.

## Source And Non-Duplicate Boundary

The governed composite packet is
`strategy-seeds/sources/MOP-SILV-WTI-FALLCORR-2026/source.md`. Moskowitz,
Ooi, and Pedersen (2012) supply WTI membership, the twelve-month own-return
sign, and monthly cadence. Silvennoinen and Thorp (2013) establish that
WTI/equity correlation is time-varying and that higher integration can
weaken diversification.

Neither paper tests the exact two-block falling-correlation filter, raw D1
Pearson proxy, Darwinex CFDs, fixed-dollar risk, ATR stop, trade density,
costs, profitability, or QM portfolio. The conjunction is a new QM
falsification and transfers no source performance claim.

The approved card records a canonical CLEAN scan across 4,499 EA-registry
rows and 595 root cards. Manual family review separates the candidate from:

- `QM5_21516`, which uses one WTI/XNG correlation block and a fixed absolute
  ceiling;
- `QM5_21522`, which compares two 252-return SP500 downside-beta slopes;
- `QM5_21523`, which gates WTI on opposite twelve-month WTI/gold signs;
- `QM5_13203`, which ranks and trades an XTI/XNG two-leg package;
- unconditional WTI time-series momentum; and
- `QM5_12567`, the incumbent short-horizon, long-only XNG RSI pullback.

## Allocation And Commit Chain

- Source approval and governed packet: `0b95083c3`.
- G0 decision, canonical/approved cards, and EA-ID allocation: `9fea633da`.
- Active slot-0 magic and regenerated resolver: `bfd8b00ce`.
- EA source/binary, SPEC, reference suite, fixed-risk setfile, and Q01 state:
  `0745d0572`.

The registry binds EA ID 21527 and slug `wti-fallcorr-tr` to active magic
`215270000` on `XTIUSD.DWX`. The resolver contains the allocation among
15,996 active registry rows.

## Q01 Evidence

- G0 lint: PASS, with no missing sections.
- Card-v2 schema lint: PASS for canonical, approved, and build-time card
  copies, with no prohibited-model hits.
- Approved-card build preflight: PASS for EA ID, EA directory, and magic
  registry prerequisites.
- Mandatory SPEC validation: PASS.
- Independent formula suite: 7 tests PASS. Coverage includes exact
  twelve-month endpoints, chronological newest-offset mapping, disjoint
  return blocks, block-local means, sample-Pearson equivalence, strict
  absolute-decline/sign boundaries, zero-variance rejection, and independence
  of the preceding block from recent data.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Targeted V5 build check: PASS, zero failures and zero warnings.
- P1 artifact validation: PASS; EA directory and compiled `.ex5` present.
- Compiled binary size: 390,786 bytes.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260815_131955/QM5_21527_wti-fallcorr-tr.compile.log`.
- Compile summary: `D:/QM/reports/compile/20260815_131955/summary.csv`.
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260815_131955.json`.
- P1 result:
  `D:/QM/reports/pipeline/QM5_21527/P1/P1_QM5_21527_result.json`.

Artifact SHA-256 values at enqueue sealing:

| Artifact | SHA-256 |
|---|---|
| Source packet | `D65315B572E4E5B3004F348CB311BEAE31D8215B7CAFE5AF4567232953C4655E` |
| Source approval | `A97D227CB873E65F01580DDECEF4F0B1ED67ABAA37157B1206500C97AFA8BD62` |
| G0 decision | `A734FE1BB74E70955BEA49AAFE5B39A4C7A3499B23E8E020215A01B8B59307D6` |
| Canonical/approved/build card | `AF1B13E888ED56923E327086769B8637A7D724FA98752AD3B65DB1D97442A8DA` |
| MQ5 | `310A76FCC2F24793367395B019B52E96D2D70649A511D804D011DBFA204E30D3` |
| EX5 | `ACB704803263F612443A7DA86A60620F774160D2A4E1130C685A8236501D0A5C` |
| SPEC | `FAF8BA73B8A68B01FE8F835099C1C48FB8CA7C007EE8431DCCC9EE60D00E7B44` |
| Reference suite | `369B454136E09A42E06B16C66E6DDF8F35C72CC1AC6A8241EF7B55B6A5468EBF` |
| Backtest set | `6F8671D60403D4E29333ED7901152183390D8F3D882076DCC84D4E918812CE2F` |
| Magic resolver | `8ECCED0D3412053853E42CF6B3A970168F723C750AC8966DF6237BBD7F448D6E` |

## Q02 Capacity And Enqueue Evidence

The exact scoped dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_21527 --symbols XTIUSD.DWX --max-part2-per-run 0

It reported `APPLY=False`, one selected never-tested item, zero scoped skips,
zero stranded retries, zero deferred promotions, and one priority-track item.

The read-only path-anchored slot scan immediately before enqueue found one
running factory terminal, T4, below the binding seven-terminal backtest CPU
ceiling. `T_Live` and one unrelated FTMO terminal were visible as non-factory
processes only and were not touched. The queue held 1,008 pending rows against
the separate 7,000-row ceiling, leaving a 5,992-item wave budget.

The exact apply command was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_21527 --symbols XTIUSD.DWX --max-part2-per-run 0

It inserted exactly one never-tested item and no retry or deferred item.
Direct read-only SQLite verification immediately afterward found:

| Field | Value |
|---|---|
| Work item | `4ec8fc49-9460-47a1-a938-619b9d50251a` |
| Phase / kind | `Q02` / `backtest` |
| Symbol | `XTIUSD.DWX` |
| Setfile | canonical `QM5_21527_wti-fallcorr-tr_XTIUSD.DWX_D1_backtest.set` |
| Status at verification | `pending` |
| Attempt count | `0` |
| Claimed by | none |
| Created UTC | `2026-08-15T13:24:34+00:00` |
| Priority track | `true` |

The helper's shared sweep evidence was
`D:/QM/reports/state/claude_sweep_enqueue_2026-06-10.json` at verification.
No dispatch command, phase runner, smoke test, or manual MT5 tester run was
issued.

## Safety Boundary

- No tester, terminal, worker, or process was started, stopped, reserved,
  reaped, or altered by this work.
- No `T_Live` file or process was accessed beyond its read-only identity in
  the fleet slot scan.
- AutoTrading was not toggled.
- The portfolio gate and T_Live manifest were not touched.
- Q02 enqueue is not certification, profitability evidence, portfolio
  decorrelation evidence, admission, or live-use authorization.
