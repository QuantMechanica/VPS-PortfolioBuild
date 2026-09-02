# Multi-host strategy-factory feasibility — decision memo

Date: 2026-09-02  
Router task: `e7d7b102-1168-4f7c-89a4-191cbc3a270c`  
Authority: CEO mandate 2026-09-02; decision support only; purchases remain OWNER-only  
Scope: read-only design; no purchase, terminal start, `T_Live`, AutoTrading, or pipeline mutation

## Decision

**Proceed with the multi-host protocol, not with a server purchase yet.** The smallest safe first step is a
loopback proof of the export/import protocol followed, only after OWNER approval, by a 48-hour **one-host,
two-terminal Q12 census canary** on an interruptible-free host. If the canary proves byte-identical results,
idempotent imports, containment isolation, and useful throughput, prefer a 128 GB dedicated satellite for
steady state. Use AWS only for short, checkpointable bursts.

The old assumption that an AX52/AX102 costs about EUR 90-110/month is no longer valid for a new order. Hetzner's
15 June 2026 list prices are EUR 97.30/month for AX42-1 and EUR 257.30/month for AX102-1 before IPv4, Windows,
VAT, and setup. AX52 is a legacy 64 GB reference and is absent from the current order matrix. At today's price,
the architecture is still feasible, but the economic case must be proven by measured cell throughput before
committing.

## Why a satellite can help

The measured host has 63 GB RAM and safely sustains only 5-6 testers. XAUUSD runs use 11-12 GB and some
index-tick runs reach 44 GB; CPU then runs at 60-96%. A DL-089 program has about 700-1,085 cells at about seven
minutes each. The satellite therefore helps only if it adds independent memory bandwidth and terminal slots;
moving the same workload to a 32 GB VM is not a capacity win.

## Architecture

### Authority boundary

`D:/QM/strategy_farm/state/farm_state.sqlite` remains on the current host and remains the only authoritative
queue. It must never be opened over SMB, copied while live as a writable replica, or mounted by a satellite.
The current host is the sole allocator and result importer. A satellite is an execution appliance.

The protocol has two append-only messages:

1. **Work envelope** — the authority transitions one row into an exported lease and emits a canonical JSON
   envelope containing `work_item_id`, exact predecessor, Q-phase, payload hash, EA/EX5/setfile hashes,
   gate-manifest hash, archive-manifest hash, registry hashes, host ID, lease generation, expiry, and nonce.
   The envelope is signed/HMAC-bound by the authority and may be claimed once.
2. **Result envelope** — the satellite returns the immutable MT5 report, logs, summary, file hashes, start/end
   times, terminal ID, host ID, input work-envelope hash, and execution verdict evidence. It does not contain
   permission to decide a pipeline verdict. The authority imports under the existing mutation lock only after
   verifying identity, hashes, lease generation, predecessor, and that no prior receipt exists.

Transport can be an authenticated HTTPS/object-store inbox or an SFTP drop with atomic rename. A shared folder
is acceptable only as a message transport; neither host opens the other's SQLite database. Import receipts are
append-only and keyed by `(work_item_id, lease_generation, result_sha256)`, so re-delivery is idempotent and a
conflicting second result fails closed for review.

If export/import volume later justifies it, a small server database can replace the message inbox. That is a
later migration, not a canary prerequisite. PostgreSQL would become the queue authority only after a schema,
transaction, failover, backup, and rollback project; dual-writer SQLite/PostgreSQL is forbidden.

### Custom-history distribution

The current Variant A contract is explicitly bound to T1-T10. Do not reinterpret or edit that sealed manifest
for a satellite. Create a new host-scoped distribution manifest that references the immutable archive root and
binds:

- source archive SHA-256 and byte count;
- target host ID and terminal IDs;
- exact custom-symbol specifications and history hashes;
- copy mode and per-terminal verification receipts;
- validity window and revocation generation.

Stage the archive while no satellite worker is active, verify it, then privatize locally. The conservative
storage budget is 10 copies x 43 GB = about 430 GB per satellite. A master-plus-hardlink/copy-on-claim design
may reduce transfer and storage, but only after the isolation canary proves that MT5 never mutates shared
history in place. No runtime history reads from SMB/object storage are permitted.

### Queue, evidence, locks, and containment

- Central export is the only claim. A satellite cannot select arbitrary pending rows.
- Each host has its own worker lock and containment state. A local RAM, archive, terminal, or identity fault
  stops only that host. An authority/import-contract fault stops all new exports.
- The existing global mutation lock remains local to the authority and guards exports/imports. Satellite lock
  files are namespaced by host and are never treated as global truth.
- Result files land first in a quarantine directory. Only an authenticated importer promotes them into the
  canonical evidence tree and updates the authoritative row.
