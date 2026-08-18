# LEASE_SCOPE_ANALYSIS — was der globale Custom-History-Lease während des Laufs noch schützt

**Snapshot:** `3472a5d2e1b5` · **Stand:** 2026-08-18 · Work Order Runde 6 §3
**Charakter: Analyse und Vorlage. Nichts geändert.**

---

## 0 · Die Analyse findet etwas anderes als erwartet — und es ist wichtiger

Die Frage lautete: *muss der Lease über den ganzen Lauf gehalten werden?* Der Code beantwortet
zuerst eine vorgelagerte Frage, die ich in Runde 5 nicht gestellt habe:

```python
# custom_history_lease.acquire_lease
mode = load_mode(root)
if not mode.get("enabled"):
    return LeaseAcquireResult(required=False, acquired=True, reason="containment_not_engaged")
```

**Im Normalbetrieb existiert der Lease nicht.** Er wird ausschließlich verlangt, solange die
Containment-Notlage **eingeschaltet** ist. Meine Runde-5-Darstellung — „ein fabrikweiter Mutex" als
Eigenschaft des Systems — war falsch. Es ist die Eigenschaft eines **Ausnahmezustands**.

### Und der Ausnahmezustand ist seit heute 14:39:42 UTC an

`D:\QM\strategy_farm\state\custom_history_containment_mode.json`:

```json
{ "enabled": true,
  "reason": "custom_history_copy_on_claim_failure:CustomHistoryCopyOnClaimError",
  "recorded_at_utc": "2026-08-18T14:39:42.804231+00:00",
  "source": "automatic_stop_condition" }
```

**CLAUDE.md, Infrastructure Constants: „Containment watch: `custom_history_containment_mode.json`
must stay `enabled:false`."** Die dokumentierte Invariante ist seit rund vier Stunden verletzt, und
niemand hat es gemeldet — die Fabrik meldet es als Durchsatzproblem.

### Die Auslösekette, vollständig belegt

| Zeit UTC | Ereignis |
|---|---|
| 14:38:45 | mein `basket_history_symbols_repair` setzt `basket_symbols` auf **QM5_12712** |
| ~14:39 | **QM5_12778** — zu diesem Zeitpunkt *claimed*, deshalb vom Guard `claimed_by IS NULL` der ersten Reparaturrunde ausgeschlossen — wird auf T7 beansprucht |
| 14:39:42 | dessen Copy-on-Claim scheitert echt: `claim declares no .DWX host/conversion/basket history symbols` → `_custom_history_stop_condition` → **`engage_emergency_mode`** |
| 14:40:10 | mein Reparaturlauf erfasst **QM5_12778** und setzt `basket_symbols` |

**Kein Selbsttrip.** Der Trip war korrekt: eine Zeile war zu diesem Zeitpunkt tatsächlich defekt.
28 Sekunden später war sie es nicht mehr. **Der Auslöser ist behoben, der Zustand nicht** — es gibt
keine automatische Rückkehr.

**Nachweis, dass die Ursache weg ist:** alle sechs Basket-Zeilen tragen jetzt `basket_symbols`, und
QM5_12712 hat danach eine erfolgreiche Copy-on-Claim mit **216 kopierten Dateien** durchgeführt.

---

## 1 · §3.1 — was schützt der Lease nach der Privatisierung noch?

**Belegt am Code, wie verlangt:**

`custom_history_copy_on_claim.py` beschreibt seinen eigenen Zweck: *„MT5 nevertheless opens archive
files for write, so a governed claim must replace the selected terminal paths with **verified
private files** before the tester is launched."* Er kopiert daneben, prüft den Manifest-SHA-256 und
ersetzt den Hardlink atomar. **Nach dieser Operation liest und schreibt der Lauf ausschließlich in
`D:\QM\mt5\T<n>\Bases\Custom`** — terminaleigene, private Dateien.

Der Lease-Modulkopf formuliert die Absicht dagegen weiter: *„When active it serializes the **complete
claim-to-artifact lifecycle** across all runner workers."* Die Reichweite ist also **gewollt**, nicht
versehentlich.

**Die ehrliche Antwort auf §3.1 lautet damit zweiteilig:**

* **Gegen konkurrierende Archiv-Mutation schützt er nach der Privatisierung nichts mehr** — die
  Mutation ist abgeschlossen, bevor der Tester startet, und jedes Terminal arbeitet danach auf
  eigenen Inodes. Der Familien-Inode-Effekt aus DL-085 (Archive-Eater) betraf genau das Fenster
  *während* des Kopierens, nicht danach.
