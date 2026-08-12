---
artifact_type: PROPOSED_STRATEGY_CARD_V2_APPROVAL_PACKET
card_schema_version: 2
proposal_status: IN_REVIEW
status: IN_REVIEW
g0_status: IN_REVIEW
execution_contract_status: IN_REVIEW
approval_effect: NONE
owner_chat_direction: RECORDED_UNSEALED
deployment_eligible: false
ea_id: QM5_1556
slug: aa-zak-mom12
target_variant: C_POLICY_REPAIR
variant_id: C_POLICY_REPAIR
symbol: XAUUSD.DWX
timeframe: D1
execution_contract_ref: docs/ops/evidence/dxz_1556_xau_ablation_contract_20260716.json
gate_matrix_ref: docs/ops/evidence/dxz_q8_fail_closed_gate_matrix_20260716.json
canonical_card_mutation: FORBIDDEN_UNTIL_ALL_CARD_APPROVALS_ARE_RECORDED
---

# PROPOSED / IN REVIEW — QM5_1556 XAUUSD Card v2 `POLICY_REPAIR`

> **Keine Freigabe und keine Laufzeitwirkung.** Dieses Dokument ist ein
> freigabefertiger Entscheidungsentwurf, aber weder die kanonische Strategy
> Card noch ein OWNER-Siegel. Es genehmigt keinen Build, keinen Pipeline-Lauf,
> keine Risikoänderung und keinen Deploy. Bis alle unten genannten Signaturen
> vorliegen, bleibt die exakte Promotion-Identität
> `1556:XAUUSD.DWX:D1:C_POLICY_REPAIR` `BLOCKED`.

Die Chat-Aussage des OWNER vom 2026-07-16, dass von seiner Seite alles
freigegeben ist, ist als unversiegelte Fortsetzungsdirektive aufgezeichnet. Sie
ist kein hashgebundenes `NO_WEEKEND_OWNER_SEAL` und ersetzt keine Freigabe einer
anderen Rolle.

## Beantragte Entscheidung

Für `QM5_1556_aa-zak-mom12` soll genau eine deploybare Semantik genehmigt
werden: `C_POLICY_REPAIR` (im Text kurz `POLICY_REPAIR`). Die Promotion-
Identität ist ohne Fallback exakt
`(1556, XAUUSD.DWX, D1, C_POLICY_REPAIR)`.

`POLICY_REPAIR` behält den monatlichen Long/Cash-Momentumzustand der Quelle,
setzt aber die verbindliche No-Weekend-Policy um: Freitag spätestens 21:00
Brokerzeit wird glattgestellt; am ersten zulässigen D1-Handelsbar nach dem
Wochenende wird bei weiterhin positivem, für den Monat eingefrorenem Signal
neu eröffnet. Der ATR-Stop wird bei jedem echten Wiedereinstieg neu gesetzt.

Die drei anderen Ablationsarme `R0`, `A` und `B` sind ausschließlich
Diagnosekontrollen. Sie dürfen unabhängig von ihrer Rendite niemals als
Live-Variante ausgewählt werden.

Die übergreifenden Gold-only-, Pair-, Kosten-, Weekend- und Q12-Gates stehen in
`docs/ops/evidence/dxz_q8_fail_closed_gate_matrix_20260716.json`. Dieser Entwurf
kann sie weder lockern noch ersetzen.

## Vorhandene Bindungen und der zu behebende Konflikt

