# E1-C option B: inactive consumer implementation

Task ea22f4b1-b299-4e2b-adb9-889dbe8f91bc; authority OWNER-DEC-CALENDAR-SCOPED-CONSUMER-20260905, Mission-Control receipt f1dc468c. **REVIEW / GOVERNED_COMPILE_PENDING.** Python contract and fixtures are complete; native compilation and a compatible EA/runner binding are not certified. This packet is not activation-ready.

Implementation commit `bb98bc03235f7f1eead716cdd63dfffb8875d1d6` on `agents/codex-e1c-scoped-consumer-20260905`, isolated checkout `C:/QM/worktrees/codex-e1c-scoped-consumer-20260905`. Four new files; existing production consumers are unchanged. Canonical evidence is in `2026-09-05_e1c_scoped_consumer_implementation/`, including the exact patch, synthetic package, hash manifest, tests and compile-readiness refusal.

## Contract and identities

`news_calendar_scoped_consumer.py` implements schema `qm.news-calendar-scoped/v1`, consumer `qm.news-scope-consumer/v1`. The caller supplies the expected raw sidecar SHA-256 from its sealed plan. The loader retains immutable bytes and verifies both named CSV hashes, source-proof bytes, the versioned symbol/exposure and class/impact map, coverage envelope and source-bound coverage assertions, declarations, sealed window policy, and exact TZif timezone-rule bytes. Duplicate JSON keys, unsupported versions, missing or empty input, unknown classes/currencies, bad CSV layouts, hash drift and unknown/cyclic basket composition are refused. CSV headers alone never establish coverage.

The full raw sidecar hash, both CSV hashes, source-proof hash, timezone hash and consumer version form the content identity. The distinct `qmscopecal-v1-` prefix is deliberately rejected by the old EA loader. `bind_run_plan` creates a new proposal identity including the request, full scope result, implementation hash and old effective-input bytes; its effective-input identity binds the new plan. Changing even sidecar whitespace changes the bundle and downstream identities. It never overwrites a plan or writes to an active calendar directory.

The source proof is a hash-bound evidence assertion, not an independent remeasurement of official events. A production source proof and usable candidate still require the Vorlage's separate ingress and evidence steps. Fixture source proofs are prominently synthetic; they are not release evidence. Scoped proofs explicitly retain `measured_full_scope_pass=false`.

## Availability and consumer behavior

All requests use UTC half-open intervals. Months are `[first instant, next month first instant)`. The sealed look-back/look-ahead expands the request before any whole-local-day expansion. Local days use the sealed TZif bytes, including 23-hour spring and 25-hour autumn Prague days. All declaration gates/reasons/IDs are unioned. Currency `ALL` reaches every exposure. Every declared class remains relevant for its currency; there is no impact exemption without a new reviewed contract. Basket exposure is the recursive union of every constituent, including non-host symbols.

Coverage is proved continuously for every mapped event class and relevant currency. Adjacent asserted spans may cover a request; a one-second gap cannot. Any expanded interval outside the envelope or with incomplete coverage becomes UNCONFIRMED. AVAILABLE describes scope only and delegates to the existing news filter; it never authorizes entry or establishes a pipeline PASS.

| Consumer | Response when scope is unknown |
|---|---|
| Entry | BLACKOUT_UNKNOWN, deny entry, retain matching declaration IDs |
| Future boundary | DATA_ERROR, no invented event or safe-close time |
| Existing positions | Preserve emergency/risk-reduction behavior; deny compliance certification; no scope-created forced-close time |
| Q09 / Q10 projection | UNCONFIRMED; no CONFIG_LOCKED or fallback-OFF credit; original result remains historical evidence |
| Experiment/census | Retain the predeclared attempted roster, missing cells and zero-trade cells; one unknown required arm makes the experiment UNCONFIRMED |
| Admission | No new credit from an unknown dependency; no historical counter rewrite |
| Legacy consumer | Old Python schema check and old EA bundle-prefix check both refuse the scoped identity before dispatch |

The roster is supplied from the sealed plan, not reconstructed from successful observations. Observed windows must equal the declared windows; control and policy windows must agree. Deleting a policy cell, shortening its window, or generating zero trades cannot produce selection credit.

## New EA include and remaining compilation boundary

