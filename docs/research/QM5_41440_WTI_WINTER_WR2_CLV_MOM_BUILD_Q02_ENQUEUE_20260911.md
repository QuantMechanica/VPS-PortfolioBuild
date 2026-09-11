# QM5_41440 WTI Winter WR2 CLV Momentum — Build And Q02 Enqueue

Date: 2026-09-11  
Branch: `agents/board-advisor`

## Outcome

`QM5_41440_wti-winter-wr2-clv-mom` is a new low-frequency WTI sleeve. During
November-May it buys at a normalized Monday boundary only when the newest of two
completed weeks has a strictly wider range and its final close is strictly above
the upper range quartile. It uses a frozen `3.5 * ATR(20,D1)` hard stop and exits
at the next week boundary, with no take profit.

This is not the certified `QM5_12567` XNG two-day cumulative-RSI pullback. It is
also distinct from monthly WTI return-sign rules, August-October WTI hurricane
WR2/CLV rules, and the symmetric XNG November-March WR2/CLV candidate. Realized
portfolio decorrelation remains a later Q09 question; it is not claimed here.

## Build Evidence

- Research approval commit: `70e703b0cc`
- Magic allocation commit: `6616ce16af`
- Source build commit: `34525f07f5`
- Compiled-artifact binding commit: `cf9dad20ae`
- EA identity / magic: `QM5_41440` / `414400000`
- Compile work item: `52424a9e-3256-45af-aa79-1e8b3101a910`
- Compile verdict: `COMPILE_OK`; zero compiler errors and warnings; strict build check `PASS`
- MQ5 SHA-256: `5d65c6b88625e4b27a8390f628c41f4b653ebcc404b7da3c0255e1d9ed65979b`
- EX5 SHA-256: `d4a8a87c3e617dbc764b2c925eaf3804ee379799294b7d94fd9212389e28aa6d`
- Q02 set SHA-256: `6f360af180b134ace733aaac6efd09f7c71fe229e88ef6214b76f36a7e833a5b`

The mandatory pre-enqueue PACER audit returned `ok=true`, `hit_count=0` for
`EA_FRAMEWORK_INPUT_PINNED`. The source guard pins only identity, fixed-risk
backtest mode, and `strategy_*` inputs. It does not compare RNG, news, or Friday
framework settings, and stress rejection is only checked for finiteness and the
inclusive `[0,1]` range.

Eleven deterministic reference tests and both card lints passed. The canonical
generated set binds `strategy_symbol=XTIUSD.DWX`, `RISK_FIXED=1000`, and
`RISK_PERCENT=0`.

## Q02 Admission And Receipt

The one fresh five-sample whole-host CPU window was `47.957464%`, `63.914601%`,
`61.051910%`, `61.346650%`, and `57.685613%`: average `58.391247%`, maximum
`63.914601%`. Both were strictly below the `97.0%` ceiling.

The governed first-Q02 intake appended pending work item
`cef7693f-73af-432a-93be-bef4123a0de0` for `XTIUSD.DWX` D1. Its external receipt
is `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/52424a9e-3256-45af-aa79-1e8b3101a910_cef7693f-73af-432a-93be-bef4123a0de0.json`.

No manual tester dispatch, optimization, portfolio-gate or live-manifest change,
`T_Live` access, AutoTrading action, terminal control, or live authorization
occurred.
