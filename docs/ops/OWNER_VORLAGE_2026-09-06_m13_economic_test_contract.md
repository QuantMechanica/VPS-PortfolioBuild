# OWNER-Vorlage 2026-09-06 — M13 Economic Test Contract (bounded FTMO learning trial)

Status: **DRAFT for OWNER decision. Nothing in this document executes.** Klasse: **ROT** (touches the FTMO purchase-adjacent path and future gate criteria) — **no Auffangregel**. This is a document, not a change: it does not create an account, run a trial, lift NO-BUY, touch T_Live/AutoTrading, or alter any gate threshold or verdict. Author: Claude (Factory CEO), Drafter lane. Task `1bf87710-04c7-4cbc-b342-0bc0d660a5fd` (audit measure M13, `docs/ops/CEO_AUDIT_INTEGRATION_2026-09-05.md:M13`).

Binds / references (read-only): audit economics `G:/.../2026-09-05 Factory CEO Audit/03 Anbieter und Wirtschaftlichkeit.md`; the **RATIFIED** long-run acceptance test `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md` (receipt `a2057610…`, 2026-09-05 12:41Z); contract V1 `docs/ops/FTMO_PROBABILITY_CORRELATION_CONTRACT_V1_2026-09-05.md`; the C-6 method `docs/ops/FTMO_C6_ESTIMATOR_METHOD_2026-09-05.md` (receipt `871cf325…`, INERT); trial design `docs/ops/evidence/2026-09-05_ftmo_readiness_part2.md`; NO-BUY receipt `decisions/2026-09-02_owner_receipts_ceo_asks.md:8` (row 6) and blanket release row 9 ("Alles, bis auf den Kauf, freigegeben").

---

## 1 · LAGE (Deutsch, eine Seite)

Der Abnahmetest R5 ist ratifiziert und macht eine **Langzeit-Aussage**: er zertifiziert eine wahre P1-Passrate von 0.90 gegen die Latte 0.80 — und braucht dafür **≈ 2.100 versiegelte OOS-Tage ≈ 5,75 Jahre** (Zwei-Phasen: 8,6 Jahre), belegt `docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md` §C.4 R-6 / Tabelle Zeile p*=0.90. Das vorhandene 96-Tage-Fenster ist um Faktor 21,9 zu kurz; der Test **kann NO-BUY heute nicht aufheben** (§D.0), und die C-6-Gates (Breach/P2/Joint) sind INERT (`FTMO_C6_ESTIMATOR_METHOD_2026-09-05.md`).

Ein **begrenzter wirtschaftlicher Lernversuch** ist eine **andere Entscheidung** als diese Langzeit-Aussage (Audit-Befund F/E07–E09). Er beantwortet nicht die Passraten-Frage, sondern liefert die **eine Evidenzklasse, die kein Backtest liefern kann**: echte M5-Equity inkl. offener PnL, Positionen und Pending-Orders unter Live-Fills am Prag-Mitternachts-Anker (`ftmo_readiness_part2.md:122` §B.0). Ohne diese Ausführungstreue bleiben Acceptance-Test und Tail-Zertifizierung **ABSTAIN** (`:28`).

Die Ökonomie ist im Audit modelliert: `EV = q·R − (1−q)·F − C` (volle Erstattung), Break-even rein illustrativ `540/2.140 = 25,2 %` bei `F=540, R=1.600` — **keine Erfolgsschätzung**, nur der Beleg, warum eine 80-%-Untergrenze allein für Phase 1 nicht die Geldmessgröße ist (`03 Anbieter…:§1`). **F=540 gilt nur für eine KAUF-Challenge; die ist ausgeschlossen.** Ein Free-Trial/Demo kostet 0 USD Gebühr und ist der zulässige Rahmen für diesen Versuch.

Vier harte Realitäten blocken heute einen *for-record*-Trial (`ftmo_readiness_part2.md:31-34`): (1) kein Live-Modus-Set-Generator auf Platte; (2) Symbolabdeckung ist geschlossen (8 Lanes decken alle 6 Instrumente); (3) der Telemetrie-Kollektor (`QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py`) ist geliefert, aber **noch nicht abgenommen/installiert**; (4) ein *ratifizierter Scoring-Vertrag* (Prediction-Bands) für den Trial existiert noch nicht.

## 2 · EMPFEHLUNG

**Option B — minimaler Capture-only-Demo-Trial (kein Kauf).** Nur echte M5-Telemetrie aufzeichnen, Scoring **verschoben**; die Aufzeichnung ist als Bestätigung **unzulässig** (`ftmo_readiness_part2.md:189`), liefert aber die fehlende Ausführungstreue-Evidenz, schließt die Kollektor-Abnahme (B.2 Limit 3) und speist den C-6-Exakt-Guard-Input. Getrennt von R5 (kein Doppelzählen) und von NO-BUY. **Cost-of-Wait:** solange kein Trial läuft, bleibt der FTMO-Cashflow-Pfad undatiert und die einzige verbleibende Route ist die ≈ 5,75-Jahre-OOS-Strecke.

