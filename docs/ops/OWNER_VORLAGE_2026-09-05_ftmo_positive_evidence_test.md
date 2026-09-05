# OWNER-Vorlage 2026-09-05 — FTMO Positive-Evidence-Abnahmetest

Status: PENDING (OWNER-Ratifizierung). Klasse: **ROT** (kauf-nah), **kein Auffangregel**.
Autor: Claude (Factory CEO). Bindet: `decisions/2026-09-02_owner_receipts_ceo_asks.md` Zeile 6 (FTMO NO-BUY, `:13`); dieser Test ist Receipt-Zeile 18 (PENDING), PENDING.

> **Integrationsstand (CEO, 2026-09-05):** Die im Entwurf als „Schwester-Deliverables“ markierten Belegdateien (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md`, `2026-09-05_news_calendar_timestamp_defect.md`, `2026-09-04_fund_score_current_population.md`) und die Receipt-Zeilen 1–17 liegen auf `agents/board-advisor` vor; dieser Test ist Receipt-Zeile **18** (PENDING). Die Zeilennummern der Belege wurden beim Integrations-Commit nicht neu verifiziert und werden im Siegel-Schritt (§E) vor dem ersten Ergebnis erneut geprüft.

---

## 1 · LAGE (Deutsch, eine Seite)

**Der Park-Trigger ist heute undefiniert.** Beleg-Zeile 6 (`decisions/2026-09-02_owner_receipts_ceo_asks.md:13`) hält den FTMO-Kauf auf NO-BUY und re-ankert den Trigger auf „positive OOS/live evidence" (verbatim: „ja, wann kommen wir aber auf FTMO?"). Die Schwester-Analyse (`docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md`, Trigger-Lücke) nennt genau das: **„positiv" ist nicht definiert und würde nach dem Ansehen der Ergebnisse zu Ad-hoc-Selektion.** Die Schließung ist eine datierte Entscheidung, die Population, Metrik, Unsicherheit und zulässige Evidenzklasse festlegt — ratifiziert **bevor** ein Ergebnis gesehen wird.

**Heutiger Messstand (read-only farm_state.sqlite + Belege dieses Branches):**
- Population: **8 identitätsgebundene Q08-Tages-PnL-Ströme** (= die Q14 KEEP_INCUMBENT-Zeilen; 9 Zeilen / 8 Paare, 11421:EURUSD doppelt). SHA-256-pinned in `docs/ops/evidence/2026-09-04_fund_score_current_population.md` (Schwesterdatei).
- FUND_SCORE aller 8 Ströme **< 1.0** (Floor = 1.0, `build_book_ftmo.py:53`), Buch verweigert; Zähler **8/25** Paare → `BOOK_BUILD_REFUSED` (`tools/strategy_farm/book_build_guard.py:28,236`).
- Der einzige billige entscheidende Test — ein **gültiger 2026-Q1-OOS-Pass (~3 Terminalstunden)** — **ist nie gelaufen** (`docs/ops/CEO_AUDIT_2026-09-02.md:14`) und ist doppelt blockiert: (i) 15/15 Confirmation-Jobs liefen 2024 statt 2026 (Dispatch-Bug, `--apply` deferred), (ii) das OOS-Fenster **2026-01-01..2026-04-06** liegt im **Kalender-Loch 2025-05..2026-06** (null News-Zeilen), misst also ohne News (`docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md`, Schwesterdatei).
- Live-Buch (governed-only, die zwei manuellen magic=0-Trades ausgeschlossen per Beleg-Zeile 1): **−469 USD über 30 aktive Tage, Sharpe-CI [−6.8, +4.6]** — statistisch nicht informativ (`docs/ops/CEO_AUDIT_2026-09-02.md:14`).
- DSR/Multiple-Testing über die 8 Kandidaten: **0 Sleeves erreichen DSR ≥ 0.95** (`...:14`; 0/24 und 0/21 für jedes N≥10, `...:43`), E[max SR] unter Null ~1.06–1.44 (`...:14`), modellierte +2.4-Buch-Sharpe überlebt Korrektur bei ~0 % (`...:14`); Walk-Forward zeigt 82 % PF>1 (`...:14`), Held-out-Folds 61/74 PF>1, geo-mean OOS PF 1.47 (selektionskonditioniert, `...:45`) — lehnt gegen Null-Edge, aber nicht kauf-tragend.

**Kernpunkt:** Der 25-Paar-Zähler ist eine **Kauf-Vorbedingung**, NICHT der Positive-Evidence-Trigger. Ihn zu bestehen ersetzt den Trigger nicht.

## 2 · EMPFEHLUNG

1. **NO-BUY beibehalten.** Kein Ergebnis liegt vor, das den Trigger erfüllt.
2. **Diesen vorab-deklarierten, widerlegbaren Abnahmetest ratifizieren** (Population / Metrik / Unsicherheit / Evidenzklasse / Refutationsklausel / Siegel), BEVOR ein Ergebnis gesehen wird. **Keine neuen Zahlen** — jede Schwelle ist ein bestehender, zeilengenau belegter Policy-Wert (§B–§E des englischen Vertrags).
3. **Reihenfolge:** zuerst Kalender E1/E4 reparieren + Loch-Backfill (Schwester-Vorlage, receipt row 8), DANN eine **versiegelte, ausreichend gepowerte** OOS-Messung auf dem korrigierten Fenster; erst dann zählt OOS als Evidenz. **Der einzelne 13-Wochen-Diagnosefenster-Lauf ist für sich genommen NICHT zulässig** (§D ist bis zur Beantwortung von OQ-2 inert).
4. Kauf, T_Live, AutoTrading, Deployment bleiben **separate, einzeln signierte** OWNER-Zeremonien — dieser Test hebt NO-BUY höchstens auf „positive-evidence-met", nicht auf „gekauft".

## 3 · ENTSCHEIDUNGSFRAGEN (je mit Rollback + Cost-of-Wait)

| Q | Frage | Klasse | Rollback | Cost-of-Wait |
|---|-------|--------|----------|--------------|
| **Q1** | Diesen Abnahmetest ratifizieren (Population/Metrik/Unsicherheit/Evidenzklasse/Refutation/Siegel wie §A–§F)? | ROT | Test bleibt unratifiziert; alle Evidenz bleibt erhalten; keine Verdikte berührt. | Jede weitere Messung ohne ratifizierten Test riskiert Ad-hoc-Selektion; der Trigger bleibt undefiniert und blockiert den FTMO-Zeitplan, den OWNER erfragt hat (Zeile 6, „wann kommen wir auf FTMO?"). |
| **Q2** | **Zulässige Evidenzquelle festlegen (OQ-2, blockierend für §D).** Genügt ein einzelnes Diagnosefenster (2026-01-01..04-06, 1 Seed, 1 Config, `diagnostic_non_admission=true`), oder ist ein breiterer versiegelter Holdout (Multi-Seed/Multi-Fenster oder explizit erweitertes OOS mit angegebenem effektiven n) erforderlich? | ROT (Population/Unsicherheit) | §D bleibt inert; keine Messung zählt als Lift-Quelle. | Ohne Antwort ist der Test nicht entscheidbar: die einzige billige Quelle ist selbst-deklariert non-admitting; NO-BUY bliebe unbestimmt lange geparkt. |
| **Q3** | Den P1-Latten-Konflikt explizit vereinheitlichen? Builder verlangt **Bootstrap-Lower ≥ 0.80** (`build_book_ftmo.py:54`); Rulepack verlangt **Punkt ≥ 80 % UND Lower-95 ≥ 70 %** (`...V2.json:480`). | ROT (Buchregeln/Zahlen) | Versionierte Reconciliation, nie stille Reklassifizierung; dieser Test zitiert bis dahin die **strengste** existierende Menge (§B/§D). | Ohne Vereinheitlichung kein konsistentes Geld-Dossier; zwei Verträge könnten sich später widersprechen. |
| **Q4** | Evidenzklasse bestätigen: OOS-2026 zählt **erst nach** Kalender-Reparatur + korrigiertem Fenster; Live-Attribution **governed-only** (manuelle magic=0-Trades ausgeschlossen, Zeile 1); Live ist **stützend, nicht hinreichend**? | ROT | Kein Rollback nötig — reine Vorab-Festlegung. | Ohne Festlegung misst OOS ohne News (Kalender-Loch) und Live-Zahlen werden durch die manuellen Trades verzerrt (~76 % des −2.227-USD-Verlusts, `...:14`). |

Alles ROT. **Kein Auffangregel.** Ratifizierung nur durch OWNER (alleinige menschliche Autorität).

---

# ENGLISH CONTRACT — FTMO Positive-Evidence Acceptance Test (predeclared, refutable)

Ratify this contract text verbatim before any evaluation stream is opened. Every threshold below is a path-referenced EXISTING policy value; this contract invents none. Anchors marked **[cross-branch — re-verify at seal]** point at sibling artifacts not present in this worktree (see Provenance note above).

## §A · Evidence sources and admissibility

**Admissible population (sealed).** Exactly the 8 identity-bound Q08 daily-PnL streams of the current bundle = the Q14 `KEEP_INCUMBENT` rows (measured: 9 rows / 8 distinct pairs, 11421:EURUSD twice; `farm_state.sqlite`, read-only). Byte-pinned by SHA-256 in `docs/ops/evidence/2026-09-04_fund_score_current_population.md` **[cross-branch — re-verify at seal]**:

| ea_id | symbol | stream SHA-256 (prefix) |
|-------|--------|-------------------------|
| 10706 | GBPUSD | 71fb35b8… |
| 11421 | EURUSD | e9d0a9ef… |
| 11422 | USDCAD | 7ce6cc3e… |
| 11910 | NZDUSD | 555bbee2… |
| 13054 | XTIUSD | 67d4fe2c… |
| 1537  | XAGUSD | 1885c21e… |
| 20048 | XTIUSD | a792e263… |
| 21505 | XAGUSD | 243804fa… |

(Stream SHA-256 prefixes carried from the sibling FUND_SCORE population artifact; re-verify the full digests against that file at seal time.)

**Admissibility rules (predeclared):**

| # | Rule | Basis |
|---|------|-------|
| a | **Governed-only live attribution.** The two `magic=0` live trades (27.07 NDX 1.00 lot, 24.07 EURUSD 0.43 lot) are OWNER manual trades and are EXCLUDED from every governed track-record read. | `decisions/2026-09-02_owner_receipts_ceo_asks.md:8` (row 1); `docs/ops/CEO_AUDIT_2026-09-02.md:14` (those two ≈ 76 % of the −2,227 USD live loss; governed book alone −469 USD / 30 days, Sharpe CI [−6.8,+4.6]). |
| b | **No manual trades count as evidence** (neither for nor against). | row 1, as above. |
| c | **No re-selection after results are seen.** The roster of 8 identities is frozen at seal; no addition, removal, or substitution after the first result is opened. | Astra Trigger row **[cross-branch — re-verify at seal]**, `docs/ops/evidence/2026-09-04_astra_ftmo_book_analysis.md`. |
| d | **OOS-2026 confirmation counts ONLY after the calendar repair (E1/E4) AND on the corrected window 2026-01-01..2026-04-06 AND only if the source qualifies under OQ-2** (single diagnostic window is NOT admissible on its own — see §D gate). | §A calendar precondition below; `docs/ops/evidence/2026-09-05_news_calendar_timestamp_defect.md` **[cross-branch — re-verify at seal]**. |

**Calendar-defect precondition (operative blocker — must be closed before any OOS-2026 result is admissible).** Two independent defects (both from the sibling news-calendar defect artifact, **[cross-branch — re-verify at seal]**):

1. **Dispatch/window bug.** 15/15 completed confirmation jobs ran **2024** in both INIs and reports despite 2026 input manifests. Repaired by commit `1ac9f653d8` (repair-oos-window contract) but `repair-oos-window --apply` is **DEFERRED** (task 1721f3a1 IN_PROGRESS).
2. **Calendar coverage hole.** The window 2026-01-01..2026-04-06 lies INSIDE the coverage hole (2025-05 through 2026-06 = zero rows; 2025-04 partial), so successor runs would measure with **no news events at all**. Repair (E1) + hole backfill are OWNER ROT decisions — separate Vorlage 2026-09-05 = receipt **row 8 PENDING** **[cross-branch — the receipts file on this branch ends at row 6; re-verify the row number on the integration branch]**.

Notes: The OOS-2026 campaign is **diagnostic by design** — `campaign_plan.json` sets `diagnostic_non_admission=true`, `diagnostic_single_window=true`, single seed / single config (`D:/QM/strategy_farm/artifacts/oos_2026_confirmation_v1/campaign_plan.json`, read-only). Because it is non-admitting by its own declaration, it is a diagnostic, not a lift source, unless OQ-2 is resolved to widen it (§D gate). Live trading is unaffected by the calendar defect — the live news branch reads the native MT5 calendar, not the CSVs. Of the 8, only 10706/GBPUSD (H1, explicit PRE30_POST30) is exposed to the timestamp defect; the other 7 are D1 bar-open (00:00 server) entries for which the defect is practically inert.

## §B · Metrics and thresholds (all derived from EXISTING policy — no new numbers)

**Provider rules** (rulepack `tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json` + snapshot `docs/ops/evidence/2026-09-04_ftmo_official_rules_snapshot.json`):

| Rule | Value | Path |
|------|-------|------|
| Phase-1 profit target | +10 % | rulepack `:96-104` (percent `:101`) |
| Verification profit target | +5 % | rulepack `:108-116` (percent `:113`) |
| Max daily loss | 5 % of initial (Prague-midnight balance − USD 5,000), equity incl. open PnL/swaps/commissions, breach `STRICTLY_BELOW_LIMIT` | rulepack `:120-131` |
| Max loss (static floor) | 10 % → USD 90,000 floor | rulepack `:140-146` |
| Min trading days | ≥ 4 CE(S)T days with a position OPENED | rulepack `:151-160` (`days:4` `:156`) |
| Pass condition | balance `STRICTLY_GREATER_THAN_TARGET`, all positions closed | rulepack `:173-181` (operator `:178`) |
| Time limit | none | rulepack `:163-170` |
| Evaluation fee | USD 540, refundable with first Reward | rulepack `:231-243` |
| Swing leverage | 1:30 FX / 1:15 metals+oil — **CARRIED_OVER / UNVERIFIED** (trading-symbols URL 404 on 2026-09-04; must be re-sourced before purchase) | rulepack `:255-257` |

**Decision gates** (rulepack `evaluation_profile.go_criteria`) — **cite the strictest existing set:**

| Criterion | Threshold | Path |
|-----------|-----------|------|
| Snapshot freshness | ≤ 7 days | rulepack `:459-464` (`maximum_age_days:7` `:462`) |
| Phase-1 pass | point ≥ **80 %** AND lower-95 ≥ **70 %** | rulepack `:477-481` (params `:480`) |
| Breach probability | upper-95 ≤ **10 %** | rulepack `:483-487` (params `:486`) |
| P2-conditional / joint | P2-conditional ≥ **85 %** AND joint ≥ **65 %** | rulepack `:489-493` (params `:492`) |
| Free-Trial / shadow | ≥ 1 clean run, 0 operational defects | rulepack `:495-499` (params `:498`) |
| Purchase | separate signed OWNER decision | rulepack go_criteria (owner-purchase gate) |

**Builder V2 OWNER_RATIFIED thresholds** (`tools/strategy_farm/portfolio/build_book_ftmo.py`, ratified under OWNER-DEC-BOOK-V2V4V6-EPOCH-20260904, `decisions/2026-09-04_owner_receipts_briefing_2_4.md:21,24-30`):

| Item | Value | Path |
|------|-------|------|
| FUND_SCORE floor | **1.0** | `:53` |
| P1 lower-bound floor | **0.80** | `:54` |
| DL-083 Q09 marginal-eval reject | 0.40 | `:69` |
| Max pairwise correlation | 0.50 | `:75` |
| Account unit-weight budget | 10.0 | `:76` |
| Sleeve unit weight | 1.0 | `:77` |
| min_sleeves | 3 | `:471` |
| min_active_days_per_60d | 4.0 (builder floor, NOT the full Q15 ceremony) | `:472` |
| Source-sleeve risk mode | RISK_FIXED=1000 / RISK_PERCENT=0 hard check | `:500-506` |

**FUND_SCORE formula** (`tools/strategy_farm/portfolio/fund_score.py`, verified in-worktree at `:59` med60, `:62` denominator, `:65` score): `FUND_SCORE = med60_1x / max(2.0, 2.0·|worst_day_1x|, wDD_p90_1x)`. Current-population rescore (commit `a774e850dc`, all < 1.0, NO-BUY unchanged; `docs/ops/evidence/2026-09-04_fund_score_current_population.md` **[cross-branch — re-verify at seal]**): 10706:GBPUSD 0.106901, 11421:EURUSD 0.015577, 11422:USDCAD 0.148329, 11910:NZDUSD 0.094695, 13054:XTIUSD 0.024265, 1537:XAGUSD 0.131237, 20048:XTIUSD 0.032985, 21505:XAGUSD 0.123500. (Line note: on this branch `fund_score.py` is 111 lines and the formula is computed at `:59-65`; no separate formula string exists at `:94-103`.)

**Book counter:** `MIN_QUALIFIED_PAIRS = 25` (`tools/strategy_farm/book_build_guard.py:28`, refusal `:236,:238`); census 8/25 → `BOOK_BUILD_REFUSED`. **The 25-pair counter is a purchase prerequisite, NOT the positive-evidence trigger — passing it cannot substitute for the trigger.**

**Concentration / tail** (`tools/strategy_farm/config/concentration_tail_limits.v1.json`, OWNER_RATIFIED via receipt row 4): stop_risk_budget_pct 2.5 (`:5`); caps as % of budget: symbol 40 (`:7`), asset_class 60 (`:8`), family 50 (`:9`), session WARN 60 (`:10`) / breach 70 (`:11`); tail: per_sleeve_worst_fraction 0.05 (`:14`), joint_sleeve_divisor 3 (`:15`), venue_daily_loss_limit_pct 5.0 (`:16`), maximum_fraction_of_daily_limit 0.8 (`:17`). Application to live weights remains a separate OWNER ceremony (`application_authority OWNER_ONLY` `:34`, `deployment_action NONE` `:35`).

**Speed doctrine** (`docs/research/FTMO_BOOK_SPEC_2026-08-02_OWNER_TIMEBOX.md`): P1 horizon **60** calendar days (`:13`), P2 horizon **30** calendar days (`:15`), design bar **P(Phase-1 pass) ≥ 0.80 measured as the moving-block bootstrap LOWER bound**, never the raw rate (`:19,26,59`). Mirrored in `ftmo_timebox_eval.py` `DEFAULT_RULES`: `design_bar_p1` 0.80 (`:77`); phase-1/2 horizons 60/30 in `DEFAULT_RULES` (`:63,:65`); bootstrap replicates 2000 / seed 20260802 / 60-day blocks / alpha 0.05 / two-sided 95 % (`:81-85`).

**Threshold conflict to reconcile (ROT — do NOT resolve unilaterally, decision Q3).** (a) builder requires bootstrap LOWER ≥ 0.80 (`build_book_ftmo.py:54`); (b) rulepack requires point ≥ 80 % AND lower-95 ≥ 70 % (`FTMO_2S_100K_SWING_V2.json:480`), breach upper-95 ≤ 10 % (`:486`), P2-conditional ≥ 85 % AND joint ≥ 65 % (`:492`); (c) timebox sets the design bar as lower-bound ≥ 0.80 (`ftmo_timebox_eval.py:77`, matches builder). **This test cites the strictest existing set (below in §D) and marks the builder-vs-rulepack lower-bound difference as an OWNER reconciliation item, inventing no new number.**

## §C · Sample-size floors, power, and the DSR engine (what the tooling can and cannot establish)

**Timebox / first-passage engines** (portfolio; none is a DSR engine, and none is a sealed once-only holdout by itself):

| Engine | What it establishes | What it CANNOT establish | Key params / path |
|--------|--------------------|--------------------------|-------------------|
| `ftmo_p1_mc.py` | Ranks compositions; daily/total-DD breach probabilities as explicit **lower bounds** (rules on CLOSED daily P&L; floating intraday DD invisible) | Joint tail independence (resamples sleeves INDEPENDENTLY — cross-sleeve correlation broken); DSR; an admission-quality bound | `:26` (independent resample); horizon 90 days `:70`, 10,000 paths `:71`, seed 20260720 `:72` |
| `challenge_firstpassage.py` | First-passage (+10 % before −5 % daily / −10 % total, no deadline) on END-OF-DAY balance; four-opening-day minimum enforced; effective sample size = overlapping starts ÷ median resolution time; preregistered **1x-no-overlay** block (selection-free) | A raw-n confidence read (starts OVERLAP); DSR; stages 1–2 are in-sample-selected and must NOT be the acceptance number | four-day `:32,:161`; preregistered 1x `:355-361,:378`; ESS `:389-390` |
| `ftmo_timebox_eval.py` | Selection-SEALED (prepare-config freezes input SHAs before any stream is opened); moving-block bootstrap; HAC effective-sample-size for autocorrelated overlapping starts; four-opening-day minimum; DL-083 correlation refusal ≥ 0.40, min 20 shared calendar days | Anything on DXZ streams — it **REFUSES** them (`REFUSED_FTMO_COST_ATTESTATION`); refuses DB/farm-state (mutable) inputs; DSR | `:60-86` (DEFAULT_RULES/BOOTSTRAP), `minimum_shared_calendar_days:92`, mutable refuse `:218-235,:345-346`, `REFUSED_COST_ATTESTATION:48` |

**DSR / multiple-testing engine (the correction IS tooled — it is NOT one of the three engines above).** The Deflated Sharpe / E[max SR under the null] correction is computed by the Q08 sub-gate 8.2 engine `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` — Bailey & López de Prado DSR (ref `:22`), `GATE_NAME "8.2_dsr_mc_fdr"` (`:32`), acceptance threshold **`DSR_P_MIN = 0.05`** (`:33`, i.e. DSR probability ≥ 0.95), `_expected_max_sharpe` E[max(SR₁..SRₙ)] ≈ √(2 ln N) (`:93-101`, note `:52`), funnel DSR via normal cdf with `effective_trial_count` (`:103-130`). **Declared trial count** for the pattern-WF selection = **154**, pinned as `census.DECLARED_TRIAL_COUNT` in `tools/strategy_farm/opt_census.py:36` (DL-089; test asserts `test_opt_census_pruning.py:365`); an identity's own trial count from its trial ledger overrides where present (`sub_8_2_dsr_mc_fdr.py:41-46`), otherwise the fleet default 154 applies. Measured baseline: **0 sleeves reach DSR ≥ 0.95** at any defensible trial count (`docs/ops/CEO_AUDIT_2026-09-02.md:14`; 0/24 and 0/21 for every N ≥ 10, `:43`); E[max SR] under the null ≈ 1.06–1.44 (`:14`); the modeled +2.4 book Sharpe survives correction at ≈ 0 % (`:14`); walk-forward held-out folds show 82 % PF>1 (`:14`) / 61/74 PF>1, geo-mean OOS PF 1.47 selection-conditioned (`:45`) — leaning against zero edge but not purchase-grade.

**Sample-size floors and error rate (predeclared, from existing policy):**
- **Declared error rate:** the moving-block bootstrap runs at **alpha = 0.05** (`ftmo_timebox_eval.py:83`), two-sided 95 % percentile CI (`:85`); the DSR gate runs at **p < 0.05** (`sub_8_2_dsr_mc_fdr.py:33`). These are the error rates against which the §D thresholds are read.
- **Opening-day floor:** ≥ 4 CE(S)T days with a position opened per phase (rulepack `:151-160`; enforced `challenge_firstpassage.py:32,161`).
- **Shared-calendar floor for correlation:** ≥ 20 shared calendar days (`ftmo_timebox_eval.py:92`).
- **Effective (not raw) n:** overlapping starts are divided by median resolution time / HAC-adjusted; report ESS, never the raw start count (`challenge_firstpassage.py:389-390`).
- **Minimum-power floor (binding).** The P1 lower-95 gate (rulepack `:480`) and the DSR bound (`sub_8_2_dsr_mc_fdr.py:33`) are only estimable when the sealed holdout carries enough effective (HAC) sample for the bootstrap lower bound to separate from the point estimate and for a peer cohort ≥ the DSR minimum (`sub_8_2_dsr_mc_fdr.py:48-52`). **A single diagnostic OOS window (2026-01-01..04-06 ≈ 13 weeks, one seed, one config, mostly D1-entry sleeves → tens of trades/sleeve) does not meet this floor and is declared UNDER-POWERED and therefore NON-LIFTING on its own.** Whether the source is widened to a multi-seed / multi-window sealed holdout (or an explicitly enlarged OOS with a stated effective-n) is the OQ-2 OWNER choice that gates §D.

## §D · Refutation clause (predeclared, symmetric — evaluated ONCE after the seal)

**§D is INERT until OQ-2 (admissible source, decision Q2) is resolved.** The single corrected 13-week diagnostic window is NOT admissible as a lift source on its own (§C minimum-power floor). Once OWNER designates the admissible sealed holdout, the following applies to the sealed 8-identity population.

**NO-BUY is LIFTED to `positive-evidence-met` ONLY if BOTH necessary conditions D.1 and D.2 hold simultaneously on the admissible sealed holdout:**

1. **A valid post-repair OOS pass** on the corrected 2026-01-01..2026-04-06 window (calendar E1/E4 applied; window-binding verified plan → INI → report identical), evaluated at the timebox 60/30-day horizons (`FTMO_BOOK_SPEC:13,15`) via the moving-block-bootstrap **LOWER** bound (`ftmo_timebox_eval.py:77,83`), meeting the **strictest existing go-criteria set**:
   - P1 point ≥ 80 % AND P1 lower-95 ≥ 70 % (rulepack `:480`), AND
   - breach upper-95 ≤ 10 % (rulepack `:486`), AND
   - P2-conditional ≥ 85 % AND joint ≥ 65 % (rulepack `:492`).
   - **Necessary screen (not the bar):** net expectancy after FTMO costs > 0, with failures/zeros retained and missingness documented. A break-even or positive window that does NOT clear the go-criteria above does NOT lift NO-BUY.
2. **The DSR / E[max SR under null] correction does not reject edge:** the sub-gate 8.2 result clears **DSR probability ≥ 0.95 (p < 0.05)** (`sub_8_2_dsr_mc_fdr.py:33`) over the declared trial count 154 per identity (`opt_census.py:36`, or the identity's own trial-ledger count where present) — NOT merely in-sample PF>1.

**Supporting (NOT necessary) input — D.3, never on its own sufficient and never able to lift alone:**

3. **Governed-only live attribution** (manual magic=0 trades excluded, row 1) is reported alongside with its stated uncertainty. Live is a SUPPORTING corroborant only; decisive weight is on D.1 and D.2. It is NOT part of the necessary conjunction and cannot by itself lift or block. (Rationale: governed live is −469 USD / 30 days, Sharpe CI [−6.8,+4.6] — statistically non-informative at this sample; `CEO_AUDIT:14`.) Its minimum informative sample and any numeric positive bar are OQ-5, unresolved; until then it is corroborative context, not a gate.

**NO-BUY is KEPT (the lift is refuted) if ANY of:**
- OQ-2 is unresolved, or the admissible source remains a single under-powered diagnostic window (§C floor);
- a fresh `PASS` for another year (e.g. 2024) re-appears — proves the dispatch repair failed;
- the OOS window still measures inside the calendar hole (no news events);
- any date/model/identity substitution occurs after the seal;
- the go-criteria in D.1 are not all met (including net expectancy after FTMO costs ≤ 0);
- the DSR-corrected edge does not clear DSR ≥ 0.95 (p < 0.05);
- **passing the 25-pair counter alone** — explicitly NOT sufficient to lift NO-BUY.

The cheapest decisive test is a valid, adequately-powered post-repair OOS pass; the ~3-terminal-hour single-window probe (`CEO_AUDIT:14`) is a diagnostic toward it, not itself the lift source.

## §E · Contamination and seal procedure

**Contamination (predeclared — any one voids the evaluation):**
1. **Look-ahead / mutable input** that changes under evaluation. Precedent: an EV script read a mutable stream dir that shrank from 21 → 5 sleeves, throwing results ≈ 16× off (`docs/ops/CEO_AUDIT_2026-09-02.md:15`; also `:56`). `ftmo_timebox_eval.py` SHA-pins every input and REFUSES DB/farm-state (`:218-235,:345-346`).
2. **Roster/identity change after results are seen** (re-selection).
3. **Calendar re-run or window substitution after the seal.**
4. **Refitting** leverage/overlay/composition on the scoring sample (`challenge_firstpassage.py` stages 1–2 are in-sample-selected and must NOT be used as the acceptance number; only the preregistered 1x block `:355-361` is selection-free).

**Seal procedure (before the first result is opened) — compute and record a sha256 over the following sealed inputs:**
1. This contract text.
2. The roster of the 8 identities with their exact stream SHA-256s from `docs/ops/evidence/2026-09-04_fund_score_current_population.md` **[cross-branch — re-verify at seal]**.
3. **The rulepack FILE sha256 `298ef1285eca49ea7f010ebc0a9353b5a821fccb40a025be129f5ca5314fd992`** (`tools/strategy_farm/config/target_rulepacks/FTMO_2S_100K_SWING_V2.json`, recomputed at seal time) — this is the config that ENCODES the go_criteria numbers (`:480/:486/:492`), so it must be bound directly.
4. The FTMO official-rules **`snapshot_sha256` `c199b8f5f528cce5a93f4751f63394de63e5fe832483ac9c4b9d0314732d2905`** — the FTMO web-page body snapshot embedded in the rulepack (`FTMO_2S_100K_SWING_V2.json:24`), the upstream provenance of the provider numbers. (This is the page snapshot, NOT the rulepack file hash — the two are distinct and both are sealed.)
5. The builder module sha of `tools/strategy_farm/portfolio/build_book_ftmo.py` (recomputed at seal time) — its floors (`:53,:54`) are equally load-bearing.
6. The DSR engine sha of `framework/scripts/q08_davey/sub_8_2_dsr_mc_fdr.py` (recomputed at seal time) — it carries the DSR acceptance threshold (`:33`).
7. The calendar-bundle sha AFTER the E1/E4 repair.

Then: run `ftmo_timebox_eval.py prepare-config` so the evaluator input digest is frozen; **OWNER (sole human authority) signs the sealed contract**; write the once-only evaluation receipt AFTER the seal.

**Who signs:** OWNER only. This is a ROT purchase-adjacent decision; automatic purchase is forbidden (rulepack go_criteria owner-purchase gate); T_Live / AutoTrading / deployment stay separate OWNER ceremonies.

## §F · Decision receipt row text (append to `decisions/2026-09-02_owner_receipts_ceo_asks.md` as the next free row — shown as row 9; confirm the number on the integration branch that carries rows 7–8)

> `| 9 | Ratify the predeclared FTMO positive-evidence acceptance test (docs/ops/OWNER_VORLAGE_2026-09-05_ftmo_positive_evidence_test.md) | PENDING | Seals population (8 identity-bound Q08 streams), metric+thresholds (existing rulepack go_criteria :480/:486/:492, builder floors :53/:54, FUND_SCORE, concentration, timebox 60/30 lower-bound, DSR p<0.05 over declared trial count 154 — no new values), the binding minimum-power floor (single diagnostic window is non-lifting), admissible evidence class (post-repair OOS-2026 on the corrected window under OQ-2, governed-only live SUPPORTING not sufficient, no re-selection), and the symmetric refutation clause; §D inert until OQ-2 resolved; ROT (purchase-adjacent), no Auffangregel; lifting NO-BUY still requires a separate signed OWNER purchase decision. |`

Mark, like row 8, as ROT with no Auffangregel.

---

## Open questions for OWNER (do not resolve unilaterally)

- **OQ-1 (ROT, = decision Q3):** Which P1 bar governs — builder bootstrap LOWER ≥ 0.80 (`build_book_ftmo.py:54`) or rulepack point ≥ 80 % AND lower-95 ≥ 70 % (`FTMO_2S_100K_SWING_V2.json:480`)? This test cites the strictest set (both) pending explicit reconciliation.
- **OQ-2 (population/uncertainty, = decision Q2, GATES §D):** Accept a SINGLE diagnostic window (2026-01-01..04-06, one seed, one config; `campaign_plan.json diagnostic_non_admission=true`) as the positive-evidence source, or require a broader sealed holdout (multi-seed / multi-window, or an enlarged OOS with a stated effective-n)? Per §C the single window is under-powered and non-lifting; §D is inert until this is answered.
- **OQ-3 (ROT, receipt row 8 — cross-branch):** Calendar-repair option E1 — A (source repair + hole backfill), B (conservative union), or C (detectors only)? OOS admissibility depends on the choice and on whether the 2025-05..2026-06 hole is backfilled for the 2026 window.
- **OQ-4 (provider):** Swing leverage 1:30 FX / 1:15 metals+oil is CARRIED_OVER / UNVERIFIED (trading-symbols URL 404 on 2026-09-04); must be re-sourced before any purchase-adjacent decision.
- **OQ-5 (population weighting):** Governed-only live is −469 USD / 30 days, Sharpe CI [−6.8,+4.6] (`CEO_AUDIT:14`). Is a live sample this short admissible AT ALL as positive live evidence, or strictly supporting (as §D.3 sets it)? If admissible, what minimum informative sample and numeric positive threshold?
- **OQ-6 (cross-branch re-verification):** Before OWNER ratifies, re-verify on the integration branch every anchor marked **[cross-branch — re-verify at seal]** — the three sibling evidence files and receipt rows 7–8 are not present in this worktree.
