# Mulham Trading — Source Reputation Research (R1) Dossier

**Date:** 2026-07-13  
**Target Source:** https://www.youtube.com/@MulhamTrading  
**Assigned Agent:** Gemini  
**Task ID:** `11105b13-8116-4ed3-a1fc-420dd98a0eff`  
**Related Documents:**
- [MULHAM_CHANNEL_TRIAGE_2026-07-13.md](file:///C:/QM/repo/docs/research/MULHAM_CHANNEL_TRIAGE_2026-07-13.md)
- [mulham_channel_mechanization_dossier_2026-07-13.md](file:///C:/QM/repo/docs/ops/evidence/mulham_channel_mechanization_dossier_2026-07-13.md)
- [qb_reputable_source_criteria.md](file:///C:/QM/repo/processes/qb_reputable_source_criteria.md)
- [OPERATING_RULES_2026-07-03.md](file:///C:/QM/repo/docs/ops/OPERATING_RULES_2026-07-03.md)

---

## 1. Author Profile & Track Record Verification

- **Identity & Background:** The channel is operated by a single trader known publicly as "Mulham." He claims approximately 8 years of trading experience in forex, metals, and indices. He is the founder of "Edge Skool," a private membership platform/community hosted on Skool.
- **Verifiable Track Record:** **None.** 
  - There are no public, third-party audited account statements (e.g., Myfxbook or Darwinex links) associated with Mulham Trading or the Edge Skool brand.
  - The creator frequently posts screenshots of profitable trades, MT5 execution panels, and claims of passing prop firm challenges. However, under strict verification standards, none of these claims are independently verifiable.
- **Independent Reviews:** Public sentiment is mixed but fits the typical pattern of retail trading influencers.
  - On community forums such as Reddit, some users express appreciation for his clear explanation of complex ICT concepts, noting that his "rules-based" formulations make the material more accessible.
  - Conversely, skeptical reviews point out that his business model heavily relies on selling educational subscriptions, e-books, and courses, questioning whether his primary source of income is live trading or education marketing.

---

## 2. Backtest Claims & External Corroboration

The channel anchors several videos on specific backtest performance claims:
1. **4H Liquidity Sweep Strategy (75% Win Rate Claim):** Featured in video `4cK3weGxZeA` (and adjacent video `IW7CSIfnJU4`). This is a manual backtest over a 3-month period consisting of 28 trades, resulting in a +44R return and 65% WR.
2. **Judas Swing Strategy (6-Month Backtest Claim):** Featured in video `Zsv16OGWVRU`. This manual backtest covers 6 months of EURUSD trading, yielding 40 setups, a 55% WR, and +44R.
3. **15-Day Turtle Soup Strategy (76% Win Rate Claim):** Featured in video `xzSFYcgKiao`. It shows an EURUSD manual chart replay claiming +20R.

### Verification and Criticism:
- **No External Corroboration:** There is no third-party audit, public sheet, or independent replication of these backtests.
- **Methodological Weaknesses:** All backtest claims are manual "hindsight replays" performed on TradingView. These are subject to severe selection bias, as the tester knows the subsequent price development when marking setups, and execution slippage/spreads/commissions are entirely ignored. 
- **Commission Vulnerability:** For forex-focused strategies (such as the EURUSD/GBPUSD legs), real-world implementation faces significant drag from commissions (typically ~$45 per million traded on prop accounts), which can devastate short-term scalping results shown in manual replays.

---

## 3. Plagiarism & Relationship to Inner Circle Trader (ICT)

- **Repackaging:** Mulham Trading's content is a direct repackaging of Michael J. Huddleston's Inner Circle Trader (ICT) concepts. The core building blocks taught—such as Fair Value Gaps (FVG), Inverse Fair Value Gaps (IFVG), Liquidity Sweeps, Order Blocks (OB), Judas Swings, and Killzones—are structurally identical to ICT's free mentorship courses.
- **Plagiarism Context:** There are no formal intellectual property or plagiarism claims. In the retail trading community, repackaging ICT concepts is extremely common and not legally actionable, as the terms are generic market structure concepts.
- **Rule Differences from Standard ICT:** 
  - Standard ICT is highly discretionary, emphasizing fluid narratives, daily bias projections, and contextual interpretation.
  - Mulham's primary modification is to force these concepts into a **simplified, mechanical "rules-based" structure**. For example, he mandates fixed risk-to-reward ratios (typically 2.5R to 3R), rigid execution checklists (e.g., HTF Sweep -> LTF BOS/CHoCH -> FVG Entry), and tight session/time anchors to eliminate discretionary decision-making.

---

## 4. G0 Reputable-Source R1-R4 Verdict

Per the canonical [qb_reputable_source_criteria.md](file:///C:/QM/repo/processes/qb_reputable_source_criteria.md), we apply the four criteria:

1. **R1 (Single Source per Card): PASS**
   - Each card in the proposed slate ([mulham_channel_mechanization_dossier_2026-07-13.md](file:///C:/QM/repo/docs/ops/evidence/mulham_channel_mechanization_dossier_2026-07-13.md)) is attributed to exactly one source ID mapping back to a specific video ID or channel-batch item.
   - Per the revised criteria (as of 2026-05-15 and 2026-06-30), **author track record is NOT required**. The source type is open, and YouTube videos from an unknown educator are explicitly accepted. The pipeline is the sole judge of strategy quality.
2. **R2 (Implementable Mechanically): PASS**
   - The strategies have explicit directional entry, stop loss, and exit rules that can be codified into MT5 Expert Advisors by Codex. Any minor parameter gaps can be filled by Codex defaults and refined via P3 parameter sweeps.
3. **R3 (Testable on >=1 DWX Instrument): PASS**
   - The strategies are fully testable on Darwinex CFD instruments (e.g., XAUUSD, EURUSD, US500, NDX).
4. **R4 (No ML / 1-pos-per-magic / Bounded Grid): PASS**
   - The strategies use deterministic price-action rules, require no machine learning, and operate under the standard 1-position-per-magic constraint without martingale runaway.

### R1 Verdict: **PASS** (Provisional on Pipeline Validation)

Under the relaxed G0 criteria, Mulham Trading qualifies as a valid source. The lack of verifiable track records and the manual nature of the backtests do not trigger a G0 rejection, as the pipeline (Q02–Q08) will filter out unprofitable variants.

---

## 5. References and Citations
- **YouTube Channel:** [Mulham Trading](https://www.youtube.com/@MulhamTrading)
- **Triage Log:** [MULHAM_CHANNEL_TRIAGE_2026-07-13.md](file:///C:/QM/repo/docs/research/MULHAM_CHANNEL_TRIAGE_2026-07-13.md)
- **Approved Slate:** [mulham_channel_mechanization_dossier_2026-07-13.md](file:///C:/QM/repo/docs/ops/evidence/mulham_channel_mechanization_dossier_2026-07-13.md)
- **Reputational Standard:** [qb_reputable_source_criteria.md](file:///C:/QM/repo/processes/qb_reputable_source_criteria.md)
