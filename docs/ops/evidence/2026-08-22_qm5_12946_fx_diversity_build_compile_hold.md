# QM5_12946 FX diversity build - governed compile hold

## Outcome

`QM5_12946_mql5-macd-obv-div-card` is source-ready as a low-frequency H1
divergence sleeve for `EURUSD.DWX`, `GBPUSD.DWX`, and `XAUUSD.DWX`. The source,
Q01 strategy spec, and three canonical fixed-risk presets are complete. Static
Q01 checks pass.

Compilation, smoke, and Q02 enqueue are intentionally not claimed. The live
factory refused an ad-hoc compile, and the EA's pre-existing governed compile
row is held for the reviewed worker rollout and is now bound to an obsolete
source hash. No factory process, T_Live state, AutoTrading setting, portfolio
gate, or deployment manifest was changed.

## Selection and collision control

- Build task: `7bc9f0f5-251e-4755-b829-33e38cfd740b`.
- Approved card: `QM5_12946_mql5-macd-obv-div-card` (R1-R4 PASS, G0 APPROVED).
- Source: Christian Benjamin, "MQL5 Wizard Techniques you should know (Part
  71): MACD plus OBV," MQL5 Articles, 2025-05-28.
- Diversity rationale: the current Q08 soft-survivor cohort is concentrated in
  indices, metals, and energy. This card introduces two major-FX lanes with a
  fixed structural divergence mechanism and an expected cadence of about 35
  trades per year per symbol.
- The farm task was created through `farmctl build-ea`; no second EA was
  claimed or advanced.

The active deterministic identity already existed and was not edited:

| Slot | Symbol | Magic |
|---:|---|---:|
| 0 | `EURUSD.DWX` | 129460000 |
| 1 | `GBPUSD.DWX` | 129460001 |
| 2 | `XAUUSD.DWX` | 129460002 |

All three rows are active in `magic_numbers.csv`, and the generated resolver
contains all three magic values.

## Mechanical implementation

The EA uses the current V5 framework skeleton and keeps its lifecycle, risk,
news, Friday-close, MAE, and transaction wiring intact. Strategy mechanics are:

- strict 3-left/3-right confirmed price fractals;
- standard MACD main (12/26/9) through the pooled framework reader;
- deterministic tick-volume OBV built from one bounded closed-bar `CopyRates`
  window behind `QM_IsNewBar`;
- lower-low/higher-MACD-low plus higher/rising-OBV long divergence, with the
  exact inverse short rule;
- first later directional candle within ten bars as confirmation;
- structural stop beyond the second swing by `0.25 * ATR(14)` and fixed 2R TP;
- early exit on the opposite confirmed divergence or a MACD zero-line cross.

No ML, adaptive rule, grid, martingale, banned raw indicator handle, external
request, or per-tick history scan was introduced. The card did not specify MACD
periods or a prior-swing history bound; the spec records the conventional
12/26/9 choice and the deterministic 160-bar bound.

## Presets and static evidence

Canonical `gen_setfile.ps1` generated one H1 backtest preset for each registered
symbol. Each preset has:

- `RISK_FIXED=1000`;
- `RISK_PERCENT=0`;
- the correct host magic slot;
- all eight explicit strategy inputs;
- `build_hash: pending`, because only a successful governed build check may
  bind the final hash.

Checks completed:

- `validate_spec_doc.py`: PASS, 1/1.
- `validate_build_guardrails.py`: PASS, four files checked, zero findings,
  stale-news ceiling 336 hours.
- `validate_symbol_scope.py --fail-on-leak`: `SINGLE_SYMBOL_OK`, zero leaks.
- focused EA/magic/resolver identity check: one active EA row and exactly the
  three active rows listed above.
- all three presets passed the explicit fixed-risk and strategy-input checks.
- `git diff --check`: clean for the EA package.

The repository-wide registry validator also reports unrelated historical
inventory defects; none names EA 12946 or its three magic rows. Those broad
pre-existing findings were not modified in this unit.

## Compile boundary and exact blocker

The fail-closed preflight returned:

`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED: terminal64 processes are alive; use the governed pipeline path`

No compiler was launched and no retry or terminal interruption was attempted.
`farmctl enqueue-compile QM5_12946_mql5-macd-obv-div-card` then returned the
idempotent existing work item:

- work item: `ae9e93a6-4a77-4ac9-bd11-e9ec1363bc60`;
- state: `pending`, unclaimed;
- active hold: `COMPILE_EA_WORKER_ROLLOUT_PENDING`;
- `release_on_restart=1`;
- bound MQ5 SHA-256:
  `2c04e592e9e86ab86ecc180b0379369db93054f5b3c6fc521316d24515ac1ac5`;
- completed source SHA-256:
  `e0adb638e3586a0c6d492e03f2ec2685cd49a63482a9ee2ba583166c3c3213b8`.

The governed worker rechecks this binding and will fail closed with
`SOURCE_CHANGED_AFTER_ENQUEUE`; an agent must not misrepresent the pending row
as a claimed compile merely to bypass the hold.

## Required next governed action

Through the OWNER/orchestrator release-on-restart ceremony, let the stale row
reach a terminal `SOURCE_CHANGED_AFTER_ENQUEUE` state (or use the sanctioned
exact supersede path). Then enqueue a fresh `COMPILE_EA` row bound to the
completed source. Its worker must produce strict compile 0 errors / 0 warnings,
full `build_check=PASS`, final hash-bound presets, and one smoke before this EA
is eligible for Q02. Until those facts exist, this record makes no pipeline or
profitability claim.
