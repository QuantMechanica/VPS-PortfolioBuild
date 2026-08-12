# QM5_20051 Energy One-Month Momentum Build And Q02 Enqueue

- Date: 2026-07-23
- Branch: `agents/board-advisor`
- EA: `QM5_20051_energy-xmom1`
- Logical symbol: `QM5_20051_XTI_XNG_XMOM1_D1`
- Source: peer-reviewed Fuertes-Miffre-Rallis (2010) packet at `strategy-seeds/sources/FMR-MOMTS-2010/source.md`

## Decision

Build one monthly market-neutral energy package: rank XTI and XNG by the immediately completed broker-month return, buy the winner, short the loser, and hold to the next month. This differs from `QM5_13126` because it has no swap/carry agreement gate, from `QM5_12733` because that build uses 63-252 D1 lookbacks and a neutral band, and from `QM5_12567` because it is neither single-symbol nor RSI mean reversion.

## Validation

- Card schema lint: PASS; no missing sections or ML hits.
- Build preflight: approved card, EA ID 20051 and both magic rows PASS.
- Strict compile: PASS, 0 errors, 0 warnings.
- Build check: PASS, 0 failures, 0 warnings.
- Binary SHA256: `42E19400E4EFBCB2FCFE23414D479397916F78AE6A44250BFB2B09607E03DDDE`.
- RISK_FIXED logical-basket setfile hash: `07cda7f57b02e30a8d8214b1eedf55d08f509cc520eb4eeea0b73d55fd9eb25f`.
- Q02 work item: `448f4edd`, pending, attempt 0, one logical basket rather than physical-leg fanout.

The repository-wide registry validator continues to report extensive pre-existing legacy registry debt; the scoped skill guard and build checks for 20051 pass.

No backtest was started. No T_Live, AutoTrading, live setfile, deploy manifest, portfolio gate, or T_Live manifest was touched.
