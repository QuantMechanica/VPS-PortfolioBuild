# MT5 local-agent optimizer lane — pass-level evidence contract

Date: 2026-09-12  
Router task: `cbacb01b-2911-46a4-954d-573c59037d8a`  
Status: **REVIEW — CONTRACT_ONLY; LANE DEFAULT-OFF AND PRE-SCREEN-ONLY**

## Decision

An MT5 optimizer pass using `Model=4` can execute the real-tick model, but the
standard optimizer XML/cache row is **not equivalent to a governed single-cell
real-tick receipt**. It does not expose the current receipt's per-pass native
HTML report bytes, canonical closed-trade bytes, entry trading days,
authenticated logger sample, or an independently authenticated real-tick
marker. Therefore optimizer passes cannot enter `MEASURED`, affect a pipeline
verdict, or enter the success counter under the current evidence contract.

The proposed lane remains `PRESCREEN`-only unless a future canary recovers every
field below and proves exact pass-versus-single-cell parity. A future new
contract could admit a pass as `MEASURED` only after that proof and separate
OWNER approval. This document does not provide either approval and changes no
verdict, threshold, gate, queue row, terminal, or runtime configuration.

References:

- `docs/ops/evidence/3e129337_v4b_mt5_native_optimizer_feasibility_2026-08-27.md`
  records the standard pass-export gaps and the binary-changing instrumentation
  alternative.
- `docs/ops/evidence/2026-09-11_v4a_resident_backend.md` records that native
  optimization is the only documented multipass MT5 surface available, while
  the current cold receipt requires field and byte parity.
- `tools/strategy_farm/warm_cell_runner.py` defines the current exact comparison,
  including trade rows, entry days, logger sample, native report, and receipt
  schema.
- MetaQuotes' platform-start documentation defines `Optimization=1`, `Model=4`,
  and local/remote/cloud agent switches; its MetaTester documentation describes
  agent isolation and remote-agent logging limitations. The source links are
  preserved in the two evidence documents above.

## Pass identity contract

One immutable pass identity is the canonical serialization and SHA-256 of all
fields in this table. Display labels or optimizer row numbers are not identity.

| Group | Required fields | Refusal condition |
|---|---|---|
| EA build | `ea_id`, expert path, MQ5 SHA-256, EX5 SHA-256, include-closure SHA-256, compile receipt/build identity | Missing hash, on-disk mismatch, stale compile receipt, or mutable/unresolved path |
| Strategy parameters | complete normalized parameter map, source setfile bytes and SHA-256, optimized input names/ranges, resolved per-pass values, parameter-map SHA-256 | Missing input, duplicate key, invalid range member, value not reconstructible from the pass row, or setfile mismatch |
| Cell axes | symbol, timeframe, `from_date`, `to_date`, tester `Model`, deposit, currency, leverage, execution mode, forward mode/split, deterministic seed where applicable | Any ambiguity, implicit default, wrong window, or `Model != 4` for a proposed `MEASURED` pass |
| Market data | custom/native symbol identity, digits/tick-size contract, history-manifest path and SHA-256, selected history-file hashes, MT5 terminal and tester build hashes | Unsigned/missing history, build drift, symbol metadata drift, or shared mutable history outside the approved isolated projection |
| Costs | commission-group bytes and SHA-256, spread mode/value, swap basis, execution-delay/slippage settings, restoration receipt | Cost schedule absent, hash mismatch, zero-cost inference, or failure to restore the canonical group |
| Optimizer job | immutable INI bytes/SHA-256, optimization setfile bytes/SHA-256, complete/genetic mode, local-agent allowlist, agent ports, job/session token, job manifest SHA-256 | Genetic/non-exhaustive search where complete enumeration is declared, remote/cloud agent enabled, reused token/port, or job manifest mismatch |
| Pass key | optimizer job SHA-256, MT5 pass identifier, parameter-map SHA-256, canonical cell key, attempt number | Collision, duplicate accepted attempt, orphan pass, or pass count/range disagreement |

Every artifact is append-only below one unique research run root. A manifest
must list path, byte length, SHA-256, producer, and production timestamp for
every file. The manifest hashes itself through the repository's established
self-hash convention. No later run may overwrite or complete an earlier pass.

## Required per-pass evidence

| Evidence surface | Required content | Comparison against governed single-cell reference |
|---|---|---|
| Native execution report | Full native report bytes and SHA-256, not only the aggregate optimizer XML row | Byte-exact after using the same native report producer; standard optimizer XML alone refuses |
| Canonical trades | Ordered closed-position/deal records with time, side, volume, price, commission, swap, profit, magic, ticket linkage, and canonical serialization SHA-256 | Byte-exact canonical stream and equal row count |
| Entry evidence | Ordered entry timestamps and derived distinct `entry_trading_days` | Exact timestamps after declared normalization and equal day count |
| Logger sample | Fresh structured sample, authenticated to EA/schema/version, cell/pass key, magic, symbol, timeframe, and run interval | Byte-exact canonical sample and valid freshness envelope |
| Tester metrics | net profit, gross profit/loss, trade/deal counts, profit factor, expected payoff, balance/equity drawdown absolute and percent, Sharpe where emitted, modeling/history errors | Every required numeric field equal under the existing cold-receipt tolerance; missing/NaN is refusal, never zero-filled |
| Model proof | Tester INI bytes/SHA-256 with `Model=4`, pass binding, tester journal/model marker, and evidence class | All independent bindings agree on `REAL_TICKS`; declaration alone is insufficient |
| Receipt schema | Complete field-path list and schema SHA-256 | Exact schema fingerprint |
| Resource/isolation receipt | Before/during/after PID inventory, CPU/RAM series, terminal root, agent allowlist/ports, job-object membership, exit codes, and untouched protected-state hashes | No foreign process, unexplained child, protected-state delta, or missing interval |

