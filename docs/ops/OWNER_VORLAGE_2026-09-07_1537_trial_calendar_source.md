# OWNER-Vorlage 2026-09-07 — QM5_1537 im FTMO-Trial: Monats-Sleeve-Kalender aus nativer Darwinex-D1-History (deklarierter Quellenwechsel)

Stand 09:50Z (lokal 11:50), CEO-Loop. Evidenz: `docs/ops/evidence/86b7dfb5_qm5_1537_calendar_staleness_recovery_2026-09-07.md`.

## Befund

QM5_1537 (aa-vol-sma10, XAGUSD D1) wählt seinen Monats-Sleeve aus einem SHA-gepinnten Kalender (`QM5_1537_monthly_sleeves_v1.csv`).
Dessen XAG-Zeilen enden bei **2024-12**. Im FTMO-Demo meldet der EA für 2026-09 `MONTHLY_SLEEVE_STATE … reject_reason=calendar_stale`
und ist damit **inert** — er würde so auch auf Darwinex Zero live nie handeln. Der Kalender lässt sich aus den heutigen Quellen nicht
ehrlich verlängern: der Builder liest die Fabrik-Custom-History (endet 2024-12-31), und weder das Darwinex-Live- noch das FTMO-Terminal
hat einen vollständigen D1-Cache für alle 37 Universum-Symbole (13 bzw. 8 von 37 parsebar).

## Optionen

| Option | Inhalt | Wirkung | Risiko |
|---|---|---|---|
| **A (Empfehlung): native Darwinex-D1 als deklarierte Fortsetzungsquelle** | Über die governed `T_Export`-Lane (Darwinex-Konto, keine T_Live-Berührung) die D1-History aller 37 Universum-Symbole ab 2024-07 nativ laden und exportieren; Kalender **v2** = v1-Zeilen unverändert bis 2024-12 + neue Monatszeilen 2025-01…2026-09 aus nativem DWX-D1 nach identischem Vertrag (37 Symbole, 252-Return-Lookback, Top-3, Slot-Tie-Break); neue SHA, Preset-Re-Pin, Trial-Install, monatlicher Refresh am 1. Handelstag | 1537 wird im Trial (und später live) handelbar; Quellenwechsel ist im Manifest deklariert und append-only (v1 bleibt) | Nativer DWX-D1 ≠ Custom-History (Bar-Definition/DST-Modell); Rangfolge könnte an Monatsgrenzen abweichen — deshalb Deklaration und, sobald Fabrik-History nachgezogen ist, Vergleichslauf |
| B | 1537 aus dem FTMO-Trial-Buch nehmen (Chart entfernen), Kalender bleibt v1 | keine Quellenvermischung | Ein Sleeve weniger im Trial; live-Untauglichkeit bleibt ungelöst |
| C | Warten auf Fabrik-History-Nachzug (Dukascopy-Backfill-Karte ist VERTAGT) | — | unbestimmt |

**Empfehlung: A.** Zusätzlich lässt Codex 21505 (weekly lowvol momentum) und alle anderen kalender-/planbasierten Sleeves auf dieselbe
Staleness-Klasse prüfen (bereits Teil des Auftrags).

## Was ein JA auslöst — genau ein Claude-Auftrag

Codex-Ticket: T_Export-D1-Download + Export der 37 Symbole (Lane, Receipt), Builder-Erweiterung mit deklarierter Quelle je Zeile,
Kalender v2 + Manifest, Preset-Re-Pin (append-only Set-Version), Demo-Install mit Receipt + OWNER-Re-Attach (3 Zeilen), Refresh-Regel,
M13-Manifest-Nachtrag. Kein T_Live, kein AutoTrading, keine Q-Gate-Änderung.

## Was ein NEIN auslöst

Option B: 1537 verlässt den Trial (OWNER entfernt den Chart), Dokumentation; oder C bei VERTAGT.

## Rollback

v1-Kalender und alte Presets bleiben erhalten; Zurückschalten = Preset auf v1-SHA, Chart neu anhängen.
