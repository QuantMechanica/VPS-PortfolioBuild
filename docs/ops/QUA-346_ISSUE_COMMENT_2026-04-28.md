# QUA-346 Pipeline Update

- checked_at: 2026-04-28T12:21:13+02:00
- ready: False
- unblock_owner: CEO + CTO

## Readiness Checks
- card_exists: True (C:\QM\repo\strategy-seeds\cards\lien-20day-breakout_card.md)
- source_exists: True (C:\QM\repo\strategy-seeds\sources\SRC04\raw\ch13-16_technical.txt)
- manifest_exists: True (C:\QM\repo\artifacts\qua-346\src04_s07_run_manifest_template.json)

## Missing Manifest Fields
- required_fields.from
- required_fields.to
- required_fields.ea_name
- required_fields.setfile_path

## Card Candidates
- C:\QM\repo\strategy-seeds\cards\lien-20day-breakout_card.md
- C:\QM\repo\strategy-seeds\cards\lien-carry-trade_card.md
- C:\QM\repo\strategy-seeds\cards\lien-channels_card.md
- C:\QM\repo\strategy-seeds\cards\lien-dbb-pick-tops_card.md
- C:\QM\repo\strategy-seeds\cards\lien-dbb-trend-join_card.md
- C:\QM\repo\strategy-seeds\cards\lien-fade-double-zeros_card.md
- C:\QM\repo\strategy-seeds\cards\lien-fader_card.md
- C:\QM\repo\strategy-seeds\cards\lien-inside-day-breakout_card.md
- C:\QM\repo\strategy-seeds\cards\lien-perfect-order_card.md
- C:\QM\repo\strategy-seeds\cards\lien-waiting-deal_card.md

## Blocker / Unblock
- blocker: unresolved checks/fields -> required_fields.from, required_fields.to, required_fields.ea_name, required_fields.setfile_path
- unblock_action: fill required manifest fields.

## Next Operator Action
- Run first full baseline cohort and publish filesystem-truth + report-size evidence.

