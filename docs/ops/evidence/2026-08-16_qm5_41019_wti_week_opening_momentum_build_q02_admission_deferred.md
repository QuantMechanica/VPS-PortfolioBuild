# QM5_41019 WTI Week-Opening Momentum - Build And Q02 Admission Evidence

Date: 2026-08-16 (Europe/Berlin; factory timestamps below are UTC)

Branch: `agents/board-advisor`

## Outcome

One new structural, low-frequency commodity sleeve was researched, approved,
allocated, built, and validated:

- EA: `QM5_41019_wti-wopen-mom`
- strategy ID: `MOP-WTI-WOPEN-MOM-2026_S01`
- symbol / timeframe: `XTIUSD.DWX` / D1
- magic slot / magic: `0` / `410190000`
- Q02 risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`
- Q01: `PASS`
- Q02: `PENDING; not enqueued`

The target-only Q02 dry run selected exactly one admissible never-tested item.
The canonical apply path did not insert it because another operator asserted
the governed `FACTORY_OFF.flag` before the helper's commit boundary. No raw
database insert or factory-state bypass was attempted.

## Locked Edge

On an exact broker-clock Wednesday, the EA consumes one durable date attempt
and follows the sign of the completed WTI return from prior Friday close to
Tuesday close. It requires the completed session sequence Tuesday, Monday,
prior Friday; buys a positive return, sells a negative return, and consumes
zero or invalid history flat. The position uses a frozen `3.5 * ATR(20,D1)`
hard stop and the framework Friday close at broker hour 21.

Factory energy D1 history can label a session with the preceding calendar
date. The implementation therefore uses broker time for the Wednesday and
attempt date, supports native same-day labels, and applies one uniform +1-day
normalization to the current and three completed labels only when the current
label is 24-48 hours behind broker time. It never shifts a holiday or
substitutes a missing session. The deterministic reference suite covers both
label conventions.

This is a WTI weekly structural return stream outside the certified XAU,
SP500, NDX, and XNG carriers. Carrier and mechanic differences do not prove
realized decorrelation; Q09 alone may do that.

## Source And Non-Duplicate Evidence

The governed packet is
`strategy-seeds/sources/MOP-WTI-WOPEN-MOM-2026/source.md`. Its parent is
Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The complete-paper review and PDF SHA-256 are
recorded in `strategy-seeds/sources/MOP-TSMOM-2012/source.md`. The paper
includes NYMEX WTI but does not test this weekly CFD package; that translation
is explicit.

The canonical pre-card checker scanned 4,506 EA-registry rows and 602 root
cards and returned `CLEAN`, with no exact or fuzzy match. Manual review
separated `QM5_41013`, `QM5_12965`, `QM5_13049`, `QM5_20154`, `QM5_20217`,
and `QM5_12567`. The fixed Friday-to-Tuesday sign, Wednesday entry, and Friday
close are not owned by those mechanics.

## Q01 Validation

- deterministic build prerequisite guard: `PASS`;
- strict compile: `PASS`, 0 errors, 0 warnings;
- compiler log:
  `C:/QM/repo/framework/build/compile/20260816_021303/QM5_41019_wti-wopen-mom.compile.log`;
- strict targeted build check: `PASS`, 0 failures, 0 warnings;
- build report:
  `D:/QM/reports/framework/21/build_check_20260816_022133.json`;
- Strategy Card schema/ML lint: `PASS` on canonical and approved copies;
- deterministic mechanic reference suite: eight tests, all `PASS`;
- generated resolver: 15,976 rows, zero dropped, registry SHA-256
  `FA28A1623231D1C18F7FB3705C7289FA75741E73886ED929B2011C2D35624882`;
- EX5 size: 381,878 bytes.

The repository-wide registry validator has pre-existing global legacy debt.
No unrelated registry cleanup was attempted. The target guard, magic row,
resolver dry run, strict compile, strict build check, and card lints accepted
EA 41019. The newer execution-contract linter is not applicable because EA
41019 has no entry in the separate Card-v2 execution-contract registry.

## Commit Chain

| Commit | Purpose |
|---|---|
| `e6bc3ffff763d8115d6cc532b06e56cdcdea6b8f` | approve the governed source intake |
| `5195e90f20b7de5b3495e66b9bc9c9b670d674b5` | approve the card and allocate EA 41019 |
| `afddde243cfa50b22c7a8d32b457c80754c01e7c` | register magic, build, compile, test, and seal Q01 |

## Artifact SHA-256 Values

| Artifact | SHA-256 |
|---|---|
| Governed source packet | `50750E1323DD1D33FC4EDE52E15A9853EAE602B9115F664C47A760A6B16CCA30` |
| Canonical / approved / build card | `0ED59BEA92AE95ADFB5EB9431BF6B738EFCCC63C8FF0661A1DA4FFDD8FE0455A` |
| MQ5 | `08E3C63A9F6CDECCB0D44854BF58D06AC34D75751FC582F944C9BEBB8AF589DF` |
| EX5 | `DB0352D6922E815337AD6FC36CF5265E2F02DDA0480B31522474B07D87E05383` |
| SPEC | `E2DCF7DCB4DFF2285C9D06F82A057B157696C1CD5C7F52A0DC34AFB72D858610` |
| Reference suite | `99F6DD35F4FC27A45866A51E2C298ECA349FD79DDD0C3B5F07EF4D01D62E0F52` |
| Backtest set | `39FC3C32C5CBC25214E7BCE171AD198B1EDBA59BB1AF9134EDE1B6BD92CADC4D` |

The three card copies were byte-identical when these hashes were recorded.

## Q02 Admission Evidence

The target-only dry run was:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41019 --symbols XTIUSD.DWX --max-part2-per-run 0

Its scoped receipt selected one priority-track, never-tested
`XTIUSD.DWX`/D1 item, with zero skips, retries, or deferred promotions. At the
receipt sample the pending queue was 980 against the soft ceiling of 7,000.

Read-only terminal samples found one factory terminal at
`2026-08-16T02:24:42+00:00` and zero at
`2026-08-16T02:32:15+00:00`, below the governed seven-terminal CPU ceiling.
`T_Live` and a separate FTMO terminal were visible but were not factory slots
and were not touched.

The exact apply command was attempted through the same helper:

    python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_41019 --symbols XTIUSD.DWX --max-part2-per-run 0

The first invocation was refused because the shared mutation lock was briefly
busy. The idempotent retry acquired the lock but returned:

    {"skipped": "FACTORY_OFF.flag set before commit", "flag": "D:\\QM\\strategy_farm\\state\\FACTORY_OFF.flag"}

Read-only verification after that return found zero work items for
`QM5_41019`. The flag was asserted by another active
`tools/strategy_farm/Factory_OFF.ps1 -NoPause` session and remained
`OFF_IN_PROGRESS`; it was not removed or bypassed. Therefore there is no Q02
work-item ID and the Strategy Card correctly remains `q02_status: PENDING`.

Two exploratory `--help` calls were interpreted by this legacy helper as
non-applying dry runs because it has no help parser. They carried no
`--apply`, inserted no work items, and did not start a tester. Their processes
were left to exit under the concurrent Factory-OFF procedure; no manual
process kill was performed.

## Safe Resume Command

Only after an authorized operator restores the factory and the flag is
absent, rerun the target-only dry run, confirm the terminal CPU ceiling is not
binding, then run the exact apply command above once. Verify one pending Q02
row with attempt count zero. Do not dispatch it manually.

## Safety Boundary

- No manual backtest, phase runner, dispatch tick, terminal reservation,
  tester launch, process kill, factory-lock bypass, or raw DB mutation was
  performed.
- No terminal was started, stopped, reserved, reaped, or altered.
- AutoTrading was not toggled.
- Neither the portfolio gate nor the `T_Live` manifest was touched.
- Q01 PASS is not a Q02 verdict, certification, profitability result,
  realized-decorrelation result, portfolio admission, or live authorization.
