# QM5_20204 XNG one-month TSMOM build and Q02 handoff

Date: 2026-08-02 (Europe/Berlin)

Branch: `agents/board-advisor`

EA: `QM5_20204_xng-tsmom1m`

Strategy ID: `MOP-TSMOM-2012_XNG_S11`

## Outcome

One new low-frequency structural energy candidate was researched, approved,
allocated, implemented, and passed through Q01. It trades `XNGUSD.DWX` in the
direction of the latest completed broker-calendar-month return and renews at
the next month boundary. The build is ready for one Q02 baseline item.

Q02 was not enqueued. A scoped dry run selected exactly one never-tested item,
but two apply attempts safely made no change because the global factory
mutation lock was busy. Immediately before the next supported apply attempt,
the required path-anchored capacity scan reached the hard limit of seven
factory terminals. The command exited before invoking the queue writer, as
required by the mission stop condition. A prior read-only query returned zero
work items for `QM5_20204`.

## Source and frozen mechanic

The governed complete-read packet is
`strategy-seeds/sources/MOP-TSMOM-2012/source.md`. Its primary source is
Moskowitz, Ooi, and Pedersen (2012), "Time Series Momentum," *Journal of
Financial Economics* 104(2), 228-250, DOI
`10.1016/j.jfineco.2011.11.003`. The source supports a
one-month-lookback/one-month-hold same-sign commodity-futures family and lists
natural gas in the source universe. It does not establish profitability for
this single Darwinex CFD translation or realized portfolio decorrelation.

- Exact route: `XNGUSD.DWX`, D1, magic slot 0 (`202040000`).
- Decision: first tradable D1 bar of each genuine broker month.
- Signal: sign of the log return between the latest two consecutive completed
  broker-month closes; equality or invalid history stays flat.
- Entry: one symmetric long or short position, one persisted attempt per
  month, no intramonth retry after a flat state, stop, rejection, or restart.
- Exit: next broker-month boundary, 40-calendar-day stale repair, or broker
  hard stop.
- Risk: `RISK_FIXED=1000`, `RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen
  `3.5 * ATR(20,D1)` hard stop, no take-profit.
- Both news axes and Friday close are OFF; no live/demo/shadow setfile exists.

## Non-duplicate boundary

The pre-allocation exact dedup check found no exact slug or strategy-ID match.
Manual review resolved the fuzzy family siblings:

- certified `QM5_12567` is a long-only two-day RSI pullback above SMA(200),
  normally held no more than five D1 bars;
- `QM5_20063` uses a 63-D1 XNG trend state;
- `QM5_12804` uses a 252-D1 XNG trend plus ATR/price corridor;
- `QM5_20054` uses the same one-month information with the opposite,
  contrarian sign under a different source;
- `QM5_20187` uses the same source horizon on WTI; and
- `QM5_20051` is an XTI/XNG cross-sectional pair.

The new carrier is therefore a distinct slow, symmetric completed-month XNG
trend mechanic. Distinct logic is not proof of low correlation; downstream
portfolio gates remain authoritative.

## Allocation and Q01 evidence

- G0/source/card commit: `6754b4764`.
- Active EA registry row: `20204,xng-tsmom1m`.
- Active magic route: `20204 / slot 0 / XNGUSD.DWX / 202040000`.
- Candidate build guard: PASS.
- Strategy-card schema lint: PASS, no missing section or ML hit.
- G0 lint: PASS.
- Strategy SPEC validation: PASS.
- Strict MetaEditor compile log:
  `framework/build/compile/20260802_223307/QM5_20204_xng-tsmom1m.compile.log` --
  PASS, zero errors, zero warnings.
- Full strict build report:
  `D:/QM/reports/framework/21/build_check_20260802_223307.json` -- PASS, zero
  failures, zero warnings.
- Setfile embedded build hash:
  `8ddc6b5d21b7b87477d6225227d16bf3a39c06245fde4b39184b64d43941bd08`.

| Artifact | SHA-256 |
|---|---|
| MQ5 | `B899FE6C4F362CACF3F761553FDE76AD9863882091497E70C65205322BCE20FE` |
| EX5 | `385F519B75375DAA118A7F47828C697F9104CD2B21DC137C716C44F4F1081A40` |
| SPEC | `3FD6CAFFB482B9219604777878C3D964118B5963CFF33566524CACAC9A74705B` |
| Backtest setfile | `5232AFD4735ED54297291A9CAE38D777652ECA0FDE69E8E436D69169A604B3DA` |
| Raw and approved cards | `F616FA65CF51902B83B69AC2741D61348FA7D89F63516524A9485A55B64E6AFE` |
| Source packet | `D7F4537D15DDFC5D9C04C7E9769CDDD73BE49702CE2C0F948457879F4A8EC56E` |

The normal resolver generator failed closed because three pre-existing active
registry IDs have no materialized EA directory. The resolver was regenerated
with its documented non-dropping `--keep-obsolete` preservation mode. CSV and
resolver hashes matched at generation, and the resulting lookup contains EA
20204 and magic 202040000. No legacy row was dropped.

## Q02 capacity stop

The dry run was restricted to `QM5_20204`, `XNGUSD.DWX`, and zero stranded
part-2 retries. It selected one part-1 never-tested item, zero part-2 items,
and zero deferred promotions.

The capacity checks counted only `terminal64.exe` processes whose executable
path matched `D:/QM/mt5/T1` through `T10`; `T_Live` was explicitly excluded.
The first apply observation was 6/7 and the second was 5/7, but both canonical
apply calls returned `factory mutation lock busy` without changing state. The
next pre-apply observation was 7/7, so the wrapper exited with code 42 before
calling the canonical enqueue script. No terminal was launched, dispatched,
reserved, stopped, or otherwise controlled.

When capacity is later below seven, the next operator should first confirm
that `farmctl.py work-items --ea QM5_20204` still returns no row, then run the
same one-EA/one-symbol dry run and apply through the global mutation lock.

## Safety boundary

No Q02 result, profitability, neutrality, decorrelation, portfolio admission,
or certification is claimed. No portfolio gate, T_Live manifest, deploy
manifest, live setfile, `T_Live` state, or AutoTrading setting was touched.