## 3 · ENTSCHEIDUNGSFRAGEN (Optionen, je mit Rollback + Cost-of-Wait)

| # | Option | Was passiert | Klasse | Rollback | Cost-of-Wait |
|---|---|---|---|---|---|
| **A** | **Kein Trial (parken)** | R5-Langzeitpfad allein; NO-BUY bleibt; keine M5-Evidenz | ROT | — (nichts geschieht) | Ausführungstreue nie belegt; ABSTAIN bleibt; nur die 5,75-Jahre-Strecke datiert den FTMO-Start |
| **B** *(empf.)* | **Minimaler Capture-only-Demo-Trial** | Demo/Free-Trial, gedeckelt; **nur** Telemetrie aufzeichnen; Scoring verschoben; **unzulässig als Bestätigung** | ROT | Env/EXPECTED_STATE zurück auf PARKED; kein Live-Effekt | Ohne ihn bleibt die Kollektor-Abnahme offen und C-6 hat keinen Pfad-Input |
| **C** | **Voller for-record-Trial** | Prediction-Bands zuerst ratifizieren, dann **ein** defektfreier Lauf gegen `ftmo_free_trial_gate` | ROT (Gate-Kriterium) | wie B + Siegel zurückziehen vor Ergebnisöffnung | Höchster Entscheidungswert, aber blockiert auf Set-Pfad + Kollektor-Abnahme + ratifizierte Bands |

Keiner der drei Wege enthält einen Kauf. B ist der kleinste Schritt, der die einzig fehlende Evidenzklasse erzeugt, ohne R5, C-6 oder NO-BUY zu berühren.

---

# ENGLISH METHOD — Bounded Economic Learning-Trial Contract (pre-registered)

## §A · Purpose — what only a bounded trial can establish

A backtest cannot produce synchronized **intraday mark-to-market**: FTMO's daily/total rules are measured on *equity including open PnL, swaps and commissions* at a **Europe/Prague midnight** anchor (`ftmo_2s_max_daily_loss`, `ftmo_complete_mtm_evidence: closed_pnl_daily_proxy_allowed=false`). The retained artifacts hold only `EQUITY_SNAPSHOT` events — no interval minimum, no endpoint equity, no pending-order census (`ftmo_readiness_part2.md:166`, `interval_equity_export.md`). An instrumented replay can *simulate* this; **execution-fidelity of real M5 equity/positions/pending under live fills needs the exact-profile trial** (`:122`). That single evidence class — and the restart / midnight-crossing / entry-window behaviour under live fills (`:194`) — is the entire reason the trial exists. It answers an **operational** question, never the long-run edge question.

## §B · Separation from the R5 long-run claim and the C-6 estimator (NO double-counting)

Three instruments, three firewalls:

| Instrument | What it claims | Population it needs | This trial's relation |
|---|---|---|---|
| **R5 acceptance test** (RATIFIED) | true P1 pass-rate ≥ bar on **sealed OOS** | ESS_min 35 → **2,100 sealed days ≈ 5.75 y** (`R5 §C.4 R-6`) | **Ineligible as R5 evidence.** R5 R-4: extra seeds/short spans do **not** widen the population; only additional disjoint sealed windows or a longer sealed span do (`R5 §C.4 R-4`). A trial is a short span. |
| **C-6 estimator** (INERT) | admissible breach-upper / P2 / joint | floors **36 / 23 / 9** observations; closed-P&L inadmissible (`FTMO_C6_ESTIMATOR_METHOD:C6-2,C6-3`) | Trial feeds the **exact-guard INPUT** (M5/Prague path) only; a few Prague-days sit far below the floors → C-6 stays `LOW_SAMPLE` / INERT. |
| **M13 trial** (this contract) | operational execution-fidelity only | 1 defect-free run within pre-registered bands (`ftmo_free_trial_gate`) | Its verdict is the free-trial gate, **not** an edge or pass-rate. |

Firewall rule (pre-registered, from `ftmo_readiness_part2.md:189`): **for-record trial data are sealed until the scoring contract is ratified; capture-only exploratory data may inform a NEW preregistration but is ineligible as confirmation under that revised plan.** A post-hoc scored rehearsal is never converted into confirmation. No trial number is ever added into the R5 sealed OOS population or credited against a C-6 floor.

## §C · Scope (venue, account type, size, duration cap, capital cap, sleeves)

