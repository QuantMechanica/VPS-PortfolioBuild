# QM5_20170 WTI Wednesday Bear-Regime Build and Q02 Enqueue

Date: 2026-07-26
Branch: `agents/board-advisor`

## Edge and non-duplicate decision

`QM5_20170_wti-wed-bear` buys the genuine Wednesday WTI D1 session only
when the completed 252-D1 own return is negative, with a next-D1 exit and a
frozen ATR hard stop. It differs from `QM5_20154_wti-wed-trend` by regime sign
and from `QM5_20169_wti-thu-bear` by weekday. It is a direct crude-oil calendar
and slow-state interaction, not an index, metal, XNG, RSI, or ML rule.

Source lineage:

- Li, Zhu, Wen, and Nor (2022), governed at
  `strategy-seeds/sources/LI-WTI-DOW-2022.md`
- Moskowitz, Ooi, and Pedersen (2012), governed at
  `strategy-seeds/sources/MOP-TSMOM-2012/source.md`
- Approved composite packet:
  `strategy-seeds/sources/LI-MOP-WTI-WEDBEAR-2026/source.md`

## Deterministic verification

- Card schema/ML lint: PASS; zero ML hits and zero missing sections.
- Magic allocation: EA 20170, slot 0, `XTIUSD.DWX`, magic `201700000`.
- Magic resolver regenerated after the EA directory existed; the new row is
  present. The regenerator also reported three pre-existing missing-directory
  warnings for IDs 1001, 1015, and 1016; none concerns this build.
- Strict compile: PASS, zero errors, zero warnings.
- Build check: PASS, zero failures, zero warnings.
- Compile log:
  `C:/QM/repo/framework/build/compile/20260726_050445/QM5_20170_wti-wed-bear.compile.log`
- Build-check report:
  `D:/QM/reports/framework/21/build_check_20260726_050445.json`
- EX5 SHA256:
  `4330A28650700F4018FF13BDE91EBA5792D79C97AC71D587B2150D174FC4155D`
- Backtest setfile locks `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`, environment `backtest`.

## Q02 enqueue

Command:

`python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20170 --queue-ceiling 10000 --max-part2-per-run 0`

Result: exactly one new pending Q02 work item, with no unrelated stranded
retries:

- Work item: `ee4a09fb-df2f-4457-ae47-e74c51391eef`
- EA: `QM5_20170`
- Symbol: `XTIUSD.DWX`
- Timeframe: `D1`
- Status at enqueue: `pending`
- Created UTC: `2026-07-26T05:05:25+00:00`

No manual backtest was run. No T_Live, AutoTrading, deploy manifest,
T_Live manifest, or portfolio-gate file was touched.