`framework/include/QM/QM_NewsScopeV1.mqh` is a new class with a disabled default. It validates a small ASCII whole-experiment receipt pinned by the effective-input identity and implementation hash, then hashes the sidecar, both CSVs, proof and timezone file. It retains verified CSV byte snapshots for a future compatible parser, avoiding reopening mutable files after verification. A receipt marked UNCONFIRMED denies all new entries for that requested experiment, including apparently favorable days. Unknown/out-of-window symbols yield BLACKOUT_UNKNOWN or DATA_ERROR. There are no order APIs or forced-close methods. The caller must supply UTC from a sealed clock adapter; interpreting broker TimeCurrent as UTC is not compatible.

The non-trading `QM_NewsScopeV1_CompileProbe.mq5` is unbound. **It has not been compiled.** The canonical governed classifier returns `EA_LABEL_INVALID` for this probe. Its ordinary Q01 path requires a registered strategy label, an ACTIVE registry identity and active magic rows (`compile_work_items.py` classifier); the existing harness path requires an already-built binary and is specific to a different fixture. No supported non-inventory compile enqueue was found. Assigning this probe an active strategy identity would violate this task's boundary. No manual compiler or terminal was launched and no compile queue row was inserted.

Consequently, the Python behavior and static EA contract are reviewable, but native MQL syntax/runtime acceptance remains unverified. A governed compile-only facility or separately approved inactive consumer cohort is needed before binding. The current implementation intentionally does not install production runner adapters or a scoped publisher while that prerequisite remains unresolved. It must not be represented as proof that an arbitrary legacy raw-CSV reader understands exclusions: the scoped namespace must remain separate from option-A default filenames, and the existing full-scope ingress continues to refuse declared exclusions.

## Future switch and ingress ordering

The exact inactive adapter switch is **`QM_NEWS_SCOPED_CONSUMER_V1=1`**. Missing, `0`, `false`, `TRUE`, or any value other than literal `1` is OFF. The new EA class must separately receive `enabled=true` through its sealed compatible consumer binding; its constructor and default state remain disabled. The switch enables only the new adapter API when explicitly called. It does not publish, reseal, make legacy dispatch accept the new version, or activate a current inventory EA.

After CEO review, preserve the Vorlage's ordering: governed native compile and compatible cohort/clock/parser bindings; separately measured create-only candidate and usable windows; OWNER activation receipt binding candidate, sidecar and implementation/cohort hashes; distinct scoped ingress/publication and verified mirrors in the scoped namespace; append-only bundles and plans; per-row dependency checks and separately authorized hold releases; ordinary pipeline evidence. This packet performs none of those activation steps. Option A, the CEO news-claim taint hold, E2/E4 dependencies, OWNER-DEC-A1 counts and all historical verdicts retain their existing meaning. No purchase, candidate-pool change, live effect or AutoTrading change occurred.

## Fixture matrix and verification

| Fixture group | Result |
|---|---|
| Default-OFF output bytes/object identity; lazy branch does not read scope | PASS |
| Missing sidecar/proof/TZif, raw tamper, each CSV hash, duplicate JSON key | PASS |
| Unknown schema/version, mapping/class/impact, empty inputs, unknown/cyclic basket | PASS |
| UTC month endpoints, look-back/look-ahead across months, one-second coverage gap | PASS |
| Sealed Prague spring/autumn days: 23 / 25 hours | PASS |
| ALL currency/class declarations, union of gates/reasons and basket currencies | PASS |
| Entry/boundary/positions, Q09/Q10, admission response contracts | PASS |
| Missing and zero-trade cells, equal control/policy windows, censored arm rejection | PASS |
| Raw-byte and request changes propagate through bundle/plan/effective identities | PASS |
| Legacy Python verifier refusal; actual unchanged EA prefix predicate | PASS; EA predicate checked statically |
| New include receipt binding, default-OFF, no active EA includes it, no trade APIs | PASS statically |
| Native MQL compilation / native fixtures | NOT RUN — governed compile route unavailable for unbound probe |

Focused run: **99 passed** (54 new contract cases and 45 existing calendar/contract/ingress/static-boundary cases). After the final snapshot-copy sizing correction, the 54 scoped cases passed again. `legacy-boundaries-unchanged.json` records unchanged Git content for the six existing consumer/ingress boundaries, distinguishing Git-normalized bytes from Windows working-file hashes. No legacy production file changed. Evidence contains a reproducible synthetic basket/ALL exclusion on the spring transition: its expanded UTC interval is March 28 23:00 to March 29 22:00 and its result is UNCONFIRMED with zero new credit.

The request's native-compilation acceptance is outstanding; retain this packet in REVIEW rather than approving activation.