- Lost host or expired lease does not overwrite a result: the authority appends a new lease generation and
  preserves the old envelope. A late result from an old generation is retained as orphan evidence, not applied.
- Metrics separate execution throughput, transport latency, import rejects, duplicate receipts, and wasted
  cell-hours. Pipeline verdicts continue to come only from pipeline evidence.

### Account, registry, and live separation

The satellite receives no `T_Live` profile or live credential. Use a dedicated Darwinex test login if terminal
bootstrap requires a broker session. Whether one Darwinex login may run concurrently across hosts must be
confirmed with Darwinex before the network canary; until then the design assumes **no shared account session**.
Custom-symbol tests must be able to run from the staged history after bootstrap.

`ea_id_registry.csv`, `magic_numbers.csv`, the generated resolver, and the active gate manifest are copied as
read-only snapshots whose hashes are embedded in every work envelope. No EA ID, magic, slot, card, setfile, or
binary is allocated or generated on a satellite. Import refuses any registry or binary hash drift.

## Cost model

### Method and assumptions

- Currency: ECB 2026-09-02 reference rate, EUR 1 = USD 1.1578.
- One cell-hour is one tester occupied for one wall-clock hour. `EUR/1,000 cell-hours = monthly cost /
  (730 * safe concurrent testers) * 1,000`.
- Prices exclude VAT. Setup fees are shown separately and excluded from normalized operating cost.
- Hetzner includes local NVMe; model includes Windows Server Standard and one IPv4 estimate. The displayed
  Windows price used is EUR 27.90 for 8 cores and EUR 55.90 for 16 cores.
- AWS Frankfurt uses Windows license-included rates built from the 2026-09-02 Linux/Spot price snapshot plus
  AWS's USD 0.046/vCPU-hour Windows rate, and 500 GB gp3 at USD 0.0952/GB-month. It excludes snapshots, support,
  extra IOPS, VAT, and small result egress.
- Safe tester counts are planning caps, not benchmark results: 5 on 64 GB, 8 on 128 GB, and 2 on 32 GB.
  A 44 GB index-tick cell cannot run safely on c6i.4xlarge.

| Option | RAM / vCPU-or-cores | Safe testers | EUR/month | EUR/1,000 cell-hours | One-time | Decision use |
|---|---:|---:|---:|---:|---:|---|
| Existing host, marginal | 63 GB / 16 logical | 5 | 0 incremental | 0 incremental | 0 | baseline; sunk cost not supplied |
| AX52 legacy reference | 64 GB / 8 cores | 5 | 88.60 | 24.27 | historical EUR 39 setup | not currently orderable; comparison only |
| AX42-1 current new order | 64 GB / 8 cores | 5 | 126.90 | 34.77 | EUR 49 plus OS/IP setup if any | cheaper canary, no RAM gain over current host |
| AX102-1 current new order | 128 GB / 16 cores | 8 | 314.90 | 53.92 | EUR 129 plus OS/IP setup if any | preferred steady-state candidate after benchmark |
| AWS c6i.4xlarge Windows on-demand | 32 GB / 16 vCPU | 2 | 994.44 | 681.12 | 0 | NO-GO for mixed fleet; RAM too small |
| AWS c6i.4xlarge Windows Spot snapshot | 32 GB / 16 vCPU | 2 | 727.10 | 498.02 | 0 | NO-GO; interruption and RAM risk |
| AWS r6i.4xlarge Windows on-demand | 128 GB / 16 vCPU | 8 | 1,271.86 | 217.78 | 0 | short canary/burst only |
| AWS r6i.4xlarge Windows Spot snapshot | 128 GB / 16 vCPU | 8 | 818.59 | 140.17 | 0 | checkpointable short cells only |

Sensitivity: if AX102 proves safe at 10 testers, its normalized value improves to EUR 43.14/1,000 cell-hours.
If it sustains only 6, it worsens to EUR 71.89. The benchmark, not nominal cores, decides.

The 430 GB archive upload into AWS is data-transfer-in and is expected to be free; 500 GB gp3 storage contributes
about EUR 41.11/month above. If the full 430 GB is later downloaded out of AWS in one month, the first 100 GB
free allowance and USD 0.09/GB next tier imply about EUR 25.65 egress. Hetzner includes 1 Gbit/s traffic on the
listed dedicated line. The operational cost is still dominated by Windows compute, not archive transfer.

## MT5 Remote Agents verdict

**Narrow use only; NO-GO as the factory scaling architecture.** MetaTrader documents that a single test uses
one agent and that remote agents receive packages during an optimization. It also documents local-network and
remote-agent optimization of custom symbols, while the MQL5 Cloud Network is prohibited for custom-symbol
optimization. QuantMechanica currently schedules each cell as a governed single backtest with its own
work-item/evidence lifecycle. Remote Agents therefore do not provide the queue, lease, evidence import,
containment, or per-cell provenance required here.