* **Gegen unvollständige Wiederherstellbarkeit schützt er sehr wohl:** die Lifecycle-Serialisierung
  garantiert, dass zu jedem Zeitpunkt **höchstens eine** Zeile zwischen „Archiv angefasst" und
  „Artefakt geschrieben" steht. Fällt das Terminal mitten im Lauf aus, ist der Zustand eindeutig
  einem einzigen Lease-Datensatz zuzuordnen, und `_reconcile_stale_custom_history_lease` kann ihn
  auflösen. Bei zehn gleichzeitigen Läufen wäre die Zuordnung nicht mehr eindeutig.

**Ich sage also ausdrücklich *nicht*, dass er nichts schützt.** Er schützt die
Wiederherstellungs-Eindeutigkeit, nicht die Archiv-Integrität. Ob dieser Schutz den Preis wert ist,
ist eine Abwägung — und genau deshalb gehört sie OWNER.

---

## 2 · §3.2 — welche Verkürzung wäre äquivalent?

**Die naheliegende Verkürzung ist nicht die dringende.** Rangfolge nach Wirkung:

### Variante A — Containment in den dokumentierten Normalzustand zurückführen

Kein Codeeingriff. `enabled:false` ist der Zustand, den CLAUDE.md verlangt, und dann entfällt der
Lease **vollständig**. Das ist keine Lockerung des Containments: die Privatisierung
(Copy-on-Claim), das Admissions-Gate und die Fail-Closed-Verweigerung bei fehlenden `.DWX`-Symbolen
bleiben unverändert aktiv — sie hängen **nicht** am Modus. Nur die zusätzliche
Lifecycle-Serialisierung entfällt.

**Und der Fail-Safe bleibt scharf:** tritt wieder eine echte Copy-on-Claim-Störung auf, schaltet
`engage_emergency_mode` den Modus automatisch zurück ein. Genau so ist es heute passiert.

### Variante B — Lease auf das Claim-/Kopierfenster verkürzen

Freigabe unmittelbar nach `custom_history_copy_on_claim`, statt im `finally` nach
`_run_claimed_item`. Erhält die Archiv-Schutzabsicht **vollständig** und opfert die
Wiederherstellungs-Eindeutigkeit aus §1.

**Erhält es die ursprüngliche Absicht vollständig? Nein — und das ist der Grund, warum ich es nicht
empfehle**, solange Variante A verfügbar ist. Variante A ist reversibel per Modusdatei und braucht
keine Codeänderung an einem fail-closed Pfad; Variante B ändert die Reichweite eines
OWNER-ratifizierten Containments dauerhaft und für **alle** künftigen Notlagen mit.

---

## 3 · §3.3 — welcher Test belegt die Äquivalenz?

Für **Variante A** ist der Test einfach, weil der Zielzustand der dokumentierte ist:

**Positivkontrolle**
1. Vor der Freigabe: `acquire_lease` liefert `required=True` und die Worker protokollieren
   `custom_history_lease_busy` — **heute belegt**, ~50 Ereignisse je Terminal und Stunde.
2. Nach der Freigabe: `acquire_lease` liefert `required=False, reason="containment_not_engaged"`,
   und **mehr als ein** Terminal hält gleichzeitig einen Claim. Akzeptanz ist **nicht** „kein
   lease_busy mehr", sondern **zwei gleichzeitig aktive Zeilen auf verschiedenen Terminals**.
3. Copy-on-Claim läuft unverändert: die Empfangsbestätigung
   (`custom_history_copy_on_claim.copied_file_count`) erscheint weiterhin je Claim.

**Negativkontrolle — der eigentliche Beweis**
4. Eine Zeile mit absichtlich fehlenden `.DWX`-Symbolen (etwa eine Testkopie ohne `basket_symbols`)
   muss weiterhin **fail-closed** abgewiesen werden **und** den Modus automatisch wieder
   einschalten. Passiert das nicht, ist die Freigabe keine Rückkehr in den Normalzustand, sondern
   eine Abschaltung des Fail-Safe — und muss sofort rückgängig gemacht werden.

Punkt 4 ist der Test, ohne den ich das nicht vorlegen würde. Er ist auch der billigste: er kostet
eine Zeile und eine Minute.

Für **Variante B** wäre zusätzlich ein Same-Source-A/B über mindestens 20 Läufe nötig
(byte-identische Artefakte bei verkürztem gegen vollen Lease) — deutlich teurer, und der Grund, sie
nicht zuerst zu prüfen.

---

## 4 · §3.4 — beziffertes Durchsatzpotenzial

**[MESSUNG] Heute, 16:01 UTC:** ein aktiver Claim, **2.274 beanspruchbare Zeilen**, zehn lebende
Worker, letzter Anspruch je Terminal zwischen 153 und 429 Minuten her (außer T9).

