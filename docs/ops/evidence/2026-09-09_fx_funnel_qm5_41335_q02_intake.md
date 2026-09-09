# FX Funnel — QM5_41335 First Q02 Intake

Date: 2026-09-09

Branch: `agents/board-advisor`

Scope: one non-live, non-portfolio Q02 enqueue

## Result

The frozen 66-pair FX cointegration scan has no unbuilt relationship left in
the repository frontier. The two preferred anchors are not Q02-blocked:
`QM5_12532` has Q02 PASS and later Q05 FAIL, while `QM5_12533` has Q02 PASS
and later Q04 FAIL. The subsequent relationship-specific sleeves are built
through `QM5_20255`, whose latest Q02 is PASS and Q04 is FAIL.

The mission therefore used its explicit fallback and advanced one existing
approved forex card: `QM5_41335_fx-usd-exhaustion-reversal-opt`, carrier
`AUDUSD.DWX`, D1. This is a low-frequency structural USD-complex exhaustion
measurement sibling with an expected five trades/year and an explicitly
authorized Q02 census. It is not represented as a new cointegration pair or
as portfolio-admission evidence.

Canonical intake appended exactly one pending row:

| Field | Value |
|---|---|
| Work item | `ff75b1c3-4930-419d-a2fe-49bd37eadc4d` |
| Phase | `Q02` |
| EA | `QM5_41335` |
| Symbol / timeframe | `AUDUSD.DWX` / `D1` |
| Status | `pending` |
| Priority boost | `false` |
| Compile predecessor | `08440065-e8fb-4400-aa99-674eb2693924` (`COMPILE_OK`) |

## Bindings and guards

- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_41335_fx-usd-exhaustion-reversal-opt.md`, SHA-256 `7826e575a21600cfcc48e7ba03e6fa38bfe8faf91e4db3978f430a49e69dc1aa`.
- MQ5 source: SHA-256 `d7eec6373be1b7b865902cd8420b2a3fe305c7a7e026603e9baef9e32ee1e7bc`.
- EX5: SHA-256 `f17045107715b1ee127011f14ee60ad36e6ad23e8dbfc372819a27d4bb596280`.
- Backtest set: SHA-256 `6ed5b4fe7549362276fa8812bcbf9450f6aca2b3b03fd169336a89799874bd47`; `RISK_FIXED=1000`, `RISK_PERCENT=0`.
- PACER source audit command returned exit 0 with `hit_count: 0` and no `EA_FRAMEWORK_INPUT_PINNED` finding.
- `intake-first-q02` dry-run returned `eligible: true` before the apply call.
- Apply receipt: `D:/QM/strategy_farm/artifacts/receipts/first_q02_intake/08440065-e8fb-4400-aa99-674eb2693924_ff75b1c3-4930-419d-a2fe-49bd37eadc4d.json`, SHA-256 `d3987de1bb6ef149158ea9e2f7dc374b938958e0b1eb8d03990def3bd86ad136`.

## Capacity and safety

The pre-enqueue five-sample host CPU series was `96.92, 96.83, 93.79,
90.10, 91.07` percent, below the binding 97% ceiling. Five factory terminals
were active. The first apply attempt was refused by the live factory mutation
lock; the lock was not modified or bypassed. The retry succeeded through the
same guarded command after the pump released it.

No MQ5, setfile, registry, gate, portfolio-admission, T_Live, deploy-manifest,
or AutoTrading state was changed. The pipeline now owns the Q02 result.
