# E1-C — Kalender mit durchgesetzten Geltungsgrenzen

Task `cf597222-24af-473c-8bc3-1d544485e989`. **REVIEW / Entscheidungsvorlage,
keine Freigabe.** Kanonische Ablage unter `docs/ops/evidence/` gemäß der
Anweisung für diesen Scheduler-Zyklus. Keine Produktionsänderung.

## Deutsche Entscheidungsseite

**Empfehlung: A für den heutigen Betrieb beibehalten; B nur als gesondert
abzunehmenden Verbraucher-Vertrag entwickeln. Jetzt keine Neuversiegelung.**
Der Kandidat `b33d0a3def6b19dfd78b977cfd13593806eb85f4b483143a5ca42980c2f4eb99`
besteht vier der acht Messprüfungen. Die übrigen vier werden durch 18.279
Ausschlusserklärungen beschrieben. Eine Erklärung ist kein bestandener Test.
Der bestehende Eingang verweigert dieses Paket ausdrücklich.

Eine entscheidende Einschränkung der Option B: Die Erklärungen betreffen auch
USD, mit mindestens einer Erklärung in **allen 144 Monaten 2015-01 bis
2026-12**; dazu kommen währungsübergreifende `ALL`-Erklärungen. „USD verifiziert“
bedeutet daher keine allgemein nutzbare USD-Zeitreihe. Ohne belastbaren
Nachweis, dass eine ausgeschlossene Ereignisklasse für den jeweiligen
Nachrichtenvertrag irrelevant ist, muss der Verbraucher den betroffenen
Währungsmonat als unbekannt behandeln. Das kann ganze Testzeiträume sperren.

**B hätte folgende Wirkung:** Ein unbekannter, relevanter Zeitraum sperrt neue
Einstiege und liefert `BLACKOUT_UNKNOWN`. Ein Q09/Q10-Versuch, dessen vollständiges
Prüffenster eine solche Grenze berührt, erhält in einer zusätzlichen Projektion
`UNCONFIRMED`; er erhält weder PASS noch eine neue Auswahlgutschrift. Fehlende
oder manipulierte Geltungsdaten sperren ebenfalls. Alte Verbraucher dürfen das
Paket nicht lesen, weil sie die Ausschlüsse ignorieren würden. Historische
Ergebnisse bleiben erhalten. Die amtliche Zählregel OWNER-DEC-A1 wird nicht
nebenbei umdefiniert; insbesondere bleibt die E2-Regel für 10706/GBPUSD bis zur
autorisierten Nachmessung bestehen.

Die aktuelle Prüfung bestätigt **13 aktive Kalender-Holds**. Bei fünf vorhandenen
Plänen überlappt das Fenster mit Ausschlüssen; acht haben kein verfügbares,
vollständig gebundenes Fenster für diesen Nachweis. **0 von 13** können auf Basis
dieser Vorlage freigegeben werden. E2 und E4 bleiben fachlich abhängig von E1.
E2 trägt technisch IN_PROGRESS ohne Codex-Zuordnung, E4 TODO; beide wurden nicht
bearbeitet. Der E4-Zeitraum Januar–April 2026 wird durch die bloße Existenz neuer
CSV-Zeilen nicht zulässig. Auch eine tägliche Einstiegszeit außerhalb bekannter
Meldungen beweist bei unbekannten Meldungszeiten keine Unbetroffenheit.

| Option | Nutzen | Kosten und Voraussetzung |
|---|---|---|
| A: volle Messung abwarten | Bestehender Kalendervertrag bleibt eindeutig | Offizielle Zeitanker, widerspruchsfreie Kodierung und M5-Fenster fehlen; Wartezeit nicht belastbar schätzbar; Holds und Nachmessungen bleiben offen |
| B: Geltungsgrenzen erzwingen | Saubere Teilnutzung wird technisch möglich | Neue Paket-/Verbraucher-/Auswerterbindung, Negativtests, neue Binärdateien und separate Aktivierung; derzeit kein nachgewiesener nutzbarer Zeitraum für die 13 Holds |

Eine Zustimmung zu B sollte **nur** die unten beschriebenen Semantiken und eine
inaktive Implementierung beauftragen. Aktivierung/Neuversiegelung folgt erst nach
nachgewiesener Nutzbarkeit, allen Verbrauchertests und einer eigenen
OWNER-Freigabe. Eine Zustimmung hebt weder Holds noch Zählgrenzen auf und erlaubt
keine Käufe, Live-Änderung oder Aktivierung von AutoTrading.

## English method and current code

The source-bound observation is
[snapshot.json](2026-09-05_calendar_scoped_consumer/snapshot.json:1), produced by
[inspect_scope.py](2026-09-05_calendar_scoped_consumer/inspect_scope.py:1).
It verifies the candidate manifest, verification, declarations and both CSV
hashes; opens SQLite in read-only mode; and observes plans without re-adjudicating
their complete lineage. Five interval/currency/unknown-symbol checks pass.
The actual ingress still refuses the candidate. This prototype is a conservative
impact projection and cannot admit a run.

