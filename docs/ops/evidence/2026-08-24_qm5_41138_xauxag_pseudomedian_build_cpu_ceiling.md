# QM5_41138 XAU/XAG pseudomedian build and CPU-ceiling handoff

Date: 2026-08-24

Branch: `agents/board-advisor`

Status: `SOURCE_READY_COMPILE_NOT_ENQUEUED_CPU_CEILING`

## New commodity sleeve

`QM5_41138_xauxag-mdaily-hl-rv` mechanizes one low-frequency,
market-neutral-style gold/silver relative-value edge. On the first synchronized
D1 bar of a broker month, it reconstructs every gold-minus-silver log-ratio
return ending in the immediately completed 17-23-session month, including the
adjacent older boundary pair. It enumerates every inclusive self/cross-pair
average `(r[i]+r[j])/2`, sorts the resulting 153-276 values, and fades their
exact odd/even pseudomedian for one broker month.

This is mechanically distinct from the directional XAU/SP500/NDX/XNG book and
from `QM5_41135`: that earlier XAU/XAG build trims the raw return tails and
averages 9-13 retained observations, whereas `QM5_41138` retains all raw
returns, expands them into 153-276 inclusive pair averages, and uses only the
pairwise median. The sleeve makes no realized-neutrality or decorrelation
claim; unchanged Q09 owns that test.

The atomic two-leg package uses equal target absolute USD notionals, no more
than 20% realized mismatch, aggregate `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `PORTFOLIO_WEIGHT=1`, frozen `3.5*ATR(20,D1)` stops, no
targets, one consumed attempt per month, and first-later-month/forty-day exits.
Both news axes and Friday close are OFF. There is no trained model, banned
signal indicator, external feed, optimization surface, or signal-strength
sizing.

## Governed source and identity

- Source approval and pre-allocation dedup: `46e7be1d3`.
- Bounded reputable-source packet: `f28f564a5`.
- EA ID reservation: `71d53a0e6`.
- OWNER-authorized G0 card: `a470bb65a`.
- Build-directory scaffold: `22f216799`.
- Basket magics and non-dropping resolver regeneration: `d176574b5`.
- EA, spec, exact card copy, basket manifest, reference suite, and fixed-risk
  setfiles: `d45395b645c4a20bd27490bdfc69a9309602954f`.

Identity is `QM5_41138`, slug `xauxag-mdaily-hl-rv`, strategy ID
`SCHWEIKERT-HL-CME-XAUXAG-MDAILY-HL-RV-2026_S01`, host magic `411380000`,
and companion magic `411380001`. MQ5 SHA-256 is
`4020FC4569B323A2B07F8872CD74CE76CA7B1EFDDE7F01695E0D040AFD254730`.

## Deterministic verification

- approved-card lint: PASS, zero missing sections and zero ML hits;
- independent pseudomedian reference suite: PASS, 9/9;
- `validate_spec_doc.py`: PASS, 1/1;
- `validate_build_guardrails.py`: PASS for MQ5 and all fixed-risk setfiles;
- `validate_symbol_scope.py --fail-on-leak`: `BASKET_OK`, zero violations;
- approved-card copy, EA-ID row, two magic rows, resolver entries, and package
  whitespace audit: PASS.

The logical Q02 carrier is
`QM5_41138_XAU_XAG_MDAILY_HL_RV_D1`, hosted on `XAUUSD.DWX` D1 with
`XAGUSD.DWX` as the companion. The manifest requests 2018-07-02 through
2024-12-31 and requires at least five packages per full year.

## Binding CPU stop

Before any compile or Q02 queue mutation, a fresh five-sample whole-host
`Processor(_Total)` window returned `99.32, 95.71, 87.42, 84.78, 93.95`
percent (average 92.24%, maximum 99.32%). The maximum exceeds the governed
`CPU_MAX_LOAD_PERCENT=97.0`; the configured resume threshold is 90.0%.

The mission requires stopping when that ceiling is hit. Therefore no direct
compile, governed compile enqueue, hold release, dispatch, terminal claim,
tester run, or Q02 enqueue was attempted. Read-only final checks show compile
status `NOT_ENQUEUED`, zero `QM5_41138` work items, and no EX5. A Q02 row
cannot be legally created before a current strict compile PASS and bound EX5.

Machine-readable evidence is
`artifacts/qm5_41138_cpu_ceiling_20260824.json`.

## Governed continuation

After sustained CPU recovery below 90%, enqueue exactly one source-fresh
governed compile for `QM5_41138_xauxag-mdaily-hl-rv`. Only a strict
zero-error/zero-warning compile with a hash-bound EX5 permits build review and
one logical Q02 enqueue using the committed D1 `RISK_FIXED` preset.

No portfolio gate, `T_Live` manifest, `T_Live` file, AutoTrading state,
terminal process, live/demo/shadow/stress preset, deploy state, gate threshold,
existing EA, or portfolio verdict was changed.
