# OWNER live-book session package — 2026-09-06

Prepared 2026-09-02 under OWNER receipt #3. This document is an unsigned, read-only decision/runbook package. Only the OWNER performs T_Live changes, toggles AutoTrading, approves the roster, or signs the deployment pointer.

## Decision sheet

The governed P&L read excludes OWNER-designated magic=0 activity per receipt #1. On the MNT-036 cut, account P&L was -$2,227.20 and the magic=0 bucket -$1,699.88, leaving approximately **-$527.32 governed**. For audit precision, the EURUSD lifecycle itself entered as QM5_11421/magic 114210000 and its magic=0 closing deal coincided with that EA's Friday-close event; the OWNER receipt controls reporting classification, while the forensic record preserves this technical nuance.

| Sleeve | Realized net | Evidence | CEO recommendation | OWNER decision |
|---|---:|---|---|---|
| 1556/XAUUSD | +$149.67 | positive, identity clean; robustness unresolved | CONTINUE, no scale; Q07 on live-binary copy | ____ |
| 10706/GBPUSD | +$394.78 | best governed sleeve; cadence consistent | CONTINUE | ____ |
| 13128/NDX | $0.00 | no trades; confirmed missed-FOMC defect | REMOVE from live, REQUALIFY offline | ____ |
| 10440/NDX | +$136.11 | Q10 FAIL, no PASS; sole KS baseline gap | REMOVE; re-gate before any return | ____ |

Proposed drag pruning (all values are the 2026-09-02 governed cut): 11708/EURUSD **-$530.67**, 11132/SP500 **-$360.73**, 10939/GBPUSD **-$264.70**, 10513/XAUUSD **-$230.94**, 1567/EURUSD **-$195.56**. Roster additions/removals do not reset the DARWIN account track record; they do change the future return stream and must be recorded in deployment provenance.

Recommended post-session scenario: remove those five drags plus 13128 and 10440, leaving **17 sleeves**. Unsigned candidate manifest:

- `D:\QM\reports\state\drafts\owner_session_20260906_candidate_17sleeve.json`
- SHA-256 `03c215d3592a12e79e39d394964a41429155927ef407dec28f323f3e0d84acef`

This is a scenario, not an approval. If OWNER chooses differently, regenerate it before touching charts.

## 10440 disposition

`live_book_pulse.json` reports KS `loaded_ok=23/24`; the sole missing file is `10440|NDX`. MNT-001 requires the baseline to derive from passing Q10 evidence, but 10440 has no Q10 PASS. Creating a baseline from its FAIL would weaken the contract. Therefore the safe live disposition is **remove now, then re-gate offline**. Do not fabricate or waive its baseline.

## Pre-change dry runs

The candidate pointer dry run is at `D:\QM\reports\state\drafts\owner_session_20260906_pointer_dry_run.json` (SHA-256 `c0fe7169c0031385634e2ca71b5bb86ae6288bc8065f5067804d33022d54e30d`). It is explicitly unsigned and uses `2026-09-06T00:00:00Z` only as a planning placeholder; regenerate with the actual deployment epoch before OWNER signature.

The read-only deployment-contract check against the current 24-chart profile returned exit 2, as expected, and wrote:

- `D:\QM\reports\state\drafts\owner_session_20260906_verify_dry_run.json`
- `D:\QM\reports\state\drafts\owner_session_20260906_verify_dry_run.md`

That RED is the correct pre-change result: the current profile still has the seven charts the candidate removes and no post-session INIT evidence exists. It must not be treated as a failed deployment.

## OWNER-only execution runbook

