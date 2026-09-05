"""Reproduce edits only inside the explicitly authorized website review copy."""
from pathlib import Path
from html import escape as esc
import json
import re
import shutil
from bs4 import BeautifulSoup

SRC = Path('C:/QM/deploy/qm-ops-refresh/Website')
DST = SRC.parent / 'tools/site-build/astra-rework'
OUT = Path(__file__).resolve().parent
EVIDENCE = OUT.parent
assert DST.resolve().is_relative_to(SRC.parent.resolve()) and DST.resolve() != SRC.resolve()
archive = json.loads((EVIDENCE/'2026-09-05_archive_v3_dryrun/strategy-archive-v3.json').read_text())
live = json.loads((EVIDENCE/'2026-09-05_live_performance_dryrun.json').read_text())
base = BeautifulSoup((SRC/'index.html').read_text(encoding='utf-8'), 'html.parser')
nav = base.find('nav')
nav.select_one('input.nav__toggle').decompose()
burger = nav.select_one('.nav__burger')
burger.name = 'button'; burger.attrs = {'class':'nav__burger','type':'button','aria-label':'Open navigation','aria-expanded':'false','aria-controls':'mobile-menu'}
nav.select_one('.nav__mobile')['id'] = 'mobile-menu'
nav.select_one('.nav__brand').clear();nav.select_one('.nav__brand').append('QuantMechanica')
footer = base.find('footer')
for a in footer.select('.footer__brand a'):
    a.clear();a.append('QuantMechanica')
contact = '''<section class="section section--alt contact-panel" aria-labelledby="contact-title"><div class="wrap cols cols-2">
<div class="stack"><p class="eyebrow">Keep the conversation open</p><h2 class="h2" id="contact-title">A question. A source. A better test.</h2><p>Share a research idea or ask about a result in the archive.</p><a class="btn btn--secondary" href="mailto:info@quantmechanica.com">Contact QuantMechanica</a></div>
<div class="stack"><h3 class="h3">Research notes, when they are ready.</h3><p>Newsletter signup is coming soon. You can contact us by email in the meantime.</p><label for="newsletter-email">Email address</label><input id="newsletter-email" type="email" disabled placeholder="Signup is not open yet"><button class="btn btn--primary" disabled>Newsletter coming soon</button><p class="caption">This form does not collect or send information.</p></div></div></section>'''


def page(path, title, description, main, *, noindex=False):
    canonical = '/' if path=='index.html' else '/'+path.removesuffix('.html')
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>{esc(title)} | QuantMechanica</title><meta name="description" content="{esc(description,quote=True)}">
<meta property="og:title" content="{esc(title,quote=True)} | QuantMechanica"><meta property="og:description" content="{esc(description,quote=True)}"><meta property="og:type" content="website"><meta property="og:url" content="https://quantmechanica.com{canonical}"><meta property="og:image" content="https://quantmechanica.com/assets/og-image.png">
<link rel="canonical" href="https://quantmechanica.com{canonical}"><link rel="icon" href="/favicon.svg"><link rel="stylesheet" href="/style.css">
{'<meta name="robots" content="noindex,follow">' if noindex else ''}
<script defer src="/scripts/stats-loader.js"></script><script defer src="/scripts/qm-charts.js"></script><script defer src="/scripts/review-site.js"></script>
</head><body><a class="skip-link" href="#main">Skip to content</a>{nav}<main id="main">{main}</main>{contact}{footer}</body></html>'''
    target=DST/path;target.parent.mkdir(parents=True,exist_ok=True);target.write_text(html,encoding='utf-8')


def hero(eyebrow,title,lead,cta=''):
    return f'<section class="hero"><div class="hero__inner"><p class="eyebrow">{eyebrow}</p><h1 class="hero__title">{title}</h1><p class="hero__lead">{lead}</p>{cta}</div></section>'


def prose(body):
    return '<section class="section section--tight"><div class="wrap wrap--measure prose">'+body+'</div></section>'


def performance_panel():
    return '''<section class="section section--tight"><div class="wrap"><div class="panel performance-panel"><div class="panel__head"><div><p class="eyebrow">Live account on Darwinex Zero</p><h2 class="h3">The record so far.</h2></div><a class="btn btn--secondary" href="https://www.darwinexzero.com/darwin/KQDS/performance" rel="noopener">View the DARWIN record ↗</a></div>
