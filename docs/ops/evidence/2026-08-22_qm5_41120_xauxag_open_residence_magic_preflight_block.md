# QM5_41120 XAU/XAG fixed-open residence reversion - magic preflight block

Date: 2026-08-22

Branch: `agents/board-advisor`

Outcome: **SOURCE AND G0 CARD COMMITTED; EA-ID RESERVED; MAGIC ALLOCATION
ROLLED BACK; BUILD NOT STARTED; Q02 NOT ENQUEUED**

## New edge completed upstream

`QM5_41120_xauxag-mopen-residence-rv` is a new low-frequency, opposite-leg
gold/silver relative-value proposal. On the first synchronized D1 boundary of
a broker month it reconstructs every synchronized `XAUUSD.DWX` and
`XAGUSD.DWX` close in the immediately completed 17-to-23-session calendar
month.

It fixes the first gold-minus-silver log-ratio close as an anchor, counts all
later closes strictly above and below that anchor, and requires at least
`ceil(3*(n-1)/4)` observations on one side plus a final close on the same side.
Upper residence maps to SELL XAU / BUY XAG; lower residence maps to BUY XAU /
SELL XAG. The intended package targets equal absolute notionals, one aggregate
`RISK_FIXED=1000` stop-risk budget, and a first-later-month exit.

This is not `QM5_41112` adjacent-return breadth, `QM5_41110` prior-month range
residence, `QM5_41119` final-close rank, or a rolling fitted ratio signal. The
canonical pre-allocation checker returned `CLEAN` across 4,619 registry rows,
1,288 cards, and 45 Strategy-Wiki nodes. Post-allocation evidence contains only
the expected `QM5_41120` slug and strategy-ID self-hits.

## Reputable-source and identity commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation dedup | `a7d733f31` |
| bounded peer-reviewed/exchange extraction | `2bb49c71f` |
| atomic EA-ID reservation | `bf8a336c4` |
| approved G0 card and post-allocation review | `26d2e4c43` |

The source lineage is Schweikert (2018), *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; and CME
Group's *Gold & Silver Ratio Spread*. Those records support the related-metal
carrier, not the untested fixed-open residence rule, CFD mapping, performance,
neutrality, or portfolio correlation.

The atomic registry allocator reserved EA ID `41120` for strategy ID
`SCHWEIKERT-CME-XAUXAG-MOPEN-RESIDENCE-RV-2026_S01`. Card schema and G0 lints
both passed with no missing sections and no forbidden-library hit.

## Deterministic build-preflight failure

The exact-card dry run of `governed_magic_allocator.py` selected only
`QM5_41120`, planned slot 0 `XAUUSD.DWX` / magic `411200000` and slot 1
`XAGUSD.DWX` / magic `411200001`, and reported the candidate eligible.

The apply run then failed closed during canonical resolver regeneration because
three unrelated active registry identities have no EA directory:

- `QM5_1001_breakout-atr`
- `QM5_1015_lien-perfect-order`
- `QM5_1016_lien-carry-trade`

`update_magic_resolver.py` classified those identities as active rows that
would be dropped and refused to replace `QM_MagicResolver.mqh` under its
strict default. The allocator rolled back atomically. Machine receipt:
`artifacts/qm5_41120_magic_allocation_20260822.json`.

Post-failure verification proved:

- zero `41120` rows in `framework/registry/magic_numbers.csv`;
- no `QM5_41120_xauxag-mopen-residence-rv` EA directory;
- no `411200000` or `411200001` entry in the resolver;
- no diff in `magic_numbers.csv` or `QM_MagicResolver.mqh`;
- the current resolver still contains the legacy `1001`, `1015`, and `1016`
  bindings.

The `--allow-dropped` recovery escape hatch was not used. It would remove
bindings currently present in the resolver and therefore is not a behavior-
preserving workaround. Empty placeholder directories, hand-written magic
rows, and manual resolver edits were also rejected because they would conceal
or bypass the deterministic gate.

## Binding skill stop and safe continuation

The `qm-build-ea-from-card` preflight requires active magic rows for every
declared `(ea_id, symbol_slot)` pair before source implementation. That gate is
absent, so no EA skeleton, source, setfile, compile request, backtest, or Q02
row was created.

A separately authorized registry-inventory repair must first decide whether
IDs `1001`, `1015`, and `1016` should have real EA directories restored or
their active registry/magic state retired through the governed process. After
that repair, the safe continuation is:

1. rerun the exact-card magic allocator for the two `41120` slots;
2. verify both rows survive strict resolver regeneration;
3. implement the approved card and one logical `RISK_FIXED` backtest set;
4. run source-level tests, governed strict compile, and Q01;
5. sample the fresh host/tester ceiling and enqueue exactly one Q02 only if
   capacity permits.

## Safety boundary

No manual backtest, terminal or worker control, AutoTrading action, `T_Live`
mutation, deploy or T_Live-manifest change, portfolio-gate change, portfolio
admission, correlation waiver, or decorrelation claim occurred. The backtest
CPU ceiling was not reached; the earlier magic/resolver preflight gate stopped
the build first.
