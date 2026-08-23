# Q17 — Live Burn-In on DarwinexZero Live

> **Gate-Manifest v4 (linear, 3 Makrophasen) — Staging-Entwurf.** Aktiver Runtime-Vertrag
> bleibt bis zur OWNER-Ratifikation v3 (`gate_manifest.v3.json`, `default_manifest_switch=false`).
> Diese Seite spiegelt den v4-Vertrag `tools/strategy_farm/config/gate_manifest.v4.draft.json`.

| Feld | Wert |
|---|---|
| **v4 Gate-ID** | Q17 — **Pipeline-Ende (`next = null`)** |
| **Makrophase** | 3 · Strategie wird zum Buch bewertet (terminal) |
| **v3-Herkunft** | Q13 — „Live Burn-In DXZ" |
| **gate_contract_version** | v4 (historische v3-Zeilen behalten ihre Bedeutung über `gate_contract_version`) |
| **Navigation** | ← [[Q16 Operational Readiness]] · → (Pipeline-Ende / Full Live nach OWNER-Verdikt) |

**Herkunft:** v4 Q17 = v3 Q13 (Live Burn-In DXZ), Burn-In-Regeln/Kill-Switch unverändert (ROT).
T_Live-AutoTrading-Toggle = **OWNER only** (HR).

> **Lese-Hinweis:** Der Fließtext nennt die Vorstufen „Q12" (Readiness) und „Q11" (Allokation)
> sowie die Referenz „Q10". v4-Entsprechung: Readiness = **Q16**, Allokation/Buch = **Q15**,
> Confirmation-Referenz = **Q11**. Mapping: [[Gate Manifest v4 Diff]].

---

**Gate Owner:** OWNER (Final Authority)
**Target:** **DarwinexZero Live account** (€100k allocated), T_Live terminal
**Duration:** 14 days minimum
**Spec version:** 2026-05-23 (post-rewrite — was Q14 in previous spec)

---

## Purpose

Q13 is the EA's first real exposure outside our test environment. No demo, no separate prop firm — straight to DarwinexZero Live with **min-lot per trade**, **14-day observation window**, **KS-test kill-switch**, **Myfxbook monitoring**.

OWNER call 2026-05-23: "Die EAs die durchkommen kommen auf das DarwinexZero Live Konto, dort wollen wir das Portfolio dann live schalten und sehen, wie es außerhalb unserer Umgebung performt."

The point of Q13: confirm the EA behaves on real DXZ infrastructure the way it did in our backtests. Real fills, real slippage, real spread variation, real connectivity.

---

## Pre-Conditions

- Q12 Operational Readiness: ALL 11 checks PASS
- Deploy manifest: OWNER signed + Claude verified
- T_Live AutoTrading: OFF until **OWNER alone** flips it on for this EA's magic number (Hard Rule: no AI seat — Claude included — may enable AutoTrading; Claude verifies pre-flight only)

---

## Burn-In Configuration

| Parameter | Value |
|---|---|
| Account | DarwinexZero Live (€100k, account ID in `.private/VPS_SERVER_RECORD`) |
| Terminal | T_Live (`C:\QM\mt5\T_Live`) — OFF LIMITS for all automation; OWNER only. Claude: read-only pre-flight verification. |
| Position sizing | **Min-lot only** (0.01 lot or instrument equivalent) |
| Duration | Minimum **14 calendar days** continuous AutoTrading |
| Risk model | RISK_PERCENT (from Q11 allocation), but capped at min-lot during burn-in |
| Monitoring | Myfxbook live link, hourly snapshot to public-data, daily health check |

---

## Kill-Switch (KS-Test)

The EA is automatically removed from T_Live (AutoTrading OFF for its magic number) if either trips during the 14 days:

1. **Drawdown > 2× simulated Q10 max DD** — execution risk diverged from backtest
2. **KS-test (Kolmogorov-Smirnov) significant divergence** — live trade distribution differs significantly (p < 0.05) from the Q10 trade distribution

Either condition fires → immediate AutoTrading OFF → OWNER decides:
- Archive (EA closed terminal FAIL after live evidence)
- Diagnose (investigate divergence cause, possibly re-run from Q10)

---

## During-Burn-In Cadence

| Who | What | Frequency |
|---|---|---|
| Pipeline-Op | Daily health check of T_Live EA performance | Daily |
| Codex | Hourly public-data snapshot with live EA status | Hourly |
| Claude | Weekly summary brief to OWNER | Weekly |
| OWNER | Final PASS/FAIL decision after ≥14 days | Day 14+ |

---

## Hard Rules for Q13

| Rule | Detail |
|---|---|
| **No AutoTrading without signed manifest** | Absolute. No exceptions, no temporary overrides. |
| **T_Live AutoTrading = OWNER only** | No AI seat and no scheduled task may interact with T_Live directly or enable AutoTrading. OWNER alone toggles AutoTrading; Claude verifies pre-flight (read-only). |
| **Min-lot for full 14 days** | No premature size-up even if performance looks good after 3 days. The point is to validate execution, not to make money in 14 days. |
| **14-day minimum** | Even if all metrics look perfect, OWNER waits the full 14 days. Edge cases (news cycles, week-end gaps) need real-time exposure. |
| **No demo gate** | We don't burn-in on a DXZ demo first. Demo execution doesn't match live; min-lot live is the validation. |

---

## After Q13 PASS (14 days complete, KS-test clean, OWNER signs off)

1. OWNER decides on position-size expansion (typically from min-lot to the Q11-allocated risk percent).
2. New deploy manifest with expanded risk parameters → re-run Q12 fast-path (re-verify checks 4, 8, 11 — the risk-related ones).
3. EA moves to "Full Live" status: standard RISK_PERCENT sizing, ongoing Myfxbook tracking, weekly portfolio review.
4. Decision logged under `decisions/YYYY-MM-DD_q13_pass_<ea>_<symbol>.md`.

## After Q13 FAIL (kill-switch tripped or OWNER veto)

1. AutoTrading OFF on T_Live for this EA's magic number.
2. Open trades managed by OWNER (close immediately or trail to break-even, OWNER call).
3. EA closed (terminal FAIL on this symbol).
4. Live evidence captured for lessons-learned: what diverged between Q10 and live? Spread? Slippage? News handling?
5. The portfolio slot opens for the next Q11 candidate.

---

## DarwinexZero Live Account Notes

- Broker time: NY-Close server, GMT+2 outside US DST, GMT+3 during
- Daily DD limit: 5% (DXZ hard rule)
- Total DD limit: 20% (DXZ hard rule, but FTMO dual-target is stricter at 10% — that's the binding constraint per the Edge-Lab FTMO dual-target note, 2026-05-22)
- Account identifier and credentials: `.private/VPS_SERVER_RECORD` (never published)