| Dimension | Value | Source |
|---|---|---|
| Venue / product | FTMO, **2-Step $100K Swing** (primary comparison candidate for D1/multi-day strategies) | `03 Anbieter…:§1`; rulepack `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` |
| Account type | **Free Trial / Demo only** (ENV=live semantics, `RISK_FIXED=0 / RISK_PERCENT`) — **no paid Challenge** | `ftmo_readiness_part2.md:31,206`; NO-BUY receipt row 6 |
| Nominal size | $100,000 demo (Swing leverage up to 1:30; FX margin 3.3333%, XAGUSD/USOIL 6.6667% — **provisional** Sep-5 API snapshot, OWNER-confirm in client area) | `ftmo_readiness_part2.md:158`; `2026-09-05_ftmo_current_pool_cost_snapshot.json` |
| Real capital at risk | **USD 0** (demo; no purchase) | NO-BUY; `ftmo_owner_purchase_gate` |
| Duration cap | **OWNER number** — recommend a small fixed window (e.g. N Prague trading days) sufficient to exercise restart + one midnight crossing + entry-window; not open-ended | design target; `ftmo_readiness_part2.md:194` |
| Sleeves | subset of the 8 sealed FTMO candidates on covered lanes (XAUUSD, GER40, GBPUSD, EURUSD, USDCAD, NZDUSD, XTIUSD, XAGUSD); FTMO manifest is its **own** book, only 10706/11421 overlap DXZ | `ftmo_readiness_part2.md:135,152` |
| News filter | **QM mandatory news blackout binds** (Swing provider exemption kept in its own column, does NOT repeal QM blackout) | `EDGE_LAB_CHARTER_2026-05-22.md:28`; `ftmo_readiness_part2.md:153` |

## §D · Pre-registered success / stop criteria (numbers + sources), fixed BEFORE any result

- **Capture-only success (Option B):** the delivered collector persists a **gap-free Europe/Prague-day-keyed M5 interval-minimum series** with per-interval position/pending census across the window, and the run exercises (i) a mid-session terminal restart, (ii) a Prague-midnight crossing with an open position, (iii) the 23:50–00:10 entry-window guardrail — with **0 operational defects**. This is a *data-capture* verdict, not an edge verdict (`ftmo_readiness_part2.md:194`; collector `QM_FTMO_TrialTelemetry.mq5` + `ftmo_trial_telemetry.py`).
- **For-record success (Option C):** `ftmo_free_trial_gate` — `minimum_runs=1`, `must_reach_profit_target=false`, `operational_defects_allowed=0`, **and** the run stays inside **pre-registered prediction bands** (rulepack `:495-498`). Bands must be ratified **before** the stream is opened.
- **Stop rule:** any single rule / governor / identity / execution defect ends the for-record run (`operational_defects_allowed=0`); the duration cap bounds the window; a demo hit of the FTMO daily (5%) / total (static 90% floor) rule is a **data point**, not a monetary loss (demo).
- **Loss budget:** for the demo trial the monetary loss budget is **0** (no real capital). A monetary loss budget is defined only for the **eventual paid path** — a cap on cumulative fees at risk before the trigger is re-anchored — and that number is an **OWNER decision**, not set here (repeated paid attempts are **not** statistically independent under the same strategy/regime, `03 Anbieter…:§1`).
- **Realistic data volume:** a demo/free trial yields a handful of Prague-days of M5 telemetry per sleeve — **orders of magnitude below** the R5 floor (2,100 sealed days) and the C-6 floors (36/23/9). Stated up front so no one mistakes it for a confirmation sample.
- **Decision rule fixed before opening:** Option B makes **no edge decision** from the trial (capture-only, ineligible as confirmation). Option C's only verdict is the pre-registered band pass/fail, evaluated **once**.

## §E · Evidence produced and where stored

- Durable telemetry: Europe/Prague-day-keyed M5 jsonl (schema `qm.ftmo-trial-telemetry.raw/v1`) via the delivered collector, compacted by `ftmo_trial_telemetry.py` — **pending review/acceptance/installation** (`ftmo_readiness_part2.md:137,208`).
- Trial record: `docs/ops/evidence/YYYY-MM-DD_ftmo_m13_trial_<mode>.md` (capture-only vs for-record), plus the pulse assessment (`ftmo_trial_pulse.py`, observation-only, never starts/stops/closes — `:178`).
- Cost confirmation: OWNER client-area readout folded into the provisional snapshot (`2026-09-05_ftmo_current_pool_cost_snapshot.json`); provisional swap/margin figures are **not** promoted into `venue_cost_model.json` until OWNER-confirmed (`ftmo_readiness_part2.md:158`).

## §F · Cost table (fees, time, opportunity)