1. Record the signed decision table above. Confirm account 4000090541 / Darwinex-Live and record the exact UTC start. Set AutoTrading OFF manually and verify it visually; agents never toggle it.
2. Back up the active `DarwinexZero_V2_LiveOps` profile and all 24 deployed presets. Record hashes. Do not modify the signed 2017–2025 history archive.
3. Confirm there are no open positions or pending orders owned by any chart being removed. If present, stop and decide explicitly—do not orphan them.
4. In the active profile detach/remove only: chart06 (11708/EURUSD), chart08 (10939/GBPUSD), chart10 (13128/NDX), chart11 (10440/NDX), chart12 (11132/SP500), chart15 (10513/XAUUSD), chart24 (1567/EURUSD). Leave AccountMonitor and the 17 retained charts unchanged.
5. Save the resulting profile under a new dated name. Export/copy the exact retained preset bytes and binary hashes into a staged go-live package. Do not reuse the candidate JSON if the OWNER decisions differ.
6. Run package validation before installation: `python -m tools.strategy_farm.validate_golive_package <STAGED_PACKAGE_ROOT> --repo-root C:/QM/repo --tlive-root C:/QM/mt5/T_Live --out D:/QM/reports/state/drafts/owner_session_20260906_golive_validation.json`. Any FAIL stops the session.
7. Generate the final manifest from the actual staged bytes, with `n_sleeves`, risk total, chart/preset paths and hashes recomputed. Run `verify_live_deployment_contract.py` read-only against the saved profile. Extra/missing chart, magic, risk, binary, account, or server mismatches stop the session.
8. Generate the pointer first unsigned with `generate_live_deployment_pointer.py --dry-run`, using the actual manifest, account/server/phase and exact deployment epoch. OWNER reviews the computed manifest/roster/binary+set fingerprint.
9. OWNER signs using the dated decision evidence (`--signed --approved-by OWNER --approval-evidence <DATED_OWNER_RECORD>`). This is the only signature-producing step. Install the pointer through the governed OWNER/ROT path.
10. Start/reload T_Live with AutoTrading still OFF. Verify 17/17 INIT identities, magics, preset hashes, account/server, AccountMonitor, and KS baselines. Any unknown or missing identity stops the session.
11. AutoTrading may be enabled only by the OWNER after all verification is green. Record the post-start deployment-contract output and pulse.
12. Do **not** lift the live risk freeze merely because SP-A1/A2 becomes green. The freeze requires all stated conditions—including NEWS-CONTRACT-V2 and governor enforcement—plus a separate written OWNER lift. If either remains partial, keep the freeze ACTIVE.

## Evidence index

- Probation detail: `docs/ops/evidence/2026-09-02_ceo_wave1_mnt036_delta_2026-09-02.md`.
- Magic-zero forensic and receipt reconciliation: `docs/ops/evidence/2026-09-02_magic0_trade_forensic.md`; `decisions/2026-09-02_owner_receipts_ceo_asks.md`.
- Live governance, Darwinex roster continuity, risk-freeze conditions: `docs/ops/evidence/2026-09-02_ceo_wave1_dxz_live_book_governance.md`.
- Sleeve execution / KS evidence: `docs/ops/evidence/2026-09-02_ceo_wave1_sleeve-execution-parity.md`; `D:\QM\reports\state\live_book_pulse.json`.

No T_Live file or database row was changed while preparing this package.

## Rechen- und Speicherkapazität — Optionen für den 06.09. (CEO, 2026-09-02 14:30Z)

**Befund heute (Messungen, nicht Schätzungen):**
- Der Durchsatzverlust der letzten Tage kam überwiegend aus der Steuerungsebene (Pump-Kaskade tot, Claim-Hashing 2–3 GB/s, Purge-Schleife, Poison-Programm) — alles heute gefixt; Zellen 0–5/10 min → 8–9/10 min.
- Nach den Fixes ist **RAM** der härteste Deckel: 63 GB physisch, Tester brauchen 5–12 GB (XAUUSD-Läufe 11–12 GB, Index-Tick-Läufe bis 44 GB); ab sechs gleichzeitigen Testern paged der Host (13:45Z: 0,9 GB frei, 16k Pages/s, drei Worker tot). Ehrliche Kapazität: **5–6 Tester parallel**.
- **CPU** (16 logische Kerne, SMT) liegt bei 60–96 % — zweiter Deckel, aber erst hinter dem RAM.
- **D:** (1 TB, ~70 GB frei) war nur wegen der Steuerungsdefekte gesättigt; 10×43 GB Custom-History sind strukturell, Purge-LowWater auf 60 GB gesetzt.

