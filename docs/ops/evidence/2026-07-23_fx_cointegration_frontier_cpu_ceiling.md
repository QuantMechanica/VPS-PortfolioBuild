# FX Cointegration Frontier / CPU-Ceiling Stop — 2026-07-23

Mission: add one non-duplicate, low-frequency forex sleeve from the 66-pair
cointegration scan, or advance an existing forex card when no unbuilt pair
remains.

## Read-only findings

- The controlling scan is
  `docs/research/CROSS_ASSET_FX_DISCOVERY_2026-06-09.md`. Its strict survivors
  are `QM5_12532` AUDUSD/NZDUSD and `QM5_12533` EURJPY/GBPJPY.
- Both anchors have repaired logical-basket Q02 PASS evidence. `QM5_12532`
  subsequently passed Q04 and failed Q05; `QM5_12533` subsequently failed
  Q04. Historical component-leg `ONINIT`, `NO_HISTORY`, and `INVALID` rows are
  superseded and are not grounds for duplicate Q02 work.
- The approved FX-cointegration card inventory contains no card without a
  matching EA directory and `basket_manifest.json`. The extended formal
  survivor `QM5_13062` AUDCAD/EURUSD is also already built and reached Q02
  PASS, Q03 PASS, Q04 FAIL.
- Therefore no reputable-source, non-duplicate unbuilt scan pair is available
  to card or mechanize in this turn.

## Concrete fallback and stop condition

The fallback lane was evaluated against existing low-frequency D1 forex work.
No new work item was inserted: the farm already reports 2,726 pending rows and
9/9 enabled terminal workers active (T5 is intentionally parked). This is the
configured paced-fleet CPU ceiling. Per the mission stop rule, no dispatcher
tick, queue-priority mutation, MT5 launch, compile, or backtest was attempted.

The next safe action after capacity frees is deterministic queue execution of
an existing non-terminal D1 forex Q02 row, after de-duplicating it against any
later-phase or terminal verdict for the same EA/symbol. Creating another
cointegration card from the exhausted scan would be duplicate or below the
documented research threshold.

## Reproduction

```powershell
python tools/strategy_farm/farmctl.py work-items --ea QM5_12532
python tools/strategy_farm/farmctl.py work-items --ea QM5_12533
Get-Content D:/QM/strategy_farm/state/health.json -Raw
```

The inventory comparison used `strategy-seeds/cards/approved` as the card
source and required both `framework/EAs/QM5_<id>_<slug>` and
`basket_manifest.json` for every approved FX-cointegration card.

## Safety boundary

No `T_Live` or AutoTrading state was touched. No portfolio-admission,
portfolio KPI, Q08-contribution, portfolio-gate, deploy-manifest, registry,
card, EA source, setfile, or runtime database was modified.

