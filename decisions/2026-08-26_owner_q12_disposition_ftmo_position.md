# OWNER-Entscheide 2026-08-26 nachmittags (Chat-Receipts, zwei Punkte)

**Receipt (wörtlich):** „Ja" + „Ftmo bleibt offen bewusst" — Antworten auf die zwei offenen
Punkte des Updates vom 26.08. nachmittags.

## 1. OWNER-DEC-Q12-MISRUN-DISPO-20260826 → **JA: Disposition genehmigt**

Die zwei falsch-PASS-Zeilen der Q12-Fehlausführung (dfca24fa-…3611822 QM5_10706/GBPUSD,
d0e53004-…4ab2a68 QM5_11421/EURUSD — vom generischen Worker als Einzel-Backtest statt
DL-089-Matrix geschlossen) werden gemäß der Vorlage im Evidenzdokument
`docs/ops/evidence/2026-08-26_78f6404a_dl089_matrix_dispatch_integrity_repair.md`
disponiert: `ACKNOWLEDGE_INVALID_FOR_DECLARED_Q12`, append-only `disposition_only`-Rows
mit dieser Decision-ID; die Originalzeilen bleiben byte-erhalten. Die autorisierten
Nachfolger (1a92b33e GBP, c4bc189b EUR) sind bereits die messenden Rows.

## 2. FTMO-Trial: offene QM-Position ist **bewusst offen**

Die eine offene QM-Position auf dem geparkten FTMO-Trial bleibt absichtlich bestehen.
`ftmo_trial_pulse` wird darauf ausgerichtet: `parked_qm_trading_active` mit dieser
Decision-Referenz = erwarteter Zustand (kein FAIL); der Check bleibt bestehen und
alarmiert weiterhin bei *Änderungen* (neue Positionen, Kontoereignisse).
Keine Konto-/Positions-Aktion durch AI-Seats.
