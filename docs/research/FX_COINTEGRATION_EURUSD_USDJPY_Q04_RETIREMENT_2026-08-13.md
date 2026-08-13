# QM5_20196 EURUSD/USDJPY cointegration Q04 retirement

Date: 2026-08-13

Branch: `agents/board-advisor`

Status: existing scan pair advanced to terminal Q04 FAIL; no portfolio admission

## Outcome

The frozen sign-aware 66-pair FX scan remains fully mechanized. The
deterministic relationship audit at commit `a80493291` accounts for all 66
relationships, leaving no honest unbuilt pair for a new Card or EA. The two
requested anchors also have terminal logical-basket Q02 results rather than a
current initialization or history blocker:

- `QM5_12532_AUDNZD_COINTEGRATION_D1`: Q02 PASS, Q04 PASS, then Q05 FAIL.
- `QM5_12533_EURJPY_GBPJPY_COINTEGRATION_D1`: Q02 PASS, then Q04 FAIL.

Following the existing-card fallback, frozen scan rank 13,
`EURUSD.DWX` / `USDJPY.DWX`, was advanced through its already-created,
append-only Q04 retry as `QM5_20196_eurusd-jpy-coint`. This is a dedicated D1
two-leg basket with logical symbol
`QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1`.

The governed retry produced a terminal strategy FAIL. F1 and F2 generated zero
trades; F3 generated two trades with net PF `0.45976252434143694`. The pooled
cadence was 2 trades versus the low-frequency minimum of 15. The sleeve is
retired at Q04 without refit, rescue tuning, requeue, or portfolio admission.

## Selection and source boundary

The exact sign-aware scan was reproduced with
`analyze_cross_asset_v3.py --include-negative-hedges`. Rank 13 retained the
frozen evidence recorded in the approved Card:

| Pair | DEV net Sharpe | OOS net Sharpe | OOS return | OOS state changes | DEV beta | Half-life |
|---|---:|---:|---:|---:|---:|---:|
| EURUSD / USDJPY | 0.661899 | 0.686450 | 4.994192% | 20 | -0.505485905 | 87.404 D1 bars |

`QM5_20196` was selected instead of duplicating the recently prioritized rank
58 and rank 65 logical Q02 rows because it is higher-ranked, already has a
current-binary Q02 PASS, and had one governed Q04 infrastructure retry awaiting
terminal economic classification.

The approved Card cites Ernest P. Chan, *Quantitative Trading* (Wiley, 2009),
through the OWNER-ratified Tier-A `SRC02` extraction. That source supports the
structural OLS residual-reversion method, not profitability for this particular
pair. The implementation uses completed D1 prices, a fixed beta, residual
z-score thresholds, ATR-based structural risk controls, and a time stop. It
uses no ML, banned indicator, grid, martingale, averaging down, or external
data API.

## Build and risk validation

- Approved Card: `strategy-seeds/cards/approved/QM5_20196_eurusd-jpy-coint_card.md`;
  SHA-256 `d6f42538b40a717a02f923d380cb863cf9783c1a471e23118ff165ba14aa51fd`.
- Card schema lint: PASS; no missing sections and no ML hits.
- Strict build check: PASS with zero failures and zero warnings;
  `D:\QM\reports\framework\21\build_check_20260813_015323.json`, SHA-256
  `258479d14c1a54b906d87e4ee856d8a3aa9552db4e9f9a976a11bfa6d4ac2be4`.
- MQ5 SHA-256:
  `8de25f66c15be8e2fdd1791d5d22acff6dab2162ea96860dfb7c5d51d70815dd`.
- EX5 SHA-256:
  `b8b268676f8cd3e8312e1e30ea71abf65efc2e8970eb618c75db281ae7947bb2`.
- Basket manifest SHA-256:
  `5b36889e87a44fa2a2961d2cfda9696fd1531e487af9be3325a05d81da114a64`.
- Logical fixed-risk setfile SHA-256:
  `b2f3c239b82655f4a95d3756db2f68cdf31b93a33be7aef21c7d0dfad106abe3`.
- Risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.

The strict build validator refreshed only the `build_hash` metadata line in
the host and logical setfiles. Inputs, risk, symbols, timeframe, and trading
mechanics did not change. The completed retry is bound to the refreshed logical
setfile hash above.

## Funnel evidence

Canonical Q02 work item `a34c39c1-7ef6-43e2-b1b4-eb6a717271b2` remains DONE
PASS on the same EX5. Its cadence probe produced 36 trades, PF `0.91`, and net
profit `-324.38`; Q02 was not treated as an economic approval.

The preserved first Q04 work item
`e2dde9f5-0ec1-488c-af5c-e6a64dce6710` ended INFRA_FAIL because recovered
cold-cache attempts were graded as `BARS_ZERO/RUN_STATUS_INVALID`. Its
aggregate remains immutable at SHA-256
`8727c5050dc60c4de3e7ee8f2280e5e4423408e45ee0bc3b2acdfbdc691489b0`.

Append-only retry `6d420834-e8d0-481e-ae3d-806bddb17ec4` preserved that row
and used the current grader. All three folds produced valid completed reports:

| Fold | OOS year | Trades | Net PF | Verdict |
|---|---:|---:|---:|---|
| F1 | 2023 | 0 | n/a | `STRATEGY_ZERO_TRADES` |
| F2 | 2024 | 0 | n/a | `STRATEGY_ZERO_TRADES` |
| F3 | 2025 | 2 | 0.4597625243 | `STRATEGY_MIN_TRADES_NOT_MET` |

The terminal aggregate is
`D:\QM\reports\pipeline\QM5_20196\Q04\QM5_20196_EURUSD_USDJPY_COINTEGRATION_D1__6d420834-e8d0-481e-ae3d-806bddb17ec4\aggregate.json`,
SHA-256 `c1557e01549dea410e6ddb43dad33056d47df1da69d2d1901f1d2d003694d1cc`.
Its aggregate identity is
`2371737c70d6d5032b6be88419bca91e48d0b3e29c72f00d096a9bf3584b5cd0`.

## Paced execution and safety

The paced launch maximum was one and the pre-launch factory count was zero. A
single exact T1 worker claimed only the governed retry. While it ran, capacity
was 1/1 and no other work was launched. The worker and its MT5 child exited
normally after recording the terminal verdict; the final slot audit found zero
factory terminals, workers, reservations, duplicates, or orphans.

A temporary `FACTORY_OFF.flag` isolated the exact one-shot worker while normal
factory tasks remained OWNER-OFF. It was removed only after its SHA-256
`e80f776f6903abbfb7e0218ee55174cee52e553a99c7375a2a69712f431d94aa`
and embedded work-item/T1 identity were revalidated. No interlock remains.

`T_Live`, AutoTrading, the live manifest, portfolio admission, portfolio KPI,
and Q08 contribution paths were not touched. The unrelated FTMO process was
observed only to exclude it from the factory count and was not controlled.

Machine-readable evidence is in
`artifacts/fx_cointegration_eurusd_usdjpy_q04_retirement_20260813T020014Z_board_advisor.json`.
