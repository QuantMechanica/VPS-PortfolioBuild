# DL — T_Live DXZ-Buch 15 → 23 Sleeves (2026-07-12)

**Status: DRAFT — DEPLOY BLOCKIERT bis Requalifikation 1556/10706 abgeschlossen
(OWNER 13.07.: „Echte Reparatur zuerst").** Kein T_Live-File angefasst; AutoTrading
unberührt. Staging `C:\QM\deploy\DXZ23_2026-07-12\` ist **STALE** (prä-Verifikations-
Binaries) und wird nach der Requalifikation neu gebaut.

**⚠️ VERIFIKATIONS-UPDATE 12./13.07. (OWNER-mandatierter Full-Book-Sweep):**
21/23 Sleeves verifiziert (18 exakt auf den Cent, 13128 in Tick-Varianz, 11165/AUDCAD
= Manifest-Basis; 12778 Langlauf). **1556/10706: die Q08/Q09-Evidenz vom 07-11 stammt
von Phantom-Builds** (Quellstand nie committet) — echte Requalifikation der committeten
Builds läuft (`D:/QM/reports/requal_20260713/`). Dabei entdeckt + gefixt: farmweite
MetaEditor-No-Op-Compile-Klasse (compile_one-Fix `abd2b1847`, echte Binaries `cf2264bb0`).
Volle Befunde: `docs/ops/evidence/dxz23_verification_sweep_2026-07-12.md`.
Nach Requal: Gewichte auf finalen Streams neu rechnen, Staging neu, dann erst Freigabe.

## Entscheidung (beantragt)

Das DXZ-Live-Buch (Konto 4000090541, T_Live) von 15 auf **23 Sleeves** erweitern:
die 5 am 07-08 freigegebenen Admits (10403/XAU, 11165/EUR, 11708/EUR, 12778/AUD-Basket,
12969/JPY) **plus** 13128/NDX (Pre-FOMC-Drift) **plus** die reparierten 1556/XAU + 10706/GBP
(OWNER-Auftrag 12.07.: „reparier sie und schau, ob du alle soweit bekommst, dass wir ein
23er Buch zusammenbringen"). Gesamt-Risiko bleibt **9.75** (capped-inverse-vol, CAP 1.0);
die Bestands-15 werden verdünnt — Wachstum über Orthogonalität, nicht Risiko.

## Zahlen (fresh q08-fixed Streams, s4/d2d-Methodik, verifiziert exakt vs Referenz)

| Buch | Sharpe | MaxDD | Quelle |
|---|---|---|---|
| Live-15 (Ist) | 2.089 | 4.19% | fresh-stream Recompute 07-11 |
| **DXZ-23 (Ziel)** | **2.348** | **3.32%** | Manifest `portfolio_manifest_sunday_23sleeve_DRAFT_20260711.json` |

DXZ-Normalisierung: Buch ist VaR-FILLED (raw VaR95 0.91% ≥ 0.667%), Darwin-Rendite ~60%/yr;
Gewichtung inverse-vol ist OOS-validiert DXZ-optimal
(`docs/ops/evidence/dxz_weighting_oos_validation_2026-07-11.csv`).

## Sperren-Aufhebung 1556 + 10706 (OWNER 12.07.)

Beide waren seit 07-08 OWNER-gesperrt (echte Defekte, `codex_review_rework=true`).
Reparatur: Commit `924b78842` (1556: Card-konforme MOM12-D1-252-Logik + Exit-Reihenfolge;
10706: Card-Spez wiederhergestellt). Rework-Guard `_rework_blocked_eas` listet beide **nicht
mehr** (DB-verifiziert 12.07.). Requalifikation auf den reparierten Binaries:
- 1556/XAUUSD: Q08 → **Q09 PASS_PORTFOLIO** `D:/QM/reports/QM5_1556/Q09_PORTFOLIO/XAUUSD_DWX/aggregate.json`
- 10706/GBPUSD: Q08 FAIL_SOFT → **Q09 PASS_PORTFOLIO** `D:/QM/reports/QM5_10706/Q09_PORTFOLIO/GBPUSD_DWX/aggregate.json`
- 13128/NDX: Q02 PASS → Q08 FAIL_SOFT → **Q09 PASS_PORTFOLIO** `D:/QM/reports/QM5_13128/Q09_PORTFOLIO/NDX_DWX/aggregate.json`

## Live-Abgleich (Ist-Zustand T_Live, 12.07. 18:00Z Puls, verdict OK)

15 Sleeves aktiv, AutoTrading AN, alle Presets RISK_FIXED=0 + RISK_PERCENT gesetzt,
Summe RISK_PERCENT = 9.750. Konvention bestätigt: Gewicht lebt allein in RISK_PERCENT.
⚠️ Das 20er-Manifest vom 07-08 war auf `account_risk_pct=2.0` skaliert (Summe 2.0) und
hätte das Buch ~5× de-riskt — **nicht verwendet**; das 23er-Manifest ist auf 9.75 skaliert.

## Staging-Verifikation (Claude, 12.07.)

- 15 Bestands-Presets: Kopie des Live-Presets, **Diff = exakt 1 Zeile** (RISK_PERCENT).
- 8 neue Presets: aus den qualifizierenden Backtest-Sets abgeleitet (Strategie-Params
  unverändert), ENV=live, RISK_FIXED=0, Slot/Magic gegen Registry geprüft.
- Magic-Formel ea_id·10000+slot: 23/23 konsistent. Binaries: 7 neu gestaged (SHA256 in
  `live_eas_sha256.txt`); 11165 nutzt das laufende Live-Binary (SHA-identisch Repo).
- Summe RISK_PERCENT staged: **9.7501**. News-Kalender: OK (Alter ~13h, <336h).
- Report: `C:\QM\deploy\DXZ23_2026-07-12\staging_report.json`.

## Größte Verdünnungen (Bestands-15, alt → neu RISK_PERCENT)

11132/SP500 1.000→0.485 · 10513/XAU 0.837→0.324 · 11421/AUD 0.868→0.384 ·
11421/EUR 0.808→0.358 · 11165/AUDCAD 1.000→0.556 · 10715/JPY 0.388→0.052

## Workflow-Rest

1. ~~Factory prepared~~ ✓ (Staging + SHA)
2. **OWNER genehmigt schriftlich** ← HIER
3. Claude deployt file-side nach T_Live + verifiziert SHA/Magic/ENV/News
4. Chart-Session (OWNER, ~25–30min, `ANLEITUNG_DXZ23.md`): 15 Preset-Reloads + 8 neue Charts;
   AutoTrading bleibt unangetastet
5. Claude verifiziert 23× INIT_OK + Magic-Set und ergänzt dieses Record um das Verify-Protokoll

Probation: 1556, 10706, 13128 gelten als Probation-Sleeves (42d-Review, Salvage-Herkunft markiert).