| Bindung | Ist-Zustand |
|---|---|
| kanonische Legacy-Card | `D:/QM/strategy_farm/artifacts/cards_approved/QM5_1556_aa-zak-mom12.md`, SHA-256 `75c450738fc0d9fb2533094fd6732c71cc21d59c04f6b9f7a0a4de21be610497` |
| registrierte EA-ID | `framework/registry/ea_id_registry.csv`, Lookup `ea_id=1556`, Slug `aa-zak-mom12`, aktiv |
| XAU-Magic | `framework/registry/magic_numbers.csv`, Lookup `ea_id=1556`, `symbol=XAUUSD.DWX`, Slot `4`, Magic `15560004` |
| aktuelle Source | `framework/EAs/QM5_1556_aa-zak-mom12/QM5_1556_aa-zak-mom12.mq5`, SHA-256 `eb21c1d5e71288e24985802081200a15ed1fbc6a70534efbae95a0ec11d8499a` |
| heutiger Contract-Status | `framework/registry/dxz23_execution_contracts.json`, exakter Lookup `(ea_id=1556, symbol=XAUUSD.DWX, timeframe=D1)`: `BLOCKED` |
| OWNER-No-Weekend-Vorgabe | `decisions/2026-07-16_dxz_no_weekend_holding_owner_directive.md`, aufgezeichnet, aber noch nicht kryptografisch versiegelt |

Die Legacy-Card verlangt das Signal am letzten abgeschlossenen Monatsbar und
den monatlichen Signal-Flip-Exit. Der aktuelle EA verwendet dagegen einen
`D1-252`-Proxy, eröffnet höchstens einmal pro Monat und lässt den Framework-
Friday-Close vor dem Strategie-Exit laufen. Danach verhindert der bereits
verbrauchte Monatsschlüssel einen Wiedereinstieg.

Die reproduzierte Legacy-Reihe bestätigt die Abweichung: 53 von 53 Exits sind
Freitagsexits, davon 52 um 21:00 UTC und einer um 20:00 UTC. Sie qualifiziert
damit eine First-Week-of-Month-Semantik, nicht die behauptete monatliche
Long/Cash-Strategie.

## Source-defined rules

Diese Regeln werden als Quellenmechanik behandelt und nicht als QM-Erfindung:

1. Long/Cash, keine Short-Baseline.
2. Auswertung einmal pro neuem Kalendermonat anhand abgeschlossener
   Monatsstände.
3. Literale Legacy-Card-Formel:
   `MOM(12) = Close(MN1,1) - Close(MN1,12)`.
4. Bei `MOM(12) > 0` ist der Monatszustand `LONG`; bei `MOM(12) <= 0` ist er
   `CASH`.
5. Quellen-Exit ist der monatliche Wechsel von `LONG` nach `CASH`.
6. Eine Position pro Symbol/Magic.

Source pointer: Valeriy Zakamulin, Alpha Architect, “Trend-Following with
Valeriy Zakamulin: Anatomy of Trading Rules (Part 4)”, 2017-08-13. Die
kanonische Legacy-Card bleibt bis zu ihrer formalen Ablösung der gebundene
Quellenbeleg.

## QM interpretations

Die folgenden Regeln sind ausdrücklich QM-Interpretationen und dürfen nicht
als wörtliche Quellenregeln bezeichnet werden:

### `QM_MONTH_END_D1_RECONSTRUCTION_V1`

`PERIOD_MN1` erzeugt im verwendeten `.DWX`-Tester keine verlässliche
Preisreihe. Deshalb werden die zwei benötigten Monatsstände deterministisch
aus D1 rekonstruiert:

- `Close(MN1,1)` ist der letzte vorhandene, vollständig abgeschlossene
  `XAUUSD.DWX`-D1-Close des unmittelbar vorherigen Kalendermonats;
- `Close(MN1,12)` ist der letzte vorhandene, vollständig abgeschlossene
  `XAUUSD.DWX`-D1-Close des Kalendermonats mit Shift 12;
- es wird nicht durch 252 Handelstage approximiert;
- das Signal wird nur auf dem ersten zulässigen D1-Bar eines neuen Monats
  berechnet und danach bis zum nächsten Monatswechsel eingefroren;
- fehlt einer der beiden Monatsstände, lautet der Zustand `STALE`: keine
  Eröffnung oder Wiedereröffnung; eine vorhandene Position wird bei der ersten
  ausführbaren Gelegenheit glattgestellt.

