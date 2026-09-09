"""One-shot mirror of the 2026-09-09 Balke video-lane result into Vault boards, routing annex, memory and OPEN_ITEMS."""
import io
import os

VAULT = "G:/My Drive/QuantMechanica - Company Reference/"
MEM = "C:/Users/Administrator/.claude/projects/C--QM-repo/memory/"
DOC = "docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md"


def rw(path, fn):
    with io.open(path, encoding="utf-8") as f:
        s = f.read()
    s2 = fn(s)
    with io.open(path, "w", encoding="utf-8", newline="") as f:
        f.write(s2)
    print("updated", path)


def video_board(s):
    start = s.index("### `OWNER-VID-BALKE-CLOCK`")
    end = s.index("\n## ", start)
    new = (
        "### `OWNER-VID-BALKE-CLOCK` — nur noch 3 Frames (Router-Task `4a3a4a02`, aktualisiert 2026-09-09 21:20Z)\n\n"
        "Claude hat die Untertitel ausgewertet (`" + DOC + "`):\n"
        "Balkes USDJPY-Setting ist **Range 00:00–07:30 Serverzeit, Close 18:00, kein Range-Filter, kein Trailing,\n"
        "max. 1 Buy + 1 Sell/Tag, SL = Gegenseite** [00:08:44–00:09:17]. Unser 03–06-Fenster stammt aus deiner\n"
        "Vorgabe vom 27.06. (12700-Brief), nicht aus einem Balke-Video (03:05–06:05 ist sein Gold-Setting).\n"
        "Offen sind nur Bildschirmwerte. Bitte drei Frames in `youtube.com/watch?v=Pay-JP34YSI` ansehen:\n"
        "- [ ] @OWNER `[00:08:52]` USDJPY-Eingabemaske: Order-Buffer-Points, Range-Filter, Max-Trades — Werte notieren\n"
        "- [ ] @OWNER `[00:10:11]` Kennzahlen-Screen: Profit Factor, Netto, Max-DD, Trades (2013–04/2024)\n"
        "- [ ] @OWNER `[00:05:26]` Tester-Chart: Zeitachse/Serverzeit des Brokers (welcher Broker, folgt US-DST?)\n"
        "`NICHT GEZEIGT`, wenn ein Wert nicht sichtbar ist. Astra-Auftrag `d444a7a8` läuft bereits mit der\n"
        "Balke-Konfiguration als Primärhypothese; die Frames verengen nur die Puffer- und Uhr-Zellen.\n"
    )
    return s[:start] + new + s[end:]


def owner_board(s):
    old = ("Balke-Uhr/Outside-Range/Puffer/Zahlen klären — Fragenliste in `OWNER Videoanalysen.md` Tier 1. "
           "Entscheidet den Astra-Auftrag `d444a7a8`.")
    new = ("nur noch 3 Frames in Pay-JP34YSI ([00:08:52], [00:10:11], [00:05:26]); Untertitel-Auswertung erledigt "
           "(Balke USDJPY = 00:00–07:30 Serverzeit, unser 03–06 war OWNER-Vorgabe 27.06.). Details `OWNER Videoanalysen.md` Tier 1.")
    assert old in s, "owner board line not found"
    return s.replace(old, new)


def routing_annex(s):
    return s + (
        "\n\n## Annex 2026-09-09 — Videorecherche durch KI-Seats (OWNER 2026-09-09 ~21:00Z)\n\n"
        "OWNER: „Die Videorecherche können du, Astra, Sonnet, Opus und agy durchführen.“ Ergänzung zur\n"
        "Regelung vom 2026-08-21: `video_analysis`-Tickets werden zuerst von einem KI-Seat auf Basis der\n"
        "Untertitel (Proxy-Transkripte, `fetch_transcript.py`) beantwortet; Bildschirmwerte gelten weiter als\n"
        "`NICHT GEZEIGT`, solange kein frame-fähiger Pfad verfügbar ist (Claude über verbundenen Chrome-\n"
        "Connector, oder OWNER-Augen). Ein Ticket geht nur noch mit der konkreten Frame-Liste (Zeitstempel)\n"
        "an OWNER. agy bleibt video-blind (verifiziert 2026-07-12). Erstanwendung: `4a3a4a02` / Balke USDJPY.\n"
    )


