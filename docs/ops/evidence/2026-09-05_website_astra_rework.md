# QuantMechanica website rework: independent review copy

Task `e0fea529-8676-41b3-8213-d85ad5a23b00`. Disposition: REVIEW. The full copy is at `C:/QM/deploy/qm-ops-refresh/tools/site-build/astra-rework/`. The original `Website/` tree is byte-identical to the captured source manifest. No commit, push or deployment was performed in the deploy repository. Its inspected source HEAD was `eed6477ce52246d79b54bb3d477646cddffad79a`.

The copy retains the established light v3 design system, adds a searchable named archive and **3,399 static strategy detail pages**, and replaces the combined-backtest and Myfxbook surfaces with the reconciled Darwinex Zero closed-position series. The complete copy is also preserved in [review_site.zip](2026-09-05_website_astra_rework/review_site.zip), with a [file hash manifest](2026-09-05_website_astra_rework/review_copy_manifest.json). The zip, analysis, scripts and renders are canonical board-advisor evidence.

## Analysis of the source

The useful foundation is shared CSS, restrained color, readable light chart frames and an archive-first direction. The main weakness is credibility: the copy repeatedly turns a process into proof. The route from a new visitor to an inspectable result should be archive → named record → specific test → limitations → observed execution. Activity counts and unsupported percentages interrupt that route.

All source pages lacked a canonical link and used a hidden checkbox with an aria-hidden label for mobile navigation; a keyboard user could not activate that control. Source anchors and metadata for every page are captured in [page_audit.json](2026-09-05_website_astra_rework/page_audit.json). File:line references below refer to that unchanged source tree.

| Source page | Concrete problem and resulting revision |
|---|---|
| `index.html:70` | “The Quantitative Edge” and the long proof-oriented lead obscure the actual public content. Shortened to the research idea and its evidence; the first action opens the archive. |
| `index.html:122` | Combined backtest equity is the dominant performance surface. Replaced with observed closed-position P&L, explicit methodology and the DARWIN link. |
| `pipeline.html:69` | The headline and gate prose imply that a completed process proves an edge. Revised to questions each test asks; Q08 explicitly distinguishes gate acceptance from sufficient statistical evidence. Removed literal execution settings and the outdated burn-in duration. |
| `strategies.html:111` | A card-revision archive is described as strategy-symbol candidates. Corrected the unit, added names, summaries, family/market search, outcome filters and static detail links. |
| `performance.html:69` | Unverified Myfxbook tracking, unsupported survival/target counts and internal operating controls dominate the page. Replaced with the governed observed series and plain distinctions between research, operation and investor-facing returns. |
| `about.html:69` | An agent-centric headline and role inventory put implementation ahead of purpose. Reframed around research, engineering, review and responsibility. Future products remain planned. |
| `faq.html:69` | Unsupported survival percentage, detailed internal routing and absolute claims about tick authenticity. Rewritten around how to interpret revisions, PASS results, missing fields and the chart basis. |
| `blog.html:52` | Numeric and promotional article titles carry unsupported claims into the index. Replaced with a coherent research notebook linking the revised notes. |
| `blog-97-percent-failures.html:53` | Unsupported percentage and failure rate treated as proof of a valid filter. Rewritten as the distinction between a failed hypothesis and a defective test. |
| `blog-ai-factory.html:53` | Task throughput is presented as the achievement. Rewritten around reproducibility and review, with no unsupported throughput figure. |
| `blog-3-agent-ai-factory.html:53` | Provider/agent details and a long promotional narrative obscure responsibility. Condensed to research, engineering and review. |
| `blog-deflated-sharpe-ratio.html:53` | A method note risks implying the current gate always establishes corrected statistics. Revised to selection history and evidence sufficiency. |
| `blog-fixed-risk-story.html:53` | Broad performance rhetoric distracts from the comparison basis. Revised to normalization versus deployment sizing, without disclosing settings. |
| `blog-monte-carlo-explained.html:53` | Portfolio-draft examples can be read as current estimates. Revised to input identity, sampling assumptions and the scope of a simulation. |
| `blog-monte-carlo-simulation.html:53` | Closed-trade resampling is insufficiently distinguished from intraday loss evidence. The new note makes that boundary explicit. |
| `blog-multi-seed-testing.html:53` | Literal thresholds and seed counts, with strong causal claims. Rewritten as a controlled sensitivity comparison. |
| `blog-prop-firm-compatibility.html:53` | Program fit can be mistaken for admission. Reframed as target-specific research and separate evidence requirements. |
| `blog-session-trading.html:53` | Detailed timing narratives and “edge” labels exceed the demonstrated record. Rewritten as a session hypothesis with explicit clock dependence. |
| `blog-sm124-gotobi-deep-dive.html:53` | A lengthy strategy-success narrative blurs hypothesis and result. Replaced with a calendar-settlement research note and archive link. |
| `blog-sm124-gotobi-story.html:53` | Describes implementation timing too specifically for the public contract. Reduced to mechanism and calendar-test definition. |
| `blog-sm186-asian-drift.html:53` | Family narrative implies transferable success across markets. Revised to a session hypothesis and per-market evidence. |
| `blog-symbol-selection.html:53` | Market-selection discussion needs a clearer population boundary. Revised to recorded coverage and separate market outcomes. |
| `blog-walk-forward.html:53` | “Separates signal from noise” overstates what chronology alone establishes. Rewritten around held-out observations and subsequent selection history. |
| `blog-why-mql5-eas-use-martingale.html:53` | Unsupported claim about most marketplace products. Replaced with QuantMechanica's own research exclusion. |
| `blog-zero-correlation-portfolio.html:53` | “Zero correlation” is read as a delivered property. Rewritten as an overlap assessment, with current portfolio evidence required. |
| `privacy.html:68` | Claims no third-party cookies while describing an embedded third-party widget; newsletter text assumes an active service. Operational descriptions now match the local-assets, outbound-link and disabled-form implementation. |
| `disclaimer.html:68` | Present-tense product sales and Myfxbook wording conflict with planned channels and the new chart. Updated those factual descriptions; retained operator-supplied legal language. |
| `impressum.html:78` | Operator identity is only “QuantMechanica / Europe.” No identity was invented. The operator must complete the legal identity before publication. Shared layout and metadata are improved. |
| `404.html:68` | The common inaccessible menu also affects recovery. Shared keyboard navigation, skip link, noindex and working recovery links now apply. |