### `QM_POLICY_REPAIR_REENTRY_V1`

- Nach einer verpflichtenden Wochenendglattstellung darf der EA nur am ersten
  zulässigen D1-Handelsbar nach dem Wochenende erneut eröffnen.
- Voraussetzung sind ein eingefrorener Monatszustand `LONG`, aktuelle
  Eingangsdaten, bestandene Entry-Filter und keine bereits offene Position.
- Der Wiedereinstieg ändert oder berechnet das Monatssignal nicht neu.
- Nach Erreichen des effektiven Wochenend-Cutoffs sind bis zur folgenden
  Handelssitzung sämtliche Entries und Pending Orders verboten.
- Der Wiedereinstieg setzt einen neuen initialen `3.0 * ATR(20,D1)`-Stop. Kein
  Trailing Stop, Take Profit, Scaling, Grid oder Martingale.

### Spread- und News-Interpretation

- Neue Entries verwenden den vorhandenen Guard `current D1 spread <= 2.5 *
  median spread of 20 completed D1 bars`; ein nicht positiver `.DWX`-Spread
  darf im Tester fail-open sein, fehlende Preise jedoch nicht.
- Entry-Gate: `QM_NEWS_TEMPORAL_PRE30_POST30` plus
  `QM_NEWS_COMPLIANCE_DXZ`, Mindestimpact `high`, Stale-Limit 336 Stunden.
- News dürfen nur Entries blockieren. Strategie-, Kill-, Daten-Stale- und
  Wochenendexits dürfen niemals durch einen News-Return unterdrückt werden.

## Framework execution overrides

### Verbindlicher No-Weekend-Vertrag

- `friday_close_enabled = true`;
- regulärer spätester Cutoff: Freitag 21:00 MT5-Brokerzeit;
- effektiver Cutoff: das frühere Ereignis aus Freitag 21:00 und dem letzten
  handelbaren Sitzungsende vor dem Wochenende;
- nach dem Cutoff: null Positionen, null Pending Orders, null Re-Entry;
- Holiday-/Early-Close-Sessions benötigen einen hashgebundenen Brokerkalender;
- die OWNER-Direktive muss außerhalb des Run-Roots signiert und hashgebunden
  werden. Die vorhandene Markdown-Entscheidung ist noch kein Trust Anchor.

### Verbindliche Laufzeitreihenfolge

1. Kill-Switch-Prüfung mit nachgewiesenem Trip-Time-Flatten und wiederholtem
   Flat-Sweep im Haltzustand;
2. kalenderbewusster Weekend-Deadline-Handler;
3. Framework-Friday-Close;
4. Daten-Stale- und Strategie-Exits;
5. News-, Spread- und sonstige Entry-Filter;
6. `POLICY_REPAIR`-Reentry oder Monats-Entry.

Kein früher Return darf die Punkte 1 bis 4 umgehen.

## Exit precedence

Höchste zu niedrigste Priorität:

1. brokerseitig bereits ausgeführter Hard Stop;
2. Kill-Switch-Trip-Flatten und Haltzustand-Flat-Sweep;
3. Holiday-/Early-Close-Weekend-Deadline;
4. regulärer Friday Close um 21:00 Brokerzeit;
5. fehlende/stale Monatsdaten (`STALE_FLAT`);
6. monatlicher Quellen-Signalwechsel `LONG -> CASH`;
7. keine weiteren Strategie-Exits.

Mehrere gleichzeitig fällige Gründe werden mit dem höchstpriorisierten Grund
protokolliert. Jeder Close braucht einen maschinenlesbaren `exit_reason`.

## Runtime data dependencies