MEMORY_FILE = "project_qm_balke_usdjpy_window_provenance_video_policy_2026-09-09.md"
MEMORY_BODY = """---
name: project_qm_balke_usdjpy_window_provenance_video_policy_2026-09-09
description: Balke USDJPY 03:00-06:00 window was an OWNER spec (2026-06-27), not Balke; Balke publishes 00:00-07:30 broker time / close 18:00 / no filters; video tickets now answered by AI seats from captions first, OWNER only for listed frames
metadata:
  type: project
---

2026-09-09: OWNER doubted QM5_41398 (Balke USDJPY). Code: fixed UTC+3 clock (00-03 UTC range, flat 15 UTC all year), stops exactly at range edges, ATR 0.4-2.5 band, trailing +1R. Captions of `Pay-JP34YSI` [00:08:44-00:09:17]: Balke USDJPY = range 00:00-07:30 broker server time, delete+close 18:00, no range filter, no trailing/BE, max 1 buy + 1 sell, SL opposite side, no TP, 0.5 % risk; his EA has an order-buffer-points input (demo 20 pts, `mOa4dqxAh4g` [00:06:40]). GMT offset never stated on-air. 03:00-06:00 came from the OWNER brief 2026-06-27 (`docs/research/BALKE_RANGE_BREAKOUT_QM5_12700_2026-06-27.md` line 3); 03:05-06:05 is the Balke GOLD setting. Evidence doc: `docs/research/VIDEO_Pay-JP34YSI_BALKE_USDJPY_CLOCK_2026-09-09.md`. Tickets: Astra `d444a7a8` (matrix, H-WINDOW primary), Astra `95b48188` (fleet clock audit), OWNER `4a3a4a02` (3 frames only).

**Why:** the lineage compared a different variant against the Balke numbers; the clock offset question is secondary to the window itself.

**How to apply:** before any "PF lower than the source" discussion, diff our inputs against the source config line by line with timestamps. Video tickets: OWNER 2026-09-09 allows AI seats to do video research; do captions first (`D:/QM/reports/research/balke_symbol_transcripts`, `fetch_transcript.py`), Chrome connector for frames if connected (was NOT connected 2026-09-09), send OWNER only a timestamped frame list. Vault annex: `02 Org/AI Agent Routing and Role Contracts.md` 2026-09-09. See [[reference_agy_no_video_tool_2026-07-12]], [[project_qm_balke_rangebreakout_walkforward_2026-07-14]].
"""

INDEX_LINE = ("- [★★★BALKE-USDJPY 03–06 = OWNER-VORGABE, Balke = 00:00–07:30 + VIDEOLANE AN KI-SEATS 09.09.]"
              "(project_qm_balke_usdjpy_window_provenance_video_policy_2026-09-09.md) — Untertitel zuerst, OWNER nur "
              "Frame-Liste; Chrome-Connector war nicht verbunden; Astra d444a7a8/95b48188\n")

OPEN_ITEMS = """
## 2026-09-09T21:25Z — Balke video lane executed by Claude (OWNER: AI seats may do video research)

RESULT: captions of Pay-JP34YSI / mOa4dqxAh4g evaluated -> `""" + DOC + """`.
Balke USDJPY = range 00:00-07:30 broker server time, delete+close 18:00, no range filter, no
trailing/BE, max 1 buy + 1 sell, SL opposite side, no TP (timestamps in the doc). The 03:00-06:00
window is the OWNER spec of 2026-06-27 (12700 brief), not a Balke rule; 03:05-06:05 is his gold
setting. GMT offset never stated on-air; PF/DD/buffer value are on-screen only (Chrome connector not
connected -> NICHT GEZEIGT). Astra `d444a7a8` updated (H-WINDOW primary, minute-granular range end,
ATR band OFF cell); OWNER `4a3a4a02` reduced to 3 frames. Policy annex recorded in Vault
`02 Org/AI Agent Routing and Role Contracts.md` (2026-09-09).
"""

if __name__ == "__main__":
    rw(VAULT + "12 ToDo/AI ToDos/OWNER Videoanalysen.md", video_board)
    rw(VAULT + "12 ToDo/AI ToDos/OWNER.md", owner_board)
    rc = VAULT + "02 Org/AI Agent Routing and Role Contracts.md"
    if os.path.exists(rc):
        rw(rc, routing_annex)
    else:
        print("routing contract NOT found:", rc)
    with io.open(MEM + MEMORY_FILE, "w", encoding="utf-8", newline="") as f:
        f.write(MEMORY_BODY)
    rw(MEM + "MEMORY.md", lambda s: s.replace("## ⚠️ READ FIRST — LIVE STATE\n", "## ⚠️ READ FIRST — LIVE STATE\n" + INDEX_LINE, 1))
    with io.open("C:/QM/repo/docs/ops/OPEN_ITEMS_STATUS.md", "a", encoding="utf-8", newline="") as f:
        f.write(OPEN_ITEMS)
    print("open items appended")
