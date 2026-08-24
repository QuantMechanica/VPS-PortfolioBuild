# OWNER-Entscheid — Q12-Provenienz und Mission Control als Schaltzentrale

**Datum:** 2026-08-24  
**Autorität:** OWNER im laufenden Codex-Dialog  
**Status:** APPROVED

## OWNER-DEC-Q12-PROVENANCE-REPAIR-20260824

Der eingegrenzte v4-Cutover-Fehler an den drei bekannten Q12-Zeilen wird
repariert. Die historischen Payloads dürfen nicht auf v4/Q12 umgeschrieben
werden. Ihre nachweisbare v3/Q14-Provenienz bleibt bytegleich erhalten.

Genehmigte Reparatur:

1. Die drei historischen Zeilen werden auf ihre wahre Spaltenprovenienz
   v3/Q14 zurückgestellt und als `failed/INFRA_FAIL` mit Reparaturevidenz
   terminalisiert.
2. Für jede Zeile wird ein neuer deterministischer v4/Q12-Nachfolger mit
   aktivem Manifest-Hash und expliziter Migrationsbindung angehängt.
3. Apply nur atomar, nur für die drei exakten IDs und nur gegen den versiegelten
   Dry-run-Plan. Claim-/Payload-/Statusdrift bricht vollständig ab.
4. Payload-Provenienz und historische Payload-Hashes bleiben unverändert;
   Reparaturzuordnung kommt in ein append-only DB-Ledger.
5. Die Factory wird dafür nicht ausgeschaltet oder umkonfiguriert. Keine
   Terminal-, Deploy-, T_Live- oder AutoTrading-Aktion ist genehmigt.

## OWNER-DEC-MISSION-CONTROL-DECISION-CENTRE-20260824

Mission Control soll von einer reinen Beobachtungsfläche zu einer
Entscheidungs-Schaltzentrale erweitert werden:

- jede echte OWNER-Entscheidung nennt Frage, Empfehlung und Entscheidungsfolgen;
- OWNER kann `JA`, `NEIN` oder `VERTAGT` wählen und eine Notiz erfassen;
- jede Antwort wird dauerhaft und auditierbar dokumentiert; der Vault ist die
  menschlich lesbare Dokumentationssicht;
- ein Klick dokumentiert ausschließlich die Entscheidung und führt niemals
  selbst Factory-, Deploy-, Live- oder AutoTrading-Aktionen aus;
- die künstliche Obergrenze von fünf OWNER-Entscheidungen entfällt;
- die lineare EA/Symbol-Frontier bleibt als letzter Dashboard-Block, zeigt dort
  aber nur eine kompakte, handlungsorientierte Auswahl. Die vollständige
  Frontier gehört in einen separaten Drill-down.

