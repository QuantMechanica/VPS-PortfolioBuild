# QM5_20117 WTI Friday Lag Reversal — Build And CPU-Ceiling Stop

Date: 2026-07-24
Branch: `agents/board-advisor`

## Scope

One new low-frequency WTI conditional-seasonality carrier was extracted from
the fully reviewed Meek and Hoelscher (2023) paper. On the first executable
broker-Friday D1 tick it sells `XTIUSD.DWX` only when the completed Thursday
log return versus Wednesday is at least 4.5%, then closes before the weekend.

Table 2 reports positive WTI Friday coefficients but negative, statistically
significant one-day lag coefficients in all five models. Dividing the Friday
coefficient by the absolute lag coefficient gives Thursday-return break-even
points from 3.19% to 4.27%; the fixed 4.5% threshold is above all five. The
fitted conditional Friday mean at that threshold is only about -0.8 to -4.3
basis points before costs. Q02 is therefore a strict falsification test, not a
profitability or decorrelation claim.

## Source, card, and duplicate evidence

- Strategy ID: `MEEK-HOELSCHER-WTI-DOW-2023_S05`.
- Primary source: Meek, Andrew C. and Hoelscher, Seth A. (2023),
  "Day-of-the-week effect: Petroleum and petroleum products," *Cogent
  Economics & Finance* 11(1), DOI
  `10.1080/23322039.2023.2213876`.
- Complete open source pointer:
  `https://www.econstor.eu/bitstream/10419/304091/1/10.1080_23322039.2023.2213876.pdf`.
- The deterministic check found no exact slug or strategy-ID duplicate. Its
  single fuzzy result was the expected `xng-thu-tue` source-family sibling;
  manual review returned `CLEAN / SOURCE_FAMILY_SIBLING`.
- `QM5_12753_wti-thu-pb-fri-bounce` buys Friday after a Thursday decline;
  QM5_20117 sells after a much rarer Thursday surge.
- `QM5_12597_wti-fri-prem` buys Friday unconditionally, and
  `QM5_20110_xti-xng-fri-rv` is a jointly managed long-XTI/short-XNG package
  without the Thursday-return state.
- Strategy-card schema lint: PASS, no missing sections or prohibited-ML hits.
- G0 card lint: PASS, no missing contract fields.

## Build evidence

- EA ID and slug: `QM5_20117_wti-fri-lagrev`.
- Magic: `201170000`, slot 0, `XTIUSD.DWX`.
- Build prerequisite guard: PASS.
- SPEC validator: PASS.
- Symbol-scope validator: PASS, `SINGLE_SYMBOL_OK`.
- Build guardrails: PASS, zero findings.
- Framework build check: PASS, 0 failures, 0 warnings.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile log:
  `C:\QM\repo\framework\build\compile\20260724_192650\QM5_20117_wti-fri-lagrev.compile.log`.
- Build-check report:
  `D:\QM\reports\framework\21\build_check_20260724_192650.json`.
- Branch artifact commit: `d0259ef1c`.
- MQ5 SHA256:
  `FCB9DC83B1C3F745A4832E94A88609A4B308D0BED98580A1D83D44229BBF41CD`.
- EX5 SHA256:
  `4FB4A879DD890AEE34ED4E0886B02DB31252600EE9EBE1A18E53B9EF080E8242`.
- Backtest setfile SHA256:
  `B22C2FB87401E27AE0E3CDEDF93414335FE7B910BCA88B07144566CA45FD6675`.
- Setfile-declared build hash:
  `FCB9DC83B1C3F745A4832E94A88609A4B308D0BED98580A1D83D44229BBF41CD`.
- Backtest risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

The generated resolver contains EA 20117 and magic `201170000`. The standard
resolver generator still reports the pre-existing missing legacy EA
directories 1001, 1015, and 1016; the scoped QM5_20117 guards pass.

## CPU-ceiling stop

At `2026-07-24T19:27:25+00:00`, the required pre-enqueue MT5 process scan
showed exactly seven active factory terminals:

`T1`, `T2`, `T3`, `T6`, `T7`, `T8`, and `T9`.

That is the paced seven-factory-terminal ceiling. The separate `T_Live`
process was excluded and was not touched. Per the mission stop condition, no
Q02 row was inserted and no tester was dispatched. A post-check returned zero
work items for `QM5_20117`.

Q02 remains pending until a later operator observes capacity below the ceiling
and performs one target-scoped enqueue.

## Safety boundary

No live setfile, `T_Live` access, AutoTrading action, deploy/T_Live manifest,
portfolio manifest, portfolio admission, portfolio-gate edit, manual
backtest, terminal mutation, or correlation waiver occurred.