`tools/strategy_farm/news_calendar_scope.py:10` emits gate, currency, event class,
month bounds, reason, required evidence, stable ID and `production_use_permitted=false`.
It leaves measured booleans false for failed gates. The current candidate has
345 declarations for 6.1, five for 6.2, 27 for 6.5, and 17,902 for 6.7.
Checks 6.3/6.4/6.6/6.8 are measured PASS.
`news_calendar_candidate_ingress.py:34` rejects any scoped declaration before
evaluating the eight PASS booleans. Therefore toggling booleans alone cannot
legitimately admit this pair.

`q09_news_calendar.py:167` seals event content and coverage into a bundle identity;
`:266` verifies it. It does not bind or enforce these exclusions.
`q09_news_contract.py:72` uses CONFIG_LOCKED / REVIEW_REQUIRED / INVALID_EVIDENCE
for its canonical adjudication, not a native UNCONFIRMED gate verdict. Therefore
UNCONFIRMED must first be an additive, non-promoting result/availability projection;
adding a canonical persisted verdict requires an explicit schema/consumer migration.
`q09_news_runner.py:3624` executes sealed plans, and `:3541` persists results;
both boundaries need the scope proof before result publication under B.

`framework/include/QM/QM_NewsFilter.mqh:44` already distinguishes a healthy
no-event result from DATA_ERROR for boundary queries. The CSV loader (`:595`),
immutable bundle loading and tester coverage checks (`:1619`) do not consume
declarations. The live path (`:1273`) queries the native calendar and fails
closed when its lookup is unavailable. B must explicitly enumerate CSV/bundle
consumers and not describe a historical CSV repair as a live-native repair.
This document does not modify either path.

## Proposed B contract: what each consumer must do

An immutable scope sidecar must bind both CSV hashes, the source proof, a
versioned symbol-to-currency and event-class/impact mapping, the permitted
coverage envelope, the declarations, and the compatible consumer version. All
of these bytes participate in bundle, run-plan and effective-input identities.
Unknown schemas, missing sidecars, unknown symbols/classes, mismatched hashes,
out-of-envelope requests and incomplete scope coverage fail closed. Empty input
must never mean unrestricted scope. Existing E1-B3 declarations contain no
sufficient impact-specific exemption proof; the prototype conservatively treats
every declared class as relevant for its currency. Narrowing this requires
source evidence and a reviewed mapping, never a favorable trading result.

Interpret each month in UTC as `[first instant, first instant next month)`.
Union all declaration gates/reasons and `ALL` currencies; expand the requested
window by its actual sealed temporal/compliance look-back, look-ahead and day
policy. Cross-month and DST boundaries must be tested. Basket relevance is the
union of the constituent exposures, including non-host symbols. Unknown basket
composition is UNCONFIRMED, not an empty union.

| Consumer | Required response to relevant overlap or missing scope proof |
|---|---|
| EA entry authorization | Deny new exposure with BLACKOUT_UNKNOWN and declaration IDs; never return healthy NONE |
| Future boundary / proactive-close API | DATA_ERROR; do not manufacture an event time or promise a safe close window |
| Existing-position management | Preserve existing risk-reduction and emergency protections; do not improvise forced close times inside an unknown news interval; deny compliance certification for affected exposure |
| Q09 temporal/compliance comparison | Mark the whole requested experiment UNCONFIRMED; no CONFIG_LOCKED or fallback-to-OFF credit |
| Q10 confirmation / news-dependent Q10 result | UNCONFIRMED for any affected required window; no favorable aggregate over the surviving cells |
| Census / optimization | Retain attempted cells and missingness in the denominator; do not select a challenger from censored evidence |
| Release/admission projection | No new release-candidate credit from an UNCONFIRMED dependency; preserve history and show the affected dependency |
| Legacy scope-unaware consumer | Refuse the new bundle version before dispatch; it cannot safely share these published bytes |

Never remove inconvenient days or zero-trade cells from an existing experiment
and call its remaining aggregate PASS. A shorter scoped experiment would need
a new prospective sampling/selection declaration and OWNER authority for the
changed candidate-pool/gate semantics. A fully blocked EA producing no trades
does not prove successful news handling. The control arm and policy arms must
retain the same requested window and the same missingness accounting.

## Held rows and counter impact

The read-only database census found twelve Q10_NEWS rows and one Q09_NEWS row.
IDs below refer to the existing held rows; this is not a release instruction.

