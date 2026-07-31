# QM5_20185 WTI winter bearfade — build and Q02 enqueue

Date: 2026-07-31 (Europe/Berlin)

Branch: `agents/board-advisor`

## Outcome

`QM5_20185_wti-win-bearfade` is a new low-frequency direct-crude sleeve. On
the first tradable D1 bar of each broker week from November through May, it
buys `XTIUSD.DWX` only when the completed 252-D1 log return is negative. The
position has a frozen `3.0 * ATR(20)` stop, no target, framework Friday close
at broker hour 21, and a seven-day stale guard.

This is a distinct WTI calendar/state carrier relative to the certified
XAU/SP500/NDX/XNG exposures. It is not a profitability, decorrelation,
certification, or portfolio-admission claim; Q02 and the unchanged downstream
gates remain authoritative.

## Source and non-duplicate boundary

The governed composite packet is
`strategy-seeds/sources/BURAKOV-MOP-WTI-WINBEAR-2026/source.md`:

- Burakov, Freidin, and Solovyev (2018), *International Journal of Energy
  Economics and Policy* 8(2), supply the November-May WTI long regime.
- Moskowitz, Ooi, and Pedersen (2012), *Journal of Financial Economics*
  104(2), supply the completed trailing own-return state definition.

Both parent source packets were already completely reviewed and durably
approved. Fresh publisher/AQR URL routing returned
`PERMISSION_REQUIRED` / `DEFERRED:SOURCE_POLICY`; no blocked page content was
used. The conjunction is explicitly a QM hypothesis, not a source claim.

The deterministic pre-allocation dedup scan was CLEAN across 4,242 registry
rows and 377 cards. Manual resolution retained nearby but different carriers:
`QM5_20135` sells the negative state monthly, `QM5_20015` is an unconditional
winter long, `QM5_20046` maps season directly to direction, `QM5_12963` is a
short stretch fade, `QM5_20141`/`QM5_20182` are July-November shorts, and
`QM5_12603` follows the return sign year-round.

## Frozen baseline

- Symbol/timeframe: `XTIUSD.DWX`, D1.
- EA/magic: `QM5_20185`, slot 0, `201850000`.
- Entry: first D1 bar of a new Monday-anchored broker week, November-May,
  completed 252-D1 log return strictly below zero.
- Attempt ledger: consume the week before history, state, spread, news, stop,
  or order gates; no same-week retry.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`.
- Exit: Friday hour 21, older-week/out-of-season/wrong-side repair, seven-day
  stale guard, frozen broker stop, and framework kill switch.
- News axes: OFF. No parameter sweep, live setfile, external runtime feed,
  banned/ML indicator, grid, martingale, scale-in, or pyramiding.

## Q01 evidence

- Strategy-card schema lint: PASS, no missing sections and no ML hits.
- Exact G0 card lint: PASS.
- Seven-section SPEC validation: PASS.
- Candidate EA/registry/magic guard: PASS.
- Strict MetaEditor compile: PASS, zero errors and zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260731_121934/QM5_20185_wti-win-bearfade.compile.log`.
- Strict V5 build check: PASS, zero failures and zero warnings.
- Build report:
  `D:/QM/reports/framework/21/build_check_20260731_121933.json`.

The default resolver generator exposed the pre-existing missing-directory
condition for active IDs 1001, 1015, and 1016. Generation with
`--keep-obsolete` retained all 15,357 prior rows, added the one registered
QM5_20185 row, and dropped none. The global registry validator still reports
its large pre-existing legacy inventory; the candidate-scoped identity and
collision checks passed.

Q01 artifacts span two branch commits because the running pump made its
deterministic artifact auto-commit while validation was in progress:

- `8b396469ccf05f86a49800d6d13260fe17068003` — EX5, RISK_FIXED setfile,
  registries, and generated resolver.
- `f05e534f8705679f6ed0e3352168a95d509a7f5a` — source packet, card, SPEC,
  and MQ5 implementation.

## Artifact hashes

- MQ5 SHA-256:
  `7F0CEB3BE1C6D984EC9C5651C7FE7D4C3DA90A7BB89B13324D8622DF1C2D14B3`.
- EX5 SHA-256:
  `A1FF4BE8A81D8AB8A562E96AD2CDCA382F4789D14D789C6A4DFA51612BF72FE3`.
- Setfile SHA-256:
  `37AF78CC51A175B16D33218E41EEDAC05750BC5F483CC771A0CA55B5E3EAD0AC`.
- Setfile build hash:
  `2bb711cb92f3fa90b7a35c1c3e2631f83d01622b07e5588f2aa0c8385c9ab988`.
- Source packet SHA-256:
  `BC7915FB66DA4B87145712FEC21D37F8873A3F04E0B8EEE37397AFF5C23F656F`.
- Farm build result SHA-256:
  `B908DE60D6CE1F759B6974ED40394886632A63D9E152ACD09F11F7832E14EFB9`.
- Farm build-bound card SHA-256:
  `FBBCB7C293135E2718DA3A981B5B0026D2F4E280BCF15040566ABE2DEDC479B2`.
- Post-enqueue repository card SHA-256:
  `24CEBE628CA4AD97A8645AADDD62621FFE7A0EA5366C0A2206C0CEB0418C8B07`.
- Post-enqueue SPEC SHA-256:
  `9C920EC2FE6FFAF72AE06DFF49CBB7AEF83BFB082F66B02DF2A1D99499EA81D7`.

## Paced Q02 handoff

- Build task: `a821d229-d62f-4e66-83e6-e82a0aa8d667`, status `done`.
- Auto-enqueue: one item enqueued, zero skipped.
- Q02 work item: `7639ee30-e765-4211-b276-97a779730a90`.
- Symbol/timeframe: `XTIUSD.DWX` / D1.
- Created: `2026-07-31T12:28:32+00:00`.
- Handoff state: `active`, attempt 0, claimed by paced terminal T3, no verdict
  or evidence yet.

No manual tester or smoke backtest was launched. The immediate pre-enqueue
scan observed five factory terminals out of the seven-terminal ceiling, plus
the separate pre-existing T_Live process. The CPU ceiling was not hit; the
paced fleet claimed the new item after canonical enqueue.

## Safety boundary

No portfolio gate, T_Live file, T_Live manifest, deploy manifest, or live
setfile was changed. AutoTrading was not toggled. The T_Live process was
observed read-only only to exclude it from the factory terminal count.