An optimizer aggregate row may additionally be retained for reconciliation, but
it is never the authoritative source when the pass-level native/trade/logger
artifacts disagree.

## Canary parity gate

Before any optimizer pass can be proposed as `MEASURED`:

1. Register at least 20 immutable, authenticated, successful single-cell
   `Model=4` references spanning the intended EA/input families, symbols,
   windows, trade/no-trade outcomes, and cost groups.
2. Run the identical configurations as complete local-agent optimizer passes in
   a disposable research seat. No production worker or work-item claim may be
   reused.
3. Require 20/20 identity matches, native-report matches, canonical-trade-byte
   matches, entry-day matches, logger matches, receipt-schema matches, and
   metric matches. One mismatch or missing artifact rejects the lane.
4. Repeat the complete optimizer job once from an empty private cache and
   require identical pass identities and evidence hashes. Cache hits may be
   measured separately but cannot establish determinism.
5. Publish timing and resource evidence. Throughput benefit is descriptive and
   cannot waive parity.
6. Obtain a separate OWNER-signed activation that names the exact adapter,
   schema, tester build, terminal seat, programs, and rollback. Until then the
   adapter must emit `PRESCREEN` only.

The current standard optimizer cannot pass step 3 because it does not produce
several required per-pass artifacts. EA-side frame/file instrumentation might
recover them, but it changes the binary and must itself be compiled, identity-
bound, adversarially reviewed, and compared against new single-cell references.
It is a future canary design, not evidence supplied by this ticket.

## Isolation and resource guards

The prospective lane is Default-OFF and may use only an OWNER-approved research
seat (initially T11 or T12), never T1–T10, T_Live, or an FTMO terminal.

- `UseLocal=1`, `UseRemote=0`, `UseCloud=0`; unique fixed local-agent ports and
  an exact executable-path allowlist are mandatory.
- One session token owns the terminal, all local agents, the unique output root,
  and a kill-on-close job object. A foreign process, live lease, reused port, or
  existing output root refuses before launch.
- Maximum two seat-scoped MetaTester agents, matching the current
  `research_canary.py` admission range. The controller must continuously prove
  the executable path belongs to that research seat.
- Preflight and continuous host CPU must remain at or below 95% by default, and
  available RAM at or above 20 GiB, matching the current canary defaults. A
  documented narrower OWNER-approved override may be stricter, never implicit.
  Crossing either boundary stops new passes and performs governed teardown; it
  does not interrupt unrelated T1–T10 work.
- Factory-off state, disabled-terminal declarations, history isolation,
  terminal build, symbol catalog, cost group, AutoTrading state, and protected
  directory hashes are recorded before and after. Any unexplained delta refuses
  the full run.
- The controller must not write `farm_state.sqlite`, claim production work,
  change a verdict/counter, enable a worker, toggle AutoTrading, or write to
  T_Live. Promotion is a separate reviewed import of immutable evidence.

## Refusal taxonomy

The adapter fails closed with one stable reason and retains the partial evidence
without a verdict:

| Reason | Trigger |
|---|---|
| `OPT_PASS_IDENTITY_INCOMPLETE` | Any identity field/hash is missing, ambiguous, or mismatched |
| `OPT_PASS_NOT_REAL_TICKS` | `Model=4` is not independently authenticated |
| `OPT_PASS_NATIVE_REPORT_MISSING` | Per-pass native report bytes are unavailable |
| `OPT_PASS_TRADES_MISSING_OR_DIFFERENT` | Canonical trade stream is absent or differs |
| `OPT_PASS_ENTRY_DAYS_MISSING_OR_DIFFERENT` | Entry timestamps/day count absent or differs |
| `OPT_PASS_LOGGER_MISSING_OR_DIFFERENT` | Fresh authenticated logger sample absent or differs |
| `OPT_PASS_SCHEMA_OR_METRIC_DIFFERENT` | Receipt schema or required metric differs |
| `OPT_PASS_COST_OR_HISTORY_UNBOUND` | Cost/history identity is incomplete or changed |
| `OPT_PASS_AGENT_ISOLATION_FAILED` | Foreign/remote/cloud agent, ownership, port, PID, or protected-state violation |
| `OPT_PASS_RESOURCE_GUARD` | CPU/RAM/agent-count guard fails before or during the run |
| `OPT_PASS_NONDETERMINISTIC` | Clean repeated run changes identities or evidence hashes |
| `OPT_PASS_NOT_ACTIVATED` | Canary passed but no exact OWNER activation exists |

No refusal is a strategy failure. No partial or aggregate-only pass is silently
reclassified as `MEASURED`; its only allowed taxonomy is `PRESCREEN` (or an
explicit refused/invalid research artifact).

## Scope and verification

This ticket produced documentation only. No code, terminal launch, tester pass,
worker reload, queue/database write, archive write, T_Live action, or
AutoTrading action was performed. Verification is static: referenced local
evidence/code paths exist, the contract contains the mandatory identity,
report/trade/logger/model, parity, isolation, resource, and refusal fields, and
the document is LF text.
