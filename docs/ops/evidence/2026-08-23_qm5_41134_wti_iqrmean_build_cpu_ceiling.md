# QM5_41134 WTI interquartile-mean build and CPU-ceiling handoff

Date: 2026-08-23

Branch: agents/board-advisor

Verdict: SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING

## Delivered commodity sleeve

QM5_41134_wti-mdaily-iqrmean-mom is a new direct-WTI D1 sleeve under strategy
ID MOP-MEEK-WTI-MDAILY-IQRMEAN-2026_S01. It is structurally distinct from the
certified XNG RSI edge and from existing WTI raw-endpoint, sign-breadth,
persistence, single-tail-trim, ordinary-median, weekday-median, and cross-month
robust-estimator families.

At the first executable D1 bar of a normalized broker month, the EA rebuilds
the immediately completed month from 17-23 session closes plus one older
boundary close. It forms every chronological close-to-close log return ending
in the month, verifies endpoint identity, sorts the full sample, removes
floor(n/4) returns from each tail, and follows the arithmetic mean of the exact
9-13 retained observations. The raw endpoint is diagnostic only.

The implementation is low-frequency and fixed-risk:

- exact XTIUSD.DWX / D1 carrier;
- one consumed attempt and at most one position per broker month;
- RISK_FIXED=1000, RISK_PERCENT=0, PORTFOLIO_WEIGHT=1;
- frozen 3.5*ATR(20,D1) stop, no target, and forty-day stale repair;
- news axes and Friday close OFF;
- no optimization, ML, banned indicator, live, demo, shadow, or stress preset.

The bounded source packet cites Moskowitz, Ooi, and Pedersen (2012) for WTI
own-return time-series-momentum lineage and Meek and Hoelscher (2023) for daily
WTI close-to-close log-return construction. The interquartile-mean translation
is explicitly a QM hypothesis; no paper result is claimed for the CFD carrier.

## Identity and commits

- EA ID: 41134
- slug: wti-mdaily-iqrmean-mom
- magic: 411340000
- source approval: 81ca87515
- bounded source packet: 6af0cbdae
- G0-approved card: 42dbee0ac
- deterministic identity reservation: 77cd62bbc
- governed magic allocation: 5fb30a1cd
- EA, spec, test, card-copy, and fixed-risk setfile: 9de298a2f
- MQ5 SHA-256: 3908940184944650DE63998266772D9B4728D32D07D08E3B7FB767FBE610DCF9

The EA-ID and magic rows are active and the generated resolver contains
411340000.

## Verification completed

- canonical pre-allocation dedup: CLEAN across 4,633 registry identities,
  1,301 cards, and 45 wiki nodes;
- post-allocation dedup: exact self identities only;
- approved-card schema lint: PASS, no missing sections and no ML hits;
- deterministic Python reference suite: PASS, 16/16;
- validate_spec_doc.py: PASS, 1/1;
- validate_build_guardrails.py: PASS for the MQ5 and sole backtest setfile;
- validate_symbol_scope.py --fail-on-leak: SINGLE_SYMBOL_OK, zero violations;
- package whitespace audit: PASS;
- approved card and build card copy remain content-identical.

## Compile and Q02 boundary

The direct build check stopped at LIVE_FACTORY_AD_HOC_COMPILE_REFUSED because
factory terminals were alive and directed the build to the governed compile
queue. No retry, bypass, terminal control, include mutation, or manual tester
was attempted.

A target-only read confirmed compile status NOT_ENQUEUED and zero work items.
No EX5 or strict Q01 PASS exists, so Q02 is not legally enqueueable.

The bounded observation in
artifacts/qm5_41134_cpu_ceiling_20260823.json recorded five consecutive 100.0%
host-CPU samples. That exceeds CPU_MAX_LOAD_PERCENT=97.0; the configured resume
threshold is 90.0%. T2, T4, and T10 were active. The mission explicitly says
to stop and summarize at the backtest CPU ceiling, so neither compile nor Q02
was enqueued.

## Governed continuation

After sustained recovery below the configured resume threshold, enqueue one
source-fresh governed compile for the exact EA. Only strict COMPILE_OK with a
bound EX5 hash permits one target-only Q02 enqueue using the committed
XTIUSD.DWX D1 RISK_FIXED setfile.

No portfolio gate, T_Live manifest, T_Live file, AutoTrading state, live
preset, gate threshold, existing EA, or terminal process was touched.
