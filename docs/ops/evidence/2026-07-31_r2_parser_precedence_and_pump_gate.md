# R2 — Q08 ablation precedence, pump gate, and Rule 11 proposal

Date: 2026-07-31

Router task: `90b16af2-8573-4245-ac77-429bd24a21de`

## Verdict

The three requested changes are implemented in separate path-scoped commits:

- `ba13af972` — exact markerless Q08 ablation-child precedence;
- `7bd303931` — 1,800-second restart-health bound spanning Pump retries;
- `133c4811b` — unratified Rule 11 hunk moved to a proposal.

No Factory, task, process, flag, terminal, queue, work-item, or live-state
mutation was performed.

## 1. Markerless ablation precedence

`parse_setfile_assignments` now accepts duplicate markerless strategy keys only
for this exact structural contract:

1. one contiguous base `strategy_` block;
2. exactly one generated `; --- ablation child NN ... ---` separator;
3. one contiguous override block;
4. identical, internally unique key sets in both blocks.

The returned metadata uses the second-block rows, implementing the MT5 Tester
last-value-wins behavior. Unequal sets, more than two blocks, an in-block
duplicate, an unrelated separator, or a split/nested override remain
fail-closed. Files with the strategy-section marker retain their prior parser
path and still reject duplicates.

### Immutable setfile SHA table and parsed override values

| File | SHA-256 (raw bytes) | Count | Parsed values in key order |
|---|---|---:|---|
| Base | `082028275fbb0870d5e0665f5c3131d2d360bb8ff36597aada955c3692eb9d04` | 6 | `1, 2, 14, 2.0, 1.5, 80` |
| Ablation 00 | `8d47c4cc8191e067af31920bceb3cdcb1af2ebea63b4ddb8df954b9a975cb4f3` | 6 | `1, 2, 16, 2.086268, 1.408344, 96` |
| Ablation 01 | `f2bf459a3255c09eaf4b2333d870eb1a7d06462132c18e0d85dc3a06ac73d5d6` | 6 | `1, 2, 14, 1.947944, 1.550112, 73` |
| Ablation 02 | `477bc9142a10fc09e590d32aad14e056af0710d520f35882525313e4babc6cf1` | 6 | `1, 2, 15, 1.946532, 1.303297, 67` |

Key order is `strategy_fast_ema_period`, `strategy_slow_ema_period`,
`strategy_atr_period`, `strategy_atr_sl_mult`,
`strategy_take_profit_rr`, `strategy_max_spread_points`. All three child
metadata records point to override lines 28–33. The setfile hashes are unchanged
from the prior exception contract.

Parser source SHA-256, UTF-8 text with LF normalization:
`6890b1ce1b99d2fc0be6cfb1ba3a4f0dd5a76c233448d10f4c5f1c039e5311d6`.

The existing Q08 single-target exception artifact still binds the superseded
parser commit/hash. It was intentionally not rewritten under this ticket and
therefore remains ineligible for apply until Claude review explicitly rebinds
and approves the new parser identity. No requalification was attempted.

## 2. Pump restart-health gate

`Factory_ON.ps1` now again sets
`$factoryPostStartHealthTimeoutSeconds = 1800`, and
`factory_restart_health.ps1` accepts `[ValidateRange(1, 1800)]`.

The measured comment remains binding: 13 substantive Pump runs had p50
550.203 seconds, p75 599.982 seconds, and five reached the 600-second ceiling.
That makes first-attempt success unreliable under load. The 1,800-second wait
can span the five-minute retry cadence, while the existing success check exits
immediately on the happy path. This is only a source change; Factory was not
cycled or touched.

Source identities (UTF-8 text, LF-normalized SHA-256):

- `Factory_ON.ps1`:
  `0697be1bf16c99fd79cb93fdb6eb35efa5c5bd38fc248d648dfe9b8fed54b9e7`
- `factory_restart_health.ps1`:
  `e1ca8e846f50cdcc02be4dbe1bd7b12e6eeadab06c9323a54ad59a5222dee1a6`

As the brief states, the runtime decision/source rebind required before a
future Factory ON is a separate operation and was not performed here.

## 3. Rule 11 disposition

No OWNER ratification note for the kill-recorder amendment was present in
`docs/ops/CONVERGENCE_LEDGER_WEEKEND_2026-07-31.md` during this ticket.
Accordingly:

- `docs/ops/OPERATING_RULES_2026-07-03.md` was restored exactly to its
  pre-amendment ratified blob
  `9fe3b2fef49c5f022fef5f18f73fa59f8c18bae0`;
- the proposed mandatory-recorder text now lives at
  `docs/ops/proposals/2026-07-31_rule11_kill_recorder_amendment.md`, explicitly
  marked non-authoritative pending OWNER ratification;
- `manual_process_kill_evidence.py` and its tests were not changed.

## Verification

- Combined Python suite: `161 passed in 17.03s`.
- PowerShell restart-health suite: `PASS` (22 assertions).
- Direct parsing of the three real 10582 ablations: 6/6 assignments each,
  override values and line numbers confirmed.
- Negative parser fixtures: unequal keys, triple block, in-block duplicate,
  unrelated separator, split override, and marker-file duplicate all refused.
- `git diff --check`: PASS for each commit scope.
- Operating Rules current Git blob equals the pre-amendment ratified blob:
  PASS.

No setfile bytes, EA source/binary, news-calendar guard, risk setting, pipeline
verdict, T5, T_Live, or AutoTrading state changed.
