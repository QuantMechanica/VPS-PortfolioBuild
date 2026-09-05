# QM5_41341 XAU/XAG Monthly Bisquare Reversion — Q02 CPU-Ceiling Stop

**Date:** 2026-09-05  
**Branch:** `agents/board-advisor`  
**Outcome:** one new, non-duplicate market-neutral commodity edge was sourced,
approved, allocated, and source-built. Its governed compile row is released
and pending. Q02 was not enqueued because the binding CPU ceiling was hit.

## Edge delivered

`QM5_41341_xauxag-mbisquare-rv` is a low-frequency XAU/XAG two-leg basket. On
the first synchronized D1 bar of each broker month it reconstructs 13 completed
month-end log ratios, forms 12 adjacent ratio returns, and computes a fixed
Tukey redescending-bisquare location (median/MAD start, cutoff 4.685, exactly
32 reweighting passes). It fades the robust location sign with equal target
USD notionals: positive location sells XAU and buys XAG; negative location buys
XAU and sells XAG. Each leg has a frozen 3.5 x ATR(20) stop, no take profit,
next-month exit, and a 40-day stale exit.

The corrected-root duplicate scan was `CLEAN` across 4,821 registry rows,
1,440 repository cards, and 45 Strategy Wiki nodes. The card explicitly
distinguishes its monthly robust-location statistic from existing ratio-level,
z-score, signed-rank, dispersion, Klotz-scale, and adjacent monthly
sign-divergence baskets. No future decorrelation waiver is implied.

Reputable governed source packets are Schweikert's peer-reviewed gold/silver
ratio study, CME's spread/ratio construction note, and the existing governed
bisquare arithmetic packet. The conjunction is identified as a QM hypothesis;
source efficacy is not claimed or transferred.

## Durable repository evidence

- Source approval, G0-approved card, EA identity, and dedup receipt:
  `dfa6354b70`.
- Two atomic magic allocations, resolver regeneration, and EA-local card:
  `57442c6bc6`.
- MQ5, basket manifest, SPEC, three fixed-risk setfiles, and independent
  reference suite: `79a6d48abd`.
- First-compile setfile provenance correction to `PENDING_BUILD_CHECK`:
  `9a9bd19f1c`.

Pinned identities:

- MQ5 SHA-256:
  `B5A281843F81F596C8FDAFDA28095CEA538CCD08CA3D3E1402A4DD4A9EED0179`;
- approved-card SHA-256:
  `76DD2AAC04EB82DEC45A3BAE67974AB3535F24DC5E64E3C1B371EACA0B59024E`;
- basket-manifest SHA-256:
  `F59B940A5BA61B2DF0B21B2132F387814F348E7B30FDEB7ED6C116672D3823D1`.

The independent Python reference suite passed 6/6 and the basket-manifest
suite passed 47/47. All three backtest sets lock `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live, demo, shadow, or stress
setfile exists.

## Governed compile state

Ad-hoc compile correctly refused while factory terminals were alive; no
terminal or process was stopped. Compile item
`55c7af5e-37f0-47ee-b00c-a5e9d054ee80` was enrolled with unbound setfiles,
source-hash checked by the bounded compile-wave utility, released, and marked
priority for this commodity-sleeve mission. At the final pre-stop inspection it
was `pending`, unclaimed, attempt zero, with no verdict, EX5, or evidence path.
The dry-run and apply release receipts are committed with this report.

## Binding CPU stop

The fresh five-sample total-CPU window at `2026-09-05T05:04:39Z` through
`2026-09-05T05:04:44Z` was:

```text
99, 78, 73, 88, 73 percent
average = 82.2 percent
maximum = 99 percent
binding ceiling = 97 percent
```

Admission requires both average and maximum to be strictly below 97%. The
maximum exceeded the ceiling, so no Q02 work item, smoke, manual backtest, or
terminal operation was launched.

## Safe continuation boundary

Reuse compile item `55c7af5e-37f0-47ee-b00c-a5e9d054ee80`; do not enqueue a
duplicate. After its governed result is `COMPILED` with strict zero-error and
zero-warning evidence, and only after a new five-sample CPU window has average
and maximum strictly below 97%, enqueue exactly the logical basket symbol
`QM5_41341_XAU_XAG_BISQ_RV_D1 / D1 / RISK_FIXED=1000` for Q02. The physical
XAU and XAG sets remain implementation legs, not separate Q02 portfolio rows.

No portfolio gate, T_Live manifest, T_Live state, AutoTrading state, or live
configuration was touched.
