# FTMO execution canary — partial implementation, native qualification open

Task b7858771-ecdc-4bb5-9d2f-d428a12bc661. No deployment or acceptance.

`prepare.py` generates an isolated 11421 review source with the entire strategy
prefix unchanged. Registered source, binary, setfile and include-closure hashes
are bound in `manifest.json`; the canary EX5 is explicitly null. Its fixed-risk
setfile is a static review artifact and has not been run. The binding slot returns
false until a separate immutable execution contract is issued; no account, policy
hash or OWNER ratification has been invented.

The source uses existing InitV3, governor client, entry risk scaling and atomic
account-risk reservation. Cleanup runs on the 200ms timer and before the entry
path, without waiting for a D1 signal or a symbol tick. A governor/news/session/
stale-quote/local-halt failure initiates conservative flattening of this symbol
and magic. Delete uses the existing send-once path; close uses TradeManagement.
It checks remaining server inventory, retries at one-second intervals, logs
unconfirmed operations and escalates after 30 seconds while continuing cleanup.
Entry remains blocked until cleanup is observed complete and all gates reopen.
It neither modifies SL/TP nor claims that a request guarantees broker execution.

The proposed internal policy closes at the start of the existing 30-minute news
blackout and five minutes before every published session pause. This is deliberately
stricter than a product-specific holding rule and changes trading evidence.
Unknown/malformed session intervals and quotes older than five seconds block.
Holiday/session freshness, starts inside a restricted interval, and market-closed
close failures remain native test cases, not guarantees. Loss anchors, total halt
and target latch remain with the existing Prague-day governor and persisted local
kill switch; the canary does not reset them or infer account phase from server name.

The required September 8 analysis was retrieved through Drive (file
1iP0JN43yOGrbH1soL4UGaPHUVq-pNw32); its corresponding repository analysis is
`docs/ops/evidence/2026-09-07_strategy_console_v2/ftmo_execution_followup.md`.
M09-B's absent-collector claim is stale: see September 6 collector compile records,
demo installation and `2026-09-06_ftmo_collector_native_acceptance.md`. The latter
still explicitly says its scripted tester was NOT_RUN; installed telemetry and
pure account-control cases do not establish the concurrent broker-chain tests.

## Verification and remaining work

39 source/oracle tests passed in 5.27 seconds: canary mechanics preservation and
binding refusal, existing runtime identity, governor wiring, risk reservation
concurrency model, and telemetry. These are **not native M01–M12 PASS results**.
An initial test read used Windows default encoding; it was corrected to UTF-8.
Generator verification also identified legacy setfiles without news-axis keys;
the review preset now supplies explicit FTMO/PRE30_POST30 values and fixed risk.

| Required native case | Current evidence | Remaining proof |
|---|---|---|
| M01 identity | Existing runtime source tests | Issued contract, wrong account/server/symbol/generation/hash negatives |
| M02 stale/torn governor | Existing client source/oracle | Native missing/future/odd/torn/lock cases including transient retries |
| M03 pending + dead governor | Timer cleanup source | Actual server cancellation, delayed/missing acknowledgement |
| M04 pending + news | Conservative news-flat source | Native boundary/calendar failure and rearming |
| M05 position + news | Explicit pre-blackout flatten policy | SL/TP/close behavior and failure inside restricted interval |
| M06 session/Friday/no ticks | Independent timer, session query | Broker holidays, missing ticks, closed market and retry evidence |
| M07 last budget | Existing atomic oracle | Two EAs on same isolated account, one last-budget reservation |
| M08 crash/partial fill | Existing reservation implementation | Crash, ambiguous send, partial fill and inventory reconciliation |
| M09 restart/day | Existing governor/client checks | Native Prague/Broker DST and durable halt reinit |
| M10 floor/taper/latch | Existing entry scale and cleanup source | Pending exposure during taper/flatten and accurate phase label |
| M11 KS baseline/window | Existing baseline receipt | Native live-window count/reset observation |
| M12 evidence identity | Source/set/available includes sealed | Canary EX5, platform includes, actual loaded set, logs/orders/deals |

Two material integration blockers remain. First,
`QM_AccountRiskReservationConfigure` rejects tester mode and fixed-risk mode;
this cycle may not change that rule or enable a trading account. Native concurrent
tests require a separately governed isolated account driver and an exact issued
contract. Second, the shared TradeContext transient retry reuses a previously
approved request; it does not refresh governor state immediately before its second
OrderSend. This canary does not claim to fix that race. A targeted send-boundary
guard with exposure-reduction exemptions and native retry tests is required before
the binding slot can be issued. No compiled canary or native acceptance is claimed.

Reproduce source preparation with `python docs/ops/evidence/2026-09-09_ftmo_execution_canary/prepare.py`.
Review the exact generated diff, complete the send-boundary guard, issue the
source-generation/account/policy binding, then use an approved isolated compile
contract and native M01–M12 driver. Requalification starts from current Q02 and
the active gate manifest for the changed identity; no old binary verdict can be
inherited, and no sealed holdout may be opened without its prospective plan.
