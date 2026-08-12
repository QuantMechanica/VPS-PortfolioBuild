# CODEX BRIEF — Tranche 12 blind specs (STR-088 / STR-104 / STR-118)

Repo: C:\QM\repo (branch agents/board-advisor). Same methodology as
tranches 2-11.

## Task

Write your INDEPENDENT spec for each strategy. **Blind rule: do NOT
read `01_spec_claude.md` in these dirs.** Read ONLY `00_source.md` and
the ledger row in docs/ops/source_harvest/SOURCE_LEDGER.csv.

Dirs (write `02_spec_codex.md` into each):

1. `docs/ops/source_harvest/strategies/STR-088-4x25ma-mtf-trend/`
   — FF thread 932507, foff00: 25EMA on M15/H1/H4/D1 alignment, H4
   execution, ATR(14) 2x SL / 3-4x TP, London-to-NY-close session.
2. `docs/ops/source_harvest/strategies/STR-104-macd-bb-campaign-m5/`
   — babypips 1266726, Eliteforexpartner 2024: M5 campaign state
   machine — MACD(6,17,1) zero-line campaigns, BB(10, shift 1,
   dev 0.66) pullback, breakout stop entry, three exit methods.
3. `docs/ops/source_harvest/strategies/STR-118-ichimoku-atr-cloud-d1/`
   — babypips 18242, unhommefou's mechanized Ichimoku simplification
   (posts #25-36): Tenkan/Kijun + cloud + ATR-distance filter, D1.
   NOTE: his 3-lot ATR scale-in is stacking (house-banned) — handle
   explicitly; his walk-forward setting claim on p.9 matters.

## Also: STR-096 retirement confirmation

STR-096 (forexfactory_1394867 mirror) was retired 2026-07-25 as an
intra-ledger duplicate of STR-027 → QM5_20109 (same thread 1394867,
same cluster CL-02, built tranche 4). CONTEST OR CONFIRM in one
paragraph of your delivery (read the STR-027 dir + QM5_20109 SPEC if
needed). If you contest, state the concrete rule delta.

## Spec format

As tranches 2-11: numbered mechanized closed-bar rules, cohort + TF,
inputs with defaults, V5 five-hook sketch, every interpretation beyond
the literal source FLAGGED. House constraints: no martingale/grid/ML/
stacking; one position per magic; RISK_FIXED backtest / RISK_PERCENT
live ≤1%; no invented commission/swap/DST values; broker time NY-close
GMT+2/+3, UTC anchors via QM_BrokerToUTC.

## Delivery

Commit the three 02_spec_codex.md files with pathspecs, then
update-task to REVIEW with artifact paths. Final line:
`T12_SPECS_DONE: <paths> | STR-096: CONFIRMED|CONTESTED`
