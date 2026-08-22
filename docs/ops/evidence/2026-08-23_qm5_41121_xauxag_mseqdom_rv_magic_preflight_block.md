# QM5_41121 XAU/XAG sequence-dominance reversion - magic preflight block

Date: `2026-08-23`

Branch: `agents/board-advisor`

Outcome: **SOURCE AND G0 CARD COMMITTED; EA-ID RESERVED; MAGIC ALLOCATION
ROLLED BACK; BUILD NOT STARTED; Q02 NOT ENQUEUED**

## New edge completed upstream

`QM5_41121_xauxag-mseqdom-rv` is a new low-frequency, opposite-leg
gold/silver relative-value proposal. On the first synchronized D1 boundary of
a broker month it reconstructs the immediately completed 17-to-23-session
calendar month from synchronized `XAUUSD.DWX` and `XAGUSD.DWX` closes.

For chronological gold-minus-silver log-ratio returns, it exhaustively counts
same-sign adjacent transitions as sequences and opposite-sign transitions as
reversals. A month qualifies when sequences are greater than or equal to
reversals. Positive net ratio displacement maps to SELL XAU / BUY XAG;
negative displacement maps to BUY XAU / SELL XAG. Exact-zero, malformed, and
non-qualifying months are consumed without entry.

The intended package targets equal absolute notionals, one aggregate
`RISK_FIXED=1000` stop-risk budget, frozen 3.5-ATR hard stops on both legs,
atomic broken-package repair, and a first-later-month or 40-day stale exit.

This is not `QM5_20275` terminal five-return run fading, `QM5_41078` weekly
three-bar streak fading, `QM5_41112` unordered monthly sign breadth,
`QM5_41113`/`QM5_41116` block voting, `QM5_41120` fixed-open residence, or a
rolling ratio/z-score signal. The canonical pre-allocation checker returned
`CLEAN` across 4,620 registry rows, 1,289 cards, and 45 Strategy-Wiki nodes.
Post-allocation evidence contains only the expected `QM5_41121` strategy-ID
and slug self-hits.

## Reputable-source and identity commits

| Stage | Commit |
|---|---|
| source approval and pre-allocation dedup | `91e138677` |
| bounded peer-reviewed/exchange extraction | `b7cd42641` |
| atomic EA-ID reservation | `9b19a5024` |
| approved G0 card and post-allocation review | `4e1c0d698` |

The source lineage is Schweikert (2018), *Journal of Banking & Finance* 88,
44-51, DOI `10.1016/j.jbankfin.2017.11.010`; Yaya, Vo, and Olayinka (2021),
*Resources Policy* 72, 102045, DOI `10.1016/j.resourpol.2021.102045`; Cowles
and Jones (1937), *Econometrica* 5(3), 280-294, DOI `10.2307/1905515`; and CME
Group's *Gold & Silver Ratio Spread*. Those records support the related-metal
carrier and sequence/reversal vocabulary, not the untested cross-asset
direction translation, CFD mapping, performance, neutrality, or portfolio
correlation.

The atomic registry allocator reserved EA ID `41121` for strategy ID
`SCHWEIKERT-COWLES-CME-XAUXAG-MSEQDOM-RV-2026_S01`. Card schema lint passed
with no missing section and no forbidden-library hit.

## Deterministic build-preflight failure

The exact-card dry run of `governed_magic_allocator.py` selected only
`QM5_41121`, planned slot 0 `XAUUSD.DWX` / magic `411210000` and slot 1
`XAGUSD.DWX` / magic `411210001`, and reported the candidate eligible.

The apply run then failed closed during canonical resolver regeneration because
three unrelated active registry identities have no EA directory:

- `QM5_1001_breakout-atr`
- `QM5_1015_lien-perfect-order`
- `QM5_1016_lien-carry-trade`

Repository history confirms that none of those three directories has ever
been tracked; this is not sparse-checkout loss or an accidental deletion in
this worktree. `update_magic_resolver.py` classified their active rows as
bindings that would be dropped and refused to replace `QM_MagicResolver.mqh`
under its strict default. The allocator rolled back atomically. Machine
receipts:

- `artifacts/qm5_41121_magic_allocation_dryrun_20260823.json`
- `artifacts/qm5_41121_magic_allocation_20260823.json`

Post-failure verification proved:

- zero `41121` rows in `framework/registry/magic_numbers.csv`;
- no `QM5_41121_xauxag-mseqdom-rv` EA directory;
- no `411210000` or `411210001` entry in the resolver;
- no diff in `magic_numbers.csv` or `QM_MagicResolver.mqh`;
- the current resolver still contains the legacy `10010000`, `10150000`, and
  `10160000` bindings.

The `--allow-dropped` recovery escape hatch was not used. It would remove
bindings currently present in the resolver and therefore is not a
behavior-preserving workaround. Empty placeholder directories, hand-written
magic rows, and manual resolver edits were also rejected because they would
conceal or bypass the deterministic gate.

## Binding skill stop and safe continuation

The `qm-build-ea-from-card` preflight requires active magic rows for every
declared `(ea_id, symbol_slot)` pair before source implementation. That gate is
absent, so no EA skeleton, source, setfile, compile request, backtest, or Q02
row was created.

A separately authorized registry-inventory repair must first decide whether
IDs `1001`, `1015`, and `1016` should have real EA directories built or their
active registry/magic state retired through the governed process. After that
repair, the safe continuation for this sleeve is:

1. rerun the exact-card magic allocator for both `41121` slots;
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