<p>Strategy-attributed closed-position P&amp;L. Losses are part of the record.</p><div class="figure-grid figure-grid--2"><div class="figure"><div class="figure__num" data-live-net>—</div><div class="figure__cap">Net closed P&amp;L since the epoch · USD</div></div><div class="figure"><div class="figure__num" data-live-closes>—</div><div class="figure__cap">Closed positions</div></div></div>
<div class="chart chart--frame live-chart" data-live-chart role="img" aria-label="Closed-position P and L index"><p>Loading the observed series.</p></div><p class="panel__cap" data-live-caption>Data has not loaded. The external DARWIN record remains available above.</p><details><summary>What this chart includes</summary><p data-live-basis></p><p>The DARWIN page reports its own return methodology. It is a separate record from this closed-position series.</p><a href="/public-data/live-performance.json">Download the aggregate daily series</a></details></div></div></section>'''


archive_cta='<div class="hero__cta"><a class="btn btn--primary" href="/strategies">Explore the strategy archive</a><a class="btn btn--secondary" href="/pipeline">Understand the tests</a></div>'
intro=hero('Research, made inspectable','Trading ideas.<br><span class="accent">The evidence behind them.</span>','We turn mechanical trading ideas into tests, then publish what those tests found. Follow the names, the markets and the gate results in our strategy archive.',archive_cta)
archive_teaser='''<section class="section section--alt"><div class="wrap cols cols-2"><div class="stack"><p class="eyebrow">Start with the archive</p><h2 class="h2">A result is more useful<br>with its history.</h2><p class="lead">Read the idea, then trace its tests. Passing and failed results sit in the same record, with a plain-language explanation of what each gate checked.</p><a class="btn btn--secondary" href="/strategies">Open the research record</a></div><div class="panel archive-preview"><p class="eyebrow">Inside every record</p><div class="preview-line"><strong>The idea</strong><span>Name, mechanism and short description</span></div><div class="preview-line"><strong>The tests</strong><span>Market, timeframe and gate result</span></div><div class="preview-line"><strong>The limits</strong><span>What a result does and does not establish</span></div><p class="caption">The archive counts card revisions. It does not count live strategies.</p></div></div></section>'''
roadmap='''<section class="section"><div class="wrap"><p class="eyebrow">Where the research could lead</p><h2 class="h2">Products have to earn their place.</h2><p class="lead measure">We are exploring channels for strategies that build enough evidence. Each remains subject to further testing and a separate release decision.</p><div class="roadmap-row"><span class="roadmap-row__label">Copy-trading accounts</span><span class="roadmap-row__body">A possible route after an inspectable operating record.</span><span class="badge">Planned</span></div><div class="roadmap-row"><span class="roadmap-row__label">MQL5 Marketplace EAs</span><span class="roadmap-row__body">Selected tools, with documented behavior and limitations.</span><span class="badge">Planned</span></div><div class="roadmap-row"><span class="roadmap-row__label">Allocation and prop evaluation</span><span class="roadmap-row__body">Research for Darwinex Zero and FTMO targets, with their own admission tests.</span><span class="badge">Under evaluation</span></div></div></section>'''
phase_teaser='''<section class="section"><div class="wrap"><p class="eyebrow">How the evidence develops</p><h2 class="h2">An idea. A comparison. An operating record.</h2><div class="phase-band"><div class="phase-band__col"><h3 class="h3">Validation</h3><p>Q00–Q08</p><p>Specify the idea and examine its historical behavior.</p></div><div class="phase-band__col"><h3 class="h3">Requalification</h3><p>Q09–Q14</p><p>Compare changes against a fixed reference.</p></div><div class="phase-band__col"><h3 class="h3">Portfolio &amp; operations</h3><p>Q15–Q17</p><p>Assess the combined book and its operating readiness.</p></div></div><a class="btn btn--secondary" href="/pipeline">Read each gate</a></div></section>'''
# Keep the light, explicitly synthetic market-structure widgets.
widgets=next(s for s in base.select('main section') if s.find(id='w-eurusd'))
widgets.select_one('h2').string='The kinds of market behavior we investigate.'
page('index.html','Trading research, made inspectable','Explore named mechanical strategies, their tests and their limitations. Read the research archive and the observed Darwinex Zero record.',intro+archive_teaser+phase_teaser+performance_panel()+str(widgets)+roadmap)

brief=json.loads((EVIDENCE/'2026-09-05_website_rework/implementation_brief.json').read_text(encoding='utf-8'))['brief']
pipeline=hero('The research process','Every test has<br><span class="accent">a specific question.</span>','The pipeline has three phases. A recorded pass answers a test under its recorded conditions; it does not establish future profitability or permission to trade.')
phase_titles=['Validation','Optimization & requalification','Portfolio & operating readiness']
phase_descriptions=['Specify and test a mechanical idea before treating it as a candidate.','Keep a fixed reference, compare a proposed change and retain the incumbent when the challenger adds no supported improvement.','Assess the combined portfolio, its operational controls and the observed record before any separate release decision.']
for n,phase in enumerate(brief['pipeline_phases']):
    pipeline+=f'<section class="section {"section--alt" if n%2==0 else ""}"><div class="wrap"><p class="eyebrow">{esc(phase_titles[n])}</p><h2 class="h2">{esc(phase_descriptions[n])}</h2><div class="gate-list">'
    for g in phase['gate_lines']:
        line=g['line'];fails=g['fails_when']
        if g['gate']=='Q06':line='Examines how the result changes when some intended fills do not execute.';fails='The remaining result does not meet the execution-stress criteria.'
        if g['gate']=='Q07':line='Repeats the test with different random seeds to inspect sensitivity to execution ordering.';fails='The results are too unstable or fail the required checks.'
        if g['gate']=='Q08':line='Reviews statistical and robustness evidence, including sample size and selection effects.';fails='The dossier does not meet the applicable gate policy. A gate pass alone does not establish that every statistical check has sufficient data.'
        if g['gate']=='Q01':line='Builds the mechanical idea into an Expert Advisor with a written specification.';fails='The build or required specification checks are incomplete.'
        if g['gate']=='Q16':line='Checks the release artifact, execution configuration and operational safeguards.';fails='A required readiness check is missing or fails.'
        if g['gate']=='Q17':line='Observes execution under the approved burn-in plan before any scaling decision.';fails='The observed record or operational controls do not meet the approved readiness requirements.'
        line=line.replace('two axes','the relevant settings').replace('EA','strategy')
        pipeline+=f'<article class="gate-line"><span class="gate-label">{g["gate"]}</span><div><h3>{esc(g["name"])}</h3><p>{esc(line)}</p><p class="caption"><strong>What can stop progress:</strong> {esc(fails)}</p></div></article>'
    pipeline+='</div></div></section>'
pipeline+=prose('<h2>Read the result and its limits together.</h2><p>Research results may need new evidence when inputs or methods change. Missing evidence is a limitation, and a historical pass is not a release approval.</p><a class="btn btn--primary" href="/strategies">Trace a strategy through the tests</a>')
page('pipeline.html','The research pipeline','Validation, requalification and portfolio readiness. Read the question behind each Q gate.',pipeline)

archive_body=hero('The strategy archive','The idea.<br><span class="accent">Then the evidence.</span>','Explore mechanical research ideas and their recorded tests. Each entry is a card revision, with a description and results by market. A passing research record is not a live-trading approval.')
archive_body+='''<section class="section section--tight"><div class="wrap"><div class="archive-toolbar"><div><label for="archive-search">Find a strategy or market</label><input id="archive-search" type="search" placeholder="Search names, families or markets"></div><div><label for="archive-filter">Recorded outcome</label><select id="archive-filter"><option value="all">All records</option><option value="pass">Includes a passing test</option><option value="fail">Includes a failed test</option></select></div></div><p id="archive-count" role="status" aria-live="polite">Loading the research record.</p><div id="archive-list" class="archive-list"></div><button id="archive-more" class="btn btn--secondary" hidden>Show more records</button><noscript><p>Enable JavaScript to search the archive, or <a href="/public-data/strategy-archive-v3.json">download the public record</a>.</p></noscript><p class="caption" id="archive-stamp"></p></div></section>'''
page('strategies.html','Strategy archive','Names, mechanisms and per-market test results. Explore card revisions and follow each recorded Q gate.',archive_body)


def detail(item):
    body=hero('Strategy research record',esc(item['display_name']),esc(item['summary']),'<a class="btn btn--secondary" href="/strategies">← Back to the archive</a>')
    market_text=', '.join(m['symbol_public']+' · '+('Timeframe not recorded' if m['timeframe']=='UNKNOWN' else m['timeframe']) for m in item['markets']) or 'No market recorded'
    body+=f'<section class="section section--tight"><div class="wrap"><div class="record-meta"><div><span class="eyebrow">Mechanism family</span><p>{esc(item["family"])}</p></div><div><span class="eyebrow">Markets</span><p>{esc(market_text)}</p></div><div><span class="eyebrow">Last recorded gate</span><p>{esc(item["terminal_gate"] or "No concluded gate")}</p></div></div><h2 class="h2">The recorded journey.</h2><p>Each result applies to the recorded test. Different markets can have different outcomes.</p><div class="gate-list">'
    for g in item['gate_journey']:
        body+=f'<article class="gate-line"><span class="gate-label">{g["gate"]}</span><div><h3><span class="result result--{g["verdict"].lower()}">{g["verdict"]}</span></h3><p>{esc(g["public_reason"])}</p>'
        if g['backtests']:
            body+='<div class="table-scroll"><table class="table"><caption>Recorded market tests</caption><thead><tr><th scope="col">Market</th><th scope="col">Timeframe</th><th scope="col">Result</th></tr></thead><tbody>'
            for b in g['backtests']:body+=f'<tr><td>{esc(b["symbol_public"])}</td><td>{esc(b["timeframe"] if b["timeframe"]!="UNKNOWN" else "Not recorded")}</td><td><span class="result result--{b["verdict"].lower()}">{b["verdict"]}</span></td></tr>'
            body+='</tbody></table></div>'
        else:body+='<p class="caption">No market-level test is attached to this gate.</p>'
        body+='</div></article>'
    body+='</div><details><summary>Scope and publication limits</summary><p>This page publishes the mechanism and the recorded outcomes. Source code, trading settings and per-strategy performance statistics remain private. A historical result can require fresh evidence and does not establish operational readiness.</p></details>'
    body+=f'<p class="caption">First test: {esc(item["first_tested"] or "Not recorded")} · Last update: {esc(item["last_updated"] or "Not recorded")}. Public card revisions may describe the same underlying strategy.</p></div></section>'
    return body


for item in archive['items']:
    page('strategies/'+item['slug']+'.html',item['display_name'],item['summary'],detail(item))
sample=next(i for i in archive['items'] if len(i['gate_journey'])>=10 and i['markets'])
page('strategies/_template.html',sample['display_name'],sample['summary'],detail(sample),noindex=True)
(OUT/'detail_sample.json').write_text(json.dumps({'slug':sample['slug'],'public_id':sample['public_id'],'rendered_as_template_example':True},indent=2)+'\n')
page('performance.html','Observed performance','Strategy-attributed closed-position results from Darwinex Zero, with an explicit basis and a link to the DARWIN performance record.',hero('Observed execution','The result.<br><span class="accent">As it stands.</span>','Read the observed closed-position series below, including losing periods. The chart covers attributed strategy activity; the DARWIN page provides the separate investor-facing record.')+performance_panel()+prose('<h2>Research and operation answer different questions.</h2><p>The archive records historical tests. This page records observed execution under its stated basis. Neither provides a promise about future returns.</p><h2>Release remains a separate decision.</h2><p>A candidate must be assessed within its portfolio and operating constraints. Historical test results do not authorize capital deployment.</p>'))
page('about.html','About the research','QuantMechanica develops mechanical trading research and publishes its test record.',hero('About QuantMechanica','Mechanical ideas.<br><span class="accent">Accountable research.</span>','QuantMechanica is an independent trading research project. We turn written ideas into reproducible tests and make the resulting record easier to inspect.')+prose('<h2>A clear division of work.</h2><p>Research defines a testable hypothesis. Engineering implements the rules. Review checks the implementation and its evidence. Automation helps with this work; responsibility for release decisions stays with the operator.</p><h2>What we investigate.</h2><p>Our focus is mechanical swing and scalping research, with explicit execution costs, news restrictions and portfolio loss constraints. Grid and martingale recovery are outside the research mandate.</p><h2>Why publish the record?</h2><p>A result becomes more useful when its definition and limitations are visible. The archive provides names, mechanisms and test outcomes while keeping source code and trading settings private.</p><a href="/strategies">Read the archive</a>')+roadmap)
questions=[('What does the archive count?','Each entry is a public card revision. Revisions can describe the same underlying strategy. Market-level results are shown inside each record.'),('Does a PASS mean a strategy is ready to trade?','It means the recorded gate accepted that result under its policy. It does not establish future profitability, complete statistical evidence or release approval.'),('Why do some timeframes say “not recorded”?','The public evidence does not provide a reliable timeframe for that test. We leave the gap visible.'),('What does the performance chart measure?','The observed closed-position net P&L of attributed strategies, including lifecycle costs. It excludes manual positions, cashflows and floating P&L. The chart states its calendar and index basis.'),('Can I buy an EA or copy the account?','Marketplace tools and copy-trading channels are planned possibilities. They require additional evidence and a separate release decision.'),('Do you publish source code and trading settings?','No. We publish names, mechanisms and recorded outcomes, while keeping the implementation and trading settings private.'),('How can I contribute?','Send a research source, a question or a reproducible critique to our contact address.')]
page('faq.html','Questions about the record','How to interpret card revisions, gate results and the observed performance series.',hero('Questions, answered','Read the record<br><span class="accent">with the right context.</span>','A few distinctions make the archive and the performance page easier to use.')+prose(''.join(f'<details><summary>{esc(q)}</summary><p>{esc(a)}</p></details>' for q,a in questions)))

# Concise method notes replace unsupported numeric headlines, settings and
# claims of validated or funded strategy success. No new result is invented.
topics={
'blog-97-percent-failures':('What failed tests can tell us','A failed test narrows a hypothesis. It can also reveal a defect in the test or its implementation. Those explanations need to be separated before treating rejection as evidence of a disciplined process.','A high failure rate by itself does not prove that surviving strategies are robust. The useful record is the test definition, its inputs and the reason for the result.'),
'blog-ai-factory':('Building a repeatable research workflow','Automation helps run a defined process repeatedly. Its value depends on the quality of the question, the implementation and the review of the output.','Activity counts are operational measures. They do not measure investment quality. A testable claim and a reproducible result are more useful than a busy task queue.'),
'blog-3-agent-ai-factory':('Research, engineering and review','Separating research, implementation and review creates distinct opportunities to catch a mistake. A reviewer needs the original hypothesis and the actual evidence, not only a summary of the result.','Automated assistance is part of the workflow. It does not make a result correct by itself, and it does not replace responsibility for a release decision.'),
'blog-deflated-sharpe-ratio':('Accounting for the search behind a result','A selected result needs to be read alongside the search that produced it. Examining many alternatives creates a different evidential question from testing a hypothesis defined in advance.','Our statistical review must account for selection history and available observations. An archive PASS should not be read as proof that a selection-adjusted estimate has sufficient evidence.'),
'blog-fixed-risk-story':('Making backtest comparisons interpretable','A comparison needs a consistent sizing basis. Otherwise changes in exposure can dominate the difference between strategies or research variants.','Research normalization is separate from a deployment risk budget. Both should be stated explicitly when a result is interpreted.'),
'blog-monte-carlo-explained':('Reading a simulation as a conditional result','A simulation explores outcomes under a specified model. Its inputs, sampling method and dependence assumptions define the question it can answer.','We review whether a simulation belongs to the current portfolio and evidence window before using it. A result from a different portfolio is not a current operating estimate.'),
'blog-monte-carlo-simulation':('What a resampled path can show','Resampling asks how results change when observations are reorganized under a chosen rule. The sampling rule determines which patterns are retained.','A closed-trade series cannot establish an intraday equity minimum. A loss-limit assessment needs observations that actually cover the relevant path.'),
'blog-multi-seed-testing':('Repeating a test under different seeds','A seeded test can be replayed, and changing the seed creates a controlled comparison. We examine whether a conclusion depends heavily on one execution ordering.','The archive publishes the gate outcome. It does not expose strategy settings or imply that repeated seeds create independent market histories.'),
'blog-prop-firm-compatibility':('Researching for a specific trading program','A strategy result and a program admission decision answer different questions. News restrictions, execution costs and portfolio loss constraints all need their own evidence.','Darwinex Zero and FTMO are research targets. A provider reference does not imply funding, partnership or a successful evaluation.'),
'blog-session-trading':('Testing a session-based hypothesis','A session hypothesis links a trading rule to a recurring market window. Its test depends on a precise clock definition and the historical data used to represent that window.','We keep the timing rules private. The public record describes the mechanism and market-level outcomes, with missing timing evidence left explicit.'),
'blog-sm124-gotobi-deep-dive':('A calendar-settlement research family','This family investigates whether recurring settlement-related calendar patterns support a mechanical hypothesis. The idea needs a specified test before it can become a strategy claim.','A narrative about market behavior is a starting point. Evidence about the implemented rule, across recorded markets and conditions, determines what can be said about the result.'),
'blog-sm124-gotobi-story':('From a calendar idea to a mechanical test','A calendar hypothesis has to become an unambiguous rule before it can be tested. Calendar handling and source timestamps are part of that definition.','The public archive shares the mechanism and observed gate outcomes. It keeps the exact entry settings and implementation private.'),
'blog-sm186-asian-drift':('Investigating Asian-session drift','This family studies a session-related price-behavior hypothesis. The research question is whether a mechanical expression remains useful under its tested conditions and costs.','We do not infer a transferable edge from a market narrative or one attractive result. The archive records the specific tests and leaves untested claims open.'),
'blog-symbol-selection':('Choosing markets for a research question','A market belongs in a research test when it fits the stated hypothesis and the available data can support the intended checks. Test coverage should be recorded before interpreting a winner.','The archive separates market-level outcomes. A passing test on one market does not establish the same result on another.'),
'blog-walk-forward':('Keeping later observations out of earlier choices','A walk-forward comparison separates the observations used to make a choice from the observations used to examine it afterward. The chronology is part of the test.','Repeatedly changing a design after seeing later outcomes creates additional selection history. That history needs to remain visible to the research review.'),
'blog-why-mql5-eas-use-martingale':('Why recovery sizing is outside our mandate','Our research mandate excludes martingale and grid recovery. We investigate mechanical swing and scalping ideas under explicit risk constraints.','This describes our design boundary. It makes no claim about how frequently another marketplace uses a particular method.'),
'blog-zero-correlation-portfolio':('Examining overlap within a portfolio','Portfolio research asks how candidate return paths interact. Similar exposures can matter even when the strategies have different names or entry rules.','Lower estimated correlation is a design objective, not a promise of independent future results. Admission requires current portfolio evidence and a separate decision.')}
for slug,(title,a,b) in topics.items():
    page(slug+'.html',title,a,hero('Research note',esc(title),esc(a))+prose('<h2>What the method asks</h2><p>'+esc(b)+'</p><h2>Where to inspect a result</h2><p>Method descriptions are not performance evidence for a particular strategy. Read the named record and its market-level gate journey in the archive.</p><a class="btn btn--secondary" href="/strategies">Explore the strategy archive</a>'))
posts=''.join(f'<article class="archive-card"><div><p class="eyebrow">Research methods</p><h2 class="h3"><a href="/{slug}">{esc(v[0])}</a></h2><p>{esc(v[1])}</p></div><a class="btn btn--secondary" href="/{slug}">Read the note →</a></article>' for slug,v in topics.items())
page('blog.html','Research notes','Plain-language notes on test design, evidence and the limits of trading research.',hero('The research notebook','How we ask<br><span class="accent">better questions.</span>','Short notes on the methods behind the archive. These explain the research process; strategy results belong to their individual records.')+'<section class="section section--tight"><div class="wrap archive-list">'+posts+'</div></section>')

# Keep operator-supplied legal language and identity. Correct only demonstrably
# obsolete operational statements; unknown identity/compliance remains a review issue.
for name in ['impressum.html','privacy.html','disclaimer.html','404.html']:
    soup=BeautifulSoup((SRC/name).read_text(encoding='utf-8'),'html.parser');main=soup.find('main')
    for el in main.find_all(['p','li']):
        text=el.get_text(' ',strip=True)
        if 'Myfxbook' in text:el.clear();el.append('The performance page links to the external DARWIN record. This website does not embed an external account widget.')
        elif 'EAs are' not in text and 'Expert Advisors sold' in text:el.clear();el.append('Marketplace Expert Advisors are a planned channel, subject to further evidence and a separate release decision. No product return is guaranteed.')
        elif 'Buttondown' in text:el.clear();el.append('Newsletter signup is not active. The disabled form does not collect or send an email address.')
        elif 'Plausible' in text or 'Google Fonts' in text:el.clear();el.append('This website uses local assets and system fonts. No third-party analytics or embedded account widget is loaded.')
        elif 'Purchases of Expert Advisors' in text:el.clear();el.append('Marketplace products are planned. This website does not accept payments.')
        elif 'Newsletter subscriber data is retained' in text:el.clear();el.append('When newsletter signup opens, its data handling will be described here.')
    if name=='privacy.html':
        for heading in main.find_all(['h2','h3']):
            heading.string=heading.get_text().replace(' (Plausible)','').replace(' (Buttondown)','')
    page(name,soup.find('h1').get_text(' ',strip=True),soup.find('meta',attrs={'name':'description'})['content'],str(main.decode_contents()),noindex=name=='404.html')

shutil.copy2(EVIDENCE/'2026-09-05_archive_v3_dryrun/strategy-archive-v3.json',DST/'public-data/strategy-archive-v3.json')
shutil.copy2(EVIDENCE/'2026-09-05_live_performance_dryrun.json',DST/'public-data/live-performance.json')
# The old combined-backtest asset contains private sizing terminology and is
# unused in the review copy. Remove only this own copied file, never the source.
unused=DST/'public-data/hero-equity.json'
if unused.exists():
    assert unused.resolve().is_relative_to(DST.resolve());unused.unlink()
urls=['https://quantmechanica.com/'+str(p.relative_to(DST)).replace('\\','/').removesuffix('.html') for p in DST.rglob('*.html') if p.name not in ('404.html','_template.html')]
(DST/'sitemap.xml').write_text('<?xml version="1.0" encoding="UTF-8"?><urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'+''.join('<url><loc>'+esc(u)+'</loc></url>' for u in urls)+'</urlset>')
(OUT/'build_receipt.json').write_text(json.dumps({'full_copy':str(DST),'source_website_written':False,'static_detail_pages':len(archive['items']),'blog_notes':len(topics),'detail_template_sample':sample['slug'],'archive_generated_at':archive['generated_at'],'live_generated_at':live['generated_at']},indent=2)+'\n')
print('Reworked full copy with',len(archive['items']),'static details')