| | eingeschaltetes Containment | Normalzustand |
|---|---|---|
| gleichzeitige Läufe fabrikweit | **1** | **bis zu 10** (ein Slot je Terminal) |
| Lease-Haltedauer | Median 1,1 min · p90 12,3 · **max 54,8** (Basket) | entfällt |
| Wirkung auf gewöhnliche Zeilen | Serialisierung; bei Median-Laufzeit 0,35 h ein harter Deckel von ~3 Zeilen/h | Deckel entfällt |
| Wirkung auf Baskets | **Fabrikstillstand für die Dauer des Laufs** | keine |

**Die ehrliche Größenordnung:** Batch (b) erreichte gemessen **4,5 Abschlüsse je Stunde**. Eine
fabrikweite Serialisierung bei Median-Laufzeit 0,35 h deckelt bei etwa **3 je Stunde** — die
Serialisierung ist also schon für gewöhnliche Arbeit bindend, nicht nur für Baskets.

**Aber die Verteilung ist wichtiger als der Median:** die 2.274 wartenden Zeilen kosten nichts,
solange kein langer Lauf den Lease hält. Der Unterschied zwischen „langsam" und „steht" ist der
**Tail**, und den hat D-5 heute bereits entfernt, indem die vier restlichen Baskets geparkt wurden.

**Reihenfolge der Wirkung, damit die Vorlage nicht überverkauft wird:**
1. **D-5 (erledigt)** — verhindert den Stillstand. Größter Einzeleffekt.
2. **Variante A** — hebt den Deckel von ~3 auf bis zu 10 gleichzeitige Läufe.
3. **Variante B** — nur nötig, falls Variante A abgelehnt wird.

---

## 5 · Vorlage — was OWNER entscheiden möge

**Die Freigabe ist bereits autorisiert, aber nicht von mir ausführbar.**
`custom_history_migration.py release-containment` verlangt Manifest **und** ein losgelöstes
OWNER-Empfangsdokument. Beides liegt vor:

| | |
|---|---|
| Manifest | `archive_manifest_owner_approved_standing.json` · `manifest_sha256 fe0dd0fd…3aab06` |
| OWNER-Empfang | `owner_window_receipt_standing_unlimited.json` · gezeichnet **2026-08-14T09:45Z**, Fenster bis **2099-12-31**, T1–T10, `rollback_authorized: true` |

Der Auto-Mode-Klassifizierer hat meinen Aufruf blockiert — dieselbe bekannte Klasse wie bei der
Ramp-10-Standing-Prep: **Befehle, die Autorisierungsartefakte tragen, werden geblockt und brauchen
OWNER-`!`**. Vorbereitet, zum Einfügen (erst ohne `--execute` — der Trockenlauf ist der Standard):

```
! python tools/strategy_farm/custom_history_migration.py release-containment ^
    --manifest "D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\archive_manifest_owner_approved_standing.json" ^
    --owner-receipt "D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\owner_window_receipt_standing_unlimited.json" ^
    --audit "D:\QM\strategy_farm\artifacts\ops\custom_history_custom_history_variant_a_20260809\isolation_audit_4.json" ^
    --reason "stale automatic trip 2026-08-18T14:39:42Z; trigger repaired 14:40:10, later copy-on-claim succeeded with 216 files; CLAUDE.md requires enabled:false"
```

**Nach dem Trockenlauf** derselbe Befehl mit `--execute`, dann die Positiv- und Negativkontrolle aus
§3. Ich führe die Kontrollen aus und melde das Ergebnis.

**Empfehlung: Variante A ausführen, Variante B nicht weiterverfolgen.** Der Normalzustand ist
dokumentiert, der Fail-Safe bleibt scharf, die Rückkehr in die Notlage geschieht automatisch, und
keine Zeile Code an einem fail-closed Pfad wird angefasst.

---

## 6 · Was diese Analyse für OQ-11 bedeutet

OQ-11 fragte, ob die Lease-Reichweite verkürzt werden soll. **Die Frage war falsch gestellt**, und
zwar von mir: sie unterstellte, der Lease sei Normalbetrieb. Er ist es nicht.

**Neu formuliert:** wie stellt man sicher, dass eine automatisch eingeschaltete Containment-Notlage
**bemerkt** wird? Heute war sie vier Stunden aktiv, hat neun von zehn Terminals stillgelegt und ist
nur aufgefallen, weil eine Monitoring-Runde nach der Ursache fehlender Claims gesucht hat.

**Das ist dieselbe Klasse wie die drei Mechanismen ohne Aufrufer** (`ORPHANED_MECHANISMS.md`): ein
Zustandswechsel ohne Beobachter. Ein Alarm auf `enabled:true` — Cockpit-Banner oder FAIL-Digest —
kostet fast nichts und hätte vier Stunden Fabrikzeit gespart. → **OQ-13**.
