# Unblock triage for 25 preflight-refused builds

Date: 2026-07-27  
Task: `9743ea84-6685-4f5c-bae9-97d4fdb808b4`

## Result

The preflight refusal was correct, but its “card body incomplete” finding is
now stale for all 25 cards: direct execution of
`farmctl._verify_card_body_coverage()` and
`farmctl.strategy_card_schema_issues()` against the approved files returned no
missing fields for every card. All 25 still had zero anchored magic rows before
this task.

Four cards have exact durable source lineage and are `FIXABLE`. Their canonical
EA directories were reserved first, then 19 active magic rows were appended,
then `QM_MagicResolver.mqh` was regenerated. No EA was built and no work item
was enqueued.

Twenty-one cards are not eligible for magic registration: one duplicate, two
with source records absent from the source registry, and eighteen recovery
cards attributed to a source note that explicitly says it produced zero cards
and rejected these families. One of the eighteen is also a prohibited bounded
grid.

## Triage

| EA | Slug | Approved card | Missing / conflict | Disposition |
|---:|---|---|---|---|
| 11212 | ft-cmcwinner | `cards_approved/QM5_11212_ft-cmcwinner.md` | magic only; exact candidate recorded in source note | FIXABLE |
| 11213 | ft-cofibit | `cards_approved/QM5_11213_ft-cofibit.md` | magic only; exact candidate recorded in source note | FIXABLE |
| 11214 | ft-clucmay | `cards_approved/QM5_11214_ft-clucmay.md` | magic only; exact candidate recorded in source note | FIXABLE |
| 11897 | vegas-wave-ema144-169-fractal-h1-alt | `cards_approved/QM5_11897_vegas-wave-ema144-169-fractal-h1-alt.md` | duplicate family: 11377, 11451, 11850 already approved; source ID absent from `sources` | RETIRE |
| 12351 | alp-ema12-26 | `cards_approved/QM5_12351_alp-ema12-26.md` | magic only; exact candidate recorded in source note | FIXABLE |
| 13208 | mulham-4h-sweep-fvg | `cards_approved/QM5_13208_mulham-4h-sweep-fvg.md` | `YT-MULHAM-2026-07` absent from `sources`; no verifiable URL in card | NEEDS-SOURCE |
| 13211 | mulham-tgif-weekly-fade | `cards_approved/QM5_13211_mulham-tgif-weekly-fade.md` | `YT-MULHAM-2026-07` absent from `sources`; no verifiable URL in card | NEEDS-SOURCE |
| 20070 | antor-mtf-macd-scalper-r1-recovery | `cards_approved/QM5_20070_*.md` | source note records zero drafted candidates | RETIRE |
| 20071 | channel-cci-bollinger-mr-r1-recovery | `cards_approved/QM5_20071_*.md` | source note records zero drafted candidates | RETIRE |
| 20072 | 4h-box-frankfurt-london-r1-recovery | `cards_approved/QM5_20072_*.md` | source note rejects anonymous Frankfurt breakout family | RETIRE |
| 20073 | pip-hunter-heiken-ashi-r1-recovery | `cards_approved/QM5_20073_*.md` | source note records zero drafted candidates | RETIRE |
| 20074 | trendline-horizontal-sr-retest | `cards_approved/QM5_20074_*.md` | source note records zero drafted candidates | RETIRE |
| 20075 | camarilla-inner-pivot-fade | `cards_approved/QM5_20075_*.md` | source note records zero drafted candidates | RETIRE |
| 20076 | trendline-diagonal-break-retest | `cards_approved/QM5_20076_*.md` | source note records zero drafted candidates | RETIRE |
| 20077 | atr-channel-trail-breakout-h1 | `cards_approved/QM5_20077_*.md` | source note records zero drafted candidates | RETIRE |
| 20078 | volume-profile-poc-retest-intraday | `cards_approved/QM5_20078_*.md` | source note records zero drafted candidates | RETIRE |
| 20079 | pip-boxer-bounded-grid-h1 | `cards_approved/QM5_20079_*.md` | source note records zero candidates; grid prohibited | RETIRE |
| 20080 | goodman-wave-theory-intersection-h1 | `cards_approved/QM5_20080_*.md` | source note records zero drafted candidates | RETIRE |
| 20081 | renko-triple-block-flip-h1 | `cards_approved/QM5_20081_*.md` | source note records zero drafted candidates | RETIRE |
| 20082 | connors-rsi2-pullback-h4 | `cards_approved/QM5_20082_*.md` | source note records zero drafted candidates | RETIRE |
| 20085 | lebeau-lucas-momentum-oscillator-h4-r1-recovery | `cards_approved/QM5_20085_*.md` | source note records zero drafted candidates | RETIRE |
| 20086 | connors-multi-day-high-low-h4-r1-recovery | `cards_approved/QM5_20086_*.md` | source note records zero drafted candidates | RETIRE |
| 20087 | carney-three-drives-h4-r1-recovery | `cards_approved/QM5_20087_*.md` | source note records zero drafted candidates | RETIRE |
| 20088 | carney-crab-pattern-h4-r1-recovery | `cards_approved/QM5_20088_*.md` | source note records zero drafted candidates | RETIRE |
| 20089 | hopwood-ts4-standalone-h4-r1-recovery | `cards_approved/QM5_20089_*.md` | source note explicitly rejects Hopwood cluster as weak/duplicate | RETIRE |

Card paths above are under
`D:/QM/strategy_farm/artifacts/cards_approved/`. No approved card was edited.

## Source evidence

- `1580128f-...` source note lines 368-380 names 11212, 11213 and 11214
  and states their exact mechanics.
- `72f9fcfa-...` source note lines 3286-3320 names 12351, its EMA(12/26)
  mechanic, and its drafted card.
- `6e967762-...` source note says “None drafted as new cards,” rejects the
  anonymous breakout families, and explicitly rejects the Hopwood cluster.
- A direct `sources` query returned no row for the Vegas source UUID or
  `YT-MULHAM-2026-07`.

## Governed registrations

Directories were created first as explicit build-pending reservations:

- `framework/EAs/QM5_11212_ft-cmcwinner/`
- `framework/EAs/QM5_11213_ft-cofibit/`
- `framework/EAs/QM5_11214_ft-clucmay/`
- `framework/EAs/QM5_12351_alp-ema12-26/`

Magic rows:

| EA | Slots | Symbols |
|---:|---:|---|
| 11212 | 0-3 | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX |
| 11213 | 0-3 | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX |
| 11214 | 0-3 | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX |
| 12351 | 0-6 | EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, XAUUSD.DWX, GER40.DWX, NDX.DWX, WS30.DWX |

Each magic is `ea_id * 10000 + symbol_slot`. Anchored row counts after the
change are 4, 4, 4, and 7 respectively.

## Verification

- Card body coverage: PASS, 25/25.
- Card schema issues: PASS, 25/25.
- Pre-change anchored magic counts: zero, 25/25.
- `python framework/scripts/update_magic_resolver.py`: PASS; 15,229 rows
  emitted, registry SHA embedded.
- Focused check: all 19 new CSV rows exist exactly once and all 19 resolve in
  `QM_MagicResolver.mqh`.
- `python framework/scripts/validate_registries.py`: global FAIL from extensive
  pre-existing registry debt (including malformed legacy EA IDs/slugs and
  orphaned rows). No reported issue names 11212, 11213, 11214 or 12351.

The four `FIXABLE` builds are unblocked at the governed prerequisites and must
return through the serial normal build lane. This task does not claim a build,
compile, smoke, pipeline, or profitability verdict.