| Abhängigkeit | Vertrag |
|---|---|
| Testsymbol | literal `XAUUSD.DWX`; kein stilles Suffix-Stripping |
| Livesymbol | durch Deploy-Packaging auf den registrierten Broker-XAU-Namen abbilden; nicht im EA hardcoden |
| Chart-/Bar-Gate-TF | `D1` |
| Signalsicht | abgeschlossene D1-Bars, zu Monatsenden rekonstruiert |
| Mindesthistorie | beide benötigten Monatsschlüsse plus `ATR(20,D1)` und 20 D1-Spreads; vor vollständiger Warmup-Historie `STALE` |
| Konto-/PnL-Währung | EUR; die gebundene EUR-Konvertierungsreihe ist Teil der Requalifikation |
| Kalender | MT5-Brokerzeit, vollständige Regular-/Holiday-/Early-Close-Abdeckung für jedes Testdatum |
| News | gebundener DXZ-Kalender, maximal 336 Stunden alt; Staleness blockiert Entries, nie Exits |
| Costs | XAU-spezifische Commission-, historische/current Spread-, Swap- und adverse-Slippage-Achsen |

## Deterministischer Zustandsautomat für `POLICY_REPAIR`

Zustände: `STALE`, `CASH`, `LONG_FLAT`, `LONG_OPEN`, `WEEKEND_LOCK`.

1. Monatswechsel: rekonstruiere das Signal einmal. Fehlende Daten -> `STALE`;
   `MOM <= 0` -> `CASH`; `MOM > 0` -> `LONG_FLAT` oder `LONG_OPEN`.
2. `CASH` oder `STALE`: keine Entry; bestehende Position schließen.
3. `LONG_FLAT`: Entry nur beim Monats-Entry oder beim ersten zulässigen
   Post-Weekend-D1-Bar; danach `LONG_OPEN`.
4. Effektiver Weekend-Cutoff: alle Positionen/Pending Orders schließen bzw.
   löschen; Zustand `WEEKEND_LOCK`.
5. `WEEKEND_LOCK`: bis zum ersten zulässigen D1-Bar der neuen Handelswoche
   keine Entry; bei positivem eingefrorenem Signal dann `LONG_FLAT` und genau
   ein Reentry-Versuch.
6. Monatswechsel hat Vorrang vor einem zeitgleichen Wochen-Reentry: zuerst
   Signal aktualisieren, dann anhand des neuen Zustands handeln.
7. Neustart: Zustand ausschließlich aus gebundenem Monatskey, letzter
   erfolgreicher Signalberechnung, Position/Magic und Brokerkalender
   rekonstruieren; ein Neustart darf keinen zweiten Entry erzeugen.

## Vorab gebundene Ablation

| Arm | Signal | Friday-Verhalten | Reentry | Rolle | promotionsfähig |
|---|---|---|---|---|---|
| `R0_LEGACY_IDENTITY` | heutiger `D1-252`-Proxy | Freitag 21 | erst Folgemonat | muss die alte 53-Close-Identität reproduzieren | nein |
| `A_SOURCE_NATIVE` | `QM_MONTH_END_D1_RECONSTRUCTION_V1` | aus | monatlich | quellengetreuer Research-Control; hält Wochenenden | nein |
| `B_OVERRIDE_NO_REENTRY` | `QM_MONTH_END_D1_RECONSTRUCTION_V1` | Freitag 21 | erst Folgemonat | quantifiziert den heutigen Semantikbruch isoliert | nein |
| `C_POLICY_REPAIR` | `QM_MONTH_END_D1_RECONSTRUCTION_V1` | effektiver No-Weekend-Cutoff | erster zulässiger Post-Weekend-D1-Bar | vorab festgelegter einziger Target-Kandidat | **ja, aber erst nach allen Gates** |

Ein nicht deploybarer Ablations-Harness darf diese vier Modi enthalten, wenn er
als Research-Artefakt hashgebunden und aus jedem Deploy-Pfad ausgeschlossen
ist. Der spätere Produktions-EA darf keinen auswählbaren Ablationsmodus
enthalten; er muss `C_POLICY_REPAIR` fest verdrahten.

## Feste Fenster und Datenverwendung

