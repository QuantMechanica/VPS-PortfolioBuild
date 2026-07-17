# DL — T_Live DXZ-Buch 23 → 24 Sleeves (Weekend 2026-07-17)

**Status: VORBEREITET + VERIFIZIERT — WARTET AUF OWNER-FREIGABE (Schritt 2 des Workflows).**
Kein T_Live-File angefasst; AutoTrading unberührt. Staging `C:\QM\deploy\DXZ24_2026-07-17\`
(24 Presets, 2 neue Binaries, SHA256, staging_report.json, ANLEITUNG_DXZ24.md).

## Entscheidung (beantragt)

Das DXZ-Live-Buch (Konto 4000090541, T_Live) von 23 auf **24 Sleeves** umbauen:

| Änderung | Sleeve | Grund |
|---|---|---|
| **RAUS** | 10476/USDCAD (Magic 104760004) | Echter Q08-Neighborhood-FAIL: `ao_slow −10%` → DD-Ratio **1.589** + Edge-Decay 1.05→0.86. OWNER-Regel 2026-07-17: Neighborhood-FAIL disqualifiziert. OWNER-Entscheid („ja") 2026-07-17. |
| **REIN** | 13117/EURGBP (Basket EURGBP/AUDJPY-Cointegration D1, Magic 131170000) | OWNER-Admission 2026-07-17. Neighborhood-PASS komplett (manuell, param-typ-bewusst, Max-Ratio 1.07×, alle 5 Knöpfe). Q09 PASS_PORTFOLIO: net PF 1.52, Sharpe 2.82, **corr-to-book 0.036**. |
| **REIN** | 13301/GDAXI (Balke Minute-Range-Breakout M5, Magic 133010010) | OWNER-Admission 2026-07-17 („DE40 ist freigegeben"). Neighborhood manuell bestätigt (Max-Ratio 1.00×; minr-Invarianz + maxr-Kontrolle, Inputs im MT5-Report verifiziert). Q09_PORTFOLIO=FAIL_PORTFOLIO durch OWNER überstimmt; Re-Run nach Q08-Refresh-Welle aussteht. |

Gesamt-Risiko bleibt **9.75** (capped-inverse-vol, CAP 1.0); Gewichtskonvention unverändert
(RISK_PERCENT = absolutes Sleeve-Risiko, PORTFOLIO_WEIGHT=1).

## Zahlen (Manifest `portfolio_manifest_weekend_24sleeve_DRAFT_20260717.json`)

| Buch | Sharpe | MaxDD | Basis |
|---|---|---|---|
| Live-23 (Referenz) | 2.348 | 3.32% | 23er-Manifest 07-11 |
| 22 (nach 10476-Removal) | 2.249 | 3.45% | dasselbe Bundle, Attribution |
| **DXZ-24 (Ziel)** | **2.381** | **3.09%** | versiegeltes Bundle 2026-07-17 |

Neue Gewichte: 13117/EURGBP **0.4243**, 13301/GDAXI **0.0700**; größte Bestands-Änderungen sind
reine ~5%-Verdünnungen. Summe RISK_PERCENT staged: **9.7501**.

## Stream-Basis (versiegelt, Stale-Stream-sicher)

Bundle `D:/QM/reports/portfolio/dxz24_weekend_frozen_20260717/` (SHA-Seal + bundle_manifest.json):

- **21 Bestands-Sleeves**: Frozen-Referenz 07-15 (`dxz23_reference_frozen_20260715T215326Z`) —
  Sweep-verifizierte Basis des live laufenden Buchs. Der volatile Common-Store war NICHT nutzbar:
  13/22 Buch-Streams seit dem Freeze divergiert (Requal-Wellen, teils As-Live-Basis).
- **11165/AUDCAD**: kanonischer Full-History-Rerun 2026-07-17 (207 Trades / Net 2 780.27,
  report-exakt). Forensik: die alte „Manifest-Basis 3 295.72" war eine Stream-Export-Zahl der
  Juli-Ära; der MT5-Report des damaligen Sweeps selbst sagt 2 780.62. **Alle drei Binary-Ären
  (T_Live Jun-28, Sweep 07-12, Repo cf2264bb0) handeln deal-identisch** (207 tr / DD 4 147.55 /
  PF 1.14 / 315.8M Ticks). Der Jun-28-Stream-Export trägt den bekannten SL/TP-magic=0-Bug
  (173/7 665 = 34 SL-Exits fehlen; Fix 234860d6e). Evidenz: `D:/QM/reports/smoke/regen11165*/`.
- **13117 + 13301**: kanonische Q08-Full-History-Reruns 2026-07-17 (2017–2025, Model 4, Repo-Sets),
  **cent-exakt validiert** gegen die Factory-Baselines: 13117 = PF 1.44 / 208 tr / DD 2 327.54 /
  244.4M Ticks; 13301 = PF 1.28 / 742 tr / DD 13 877.95 / 138.8M Ticks. Bestätigt zugleich die
  Binary-Lineage der committeten .ex5 (adfa1ba6 / d7f10a68).
  Evidenz: `D:/QM/reports/smoke/regen13117|regen13301/`.

**Mixed-Era-Hinweis:** Die 21 Frozen-Streams stammen aus der Juli-Exporter-Ära (leichter
Net-Bias vs Report möglich, vgl. AUDCAD +515); die 3 frischen sind report-exakt. Konvergenz:
nach Codex' param-typ-bewusstem Neighborhood-Fix (Task 032d28e1) läuft ohnehin eine
Q08-Refresh-Welle — dann Voll-Buch-Streams auf aktuellem Exporter neu ziehen.

## Qualifikations-Evidenz der Admits (2026-07-17, Factory OFF, T8 seriell)

- **13117 Neighborhood** (Baseline 2020–2022 PF 1.53/68tr/DD 2 327.54): entry_z ±10% → 0.86×/0.68×;
  exit_z ±10% → 1.00×/1.00× (D1-insensitiv, Kontrolle verifiziert); z_lookback ±10% → 1.00×/1.00×
  (PF 2.10/1.34); sl_mult ±10% → 1.07×/0.98×; atr_period ±10% Factory 1.41/1.44. `beta` als
  gefitteter Koeffizient ausgeschlossen (OWNER-Regel; Spec
  `docs/research/Q08_NEIGHBORHOOD_PARAM_TYPE_AWARE_SPEC_2026-07-17.md`). Evidenz `D:/QM/reports/smoke/nb13117/`.
- **13301 Neighborhood** (Baseline 2021–2022 PF 1.35/229tr/DD 7.44%): min_range ±10% → 1.00×/1.00×
  (echte Invarianz, Inputs im Report); max_range ±10% → 0.96×/1.00× (PF 1.58/1.39). Evidenz
  `D:/QM/reports/smoke/nb13301/`.
- **10476 Referenz-FAIL** bleibt gültig (valider Bruch 1.589×) — Regressions-Anker der neuen
  Verdict-Semantik.

## Staging-Verifikation (Claude, 2026-07-17, `staging_report.json`)

- 22 Bestands-Presets: Kopie der (SHA-verifiziert deployten) dxz23-Staging-Presets,
  **Diff = exakt 1 Zeile** (RISK_PERCENT).
- 2 neue Presets: aus den qualifizierenden Backtest-Sets abgeleitet (Strategie-Params byte-gleich),
  ENV=live, RISK_FIXED=0, RISK_PERCENT=Gewicht, build_hash=aktuelle .ex5-SHA.
- Verifikations-Pass: 24/24 RISK_FIXED=0 ✓, RISK_PERCENT==Manifest ✓, Magic-Formel
  ea_id·10000+slot 24/24 ✓ (13117: slot0→131170000; 13301: slot10→133010010), Summe 9.7501 ✓.
- Binaries staged + SHA256 (`live_eas_sha256.txt`): 13117 `adfa1ba6…`, 13301 `d7f10a68…`.
- News-Kalender: 10.7h alt ✓ (<336h).

## Live-Ist-Abgleich (Puls, read-only, 2026-07-17)

- **22/23 Charts geladen — 10919/XTIUSD fehlt** (Gewicht 0.976!). Weekend-Session stellt ihn
  wieder her (ANLEITUNG Teil C).
- AutoTrading an, 1 offene Position; WARN journal-stale (Terminal ruhig, Watch-Item).
- Preset-Ambiguity-Warnings (alte d2d_s3-Presets neben dxz23): Cleanup im file-side Deploy
  (Archiv-Ordner), silenziert den Puls.

## Empfohlene Hygiene-Option (OWNER-Entscheid)

**11165-Binary beim Deploy mit erneuern** (aktuelles Repo-.ex5 8f6d33a3): behavioral identisch
(deal-exakt bewiesen), killt den SL/TP-Export-Bug des Jun-28-Binaries auf T_Live und aligned die
SHA-Lineage. Betrifft beide 11165-Sleeves (EURUSD+AUDCAD); Chart-Reload der Session lädt das
Modul ohnehin neu.

## Workflow

1. ~~Factory prepared~~ ✓ (Manifest + Bundle + Staging + SHA + ANLEITUNG)
2. **OWNER genehmigt schriftlich** ← HIER
3. Claude deployt file-side nach T_Live (24 Presets, 2(+1) Binaries, Alt-Preset-Archiv) +
   verifiziert SHA/Magic/ENV/News
4. Chart-Session OWNER (~30–35 min, `ANLEITUNG_DXZ24.md`): 1 Chart raus, 2 neu, 1 Restore
   (10919!), 22 Preset-Reloads; AutoTrading unangetastet
5. Claude Schlussverify: 24× INIT_OK + Magic-Set 24/24 + Summe RISK; Record-Ergänzung hier

Probation unverändert: 1556, 10706, 13128 (42d-Review). Neu in Probation: 13117, 13301
(Standard-Neuaufnahme-Beobachtung; 13301 zusätzlich: Q09-Portfolio-Re-Run nach Refresh-Welle).
