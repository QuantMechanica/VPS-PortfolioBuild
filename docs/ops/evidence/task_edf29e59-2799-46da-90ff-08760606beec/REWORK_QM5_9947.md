# REWORK QM5_9947 bandy-double-bottom-formalised-mr-index — card-fidelity repair

Task `edf29e59-2799-46da-90ff-08760606beec` (routed to claude, directive
`OWNER-DEC-CLAUDE-CAPACITY-REBALANCE-20260926`). Source review:
`docs/ops/evidence/2026-09-26_family_fix_review_ea/REVIEW_QM5_9947.md`
(REVIEW_FAIL, findings #1/#2/#3/#6 STILL_OPEN; #4 FIXED; #5 SUPERSEDED).

## Baseline note (worktree currency)

This worktree's branch (`agents/claude-orchestration-2`) never had
`framework/EAs/QM5_9947_bandy-double-bottom-formalised-mr-index/` at all —
not predating it with an older copy (as the sibling `QM5_9946` repair found),
but missing the directory outright; `git log --oneline -- <path>` on this
branch returns nothing. The EA was built and reviewed on a different,
ephemeral agent-worktree lineage (`worktree-agent-a77014aa650fd36d1`) that
was never merged into this branch.

I imported the file set directly from the canonical checkout
(`C:/QM/repo/framework/EAs/QM5_9947_bandy-double-bottom-formalised-mr-index/`),
verifying the `.mq5` on-disk sha256 (`b1aa2d2e5108a9a8c74ce0a870005e8a07eb0df9f80a2afb7bc49dd7682bf206`)
matches exactly the hash `REVIEW_QM5_9947.md` traced against the governed
`COMPILE_OK` row (`0ed3980f-1406-4875-8412-79b66bbcbab2`), committed that as
a clean baseline (`a1599f6550`), then applied this task's fixes on top of
it in a second commit (`119d0fdc63`) — both in this worktree only. No files
under `C:/QM/repo` were written; the import was read-only from there.

## Findings repaired

| # | Finding | Fix | Where |
|---|---|---|---|
| 1 | Time stop was wall-clock (`TimeCurrent()-opened >= strategy_max_hold_bars*PeriodSeconds(D1)` = 20 calendar days ≈ 14 D1 trading bars, ~6 bars early) vs card's 20 **completed D1 bars** | Replaced with `QM_TM_HeldPeriods(_Symbol, PERIOD_D1, opened) >= strategy_max_hold_bars` — the framework's restart-safe completed-bar-count helper (same convention as `QM5_9908`/`QM5_9501`); `-1` (unknown history) fails closed against the positive threshold | `Strategy_ExitSignal()`, was L271 |
| 2 | Target installed as an intrabar broker take-profit (`req.tp = ask + pattern_height`); card wants "when `high >= target`, close at next bar's open" | Removed the broker TP (`req.tp = 0.0`); the entry-time target price (`ask + pattern_height`) is encoded into `POSITION_COMMENT` via `req.reason` (`Strategy_EntryReason`/`Strategy_ReadTargetPrice`, `_T=` marker) and checked every tick in `Strategy_ExitSignal` against the last **closed** bar's high (`iHigh(...,1)`), so a touch is acted on at the first tick of the following bar instead of filling intrabar at the TP price | `Strategy_EntrySignal()` was L233/L240; `Strategy_ExitSignal()` |
| 3 | Re-entry guard was a function-static `last_fired_p2_time` (resets on EA restart — late re-entry risk) and fired on any `close > neckline` for an unfired P2 rather than strictly a fresh cross | Replaced the static with a `GlobalVariable` keyed on account/magic/symbol (restart-safe, same idiom as `QM5_10628`'s `Strategy_StateKey`: `Strategy_LastFiredP2Key`/`Strategy_ReadLastFiredP2Time`/`Strategy_WriteLastFiredP2Time`). Added a strict fresh-cross test — reject if the **prior** completed bar's close was already above the neckline — so a stale, already-broken-out P2 cannot fire a late entry days after the actual breakout | `Strategy_EntrySignal()`, was L116/L245 |
| 6 | SPEC.md corruption: (a) slug was a literal backspace control byte (`0x08`) followed by `andy-double-bottom-...`, rendering as `andy-...` instead of `bandy-...`; (b) Risk Model table read `,000 per trade` instead of `$1,000 per trade`; (c) two escaped apostrophes (`Bandy\'s`, `pattern\'s`) | (a) byte-level fix replacing the `0x08` with `b`; (b) text fix to `$1,000 per trade`; (c) un-escaped both to plain `'s` | `SPEC.md` L4, L13, L92 |

No other mechanics touched: symbol universe (13-symbol `.DWX` allow-list via
inputs), pivot/separation/tolerance/depth/regime gates, catastrophic SL
placement, `RISK_FIXED`/`RISK_PERCENT`, and news/Friday-close handling are
unchanged. Card of record:
`D:/QM/strategy_farm/artifacts/cards_approved/QM5_9947_bandy-double-bottom-formalised-mr-index.md`.

## Verification performed (read-only / static — no compile, no terminal64.exe)

- `.mq5` on-disk sha256 after the fix:
  `6640a6ae711e3c8d7fc8d079116ab07965957a7026163e3b737ae4e9b40c746b`.
- Brace/paren balance check on the edited `.mq5`: 29/29 braces, 170/170 parens.
- Line-ending check: file is uniformly CRLF after edits (440/440 lines,
  0 LF-only lines) — no stray LF-only lines introduced by the edit tool.
- `framework/scripts/lint_ea_symbol_literals.py` does not exist on this
  branch (another symptom of the missing-EA baseline above); substituted a
  manual grep for hardcoded `.DWX` literals outside the `strategy_symbol_*`
  input defaults — none found (symbol handling was not touched by this
  task's findings).
- Byte-level hexdump confirmed the SPEC.md slug corruption was a single
  `0x08` backspace byte (not a missing-character typo), and confirmed the
  two apostrophe corruptions were literal `\` + `'` byte pairs.
- Manual card-vs-code trace of all four repaired findings against
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_9947_bandy-double-bottom-formalised-mr-index.md`
  and the `REVIEW_QM5_9947.md` card-rule-wiring table.

## Not done in this pass (governed steps outside this worktree's authority)

- **No compile.** Per standing instruction, `terminal64.exe`/MetaEditor is
  never started manually from this session. The committed `.ex5` in this
  worktree is the imported pre-fix baseline (governed `ex5_sha256`
  `b62fa5b54bafb77956155ca92cdd1f755c1a6ce5b8a615a278e08887a4ff941d`, itself
  already flagged stale by the 2026-09-26 review relative to the on-disk
  canonical binary at the time) and is now additionally stale relative to
  this source change. A governed recompile under `compile_fail_repair`
  authority + binary resync is required before any Q02/pipeline handoff —
  that is the factory build lane's job, not this headless cycle's.
- Set files (`sets/*.set`) were not touched — no parameter defaults changed
  (`strategy_max_hold_bars` default is unchanged; only how the code *uses*
  it, and the new target/comment plumbing, changed).

## Router state transition attempted — blocked on governed-compile identity

Attempted `agent_router.py update-task edf29e59... --state REVIEW`: refused
with `gate_code=D6_BUILD_IDENTITY_MISSING` /
`reason=build_identity_json_missing_review_dispatch_refused`. For
`task_type=build_ea`, the router requires a governed `COMPILE_EA` receipt
binding the new `mq5_sha256` before a task can enter REVIEW.

Investigated the one queuing path the commit guard itself suggested
(`farmctl.py enqueue-compile --build-task-id edf29e59... QM5_9947_bandy-double-bottom-formalised-mr-index`):
refused with `build_task_binding.reason=BUILD_TASK_BINDING_NOT_FOUND` (no
pre-registered binding record exists for this task id) and
`source_repair_authority=null` / `source_repair_authorized=false`.
Separately, and more importantly: this command's `ea_dir` resolves to
`C:\QM\repo\framework\EAs\QM5_9947_bandy-double-bottom-formalised-mr-index`
— the **canonical checkout**, not this worktree — so even a successful call
would not have compiled this worktree's fixed source; it operates on
whatever is currently on disk at `C:/QM/repo`. Per standing instruction
(never write under `C:/QM/repo`; `farmctl.py` runs against the canonical
checkout only) and because the binding lookup fails regardless, no further
enqueue attempts were made and no `--source-repair-authority` grant was
invoked (that mechanism is additionally scoped to repairing a *failed*
predecessor compile — the predecessor `0ed3980f` was `COMPILE_OK`, not a
failure, so it would not apply even if a grant existed; the same reasoning
the sibling `QM5_9946` repair, task `2cdf5e8f`, already established for an
identical refusal).

**Net: the source-level repair is complete, verified, and committed in this
worktree. It cannot be carried to REVIEW from this session** — that requires
the build lane's governed `COMPILE_EA` queue (over the committed
`agents/claude-orchestration-2` source) to produce a receipt binding this
commit's `mq5_sha256`, followed by a binary resync. Router state set to
`BLOCKED` with this evidence path so the compile dependency is visible to
the next routing cycle, rather than forcing a disallowed state transition.
