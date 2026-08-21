# Probation Evidence Package — MNT-036 (three live sleeves)

- Assembled: 2026-08-21 (read-only; no T_Live file touched, no DB write, no AutoTrading interaction)
- Probation window: **2026-07-13** (admission decision dated 2026-07-12; EAs first INIT_OK 06:29–06:37Z on 07-13) → OWNER review **2026-09-06**
- Sleeves: QM5_1556/XAUUSD.DWX, QM5_10706/GBPUSD.DWX, QM5_13128/NDX.DWX
- Live account: 4000090541 (Darwinex-Live, T_Live)
- Primary live-trade source: `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\journal\live_deals_normalized.csv`
  (AccountMonitor normalized deal export; 166 deals, 2026-04-24 → 2026-08-21T11:07Z, last_deal_ticket 152589648)
- Per-EA self-report source: `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\QM5_<id>_ea-<id>.log` (JSONL, EA-written)
- Farm DB (read-only): `D:/QM/strategy_farm/state/farm_state.sqlite` table `ea_metrics`

---

## 1) QM5_1556 / XAUUSD.DWX

### 1. Identity
- Attached binary: `C:\QM\mt5\T_Live\MT5_Base\MQL5\Experts\Live EAs\QM5_1556_aa-zak-mom12.ex5`
  (build/deploy mtime 2026-07-13 06:47)
- SHA256 (measured): `9371a8a03008e2fd8a3fc9dbec75586f7ade71ea857e9ff8f9c3fd0fd95cb3cb`
- Admission manifest `C:\QM\deploy\DXZ23_2026-07-12\live_eas_sha256.txt`: `9371a8a0…` → **MATCH** ✓
  (07-19 final book left this sleeve unchanged — "Bestand"; its SHA file lists only the 2 new 07-19 binaries)
- Preset: `…\MQL5\Presets\22_XAUUSD_D1_QM5_1556_aa-zak-mom12.set` (ENV=live, `RISK_FIXED=0`, `RISK_PERCENT=0.6017`, `PORTFOLIO_WEIGHT=1`, `qm_magic_slot_offset=4`)
- Magic: **15560004** (ea_id·10000+slot4) — consistent across set file, EA runtime log (`magic:15560004`) and deal stream ✓
- **Provenance caveat:** the set file's `build_hash` header is `07671ebe…` (set_version s20260627-001, dated 2026-06-27, pre-repair) — it does **not** match the running binary SHA `9371a8a0…`. The binary is correct per the admission SHA manifest; the set-file build_hash is stale.

### 2. Live behaviour since 2026-07-13
Source for all figures: `live_deals_normalized.csv`, magic 15560004.
- Trades: **5 round-trips** (10 deals: 5 IN / 5 OUT). All within window.
- Distinct trading days (entry-day basis): **5** — 2026-07-13, 07-20, 07-27, 08-06, 08-13
- First deal 2026-07-13T20:52:07Z; last deal 2026-08-14T18:00:00Z (flat since)
- Realised P&L (Σ net_actual, incl. commission+swap): **+164.09 USD** (gross profit-only +190.06)
  Per closed trade net: +14.62, +74.17, −50.52, +168.11, −41.26
- Drawdown: realized-PnL-curve maxDD over closed trades = **−50.93 USD** (single losing trade 07-31→08-06). NOTE: per-sleeve *floating* equity drawdown is not separable from the shared account and is not recoverable from the deal stream (see Gaps).

### 3. Operating continuity
Source: `QM5_1556_ea-1556.log`.
- First INIT_OK 2026-07-13T06:37:20Z; EQUITY_SNAPSHOT emitted throughout; log current to 2026-08-20.
- Restarts in window: DEINIT reason 9 (terminal close) ×12, reason 5 (parameters) ×1 — each followed by clean re-INIT_OK. No missed-session gap; no HALT / kill-switch trip.
- **KS kill-switch dormant 2026-07-13 → 2026-08-14:** init logged `KS_BASELINE_ABSENT` on 07-13; baseline file written 2026-07-25 but only `KS_BASELINE_LOADED` (n=53) on the 2026-08-14T17:01Z restart. ~32 days of KS dormancy at the start of probation.

