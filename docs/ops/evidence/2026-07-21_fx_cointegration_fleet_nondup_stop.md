# FX cointegration fleet non-duplication / CPU-ceiling stop — 2026-07-21

## Mission

Mechanize one unbuilt next-best pair from the OWNER-requested 66-pair FX
cointegration scan, or advance an existing forex card. Do not duplicate an
existing build and stop at the backtest CPU ceiling.

## Filesystem and research verdict

- `docs/research/MULTICURRENCY_STRATEGY_SURVEY_2026-07-15.md` records that the
  seven qualifying sign-aware scan rows are already represented as cards/EAs.
- The filesystem contains the original positive-beta anchors `QM5_12532` and
  `QM5_12533`, the subsequent sign-aware scan lineage, and the later all-sign
  strict survivors through `QM5_13106` and `QM5_13117`.
- `strategy-seeds/cards/aud-eurgbp-coint_card.md` identifies `QM5_13106` as the
  highest OOS-ranked strict row not already built after the two anchors,
  `QM5_12978`, and `QM5_13003`. Its EA, EX5, RISK_FIXED setfile, and
  `basket_manifest.json` already exist.

Creating another card from the scan would therefore be duplicate work, not a
new forex sleeve.

## Live farm verdict

Read-only queries against
`D:/QM/strategy_farm/state/farm_state.sqlite` established:

- `QM5_12532`: logical-basket Q02 PASS, Q04 PASS, Q05 FAIL.
- `QM5_12533`: logical-basket Q02 PASS, Q04 FAIL.
- `QM5_13106`: Q02 PASS, Q03 PASS, Q04 FAIL.
- `QM5_13117`: Q02-Q07 PASS lineage, later Q08 FAIL_HARD.
- The other scan-lineage builds inspected have terminal downstream failures;
  none is an untested build awaiting its first Q02 enqueue.
- The farm already has a large pending FX Q02 backlog and active terminal work.
  Eight `terminal64` processes were present at the stop check. The read-only
  `farmctl mt5-slots` / `health` call itself exceeded its 30-second command
  ceiling, consistent with a saturated factory control path.

## Action

No duplicate card, EA, work item, portfolio-gate change, or T_Live change was
made. No terminal was started or stopped. In accordance with the mission's
explicit CPU-ceiling instruction and the OWNER-ratified recovery rule against
queue flooding, work stopped without another enqueue.

## Next valid action

Wait for existing FX work to clear terminal capacity, then select a genuinely
non-terminal forex card from live farm state. Do not reopen the exhausted
66-pair cointegration lineage without a new OWNER-approved source or scan
contract.
