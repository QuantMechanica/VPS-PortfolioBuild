# QM5_41383 WTI Four-Month Momentum / Two-Month Hold — Build And Q02 CPU Stop

## Outcome

`QM5_41383_wti-tsmom4-h2` implements a new low-frequency structural WTI
stream: the sign of the exact return over four completed broker months,
evaluated only in odd months and held for a fixed two-month package. It is a
direct energy exposure with a different carrier and return driver from the
incumbent index, gold, and natural-gas sleeves. Realized decorrelation is not
claimed before Q09.

The governed Q01 compile passed. Q02 was not enqueued because the fresh host
CPU window reached the mission's binding ceiling.

## Source And Non-Duplicate Boundary

The complete-read, peer-reviewed source is Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, Journal of Financial Economics 104(2),
228–250, DOI `10.1016/j.jfineco.2011.11.003`. It defines the own-return
momentum family and includes WTI; the standalone WTI `k=4,h=2` result remains
explicitly unproven.

Canonical dedup found no exact identity. `QM5_20280` is four-month formation
with monthly renewal; `QM5_20281` is twelve-month formation with the same
two-month clock; `QM5_41379` through `QM5_41382` are the three-, one-, nine-,
and six-month two-month-hold variants. This identity requires both exact
four-month endpoints and the fixed odd-month two-month lifecycle.

## Q01 Evidence

- EA ID and magic: `QM5_41383`, slot 0, `413830000` on `XTIUSD.DWX`.
- PACER audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Deterministic reference vectors: 13/13 PASS; strategy-card schema issues 0;
  prohibited-ML hits 0.
- Compile work item: `2560324d-2582-45cd-8ed7-63bf439589ca` on non-live `T10`.
- Compile result: `COMPILE_OK`; compiler errors 0, compiler warnings 0; strict
  build check PASS with three non-failing card-resolution advisories.
- Source SHA-256:
  `5e741d31c4c0dc85addc70d097e5be5c7e1ec8537dd833b4f57c107f334e3498`.
- Binary SHA-256:
  `b310ab285973cefd7c17c81dec90c371f1dd8301d60955fa05569ae987daccde`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Q02 Admission Stop

The exact fixed-risk `XTIUSD.DWX` D1 first-Q02 dry run returned `ELIGIBLE`.
Immediately afterward, the required five one-second whole-host CPU samples
were `99.221850%`, `97.010823%`, `93.879374%`, `94.923138%`, and
`91.017351%`. Average CPU was `95.210507%`; maximum CPU was `99.221850%`.
Because Q02 admission requires every sample to remain strictly below the
binding `97%` ceiling, the stop fired. No Q02 work item was created and no
manual backtest was launched.

## Safety Boundary

No `T_Live` terminal, AutoTrading control, portfolio gate, deploy/live
manifest, or live surface was touched. WTI-specific economics remain unproven
until a later admitted Q02 run; realized portfolio decorrelation remains a
Q09 question.
