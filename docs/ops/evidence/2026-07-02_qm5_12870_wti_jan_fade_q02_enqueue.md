# QM5_12870 WTI January Fade Q02 Enqueue

Date: 2026-07-02
Branch: agents/board-advisor
Farm task: `984cdf19-838d-4df1-ab26-77a76f0fb087`
EA: `QM5_12870_wti-jan-fade`

## Scope

Advanced the approved WTI January calendar-fade card into Q02 without touching
the portfolio gate, deploy manifests, `T_Live`, or AutoTrading.

## Verification

- `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_12870_wti-jan-fade`
  - PASS
- `pwsh -File framework/scripts/build_check.ps1 -EALabel QM5_12870_wti-jan-fade`
  - PASS, compile errors 0, warnings 16 framework-level DWX advisories
- Existing smoke report:
  - `D:\QM\reports\smoke\QM5_12870\20260702_042254\summary.json`
  - wrapper result `FAIL / MIN_TRADES_NOT_MET` because it enforced a 5-trade
    floor on a low-frequency D1 January-only card
  - valid reports `run_03` and `run_04` each generated 1 closed `XTIUSD.DWX`
    trade in 2024, so this is nonzero trade-generation, not a zero-trade build

## Farm DB Update

Recorded build result:

- `D:\QM\strategy_farm\artifacts\builds\984cdf19-838d-4df1-ab26-77a76f0fb087.json`

Q02 work item created:

- Work item: `329969a7-9e22-4ffa-ab47-09061fdef227`
- Phase: `Q02`
- Symbol: `XTIUSD.DWX`
- Timeframe: `D1`
- Status at enqueue: `pending`
- Setfile: `C:\QM\repo\framework\EAs\QM5_12870_wti-jan-fade\sets\QM5_12870_wti-jan-fade_XTIUSD.DWX_D1_backtest.set`