| Fenster | Von | Bis | Zweck |
|---|---:|---:|---|
| `W0_WARMUP_DIAGNOSTIC` | 2017-01-01 | 2018-06-30 | Historie/Warmup; keine Auswahlmetrik |
| `W1_LOCKED_SELECTION` | 2018-07-01 | 2022-12-31 | einziges historisches Auswahlfenster |
| `W2_CONSUMED_EVALUATION` | 2023-01-01 | 2025-12-31 | bereits gesehen; nur Entwicklungs-/Robustheitsdiagnostik |
| `W_FULL_RECONCILIATION` | 2017-01-01 | 2025-12-31 | Identität, Close-Reasons und Kostenabgleich |
| `W3_PROSPECTIVE_SHADOW` | frühestens 2026-08-01 | vor Start separat versiegeltes Ende | neue Evidenz; weder rückdatieren noch nach Ergebnis verkürzen |

Bekannte Datenlücken und EUR-Konvertierungsabhängigkeiten müssen die spätere
`TARGET_BINARY_REQUAL` in unabhängige kontinuierliche Segmente teilen. Nach
jeder Lücke wird die vollständige Signal-/ATR-/Spread-Warmup neu aufgebaut;
keine Position und kein Indicator-State darf die Lücke überqueren.

## Fixe Testparameter

- `XAUUSD.DWX`, `D1`, MT5 Model 4 / real ticks;
- `RISK_FIXED = 1000`, `RISK_PERCENT = 0`, `PORTFOLIO_WEIGHT = 1`;
- Momentumformel und Schwelle unverändert: `MOM > 0`;
- `ATR(20,D1) * 3.0` initialer Stop;
- eine Position pro `15560004`;
- kein Parametergrid, keine symbolübergreifende Auswahl, keine Ex-post-
  Optimierung, keine Kostenachse nach dem Ergebnis wählen;
- alle vier Arme verwenden denselben Daten-, Session-, Kosten- und
  Kontowährungsvertrag.

Eine spätere Live-Allokation ist nicht Teil dieser Card-Freigabe. Sie benötigt
nach den individuellen Gold-PASS-Gates `Q00` bis `Q11` und dem manuellen
Portfolio-Gate `Q12` eine eigene OWNER-signierte Buchentscheidung; der universelle
1-Prozent-Cap bleibt bindend.

## Pflichtmetriken

Je Arm und je festem Fenster:

- Signalzeit, Signalwert, Monatskey und Signalidentitäts-Hash;
- Trades, Entries, Reentries, Exits nach Reason und vollständiger
  Round-Trip-Identity-Hash;
- Net/Gross P&L, Profit Factor, Winrate, durchschnittlicher/medianer Trade;
- Close-to-close- und synchronisierter Mark-to-market-MaxDD;
- bester/schlechtester Broker-Tag und rollierende 6-Monats-Ergebnisse;
- Exposure-Tage, Time-in-Market, Haltedauer und Anzahl/Sekunden von
  Weekend-Exposure;
- Post-Cutoff-Entries, Pending Orders am Cutoff und Restart-Duplikate;
- Turnover sowie Commission, historische/current Spreads, Swap und adverse
  Slippage getrennt und kombiniert;
- im `W1_LOCKED_SELECTION`: Tradezahl, PF und absolute zero-filled monatliche
  Korrelation gegen jedes Q6-Sleeve;
- nach individueller Qualifikation: `Q12`-Portfolioverdict, synchronisierter
  Q8-Buch-DD, Worst-Day und Risikobeitrag.

## Vorab festgelegte Auswahlregel

1. `R0` besteht nur bei exakt 53 Close-Zeiten und dem gebundenen Legacy-
   Close-Time-Hash. Ein Fehlschlag invalidiert den Harness.
2. `A` und `B` sind immer Diagnosearme. Ihre Rendite kann keine Promotion
   auslösen.
