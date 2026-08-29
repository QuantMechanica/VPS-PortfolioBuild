# QM5_41193 XTI/XNG Fractional-Difference Source Build and CPU Stop

Date: 2026-08-29

Branch: `agents/board-advisor`

Outcome: `SOURCE_BUILD_COMMITTED; COMPILE_HELD; CPU_CEILING_BINDING; Q02_NOT_ENQUEUED`

## New commodity/energy edge

`QM5_41193_xtixng-fracd-rv` is a low-frequency, market-neutral-style XTI/XNG
relative-value basket. At the first synchronized D1 boundary of a broker month,
it loads exactly 316 synchronized completed daily `log(XTI)-log(XNG)` ratios,
applies the fixed fractional-difference operator `(1-L)^0.40` with 64 lag
coefficients, estimates the mean and sample standard deviation from the first
252 filtered observations, and holds the latest filtered observation out for
the decision. An inclusive z-score of at least `+0.50` opens SELL XTI / BUY
XNG; at most `-0.50` opens BUY XTI / SELL XNG; the interior consumes the month
flat.

The legs target equal absolute USD notionals within a fixed 20% mismatch
tolerance. One aggregate `RISK_FIXED=1000` budget is split across frozen
`3.5*ATR(20,D1)` stops, with `RISK_PERCENT=0`. The package exits at the next
broker month or through the forty-day stale-position repair. All three presets
are backtest-only; there is no live preset.

The economic exposure and mechanic differ from certified `QM5_12567`, which is
a long-only two-day cumulative-RSI pullback on XNG, and from the existing
directional index/metal sleeves. The construction makes diversification
plausible but does not claim realized decorrelation; Q09 remains authoritative.

## Reputable-source and duplicate boundary

The source packet uses the U.S. Energy Information Administration analysis by
Villar and Joutz and the peer-reviewed Energy Journal study by Ramberg and
Parsons for the weak, time-varying crude-oil/natural-gas linkage and its adverse
evidence. The governed `YAYA-CME-XAUXAG-FRACD-RV-2026` record supplies only the
audited fractional-difference arithmetic and basket-lifecycle precedent; its
gold/silver empirical evidence is explicitly not transferred to oil/gas.

Before allocation, the canonical checker returned CLEAN across 4,692 registry
rows, 1,343 cards, and 45 Strategy Wiki nodes. Manual boundary review separated
this exact fixed fractional-difference level statistic from the completed-month
daily high/low pseudomedian in `QM5_41192`, rolling fitted-ECM, raw-ratio,
return-spread, slope, rank, and calendar families. The candidate is therefore a
new governed identity, not a rename of an existing oil/gas basket.

## Governed identity and committed build

- EA identity: `41193 / xtixng-fracd-rv`;
- active XTI magic: `411930000`;
- active XNG magic: `411930001`;
- approved card SHA-256:
  `67626CE338373B9026690B6CCC83DA91ED1E5ED7307AE4EE2E453786083EFC7F`;
- EA-local and canonical approved cards are byte-identical;
- MQ5 SHA-256:
  `8E3FB9D1A459712026BF9AFE91ED8AE0A9DA32F4A360A6B9DECE20C4AF40B7EB`;
- SPEC SHA-256:
  `C4481D73FA2227EBFE4C23B9B440E95FC3908A79E9E44136DC656F646E4E4285`;
- basket-manifest SHA-256:
  `78814335E2283B7B9EFA4FD28D682871978564CC143C0C3AA265009D218FB5DF`.

Mission commits before this receipt:

- `77d16d8a1` — reputable-source approval, provenance, and preallocation dedup;
- `3d31d9c53` — bounded source-to-rule extraction packet;
- `9c3e27e05` — deterministic EA allocation, G0-approved card, and decision;
- `5a53d0af2` — magic allocation, V5 EA, basket manifest, SPEC, reference suite,
  and three fixed-risk backtest presets; and
- `c12e07bef` — byte-identical EA-local Strategy Card binding.

## Validation and governed compile disposition

The deterministic reference suite passes 8/8 tests. Card schema and G0 linters
pass with zero prohibited-ML hits. The three presets all bind
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and the backtest environment.

The ad-hoc strict compile correctly refused while factory terminals were live;
no interlock bypass was attempted. The governed queue accepted exactly one
source-bound compile item, `37e3b310-7384-48df-8d3a-92eb4f80c0da`. A target-only
rollout dry run selected only that item and verified that its expected and
actual MQ5 hashes both equal
`8e3fb9d1a459712026bf9afe91ed8ae0a9da32f4a360a6b9dece20c4af40b7eb`.

The item remains pending, unclaimed, at attempt zero, without a verdict or
evidence path, under its active `COMPILE_EA_WORKER_ROLLOUT_PENDING` hold. No EX5
exists. The hold was not released.

## Binding CPU stop and Q02 disposition

The fresh five-sample admission window was `100.000, 99.807, 94.828, 96.004,
99.416` percent: average `98.011%`, maximum `100.000%`. Both the average and
maximum breach the `97.0%` hard ceiling. At the concurrent slot readback, five
governed tester slots were active: T2, T3, T6, T7, and T8.

The mission requires an immediate stop when the backtest CPU ceiling is hit.
Accordingly, no compile-hold release, worker claim, terminal action, backtest,
or Q02 enqueue followed this sample. The canonical database contains exactly
one row for this EA—the held compile item—and zero Q02 rows, including zero
physical-leg rows. A later paced continuation may reuse the existing compile
item after a fresh below-ceiling admission window; only after a strict current
compile/build PASS may it enqueue exactly one logical
`QM5_41193_XTI_XNG_FRACD_RV_D1` Q02 row.

Machine-readable evidence is
`artifacts/qm5_41193_xtixng_fracd_source_build_cpu_stop_20260829.json`.

## Safety boundary

AutoTrading was not toggled. No T_Live process or manifest, portfolio gate,
deploy record, or portfolio-admission record was changed. No manual tester was
launched, no terminal was started/stopped/reserved/released, and no compile or
backtest safety control was bypassed. Unrelated dirty fleet-generated files
were preserved and excluded from the mission commits.
