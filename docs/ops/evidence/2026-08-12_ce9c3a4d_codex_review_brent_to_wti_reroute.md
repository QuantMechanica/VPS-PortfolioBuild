# Codex Review — 23-EA Brent-to-WTI Q02 Reroute

Date: 2026-08-12

Router review task: `ce9c3a4d-0ae0-4322-aa62-a27386f9008a`

Gemini source task: `9ad6d9c0-d67b-4092-80e6-4df2f826eb73`

Reviewed commit: `387b7fd003af6648b377ca26c73dfc7d1ae39b01`

Source artifact: `docs/ops/evidence/2026-08-12_brent_oil_cards_reroute_to_xtiusd_q02_enqueue.md`

## Verdict

**CHANGES_REQUIRED — do not accept or promote the reroute build.**

The registry, resolver, setfiles, and compiles are structurally valid, but the
reroute is functionally incomplete. Every one of the 23 MQ5 sources still
hard-codes `XBRUSD.DWX` as its only permitted host symbol. The new XTIUSD Q02
runs therefore cannot exercise the strategy and deterministically produce zero
trades.

This is an implementation/setup defect, not a strategy verdict and not a
pipeline verdict.

## Blocking finding

All 23 reviewed sources contain this executable predicate:

```mql5
return (_Symbol == "XBRUSD.DWX" && _Period == PERIOD_D1);
```

The predicate feeds the strategy no-trade filter. For example,
`QM5_12841_brent-thu-prem.mq5` line 51 defines the XBR-only predicate and lines
113–116 return `true` from `Strategy_NoTradeFilter()` whenever that predicate
is false. An XTIUSD.DWX D1 test therefore suppresses every entry.

The finding covers the complete task cohort:

| EA | XBR-only executable gate line |
|---|---:|
| QM5_12841 | 51 |
| QM5_12849 | 53 |
| QM5_12853 | 51 |
| QM5_12854 | 49 |
| QM5_12855 | 51 |
| QM5_12856 | 51 |
| QM5_12859 | 56 |
| QM5_12865 | 51 |
| QM5_12866 | 51 |
| QM5_12871 | 49 |
| QM5_12911 | 51 |
| QM5_12976 | 51 |
| QM5_12980 | 57 |
| QM5_12981 | 52 |
| QM5_12982 | 51 |
| QM5_13052 | 51 |
| QM5_13054 | 57 |
| QM5_13055 | 58 |
| QM5_13056 | 58 |
| QM5_13061 | 51 |
| QM5_13072 | 51 |
| QM5_13091 | 58 |
| QM5_20171 | 53 |

Commit `387b7fd00` changes 49 files but changes no `.mq5` source. It adds 23
XTIUSD backtest sets, recompiles 23 unchanged sources, changes the registry and
resolver, and adds the source evidence. Consequently, the compiled EX5 files
retain the XBR-only runtime gate.

At the read-only database snapshot taken during review, the 23 new XTIUSD Q02
rows were unique by `(ea_id, symbol, phase)` and had this state distribution:

- 4 `done / ZERO_TRADES`
- 1 `active`
- 18 `pending`

The four completed results independently corroborate the static finding. The
active run was not interrupted, and no pending or historical work item was
mutated by this review.

## Checks that passed

- `validate_build_guardrails.py` returned PASS for all 23 new setfiles with the
  336-hour maximum news-staleness bound. Each set uses `RISK_FIXED=1000` and
  `RISK_PERCENT=0`.
- The 23 compile logs from `20260812_160845` through `20260812_161909` each end
  in `Result: 0 errors, 0 warnings`.
- Registry audit: all 23 EAs have exactly one retired XBRUSD slot-0 row and one
  active XTIUSD slot-0 row, preserving the same magic number.
- Resolver dry-run: 15,903 rows kept, zero dropped. Its declared registry hash
  `07FCB0DE...` matches the canonical-LF SHA-256 of `magic_numbers.csv`.
- Database audit: exactly 23 new XTIUSD Q02 rows exist for the 23 requested EAs;
  no duplicate reroute row was found in this cohort.

These checks establish structural integrity only. A clean compile cannot prove
that a new host symbol passes an EA's runtime scope guard.

## Required rework

1. Change each EA's executable host-symbol predicate from the retired Brent
   symbol to the OWNER-authorized WTI proxy `XTIUSD.DWX`; keep the D1 restriction.
2. Update stale symbol-specific comments/function names where useful, without
   changing strategy mechanics.
3. Re-run the 336-hour news/risk guardrail check and strict compilation for all
   23 sources.
4. Add or run a static regression that proves no reviewed source retains an
   executable XBR-only host gate and every source accepts XTIUSD.DWX D1.
5. Preserve the existing Q02 rows as immutable evidence. Any post-fix tests
   must use the governed append-only recovery path and bind fresh MQ5, EX5, and
   setfile hashes.

No efficacy, certification, decorrelation, or portfolio-admission conclusion
is made. The Gemini source task remains in REVIEW; this review does not move it
or any EA to PIPELINE.