| Item | Value | Source |
|---|---|---|
| Free-trial / demo evaluation fee | **USD 0** | NO-BUY; free-trial scope |
| Paid-challenge fee (EXCLUDED) | USD 540 list, one-time, refundable 100% after first Reward | rulepack `:231-243` |
| Illustrative paid break-even q | `540 / (1600+540) = 25.2%` — **not** our success estimate | `03 Anbieter…:§1` |
| Reward split (context) | 80% base, up to 90% via Scaling/Premium | rulepack `:247-249` |
| Time-to-cash (paid path) | Reward requestable **day 14** after first trade; no fixed evaluation deadline; processing after | `03 Anbieter…:§1` |
| AI engineering | live-mode set-path generator + collector review/accept — commissionable (standing-auth review lane, ≤ small factory time) | `ftmo_readiness_part2.md:208` |
| OWNER time | account/demo creation + login + PARKED→RUNNING flip + client-area terms | `ftmo_readiness_part2.md:202-205` |
| Opportunity / concentration | single-provider concentration; repeated attempts not independent; factory lane time | `03 Anbieter…:§1` |
| Cost of a **wrong** decision | laundering a capture-only rehearsal into confirmation → paying USD 540 × N on a false-positive edge, plus provider concentration | firewall §B; `03 Anbieter…:§1` |

## §G · Uncertainty procedure (fixed before opening any result)

The trial's small n is reported with an **explicit non-inferential status** and never enters the R5 population (R-4) or a C-6 floor. Provider cost figures stay flagged `MISSING_MATCHED_FTMO_DXZ_CALIBRATION` until OWNER-confirmed (`ftmo_readiness_part2.md:158`). Repeated attempts are correlated (same strategy/same regime) — the EV formula is **not** a licence to re-buy (`03 Anbieter…:§1`). If capture-only data later seeds a new preregistration, that data is exploratory only and ineligible as its own confirmation (§B firewall). C-6 remains INERT until its fixtures pass and an OWNER activation card is signed — the trial does not activate it.

## §H · OWNER-only decision points (nothing here is AI-executable)

1. **Purchase of any paid Challenge — EXCLUDED** (NO-BUY; `ftmo_owner_purchase_gate: owner_signature_required=true, automatic_purchase_allowed=false`).
2. **Create the FTMO Free-Trial / Demo account + terminal login** (login-gated OWNER act, `ftmo_readiness_part2.md:203`).
3. **Flip `EXPECTED_STATE` PARKED → RUNNING** — authorizes a live-executing demo; the current PARKED state was itself set by an OWNER receipt (`:182`).
4. **Confirm client-area terms** (Swing leverage, symbol list, margin/swap, triple-swap weekday) (`:202`).
5. **Ratify the trial scoring contract / prediction bands** before any for-record stream (Option C) — a gate-criterion, ROT.
6. **Set the paid-path monetary loss budget** (§D) if/when a paid path is ever chosen — separate future decision.
7. Live trading, AutoTrading toggle and every gate threshold are **untouched** by this Vorlage.

## §I · Options, recommendation, cost of waiting

- **Option A — No trial (park).** Keep R5-only. *Cost of waiting:* execution-fidelity never obtained; acceptance/tail-cert stay ABSTAIN; the FTMO cashflow path stays undated behind the ~5.75-year OOS route.
- **Option B — Minimal capture-only demo trial (RECOMMENDED).** Demo/free-trial, capped, capture telemetry only; scoring deferred; ineligible as confirmation. Produces the single missing evidence class, closes collector acceptance, feeds the C-6 exact-guard input, stays firewalled from R5 and NO-BUY. Requires OWNER points 2-4; AI commissions the set-path + collector acceptance. *Cost of waiting:* collector acceptance and C-6 path-input stay open.
- **Option C — Full for-record trial.** Ratify prediction bands first, then one defect-free run against `ftmo_free_trial_gate`. Highest decision value but blocked on set-path + collector acceptance + ratified bands; still no purchase; higher OWNER time.

**Recommendation:** **Option B** — the smallest step that produces the one evidence class backtests cannot (real intraday M5 equity/positions/pending under live fills), while staying fully separated from the R5 long-run claim, the INERT C-6 estimator, and NO-BUY, and cannot be laundered into confirmation.

## §J · Limits

- **No purchase and no account creation are authorized by this document.** NO-BUY stands; the OWNER decides purchases himself.
- No live-trading change, no AutoTrading toggle, no T_Live write; no gate threshold, verdict, candidate-pool or book is altered.
- Every number here is an **existing** policy/measured value with a path; this Vorlage defines **no new threshold**. The paid-path loss budget and the trial prediction bands are explicitly left as OWNER numbers.
- The C-6 gates stay INERT; R5 stays as ratified; this trial widens **neither** population.
- Provider cost/margin/swap figures are **provisional** (Sep-5 public-API snapshot) and are not promoted into the governed cost model until OWNER-confirmed in the client area.
- **DRAFT — nothing in this document executes.** It becomes a Mission-Control card only after the OWNER decides an option.