3. `C` ist der einzige mögliche Target-Kandidat. Im Locked Window muss es
   mindestens 20 geschlossene Trades, `PF >= 1.10` und absolute monatliche
   Zero-Fill-Korrelation `<= 0.30` gegen jedes Q6-Sleeve erreichen.
4. `C` muss null Weekend-Exposure, null Post-Cutoff-Entries, null Pending
   Orders am Cutoff und deterministische Restart-Identität nachweisen.
5. Danach sind ein frischer kompletter Individualdurchlauf `Q00` bis `Q11` mit
   ausschließlich harten `PASS`-Verdikten und `Q12 = PASS_PORTFOLIO`
   erforderlich. Für das resultierende Q8-Buch gelten
   synchronisierter MTM-DD `<= 9.5%`, gestresster Worst Broker Day `<= 4.0%`
   und der 1-Prozent-Einzelsleeve-Cap.
6. `W2` darf einen in `W1` gefallenen Kandidaten nicht retten und ist kein
   untouched Holdout.
7. Fällt `C` an irgendeinem harten Gate, wird 1556 geparkt/verworfen. Es wird
   weder `A` noch `B` nachträglich ausgewählt und kein Parameter angepasst.

## Falsification and requalification

Jede der folgenden Änderungen erzwingt eine neue Card-Entscheidung, einen
neuen Binary-Hash, vollständige Stream-Reconciliation, `Q00` bis `Q11` und
`Q12`:

- Momentumformel, Monatsschluss-Rekonstruktion oder Signal-Schwelle;
- Entry-/Post-Weekend-Reentry-Zeitpunkt;
- Friday-/Holiday-/Early-Close-Regel oder Exit-Priorität;
- ATR-Periode/-Multiplikator oder Stop-Reset-Regel;
- News-, Spread-, Daten-Stale- oder Restart-Verhalten;
- Symbol, Magic, Timeframe, Kontowährung oder Kostenmodell;
- Source- oder rekursive Include-Closure;
- Master-Modul-Disposition;
- irgendein Live-Presetwert, der von der qualifizierten Target-Bindung
  abweicht.

Eine Abweichung ist niemals „kleine Reparatur“ und darf keine alte
`Q00`-bis-`Q11`- oder `Q12`-Evidenz erben.

## `TARGET_BINARY_REQUAL`

Der heutige Live-Binary-Hash `9371a8a03008e2fd8a3fc9dbec75586f7ade71ea857e9ff8f9c3fd0fd95cb3cb`
und seine 53-Trade-Reihe sind nur Legacy-Evidenz. Sie sind kein Target und
dürfen nicht als Qualifikation für `POLICY_REPAIR` verwendet werden.

Nach Card-Freigabe muss Development einen frischen Source-of-Record-Build
erzeugen. Der Target-Manifest bindet mindestens:

- final signierte Card-v2 und Execution Contract;
- MQ5 und vollständige rekursive Include-Closure;
- clean-compile EX5;
- explizites XAU-Backtestset und später separates Live-Set;
- Magic `15560004`, Symbolrouting und D1-Timeframe;
- Daten-, Brokerkalender-, News- und Fünf-Achsen-Kostenmanifeste;
- zwei unabhängige, serialisierte Requalifikationsläufe mit identischen
  Signal-, Entry-, Exit-, Lot-, Outcome- und PnL-Identitäten;
- frische Gold-PASS-Artefakte `Q00` bis `Q11`, ein frisches
  `Q12 = PASS_PORTFOLIO` sowie die abschließende OWNER-Buchsignatur.

Bis alle Hashfelder gesetzt und alle Gates `PASS` sind, lautet der Status
`TARGET_BINARY_REQUAL_REQUIRED`; kein Resize oder Deploy darf den Kandidaten
verwenden.

## Master-Modul-Blocker

`framework/include/QM/modules/QM_Mod_AaZakMom12.mqh` repliziert die aktuelle
Standalone-Semantik und wird von
`framework/EAs/QM5_MXAU_master-xauusd/QM5_MXAU_master-xauusd.mq5` eingebunden.
Dieses Include liegt außerhalb der Development-Build-Autorität.