| Work item prefix | EA / symbol | Proposed availability |
|---|---|---|
| 06b9c0f8 | 11147 / SP500 basket | UNCONFIRMED — observed scope overlap |
| 1cff016c | 12989 / XAUUSD | UNCONFIRMED — missing sealed window |
| 24acc5d4 | 12778 / AUDUSD basket | UNCONFIRMED — observed scope overlap |
| 2604a1f0 | 1567 / EURUSD | UNCONFIRMED — missing sealed window |
| 49a059da | 10847 / GDAXI | UNCONFIRMED — missing sealed window |
| 57d8bacd | 10815 / GDAXI | UNCONFIRMED — missing sealed window |
| 7bbeef66 | 12567 / XAUUSD | UNCONFIRMED — missing sealed window |
| 84c6e9e9 | 13301 / GDAXI | UNCONFIRMED — missing sealed window |
| 86cccb8a | 13059 / XTI–AUDJPY basket | UNCONFIRMED — observed scope overlap |
| 9639a773 | 10939 / GBPUSD | UNCONFIRMED — missing sealed window |
| a6e2cc8b | 11179 / USDJPY | UNCONFIRMED — observed scope overlap |
| aa80274f | 13128 / NDX | UNCONFIRMED — missing sealed window |
| aece4bcc | 12580 / USD basket | UNCONFIRMED — observed scope overlap |

E2 (`90431302`) names 63 exposed phase-pairs, with 12 Q10/Q14-relevant first,
and explicitly retains 10706 in the count until its remeasurement verdict.
E4 (`49a8c88b`) depends on admissible January–April 2026 coverage before its
governed window repair. B by itself satisfies neither dependency. Earlier
retirement/requalification and vintage holds also survive calendar repair.

OWNER-DEC-A1 counts terminal Q14 pairs, not Q11 frontier rows or declared calendar
PASSes (`decisions/2026-08-27_owner_count_definition_option_a.md:9`). Keep the
official rule, pair identity, threshold and historical ledger intact. The proposed
availability projection separately reports excluded dependencies and grants zero
new credit for UNCONFIRMED results. Do not silently subtract old counted pairs or
reuse old PASS as proof for a new release; any reconciliation of the official
count follows the existing E2 decision or a new explicit OWNER amendment.

## Exact ingress and reseal ordering if B is approved

There is **no executable B publication switch today**. The existing refresh
command is full-scope and must continue rejecting this manifest. A future B
implementation must follow this dependency order:

1. Record OWNER adoption of the versioned scoped contract and its exact evidence
   mapping. Deliver compatible EA, bundle, run-plan, adjudication and read-only
   admission consumers inactively; preserve the full-scope ingress path.
2. Pass tamper/missing/unknown/wildcard/boundary/DST/basket/zero-trade and mixed
   control-policy fixtures. Compile and bind consumer binaries through the
   governed queue. Prove no legacy consumer can ingest a scoped bundle.
3. Produce a new create-only candidate and scope proof. Keep the original four
   measured failures visible; a scoped validity claim must never be encoded as
   eight measured full-envelope PASSes. Independently measure usable requested
   windows and affected roster/counter projections before requesting activation.
4. Obtain the separate OWNER activation receipt binding candidate, sidecar,
   implementation and consumer cohort hashes. Use a distinct registered scoped
   ingress authority; do not reuse E1-A full-scope authority as an exemption.
5. Through the governed refresh parent, dry-run exact staged-pair reconciliation
   and consumer compatibility, then create the new staging child, publish the
   pair plus scope identity, mirror and verify identical FILE_COMMON bytes,
   and complete the registered repin chain under the existing mutation lock.
   Incomplete publication/repin leaves admission closed.
6. Build new immutable compatible bundles and append-only successor run plans.
   Recheck every required window, source/build vintage and all other holds.
   Existing defective historical verdicts remain immutable. Only the authorized
   per-row close-out can release a hold whose full dependency set is satisfied.
7. Execute and review new pipeline evidence through ordinary workers. E2/E4 and
   the official counter move only through their existing authorized evidence
   paths. This sequence itself changes neither live deployment nor AutoTrading.

## Refutation and lifting exclusions

Reject B activation if any missing/tampered declaration yields healthy NONE,
CONFIG_LOCKED/PASS or credit; if the same requested window can gain PASS by
deleting excluded days; if a legacy consumer accepts the bundle; if an unknown
basket becomes an empty currency set; if publication leaves pair/scope/mirrors
with different identities; or if no useful requested interval is demonstrably
admissible. The present 13-row census provides no positive release example.

Lift each declaration only in a new append-only version after the named evidence
has been supplied: official class/source/year anchors satisfying the unchanged
share test (6.1), complete native currency/month coverage and accepted timestamp
anchors (6.2), official instants plus actual M5 footprint/selector proof (6.5),
and resolved detector/encoding/input-integrity defects (6.7). Re-run all eight
measurements, cross-file identities, no-row-loss and schema checks. Hash-bind
the new proofs, retain superseded declarations and show the exact lifted IDs.
A full-envelope PASS additionally requires no unresolved exclusion and all eight
measured booleans true. Neither file freshness nor a declaration's age lifts it;
the stale-news ceiling remains 336 hours.
