# DL — T_Live DXZ Sonntags-Final: 23→24 Sleeves, Komposition v2 (2026-07-19)

**Status: VORBEREITET + VERIFIZIERT — WARTET AUF OWNER-FREIGABE (Schritt 2).**
Kein T_Live-File angefasst. Staging `C:\QM\deploy\DXZ_FINAL_2026-07-19\` (24 Presets,
2 neue Binaries, SHA256, staging_report.json, ANLEITUNG_DXZ_FINAL.md). Ersetzt das am
17.07. freigegebene, nie chart-deployte DXZ24-Paket (dessen Freigabe-Entscheidungen —
10476 raus, 13117+13301 rein — bleiben Bestandteil dieser Komposition).

## Kontext: Requalifikations-Welle unter der typisierten Q08-Engine (17.–19.07.)

OWNER-ratifiziert 18.07. („Zieh das sofort durch"): alle 24 Buchsleeves unter der
param-typ-bewussten Engine requalifiziert. Ergebnis: **19 bestätigt** (valide robuste
Neighborhoods), **0 Implosionen**, 5 ehrliche Befunde. Engine-Abnahme komplett
(10476-Regression, 1567/XAG-Implosion, 13117-Bestätigung, 10513-Auflösung). Nebenbei
repariert: NDX-Store (Voll-Reimport 563M Ticks nach Fenster-Root-Cause), 8 param-leere
Setfiles materialisiert, 5 falsch verdrahtete Work-Item-Lanes (Ablation/Grid/Worktree),
4 Engine-Fixes deployed (Fenster-Clamp f0b8d8d8c, Timeout-Floors a4d02cab4/eb718c47c,
Baseline-Budget; Kalibrierung via Codex 29f2ed8af/6b40ccd0a).

## Entscheidung (beantragt): Komposition

| Änderung | Sleeve | Begründung |
|---|---|---|
| RAUS (aus 17.07.-Freigabe) | 10476/USDCAD | Neighborhood-FAIL 1.589× (Referenzfall) |
| **RAUS (neu)** | 10715/USDJPY (0.05) | Typisierter Bruch: `asian_end_hour ±1h` → DD-Ratio **1.906** |
| **RAUS (neu)** | 10692/NDX (0.08) | **Ehrlicher PBO 82.9%** (echte Q03-Kohorte, 35 Splits, 29 overfit) |
| REIN (aus 17.07.-Freigabe) | 13117/EURGBP-Basket | Admission 17.07.; Factory bestätigt manuelle Quali (4/4 Plateau) |
| REIN (aus 17.07.-Freigabe) | 13301/GDAXI (DE40) | Admission 17.07.; Factory-Requal 742 tr, 4/4 Plateau |
| **REIN (neu)** | **13213/USDJPY (Balke #2)** | Manuelle typisierte Quali (DE40-Methode): 3 valide Kalender-Störungen 0.90–1.05×, 0 Brüche; Baseline PF 1.18/1587 tr; Decay **negativ**; corr 0.145 |
| **REIN (neu)** | **1567/EURUSD (TD-Reverse)** | Voller typisierter Pipeline-Durchmarsch 19.07. inkl. Countdown-±1 (schwächster Punkt 1.445× im Plateau); Q09: corr 0.257, standalone PF 1.60, Buch Sharpe +0.09/DD −4.5pp (Q09-Basis) |

**Bleiben mit Flag (42d-Probation-Review):** 11421/AUD + 11165/EUR (einseitige
Marginal-Brüche, Geschwister sauber), 12567/XNG (ehrlicher Decay-Hard pf_last 1.03 bei
29-Trade-Hälften; live 0 Trades = neutral; Removal kostete 0.33pp Buch-DD), 13117
(runs-p 0.0488). Eliminierte Kandidaten der Woche: 12474 beide Symbole
(Lookback-Klippe ~2× DD, Familie), 1567 XAG/GBPNZD/GBPJPY/EURGBP (Countdown-Klippe),
1551 (Q09-corr), 10828 (runs-HARD), 10848 (XAU-Lane corr).

## Zahlen (Manifest `portfolio_manifest_sunday_final_24sleeve_DRAFT_20260719.json`)

| Variante | Sharpe | MaxDD | n |
|---|---|---|---|
| Live-23-Referenz | 2.348 | 3.32% | 23 |
| 24er (17.07. freigegeben, nie deployt) | 2.381 | 3.09% | 24 |
| **FINAL (beantragt)** | **2.409** | **2.59%** | 24 |
| Alternate: FINAL ohne XNG | 2.377 | 2.92% | 23 |
| Alternate: nur −10715 | 2.431 | 3.27% | 22 |

Neue Gewichte: 1567/EUR **0.179**, 13301 0.069, 13213 0.043; 13117 0.420. Summe 9.7499.

## Stream-Basis (versiegelt)

`D:/QM/reports/portfolio/dxz_final_20260719/`: dxz24-Frozen-Basis (Sweep-verifiziert)
minus Removals; Neuzugänge als kanonische Full-History-Reruns 19.07., Trade-Count-validiert
(13213: 1587 ✓; 1567/EUR: 86 ✓; beide nach Kinder-Überschreib-Falle frisch regeneriert).

## Staging-Verifikation (19.07., staging_report.json)

- 22 Bestands-Presets: 1-Zeilen-Diff (RISK_PERCENT) der SHA-verifizierten dxz24-Staging.
- 2 neue Presets aus den exakten Qualifikations-Sets (13213: Neighborhood-Nominal-Set;
  1567: kanonisches materialisiertes Set), ENV=live, RISK_FIXED=0, build_hash=ex5-SHA.
- Verify-Pass 24/24: RISK_FIXED=0 ✓, Magic-Formel ✓ (13213 slot0→132130000;
  1567 slot7→15670007), Summe 9.7499 ✓. Binaries staged+SHA
  (13213 `321b1dca…`, 1567 `71c2f84b…`; 13117/13301/11165 aus DXZ24-Staging unverändert).
- News-Kalender 6.5h ✓.

## Workflow

1. ~~Prepared~~ ✓ (Manifest + Bundle + Staging + SHA + ANLEITUNG)
2. **OWNER genehmigt schriftlich** ← HIER
3. Claude file-side Deploy (24+alte Presets, 5 Binaries gesamt, Archiv) + SHA/Magic/ENV/News-Verify
4. Chart-Session OWNER (~35 min, ANLEITUNG_DXZ_FINAL): 3 raus, 4 neu, 10919-Restore,
   19 Reloads (davon 2× 11165-Re-Attach)
5. Claude Schlussverify: 24× INIT_OK + Magic-Set + Summe; Record-Ergänzung hier

Probation: 1556/10706/13128 (Bestand) + 13117/13301/13213/1567-EUR (Neuzugänge) +
Flag-Reviews 11421-AUD/11165-EUR/XNG. Offene Nacharbeiten: 12474-6er-Proben (Nacht),
1230/AUDJPY + 10123 (Pipeline läuft), T5-Terminal-Rebuild, Zykler/Multi-Row-Audit (Codex).
