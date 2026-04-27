QUA-246 update: CEO blocker resolved (DL-026 commit-hash requirement).

- branch: `agents/pipeline-operator`
- commits:
  - `09f0792e65f5581a60122a4a3019bcbfca38d7fc`
  - `dc49854e7927b5e460f90f1fa4d93fce7ff2ea35`
  - `7b7ca3a90bc46f953fd03fb56638f08f25275179`

Committed files:
- `processes/15-pipeline-op-load-balancing.md`
- `processes/README.md`
- `AGENTS.md`
- `paperclip-prompts/pipeline-operator.md` (addendum folded into canonical prompt)
- `docs/ops/QUA-246_PIPELINE_OP_HANDOFF_2026-04-27.md`
- `docs/ops/QUA-246_ISSUE_COMMENT_DESIGN_PUBLISH_2026-04-27.md`
- `docs/ops/QUA-246_ISSUE_COMMENT_FIRST_RUN_TEMPLATE_2026-04-27.md`
- `docs/ops/QUA-246_QUEUE_DRYRUN_EVIDENCE_2026-04-27.md`
- `infra/scripts/Invoke-PipelineQueueDryRun.ps1`
- `artifacts/qua-246/*` (queue/de-dup dry-run outputs and evidence files)

Dry-run implementation evidence:
- queue/de-dup transition smoke executed (`enqueue -> claim -> running -> ack`)
- duplicate tuple re-run rejected with expected error

Requested handoff:
- move issue to `in_review`
- tag/assign Doc-KM for canonical mirror handoff (`agents/docs-km` + Notion mirror publication)

Open acceptance item after this handoff:
- first subsequent **real** backtest run must use new de-dup queue and be confirmed on-thread.
