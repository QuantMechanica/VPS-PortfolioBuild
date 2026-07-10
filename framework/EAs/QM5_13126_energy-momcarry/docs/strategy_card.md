---
strategy_id: FMR-MOMTS-2010_XTI_XNG_S01
source_id: FMR-MOMTS-2010
ea_id: QM5_13126
slug: energy-momcarry
status: APPROVED
g0_status: APPROVED
created: 2026-07-10
created_by: Research
last_updated: 2026-07-10
target_symbols: [XTIUSD.DWX, XNGUSD.DWX]
period: D1
logical_symbol: QM5_13126_ENERGY_MOMCARRY_D1
expected_trades_per_year_per_symbol: 6
r1_track_record: PASS
r2_mechanical: PASS
r3_data_available: PASS
r4_ml_forbidden: PASS
pipeline_phase: Q02
---

# XTI/XNG Momentum-Carry Double Screen

## Hypothesis

Trade the XTI/XNG relative winner only when an independent broker-native carry
rank agrees, testing the source's high-roll-return-winner versus
low-roll-return-loser structure in a two-energy CFD carrier.

## Entry Rules

- On the first `XTIUSD.DWX` D1 bar of a new month, rank synchronized last-
  completed-month returns for XTI and XNG.
- Independently rank each leg's broker long-minus-short swap differential.
- Enter a paired long-winner/short-loser package only when both ranks agree.
- Stay flat on return ties, nonzero carry ties, missing data, invalid risk
  metadata, or excess spread. For `.DWX` tester all-zero swap only, use the
  card-locked `+1` carry rank and still require momentum agreement.
- Split `RISK_FIXED=1000` equally and place frozen `ATR(20) * 3.5` hard stops.

## Exit Rules

Close both legs at the next month transition, after 35 days, or on orphan or
invalid package composition. Friday close is disabled only for the one-month
source hold.

## Risk

The paper uses 37 futures and front-end roll returns; this two-CFD carrier uses
broker swap as a falsifiable proxy. The fixed all-zero tester carry rank means
Q02 tests the interaction conditional on that prior, not historical carry
changes. Retire below five completed packages per year. No source performance
or correlation is imported. No live, T_Live, AutoTrading, deploy-manifest, or
portfolio-gate change is authorized.

Canonical card: `strategy-seeds/cards/energy-momcarry_card.md`.
