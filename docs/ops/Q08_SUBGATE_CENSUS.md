# Q08_SUBGATE_CENSUS — welches Untergate wirklich entscheidet

**Stand:** 2026-08-19 23:25 UTC · Anlass: drei Q08-FAIL_SOFTs am 19.08. (QM5_21506,
QM5_11754, QM5_21502) mit scheinbar identischem Soft-Quartett (8.4/8.6/8.7/8.10)
**Quelle:** alle 445 done-Q08-Zeilen mit `verdict_classification` in den Aggregaten
(farm_state read-only + Evidenz-JSONs); Skriptlauf im Monitoring 23:22 UTC

---

## 0 · Die Antwort

> **Das „Quartett" war eine optische Täuschung. Drei der vier Achsen sind
> Quasi-Konstanten, die auf fast jeder Zeile anschlagen — PASS wie FAIL_SOFT.
> Der tatsächliche Diskriminator ist 8.7 PBO: er ist in 72 % der FAIL_SOFTs weich
> und in 0 % der PASSes.** Wo PBO weich wird, gibt es kein PASS.

## 1 · Die Messung

| Untergate non-PASS | PASS (n=64) | FAIL_SOFT (n=105) | Diskriminiert? |
|---|---:|---:|---|
| 8.4_seasonal | **100 %** | 99 % | **nein — Konstante** |
| 8.6_chopping_block | 70 % | 70 % | nein |
| 8.10_regime_crisis | 67 % | 71 % | nein |
| **8.7_pbo** | **0 %** | **72 %** | **ja — der bindende Riegel** |
| 8.2_dsr_mc_fdr | 12 % | 13 % | nein |
| 8.5_neighborhood | 0 % | 12 % | schwach, gleichgerichtet mit PBO |
| cost_cushion | 0 % | 10 % | ja, selten bindend |

(Verdikt-Bestand gesamt: 64 PASS · 105 FAIL_SOFT · 98 FAIL_HARD · 178 INFRA_FAIL.
Nur 39 der 105 FAIL_SOFTs tragen das komplette „Quartett" — auch das widerlegt die
Quartett-These.)

## 2 · Konsequenzen

1. **Für die Optimierungsspur (Q14):** Die bindende Q08-Achse der heutigen
   Kandidaten ist Parameterlandschafts-Robustheit (PBO), nicht Rendite. Ein
   Optimierer, der Rendite/Drawdown maximiert, ohne die Nachbarschaft zu
   verbreitern, verschlechtert genau diese Achse. **Jeder Q14-Hebel braucht
   neben der Frequenzprüfung eine PBO-Prüfung.** Das bestätigt auch OWNERs
   Parameterkosten-Einwand zum Pattern-Filter: 12 Freiheitsgrade wären
   PBO-Gift; die 1-kategoriale Bank-Fassung ist die PBO-verträgliche Form.
2. **Für die Gate-Kalibrierung (ROT — nur Vorlage):** 8.4_seasonal schlägt auf
   **100 % aller Zeilen** an, PASS wie FAIL. Ein Untergate ohne Varianz trägt
   null Information; es kostet Rechenzeit und verwässert die
   FAIL_SOFT-Lesbarkeit. Vorlage: Schwelle rekalibrieren oder als
   Diagnose-Feld weiterführen (nicht verdikt-wirksam). **Nichts geändert.**
3. **Die drei heutigen FAIL_SOFTs sind damit präziser gelesen:** alle drei
   scheiterten real an PBO (21506, 21502, 11754), 11754 zusätzlich an
   MC-Shuffle-DD und Kostenpolster. Die Familienobservation „gleiche vier
   Achsen" war Hintergrundrauschen der drei Konstanten.

## 3 · Was offen bleibt

- QM5_21507 (Q08 läuft) als vierter Datenpunkt — erwartet: PBO-soft.
- Ob PBO-soft bei den 64 PASSes wirklich exakt 0 ist, wenn man auch ältere
  Schema-Versionen der Aggregate einbezieht (dieser Zensus las das aktuelle
  `verdict_classification`-Feld; ältere Läufe ohne das Feld fehlen).
