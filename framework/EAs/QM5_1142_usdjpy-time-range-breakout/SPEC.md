# QM5_1142_usdjpy-time-range-breakout - Strategy Spec

**EA ID:** QM5_1142  
**Slug:** usdjpy-time-range-breakout  
**Card of record:** `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1142_usdjpy-time-range-breakout.md`  
**Source:** Crabel (1990) opening-range breakout and Fisher (2002) ACD range mechanics  
**Last revised:** 2026-07-13

---

## 1. Strategy Logic

### Approved Baseline

The approved baseline trades a two-sided USDJPY opening-range breakout on M30.
It records the broker-time range beginning at 22:00 for 240 minutes, then places
OCO stop entries five points beyond the completed range. A filled side cancels
the opposite pending order. Friday entries are disabled and the framework's
Friday close remains enabled.

The baseline requires the completed range to be between 0.5 and 3.0 times
ATR(14). Initial stop distance is 2.0 ATR. The default target is disabled and
open positions are time-exited no later than 22:00 broker time.

### FTMO Research Variant

`sets/QM5_1142_usdjpy-time-range-breakout_USDJPY.DWX_M30_ftmo_research.set`
is an OWNER diagnostic variant, not an approved baseline set. It changes the
range to 03:00-06:00 broker time, extends the hold horizon to the 22:00 exit,
and disables the range/ATR and news-hour filters. These changes are outside the
approved card.

Status: **RESEARCH_ONLY / NO DEPLOY**. The machine-readable candidate evidence
also labels this exact parameter lineage research-only:
`artifacts/ftmo_1142_usdjpy_candidate_spec_2026-07-12.json`.

Promotion requires a separately approved card amendment, a frozen set hash,
fresh current-binary Q02-Q10 evidence, FTMO cost reconciliation, joint floating
MAE analysis, and a signed deploy manifest.

## 2. Parameters

| Parameter | Baseline |
|---|---:|
| Symbol | `USDJPY.DWX` |
| Timeframe | `M30` |
| Range start | `22:00` broker time |
| Range duration | `240` minutes |
| Maximum hold | `480` minutes |
| Daily exit | `22:00` broker time |
| ATR period | `14` |
| Stop | `2.0 ATR` |
| Target | disabled (`0.0 ATR`) |
| Range/ATR filter | `0.5` to `3.0` |
| Breakout buffer | `5` points |
| Maximum spread | `30` points |
| Friday entries | disabled |

Backtests use `RISK_FIXED=1000`. A future live set must use the environment's
approved percentage-risk contract and must not reuse a backtest set.

## 3. Symbol Universe

The approved baseline universe is `USDJPY.DWX` only. The pre-existing broad
matrix set inventory is not card coverage and is not deployment authority.

## 4. Timeframe

The execution timeframe is `M30`. ATR and range construction also use closed
M30 data. The daily windows are interpreted in broker time.

## 5. Expected Behaviour

- At most one filled position per symbol and magic.
- At most one OCO order pair per completed daily range.
- Typical holding period is intraday; all positions are bounded by the daily
  exit and framework Friday close.
- The FTMO diagnostic variant is expected to trade more often than the approved
  baseline but has no approved frequency or profitability claim.

## 6. Source Citation

- Toby Crabel, *Day Trading with Short Term Price Patterns and Opening Range
  Breakout*, Traders Press, 1990, ISBN 9780934380171.
- Mark Fisher, *The Logical Trader: Applying a Method to the Madness*, Wiley,
  2002.

The approved card is the source of record for the full bibliography and R1-R4
assessment.

## 7. Risk Model

| Environment | Mode | Contract |
|---|---|---|
| Q02-Q10 backtest | `RISK_FIXED` | `$1,000` nominal trade risk |
| FTMO research reconstruction | `RISK_FIXED` | simulator input only; no deploy right |
| Future approved runtime | `RISK_PERCENT` | portfolio allocation and account governor required |

## 8. Runtime Contract

- One position per symbol and magic; pending orders are OCO-managed.
- Entry and exit schedules use broker time as implemented by the EA.
- `QM_FrameworkInit()` owns registry, news, risk-mode, and kill-switch checks.
- The strategy must fail closed on invalid windows, invalid ATR, excessive
  spread, conflicting long/short flags, or an unavailable risk size.

## 9. R1-R4

| Gate | Baseline | FTMO research variant |
|---|---|---|
| R1 documented family | PASS | inherited concept only |
| R2 mechanical | PASS | deterministic but unapproved delta |
| R3 data available | PASS | PASS |
| R4 no ML | PASS | PASS |
| Deploy authorization | card-approved baseline only | **NO** |

## Revision History

| Version | Date | Reason |
|---|---|---|
| v1 | 2026-05-17 | Approved USDJPY M30 baseline card and implementation. |
| v1.1 | 2026-07-12 | OWNER diagnostic 03:00-06:00 FTMO research set created; no card promotion. |
| v1.2 | 2026-07-13 | Baseline and research lineage documented fail-closed. |