**Was das für das Ziel heißt:** ein DL-089-Zensus hat ~1.085 Zellen (mit Pruning ~700) à ~7 min; bei 40–50 Zellen/h ≈ 15–20 h je Programm. 25 terminale Paare ≈ 25 Programme ≈ **3 Wochen auf dieser Maschine, wenn sie sauber läuft** (heute 279 Zellen). Jede Verdopplung der Kapazität halbiert das.

**Optionen (Vorbereitung für Sonntag):**
1. **VPS bleibt, zweite Bare-Metal-Box als Satelliten-Fabrik** (z. B. Hetzner AX52, 64→128 GB RAM, ~€90–110/Monat): +8–10 Tester. Voraussetzung: Multi-Host-Design — Custom-History-Archiv (43 GB je Terminal, signiertes Manifest) auf den zweiten Host verteilen, Work-Queue/Evidenz-Sync (SQLite ist Single-Host; kein SQLite über SMB), Containment je Host, gleicher Darwinex-Login. Aufwand: Codex-Spike + ~1–2 Wochen Umbau. Dauerbetrieb am günstigsten.
2. **AWS/Cloud-Burst** (c6i.4xlarge 16 vCPU/32 GB ≈ $0,68/h on-demand ≈ $500/Monat; r6i.4xlarge 128 GB ≈ $1/h; Spot ≈ −60 %, aber Unterbrechungen killen 2–4-h-Läufe (Q07/News)): sinnvoll nur für Kampagnen-Bursts, nicht für Dauerbetrieb; gleiche Multi-Host-Voraussetzungen wie 1., plus Windows-Lizenz/AMI und Archiv-Transfer (430 GB) je Instanz.
3. **MT5 Remote Agents** (Spike 52032627 liegt im Board): hilft nur im Optimizer-Modus; unsere Zellen sind Einzel-Backtests mit Custom-Symbolen → geringer Hebel, wahrscheinlich NO-GO; Spike bestätigt das billig.
4. **Kein Zukauf, Software weiter schärfen:** Claim-Overhead (Prestage/Hash) ist heute gecacht; verbleibender Hebel ~10–20 %. Reicht nicht für die Zeitlinie.

**CEO-Empfehlung für Sonntag:** Option 1 als Standardpfad (bestes €/Zellen-Stunde, keine Unterbrechungen), Option 2 nur als Burst-Werkzeug für OOS-/News-Kampagnen. Vorab beauftrage ich den Multi-Host-Spike (Archivverteilung, Queue-Sync, Kosten je Zellen-Stunde) an Codex, damit am Sonntag Zahlen statt Vermutungen vorliegen. Kauf/Anmietung bleibt OWNER-Entscheidung.

**Anbieter-Vergleichsrahmen für den Spike e7d7b102 (OWNER-Frage 14:4xZ; Preise am Abfragetag verifizieren):**
- Dedicated: Hetzner (inkl. Serverbörse), OVHcloud Rise/Advance, netcup Root-Server (Virtualisierung prüfen), Scaleway Elastic Metal, Leaseweb, IONOS.
- Cloud mit dedizierten vCPUs, stundenweise, ohne Spot-Unterbrechung: Hetzner Cloud CCX, OVH Public Cloud, Scaleway.
- Hyperscaler nur für Burst: AWS (Spot = 2-Minuten-Vorwarnung, tödlich für 2–4-h-Läufe), Azure (Windows inkl.), GCP, Oracle Cloud (billige AMD-Instanzen).
- Eigene Hardware: gebrauchte 128–256-GB-Workstation (€1.500–3.000 einmalig), Amortisation 1–2 Jahre, Betrieb/Ausfall beim OWNER; nur für Zensus, nie für T_Live.
- Bei allen gleich: Windows-Lizenz (Add-on oder inklusive), Multi-Host-Umbau, Transfer der ~430 GB Custom-History, Auswahl nach RAM vor Kernen (128 GB je Box).