Vor Target-Promotion muss OWNER nach dem Implementierungsvorschlag von
Development und dem technischen Review durch Quality-Tech genau eine Variante
freigeben:

1. das Modul in einem separaten, autorisierten Framework-Change auf dieselbe
   Card-v2-Semantik bringen und den Master vollständig requalifizieren; oder
2. das Modul nachweislich deaktivieren/entkoppeln und jede Master-Evidenz für
   Magic `15560004` sperren.

Ein stiller Standalone-Fix bei weiter driftendem Master-Modul ist unzulässig.

## Erforderliche Signaturen

| Signatur | Rolle | Inhalt | Status |
|---|---|---|---|
| `SOURCE_SEMANTICS_ACK` | Research | trennt Quellenmechanik von allen QM-Interpretationen | PENDING |
| `CARD_V2_APPROVED` | OWNER + Quality-Business | genehmigt genau `C_POLICY_REPAIR`, Falsifikation und Auswahlregel | PENDING |
| `EA_ID_REUSE_APPROVED` | OWNER | bestätigt, dass die materielle Policy-Variante unter EA-ID 1556 verbleiben darf; Development dokumentiert den Registry-Eintrag | PENDING |
| `NO_WEEKEND_OWNER_SEAL` | OWNER | signiert Cutoff, Holiday-Fallback, Reentry und No-Weekend-Zweck außerhalb aller Run-Roots | PENDING |
| `MASTER_MODULE_DISPOSITION` | OWNER + Quality-Tech | autorisiert nach technischem Review Modul-Sync oder Deaktivierung | PENDING |
| `TARGET_SOURCE_CLOSURE_ACCEPTED` | Development + Quality-Tech | bindet Source/Includes und clean compile | PENDING |
| `TARGET_BINARY_REQUAL_PASS` | Pipeline-Operator + Quality-Tech | bindet zwei Requal-Läufe, Pair-Gate, `Q00`–`Q11`, `Q12` und Kosten | PENDING |
| `BOOK_ADMISSION_AND_DEPLOY` | OWNER | separate finale Risiko-, Buch- und Deployentscheidung | PENDING |

Ein Name, Haken oder Commit in diesem Entwurf ersetzt keine Signatur. OWNER-
Vertrauen muss über den extern registrierten und out-of-band gepinnten
Signaturschlüssel hergestellt werden.

## Freigabe-Checkliste

- [ ] Research bestätigt die Source/QM-Trennung.
- [ ] OWNER + Quality-Business setzen die kanonische Card v2 auf `APPROVED`.
- [ ] OWNER bestätigt die Wiederverwendung von EA-ID 1556; Development dokumentiert sie im Registry-Eintrag.
- [ ] OWNER versiegelt die No-Weekend-/Reentry-Entscheidung.
- [ ] OWNER schließt den Master-Modul-Blocker nach Review durch Quality-Tech.
- [ ] Erst danach implementiert Development `C_POLICY_REPAIR`.
- [ ] Ablations-Harness bleibt non-deployable; Target-Binary enthält nur C.
- [ ] R0-Identität und A/B/C-Ablation laufen auf den gebundenen Fenstern.
- [ ] Zwei frische `TARGET_BINARY_REQUAL`-Läufe bestehen das Pair-Gate; danach bestehen `Q00`–`Q11` Gold-only und `Q12`.
- [ ] OWNER genehmigt Buchaufnahme, Risiko und Deploy separat.

## Ausdrücklich nicht autorisiert

- keine Änderung an der kanonischen APPROVED Card;
- keine Änderung an MQ5, Includes, Sets, EX5, Registry oder MT5;
- kein Backtest- oder Pipeline-Lauf;
- kein Risiko-Resize, kein Deploy und kein AutoTrading-Eingriff;
- keine Promotion aufgrund der Legacy-53-Trades.
