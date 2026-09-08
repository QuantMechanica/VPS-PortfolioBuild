# QM5_41384 WTI Two-Month Momentum / Two-Month Hold — Build And Q02 CPU Stop

## Outcome

`QM5_41384_wti-tsmom2-h2` implements a new low-frequency structural WTI
stream: the sign of the exact return over two completed broker months,
evaluated only in odd months and held for a fixed non-overlapping two-month
package. It supplies direct crude-oil exposure outside the incumbent
XAU/SP500/NDX/XNG carriers. Realized decorrelation is not claimed before Q09.

The governed Q01 compile passed. Q02 was not enqueued because the terminal
worker recorded the mission's binding CPU ceiling twice.

## Source And Non-Duplicate Boundary

The complete-read, peer-reviewed source is Moskowitz, Ooi, and Pedersen
(2012), *Time Series Momentum*, Journal of Financial Economics 104(2),
228–250, DOI `10.1016/j.jfineco.2011.11.003`. It defines the own-return
momentum family and includes WTI; the standalone WTI `k=2,h=2` result remains
explicitly unproven.

The corrected-root canonical checker found no exact identity. `QM5_20064`
uses the same two-month formation with monthly renewal; `QM5_20281` uses the
same two-month clock with twelve-month formation; `QM5_41379` through
`QM5_41383` use three-, one-, nine-, six-, and four-month formations. This
identity requires both exact two-month endpoints and the fixed odd-month
two-month lifecycle.

## Q01 Evidence

- EA ID and magic: `QM5_41384`, slot 0, `413840000` on `XTIUSD.DWX`.
- PACER audit: exit 0, zero `EA_FRAMEWORK_INPUT_PINNED` findings.
- Deterministic reference vectors: 13/13 PASS; strategy-card schema issues 0;
  prohibited-ML hits 0.
- Compile work item: `6a063c3e-c161-4069-90fe-2bbefc258f08` on non-live `T10`.
- Compile result: `COMPILE_OK`; compiler errors 0, compiler warnings 0; strict
  build check PASS with three non-failing card-resolution advisories.
- Source SHA-256:
  `5b81bb16c6097eedc76858716bf9b441379033f900a122e3baab7dfab042d880`.
- Binary SHA-256:
  `01c5f5e685589b7da9eed68a0426cd8c38718e11d05784823189ee1a7325feb0`.
- Backtest risk contract: `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Q02 Admission Stop

At `2026-09-08T12:48:04.974424Z`, the T10 worker recorded `98.3%` CPU against
the `97%` ceiling. At `2026-09-08T12:49:27.860871Z`, it recorded `97.3%`.
Both events were latched `cpu_high_pause` records. The mission requires work
to stop when the backtest CPU ceiling is hit, so no Q02 work item was created
and no manual backtest was launched.

## Safety Boundary

No `T_Live` terminal, AutoTrading control, portfolio gate, deploy/live
manifest, or live surface was touched. WTI-specific economics remain unproven
until a later admitted Q02 run; realized portfolio decorrelation remains a
Q09 question.