## Design and behavior

Typography and spacing use the existing neutral/emerald system, with darker secondary text, narrower prose and more consistent section rhythm. Pass/fail color is limited to explicitly labeled result badges. Archive rows give priority to the name and mechanism; the gate journey is secondary evidence. Every result is also readable as text. Tables retain captions and column headers.

The navigation uses a real button, expanded-state semantics, Escape handling and an inert closed menu. Focus indicators and a skip link support keyboard users. The responsive layout was checked at actual browser viewport widths, including a 390-pixel phone viewport. Reduced motion is respected. The light synthetic candle widgets remain labeled as illustrations.

The live panel reads the public producer's JSON. It retains losing results, states the epoch and observation date, describes its USD 100,000 reference-capital index, excludes floating P&L, and links the separate DARWIN return record. A data error shows an unavailable state rather than a fabricated curve. The source dry run is −1,436.59 USD over the epoch; its August-through-September validation window reconciles exactly in the separate producer evidence.

The archive displays the v3 fields without exposing settings or strategy metrics. Static detail pages include market/timeframe results and explicit missing-timeframe labels. Alphabetical ordering is independent of outcome. Search, filters, an empty result state and incremental display are implemented. The `_template.html` preview uses an actual record and is marked noindex.

Contact uses the existing public email address. The newsletter control is visibly disabled and sends nothing. Marketplace and copy-trading channels are described as planned. All wordmarks read **QuantMechanica**. The copy loads local assets and system fonts; third-party analytics and embedded account widgets are absent.

## Verification and review limits

The complete static check covers **3,428 HTML pages**: no unresolved internal links or fragment targets, no missing title/description/single-heading metadata, and no forbidden exposure tokens across HTML, JavaScript, CSS and JSON. Source hashes prove `Website/` remained unchanged. [Static verification](2026-09-05_website_astra_rework/static_verification.json) also inventories numeric prose. Numbers are public-data values, measured chart captions, public gate/timeframe identifiers, product names, dates or legal section labels; unsupported statistical headlines were removed.

Browser checks verify HTTP success and no horizontal overflow for index, pipeline, strategies, the detail template and performance at **1400 and 800 pixels**. Additional **390-pixel** checks cover market search, outcome filtering, no-match behavior, keyboard menu activation and Escape. There were no JavaScript errors. The missing-data performance state was verified. The temporary local preview server was shut down. [Browser verification](2026-09-05_website_astra_rework/browser_verification.json).

Review still needs editorial attention to the producer's **3,368 weak fallback names** and stripped descriptions. Their source wording is preserved rather than inventing mechanisms. Operator legal identity and final legal text require completion; no legal-compliance conclusion is claimed. The unavailable Drive identity and pipeline documents could not be consulted, so the canonical brief and current evidence were used. The updated Q08 wording avoids carrying forward claims contradicted by the statistics audit.

Renders are in [the evidence folder](2026-09-05_website_astra_rework/): `index_1400.png`, `index_800.png`, `pipeline_1400.png`, `pipeline_800.png`, `strategies_1400.png`, `strategies_800.png`, `strategies__template_1400.png`, `strategies__template_800.png`, `performance_1400.png`, `performance_800.png`, and `strategies_mobile_390.png`. The scripts and manifests make the review copy inspectable without integrating it into main or the deployment branch.