A later narrow experiment may wrap an internally generated parameter sweep as one genuine MT5 optimization,
provided it uses no DLL/file-common dependency and can emit cell-level provenance equivalent to the current
contract. It must not be used for the first satellite canary.

## Phased plan and acceptance gates

### Phase 0 — no-purchase loopback spike

Implement envelope schemas, signer/verifier, local export from a fixture DB, quarantined import into a second
fixture DB, duplicate/replay/late-result tests, and a dry-run archive-manifest verifier. No live DB mutation.

Pass requires: deterministic hashes; duplicate import is a no-op; conflicting import refuses; stale lease
refuses; registry/EX5/set/archive drift refuses; source row and evidence are unchanged on any refusal.

### Phase 1 — OWNER-approved 48-hour canary

Rent one r6i.4xlarge Windows on-demand only after OWNER approval, or use an already available Windows host.
Limit it to two terminals and 20-50 short Q12 census cells from one non-live program. No Q07/Q10 long run,
no Spot, no `T_Live`, no AutoTrading, and no concurrent reuse of a Darwinex login without written confirmation.

Pass requires: 100% result-envelope imports; zero identity/hash discrepancies; byte-equivalent summary metrics
against five duplicated local control cells; no cross-host containment; no duplicate verdict; and measured
all-in EUR/1,000 cell-hours plus p50/p95 cell time.

### Phase 2 — steady-state purchase decision

If the canary passes and the backlog still justifies capacity, ask OWNER to choose AX102-1 (or a price-equivalent
128 GB dedicated host) for a one-month trial. Ramp 2 -> 4 -> 6 -> 8 terminals only after RAM, paging, CPU,
archive integrity, and importer error budgets remain green. Keep long Q07/Q10 work on non-interruptible hosts.

### Phase 3 — optional cloud burst

Use r6i on-demand for time-boxed campaigns. Admit Spot only for cells with useful checkpoints or cheap restart
cost. A two-to-four-hour Q07/Q10 run is not Spot-safe because AWS may interrupt the instance; a two-minute
notice does not make an uncheckpointed tester result durable.

## Principal risks

| Risk | Consequence | Control |
|---|---|---|
| Split-brain queue | duplicate/conflicting verdicts | single authority; signed leases; idempotent importer |
| Archive drift | false economic evidence | immutable host manifest; per-terminal receipt; fail closed |
| Late result after reassignment | wrong row updated | lease generation; retain late result as orphan evidence |
| Broker session limit | disconnects or account lock | dedicated test login; written Darwinex confirmation |
| Registry divergence | magic/identity collision | read-only registry hash in envelope; no satellite allocation |
| Spot interruption | lost multi-hour cell | no Spot for Q07/Q10; checkpointable short work only |
| Cost estimate drift | bad purchase decision | OWNER quote + 48-hour measured benchmark before commitment |
| Wider blast radius | both factories stop | host-local containment; global stop only on authority-contract fault |

## Recommendation for the 2026-09-06 OWNER session

Approve engineering Phase 0. Do not buy hardware on the memo alone. Authorize at most a 48-hour r6i on-demand
canary budget after the loopback tests pass. If the measured canary clears the gates, order one month of a
128 GB dedicated host; AX102 is the reference, but obtain a same-day quote because 2026 pricing changed sharply.
Reject c6i and reject Remote Agents as general factory paths. Reserve Spot for short, restartable campaigns.

## Sources

- Internal measurements and scope: `docs/ops/evidence/2026-09-02_owner_session_20260906_package.md` and the
  router payload for this task.
- Hetzner current prices and limited-offer policy: <https://docs.hetzner.com/general/infrastructure-and-availability/price-adjustment/>
- Hetzner current AX hardware matrix: <https://www.hetzner.com/dedicated-rootserver/matrix-ax/>
- Historical AX52 specification/price: <https://www.hetzner.com/pressroom/neue-dedicated-server-2023/>
- AWS Price List API provenance: <https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/price-changes.html>
- AWS Windows license-included rate: <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/optimize-cpu.html>
- AWS EBS charging model: <https://aws.amazon.com/ebs/pricing/>
- AWS data-transfer tiers: <https://aws.amazon.com/ec2/pricing/on-demand/>
- AWS Spot interruption contract: <https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/spot-interruptions.html>
- ECB 2026-09-02 FX rate: <https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html>
- MetaTrader single-test/agent and optimization behavior: <https://www.mql5.com/en/docs/runtime/testing>
- MetaTrader custom-symbol remote-agent limitation: <https://www.mql5.com/en/articles/3540>