### 4. Gate-evidence vintage
| Gate | Verdict | Date | Evidence path |
|---|---|---|---|
| Q06 | PASS (pf=2.020:dd=2.68:stress=HARSH) | **2026-07-05** (pre-probation) | `D:\QM\reports\pipeline\QM5_1556\Q06\aggregate.json` |
| Q07 | PASS (var 0.00) — **INVALID, see §5** | **2026-07-05** (pre-probation) | `D:\QM\reports\pipeline\QM5_1556\Q07\aggregate.json` |
| Q08 | FAIL_SOFT | 2026-08-18 | `…\work_items\36d46f72-…\QM5_1556\Q08\XAUUSD_DWX\aggregate.json` |
| Q10 | PASS (pf=1.930:dd=2.68, 53 trades) | 2026-07-24 | `D:\QM\reports\pipeline\QM5_1556\Q10\XAUUSD_DWX\aggregate.json` |

**Flags:** Q06 and Q07 both predate probation start (2026-07-05 < 07-13). Q07 is additionally invalid (§5). Q08 stands at FAIL_SOFT. The DB row `ea_metrics` for Q07 XAUUSD points at a now-missing work_items aggregate (`5b9d5cf2-…`, src=missing) and carries a PASS from the stale canonical file.

### 5. Seed effectiveness — CONFIRMED DEFECT
- Binding Q07 (`…\pipeline\QM5_1556\Q07\aggregate.json`, 2026-07-05): verdict PASS, reason
  `variance_pct=0.00<20.0:min_pf=2.020`. per_seed_pf = **[2.02, 2.02, 2.02, 2.02, 2.02]**, spread 0.0, and identical dd_pct 2.68323 across all 5 seeds {42,17,99,7,2026}. **Zero variance = seeds never took effect; this Q07 did not test what it claims.** (OWNER's measurement confirmed.)
- A corrected rerun with working seeds exists but is **orphaned / not bound**: `D:\QM\reports\q07_rerun_20260725\1556_XAUUSD_DWX\QM5_1556\Q07\XAUUSD_DWX\aggregate.json` (2026-07-25): verdict **FAIL**, reason `pf_variance_pct=21.20>=20.0`, per_seed_pf [2.01, 2.19, 1.99, 1.76, 2.19], spread 0.43. **When seeds actually perturb the run, 1556/XAU Q07 FAILS the 20% gate.**
- Net: 1556/XAU stands on a Q07 that is both stale (pre-probation) and inert; the only seed-effective measurement available is a FAIL.

---

## 2) QM5_10706 / GBPUSD.DWX

### 1. Identity
- Attached binary: `…\Experts\Live EAs\QM5_10706_tv-mon-ls.ex5` (mtime 2026-07-13 06:46)
- SHA256 (measured): `01e34b2059de6ed505d445ce9fcbac7da0eb10d51e5cbcbbd18d38a968916078`
- Admission manifest `01e34b20…` → **MATCH** ✓ (unchanged in 07-19 final book)
- Preset: `…\Presets\11_GBPUSD_H1_QM5_10706_tv-mon-ls.set` (ENV=live, `RISK_FIXED=0`, `RISK_PERCENT=0.0530`, `PORTFOLIO_WEIGHT=1`, `qm_magic_slot_offset=1`, strategy params present)
- Magic: **107060001** — consistent across set/log/stream ✓
- Provenance caveat: set-file `build_hash=pending` (never recorded); binary verified against admission SHA manifest.

### 2. Live behaviour since 2026-07-13
Source: `live_deals_normalized.csv`, magic 107060001.
- Trades: **5 round-trips** (10 deals). Distinct trading days (entry-day): **5** — 2026-07-14, 07-28, 08-05, 08-12, 08-18
- First deal 2026-07-14T07:00:00Z; last deal 2026-08-19T12:37:33Z (flat since)
- Realised P&L (Σ net_actual): **+219.46 USD** (gross profit-only +236.37)
  Per closed trade net: −56.56, +168.46, −53.85, +1.44, +164.70
- Drawdown: realized-PnL-curve maxDD = **−58.33 USD** (opening trade 07-14 SL). Floating-equity per-sleeve DD not separable (see Gaps).

### 3. Operating continuity
Source: `QM5_10706_ea-10706.log` (27 MB — EA logs per-bar TM_MODIFY/BROKER_OTHER; verbose but healthy).
- First INIT_OK 2026-07-13T06:29:35Z; log current to 2026-08-20.
- Restarts: DEINIT reason 9 ×12, reason 5 ×1, each with clean re-INIT_OK. No HALT / kill-switch trip.
- **KS dormant 2026-07-13 → 2026-08-14** (same pattern): `KS_BASELINE_ABSENT` at init; `KS_BASELINE_LOADED` (n=284) on 2026-08-14T17:01Z restart.

### 4. Gate-evidence vintage
| Gate | Verdict | Date | Evidence path |
|---|---|---|---|
| Q06 | PASS (325–326 trades) | 2026-07-18 | `…\work_items\b450f8ec-…\QM5_10706\Q06\GBPUSD_DWX\aggregate.json` |
| Q07 | PASS (var 10.71) | 2026-07-18 | `…\work_items\0c395bec-…\QM5_10706\Q07\GBPUSD_DWX\aggregate.json` |
| Q08 | PASS (360 trades) | 2026-08-18 | `…\work_items\335d9197-…\QM5_10706\Q08\GBPUSD_DWX\aggregate.json` |
| Q10 | PASS (pf=1.510:dd=19.93, 284 trades) | 2026-07-25 | `D:\QM\reports\pipeline\QM5_10706\Q10\GBPUSD_DWX\aggregate.json` |

**Flags:** all four gates post-date probation start and are evidence-bound. (Q08 was INFRA_FAIL/FAIL_HARD through 07-18/19 and only turned PASS on 2026-08-18; a stray 08-21 aggregator snapshot shows FAIL_SOFT with src=missing/no evidence — the evidence-bearing run is the 08-18 PASS.) Clean.

### 5. Seed effectiveness — HEALTHY
- Q07 (`…\0c395bec-…\aggregate.json`, 2026-07-18): reason `variance_pct=10.71<20.0:min_pf=1.330`, per_seed_pf **[1.40, 1.45, 1.33, 1.48, 1.34]**, spread 0.15. Seeds genuinely perturb the run. **No zero-variance signature.**

---

## 3) QM5_13128 / NDX.DWX

### 1. Identity
- Attached binary: `…\Experts\Live EAs\QM5_13128_pre-fomc-drift-ndx.ex5` (mtime 2026-07-13 06:47)
- SHA256 (measured): `364867a9fe8d58478ade5526aad19deb377a35b313cfdac29763bb2eb82d273b`
- Admission manifest `364867a9…` → **MATCH** ✓ (unchanged in 07-19 final book)
- Preset: `…\Presets\14_NDX_H1_QM5_13128_pre-fomc-drift-ndx.set` (ENV=live, `RISK_FIXED=0`, `RISK_PERCENT=1.0000`, `PORTFOLIO_WEIGHT=1`, `qm_magic_slot_offset=0`, `qm_ea_id=13128`)
- Magic: **131280000** — set and EA runtime log agree ✓
- Provenance caveats: set-file `build_hash=pending`. Also the set file carries **no news-filter params** and the EA logs `NEWS_CALENDAR_SKIPPED reason=all_news_axes_off` (news gating OFF for this sleeve — unlike 1556/10706 which run `qm_filter_news_mode=3`).

### 2. Live behaviour since 2026-07-13
Source: `live_deals_normalized.csv`.
- Trades under magic 131280000: **ZERO** (0 deals in the entire stream).
- The 3 magic-0 NDX deals in the stream are **not** attributable to 13128: one is a 10692 exit whose closing deal recorded magic 0 (2026-07-10, comment-linked to the 106920005 entry); the other is a 1.00-lot, empty-comment round-trip (2026-07-27, −1536.75 net) that carries no 13128 strategy tag. All other NDX deals belong to 10440 (104400003) and 10692 (106920005).
- Realised P&L attributable to 13128: **0.00** (no positions). No drawdown (never in market).
- NOTE: the `EQUITY_SNAPSHOT.day_pnl`/`month_pnl` values in 13128's own log are **account-wide** (the EA reads ACCOUNT_EQUITY), not 13128-specific — do not attribute them to the sleeve.

### 3. Operating continuity
Source: `QM5_13128_ea-13128.log`.
- First INIT_OK 2026-07-13T06:29:55Z; daily EQUITY_SNAPSHOT emitted continuously through 2026-08-20 → **sleeve is alive and evaluating bars**, it simply never took a signal (a pre-FOMC-drift EA; FRIDAY_CLOSE events show `closed:0`).
- Restarts: DEINIT reason 9 ×n (incl. 2026-08-14T16:54, REASON_CLOSE/terminal shutdown), clean re-INIT_OK each time. No HALT / kill-switch trip.
- **KS dormant 2026-07-13 → 2026-08-14:** `KS_BASELINE_ABSENT` at init; `KS_BASELINE_LOADED` (n=57, mean 78.5572, std 244.6197) on the 2026-08-14T16:57Z restart.

### 4. Gate-evidence vintage
| Gate | Verdict | Date | Evidence path |
|---|---|---|---|
| Q06 | PASS (53 trades) | 2026-07-31 | `…\work_items\ee7bd4cd-…\QM5_13128\Q06\NDX_DWX\aggregate.json` |
| Q07 | PASS (var 27.38) | 2026-08-05 | `…\work_items\e823ce10-…\QM5_13128\Q07\NDX_DWX\aggregate.json` |
| Q08 | PASS (57 trades) | 2026-08-18 | `…\work_items\91a6f7bc-…\QM5_13128\Q08\NDX_DWX\aggregate.json` |
| Q10 | PASS (pf=2.290:dd=1.25, 57 trades) | 2026-07-24 | `D:\QM\reports\pipeline\QM5_13128\Q10\NDX_DWX\aggregate.json` |

**Flag — vintage inversion:** the closing Q10 (2026-07-24) is **older** than the Q06 (07-31) and Q07 (08-05) it should summarize — the sub-gates were re-run after Q10, so the standing Q10 verdict predates the current robustness evidence. All four post-date probation start; all evidence-bound. (Q08 was INFRA_FAIL/FAIL_SOFT through 07-18 and only turned PASS on 2026-08-18.)

### 5. Seed effectiveness — HEALTHY
- Q07 (`…\e823ce10-…\aggregate.json`, 2026-08-05): reason `second_axis:variance_pct=27.38<40.0:min_pf=1.970>=1.1`, per_seed_pf **[2.55, 2.62, 1.97, 2.37, 2.36]**, spread 0.65. Seeds genuinely perturb the run. **No zero-variance signature.**

---

## KS baseline status (chk_ks_baseline_dormancy: loaded_ok=23, no_baseline_file=1)
All three probation sleeves have a baseline file present and now loaded:
- `QM5_1556_XAUUSD.json` (n=53), `QM5_10706_GBPUSD.json` (n=284), `QM5_13128_NDX.json` (n=57)
  in `C:\QM\mt5\T_Live\MT5_Base\MQL5\Files\QM\baselines\` (also `_DWX` aliases), all `KS_BASELINE_LOADED` since the 2026-08-14 restart.
- **None of the three is the `no_baseline_file=1` sleeve.** Per the 2026-08-02 KS-recompile decision the single uncovered book member is **QM5_10440** (no Q10 PASS exists — honest gap), consistent with 23 loaded + 1 missing = 24.
- Caveat worth flagging for the review: all three ran **KS-dormant for the first ~32 days of probation** (2026-07-13 → 2026-08-14); kill-switch protection over most of the window was not actually armed.

## Live behaviour vs backtest expectation
- **QM5_13128/NDX — no live signal at all.** Zero trades in the window. This is *consistent* with its Q10 profile (57 trades / 9 yr ≈ 6/yr → ~0.7 expected in a 40-day window; pre-FOMC-drift with no qualifying event in-window), so not a contradiction — but the probation produced **zero live edge evidence** for this sleeve.
- **QM5_1556/XAU — possible frequency divergence (flag).** Live cadence ≈ 5 round-trips in 32 days (~weekly entries, closed each Friday via `qm_tm_close`) ≈ ~57 entries/yr annualized, vs Q10 = 53 trades / 9 yr ≈ 6/yr — roughly a 10× higher live turnover. A plausible benign explanation is the 2026 gold up-trend keeping the 12-month-momentum signal continuously long (weekly re-entry) where the 9-year backtest was long only intermittently; but the gap is large enough to warrant a look, especially given the invalid Q07 (§1.5).
- **QM5_10706/GBP** — live ≈ 5 round-trips in 37 days (~49/yr) vs Q10 284/9 yr ≈ 32/yr; same order of magnitude, no contradiction.

## Gaps and what would close them
1. **[Biggest] 1556/XAU has no valid, bound robustness evidence.** The binding Q07 (2026-07-05) is inert (variance 0.00, identical per-seed PF/DD) and pre-probation; the only seed-effective Q07 (2026-07-25) is orphaned and **FAILS** (variance 21.20 ≥ 20). Q06 is also pre-probation (07-05) with the same single-run PF. *Close:* re-run Q06+Q07 for 1556/XAU on the running binary (SHA 9371a8a0…) with confirmed seed effect, and rebind the DB/canonical evidence. Until then 1556's robustness stack cannot be trusted.
2. **Per-sleeve floating-equity drawdown is not recoverable** from the normalized deal stream (realized-PnL-curve DD is a lower bound only). *Close:* export per-position mark-to-market or the per-magic equity curve from the account (would need an MT5 history export, OWNER-side).
3. **13128/NDX produced zero live trades** → no live confirmation of its edge in the probation window. *Close:* extend observation past a live FOMC event, or judge the sleeve on backtest evidence alone.
4. **Q10 vintage inversion on 13128** (Q10 07-24 older than Q06 07-31 / Q07 08-05). *Close:* re-run Q10 on the current binary so the closing verdict post-dates its sub-gates.
5. **Set-file provenance hygiene:** 1556 build_hash stale (07671ebe… ≠ running 9371a8a0…); 10706 & 13128 build_hash=pending. Binaries themselves are SHA-verified against the admission manifest, so this is a documentation gap, not an identity mismatch. *Close:* regenerate set-file headers from the deployed EX5 SHAs.
6. **KS dormancy over most of probation:** all three unarmed 07-13 → 08-14. Informational for the review; already resolved by the 08-14 restart.

### Identity summary (all three)
| Sleeve | Running SHA256 | Admission SHA | Match |
|---|---|---|---|
| 1556/XAU | 9371a8a03008e2fd…d95cb3cb | 9371a8a0… | ✓ |
| 10706/GBP | 01e34b2059de6ed5…968916078 | 01e34b20… | ✓ |
| 13128/NDX | 364867a9fe8d5847…b82d273b | 364867a9… | ✓ |

---

# Nachtrag Claude, 2026-08-21 — die Evidenzkette von QM5_1556 aufgelöst

Der Befund „Q07 inert, korrigierter Rerun FAILT" ist **so nicht haltbar**. Nachgemessen:

## 1 · Der verwaiste Rerun scheitert an einer abgeschafften Regel

`D:\QM\reports\q07_rerun_20260725\1556_XAUUSD_DWX\...\aggregate.json`:

| Seed | 42 | 17 | 99 | 7 | 2026 |
|---|---|---|---|---|---|
| PF | 2.01 | 2.19 | 1.99 | **1.76** | 2.19 |

`variance_pct = 21.20`, `min_pf = 1.76`. Gestempelt wurde `FAIL: pf_variance_pct=21.20>=20.0`
— also nach der **einachsigen** Regel.

**Am selben Tag, dem 2026-07-25, hat der OWNER die Zweitachse ratifiziert**
(`decisions/2026-07-25_q07_second_axis_worst_seed_pf.md`, Commit `5f677d865`; im Code
`framework/scripts/q07_multiseed.py:56-58`): Varianz in **[20 %, 40 %)** ist zulässig, wenn der
**schlechteste Seed** die Kostenrausch-Untergrenze **1,10** hält. Varianz ≥ 40 % scheitert
weiterhin, ein verlierender Seed (< 1,0) ebenfalls.

Hier: Varianz 21,20 liegt im Toleranzband, schlechtester Seed 1,76 liegt **weit** über 1,10.
**Unter dem heute gültigen Vertrag ist dieser Lauf ein PASS.** Das „FAIL" ist ein Artefakt der
Regel, die am Tag des Laufs ersetzt wurde.

## 2 · Aber er beschreibt nicht den Live-Sleeve

Drei verschiedene Binaries, alle drei gemessen:

| Rolle | SHA256 (Kopf) | Herkunft |
|---|---|---|
| **live** (handelt) | `9371a8a0…` | `C:\QM\mt5\T_Live\...\Live EAs\QM5_1556_aa-zak-mom12.ex5` |
| Fabrik (heute) | `0962ca65…` | `framework/EAs/QM5_1556_aa-zak-mom12/…ex5` |
| Rerun vom 25.07. | `9d95921e…` | `execution_identity.expert_binary`, gebaut 2026-07-24 |

Der seed-wirksame Lauf lief also auf einem **dritten** Artefakt. Er ist die beste vorhandene
Robustheitsevidenz — aber er ist **nicht an das Binary gebunden, das live handelt**.

## 3 · Was daraus folgt

- Die **gebundene** Q07-Evidenz (05.07., `variance_pct = 0.00`, fünf identische PF 2.02 und
  identische DD) hat die Seed-Robustheit **nicht getestet**. Sie trägt nichts.
- Die **seed-wirksame** Evidenz (25.07.) besteht unter heutigem Vertrag, beschreibt aber ein
  anderes Binary.
- **QM5_1556 hat damit keine gültige, an das laufende Binary gebundene Robustheitsevidenz.**

Nach der am 2026-08-21 ratifizierten Matrix (MNT-036 §A.2) ist die Evidenz-Achse für diesen
Sleeve deshalb **nicht entscheidbar** — der Ausgang wäre zwangsläufig EXTEND. Das ist besser
als ein REMOVE auf ein Verdikt, das eine abgeschaffte Regel anwendet, und ehrlicher als ein
CONTINUE auf Evidenz, die ein anderes Artefakt beschreibt.

**Die Lücke schließt genau eine Messung:** ein Q07 auf einer *Kopie* des Live-Binarys
(niemals im T_Live-Verzeichnis, niemals AutoTrading). Ob der Binary-Unterschied überhaupt
materiell ist, adressiert die Kausalitätsstudie aus MNT-043 („Recompiles ändern Streams,
nicht Verdikte") — falls sie hier trägt, ist der 25.07.-Lauf übertragbar und der Sleeve
sauber. Diese Übertragung zu behaupten, ohne sie zu prüfen, wäre aber genau die Art
Abkürzung, die diesen Fall überhaupt erst erzeugt hat.

## 4 · Zweiter, schwererer Befund: QM5_10440/NDX

Beim Nachgehen der KS-Baseline (die fehlende gehört diesem Sleeve) gemessen:

**QM5_10440/NDX ist der einzige der 21 Live-EAs ohne ein einziges Q10-PASS — und trägt ein
Q10 `FAIL` vom 2026-07-25.** Dazu Q08 `FAIL_HARD` (1×) und `FAIL_SOFT` (5×), Q05
`INFRA_FAIL` (34×). Im Manifest `portfolio_manifest_live_24sleeve_20260724.json` steht er mit
Magic `104400003`, Gewicht 1,0 und `risk_percent` 0,0577.

Q10 ist laut Pipeline-Kanon „the closing per-(EA, symbol) verdict". Ein Live-Sleeve auf einem
gescheiterten Abschlussverdikt ist eine OWNER-Frage, keine Claude-Entscheidung.

**Folge für MNT-001:** Die OWNER-genehmigte Empfehlung lautet „Baseline **aus der
Q10-Evidenz** erzeugen". Für 10440 existiert keine bestandene Q10-Evidenz — der Auftrag ist
so nicht ausführbar. Der Codex-Task `f421b62a` wurde entsprechend korrigiert.
