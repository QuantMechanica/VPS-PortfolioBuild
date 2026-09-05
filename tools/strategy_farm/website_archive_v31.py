"""Review-only strategy-family archive. This command has no publication path."""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
from collections import Counter, defaultdict
from functools import lru_cache
from pathlib import Path

try:
    from tools.strategy_farm import website_archive_contract as legacy
    from tools.strategy_farm import website_archive_v3 as v3
    from tools.strategy_farm.rebaseline_census import open_ro, summarise_pair, vclass
except ImportError:
    import website_archive_contract as legacy
    import website_archive_v3 as v3
    from rebaseline_census import open_ro, summarise_pair, vclass

SCHEMA = "https://quantmechanica.com/schemas/strategy-archive/v3.1.json"
DISCLOSURE = "named_gate_journey_without_metrics"
PHASES = (
    ("validation", "Validation", tuple(f"Q{i:02d}" for i in range(9))),
    ("optimization", "Optimization and requalification", tuple(f"Q{i:02d}" for i in range(9, 15))),
    ("book", "Book build and live readiness", ("Q15", "Q16", "Q17")),
)
REVIEW = "OWNER_CEO_REVIEW_REQUIRED"
SCOPE = "Historical evidence; current release and live operation require separate verification."
ID_RE = re.compile(r"^strategy_[0-9a-f]{16}$")
REVISION_SUFFIX = re.compile(r"(?:-(?:r\d+(?:-recovery)?|requal\d*|opt|recovery|v\d+))+$", re.I)
TF_RE = re.compile(r"(?<![A-Z0-9])(?:PERIOD_)?(MN1|M[1-9][0-9]?|H[1-9][0-9]?|D1|W1)(?![A-Z0-9])", re.I)
TF_KEYS = ("period", "timeframe", "timeframes", "execution_timeframe", "signal_timeframe")

# Editorial vocabulary: predicates inspect section one and the card summary/title.
# Numbers, private identifiers and source text never enter the generated copy.
NAMING_RULES = (
    (r"multi.factor|factor.scor", "Factor Alignment", "Factor", "Looks for agreement between complementary market signals."),
    (r"harmonic|gartley|butterfly|cypher|pesavento|carney|xabcd", "Harmonic Swing", "Price action", "Studies recurring geometric relationships between price swings."),
    (r"demark|\btd.seq|td.comb", "Exhaustion Sequence", "Price action", "Studies recurring price sequences around potential directional changes."),
    (r"pitchfork|murrey|gann|goodman", "Geometric Price Path", "Price action", "Studies price movement around geometric trading levels."),
    (r"dual.?mom|asset.allocation|tactical|rotation|rotator", "Tactical Rotation", "Rotation", "Studies mechanical changes in exposure across a market universe."),
    (r"pairs.trading|etf.pairs", "Paired Market Convergence", "Relative value", "Studies convergence between related markets after their prices diverge."),
    (r"inflation|macro.timing|box.ppi", "Macro Regime Switch", "Macro", "Studies mechanical exposure changes conditioned on economic data."),
    (r"statistical.reversion", "Statistical Rebound", "Reversal", "Studies a return toward balance after a short term price displacement."),
    (r"gamma|hedging.cluster|round.number", "Round Level Response", "Price action", "Studies price behaviour around prominent trading levels."),
    (r"candle.*(?:align|continu)|continuation|candle.color|heiken.ashi|renko", "Candle Continuation", "Price action", "Studies persistent directional structure in completed price bars."),
    (r"divergence|\bdiv\b|lead.lag|lag.sign|correlation|corr.triad", "Market Divergence", "Relative structure", "Studies differences in the behaviour of related market signals."),
    (r"meanrev|rebound|contrarian|bounce|\bmrwings\b", "Price Rebound", "Reversal", "Studies price recovery following an extended directional move."),
    (r"parabolic|\bsar\b|nrtr", "Trailing Trend Turn", "Trend", "Studies directional changes around a trailing price reference."),
    (r"pivot|double.top|double.bottom|head.shoulder", "Pivot Structure Turn", "Price action", "Studies directional changes around established swing levels."),
    (r"daily.open|dailyopen|session.open", "Session Opening Drift", "Session", "Studies price movement relative to the session opening level."),
    (r"gap", "Opening Gap Response", "Price action", "Studies how price responds to a gap between trading periods."),
    (r"\b(?:fib|fibonacci)\b", "Retracement Geometry", "Price action", "Studies price reactions around geometric retracement levels."),
    (r"quarter.end|benchmark.fix|hedge.flow", "Quarter Turn Flow", "Calendar", "Studies recurring directional flow around the quarter end calendar."),
    (r"announcement|inventory.release|\becb\b", "Announcement Drift", "Event conditioned", "Studies market movement around scheduled economic announcements."),
    (r"squeeze.*revers|revers.*squeeze", "Squeeze Reversal", "Reversal", "Looks for reversals after a contraction in the trading range."),
    (r"fomc|federal.*meeting", "Policy Cycle Drift", "Event conditioned", "Studies directional drift around the monetary policy calendar."),
    (r"cointegr|relative.value|spread.*(?:mean|rever)|xauxag|xtixng", "Relative Value Reversion", "Relative value", "Looks for a return toward balance between related markets."),
    (r"turn.of.*month|month.end|\btom\b", "Month Turn Flow", "Calendar", "Studies recurring market movement around the turn of the month."),
    (r"holiday|preholiday", "Holiday Drift", "Calendar", "Studies directional movement around the holiday calendar."),
    (r"opening.range|open.range|\borb\b", "Opening Range Break", "Breakout", "Looks for price to move beyond the range established near the session open."),
    (r"liquidity.*(?:sweep|grab)|stop.hunt", "Liquidity Sweep Reversal", "Reversal", "Looks for price to reverse after testing a nearby liquidity area."),
    (r"liquidity.*(?:break|contraction)|contraction.*pivot|liq.break", "Liquidity Range Break", "Breakout", "Looks for a directional break after nearby price levels converge."),
    (r"vwap|volume.weighted", "Volume Anchor Pullback", "Pullback", "Studies price movement around a volume weighted reference."),
    (r"squeeze|compression|contraction", "Range Compression Break", "Breakout", "Looks for directional movement following a compressed trading range."),
    (r"fair.value.gap|\bfvg\b", "Value Gap Return", "Pullback", "Studies how price responds when it revisits a market imbalance."),
    (r"donchian|turtle|channel.*break", "Channel Breakout", "Breakout", "Looks for directional movement beyond an established price channel."),
    (r"bollinger|bband|\bbb\b|keltner|\bkc\b|envelope|\bbb[w]\b", "Volatility Envelope", "Volatility", "Studies price behaviour around a volatility envelope."),
    (r"ichimoku|\bichi\b|cloud", "Cloud Trend", "Trend", "Uses price structure around a trend cloud to frame directional trades."),
    (r"engulf|outside.bar", "Outside Bar Reversal", "Price action", "Studies directional changes around an outside bar pattern."),
    (r"inside.bar|harami", "Inside Range Break", "Price action", "Studies price movement after an inside range pattern."),
    (r"pin.bar|hammer|shooting.star", "Rejection Bar Turn", "Price action", "Looks for directional changes around price rejection bars."),
    (r"wedge|triangle", "Converging Range Break", "Price action", "Studies price movement as a converging range resolves."),
    (r"head.and.shoulder|\bhs.rev\b", "Swing Structure Reversal", "Price action", "Looks for directional changes in the structure of price swings."),
    (r"carry", "Carry Regime", "Carry", "Studies currency carry exposure within a mechanical market regime."),
    (r"season|january|february|march|april|june|july|august|september|october|november|december", "Seasonal Drift", "Calendar", "Studies recurring directional patterns in the market calendar."),
    (r"momentum|\bmom\b|\bmomo\b|tsmom|ewmac", "Directional Momentum", "Momentum", "Looks for established directional movement to persist."),
    (r"pullback|\bpull\b|\bpb\b|retest", "Trend Pullback", "Pullback", "Looks for a retracement within an established directional move."),
    (r"mean.reversion|revert|\bmr\b|\brev\b|reversal|fade", "Price Reversal", "Reversal", "Looks for an extended price move to turn back toward balance."),
    (r"breakout|\bbrk\b|\bbreak\b", "Price Range Break", "Breakout", "Looks for directional movement beyond a previously established range."),
    (r"cross|moving.average|\bema\b|\bsma\b|\bwma\b|\bma\b|lwma|sidus", "Average Trend Turn", "Trend", "Studies directional changes around moving price averages."),
    (r"\brsi\b|relative.strength", "Relative Strength Turn", "Oscillator", "Studies changes in the balance of recent upward and downward movement."),
    (r"\bcci\b|commodity.channel", "Channel Momentum Turn", "Oscillator", "Studies directional changes in a price deviation oscillator."),
    (r"stoch", "Stochastic Turn", "Oscillator", "Studies changes in the position of price within its recent range."),
    (r"macd", "Momentum Convergence", "Oscillator", "Studies changes in the convergence of moving price averages."),
    (r"trend|directional|\badx\b", "Directional Trend", "Trend", "Studies persistent directional structure in price movement."),
    (r"volatil|\batr\b|lowvol", "Volatility Regime", "Volatility", "Studies price behaviour conditioned on the volatility regime."),
    (r"cycle|oscillat|ehlers", "Market Cycle Turn", "Cycle", "Studies recurring changes in the direction of market movement."),
    (r"volume|obv", "Volume Flow", "Volume", "Studies directional price movement alongside trading activity."),
    (r"range|support|resistance|fractal|channel|highlow|hilo|inside|straddle", "Range Structure", "Price action", "Studies price behaviour around established trading levels."),
    (r"rank|median|dispersion|entropy|variance|distribution|skew|kurt|samecal|meanloc", "Distribution Shift", "Relative structure", "Studies changes in the distribution of historical price movement."),
    (r"overnight|session|intraday|morning|lunch|payday|weekly|week|friday|\bfri\b|calendar|day.of.month", "Calendar Session Flow", "Session", "Studies directional movement within recurring trading periods."),
    (r"factor|beta|\bbab\b|valuation|\bcape\b", "Market Factor Balance", "Factor", "Studies differences in mechanical market factor exposures."),
    (r"money.flow|chaikin|demand.index|cvd|accumulation|sentiment", "Market Pressure", "Volume", "Studies changes in the balance of buying and selling pressure."),
    (r"signal|score|confluence|confirm|composite|blend|stack|screen|impulse", "Signal Confluence", "Confirmation", "Looks for agreement between mechanical market signals."),
)


def digest(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def section_one(text: str) -> str:
    found = re.search(r"(?ims)^##\s*1[.)]?\s+[^\n]*\n(.*?)(?=^##\s|\Z)", text)
    return found.group(1).strip() if found else ""


def card_summary(card: dict) -> str:
    body = card["body"]
    # Headline plus lead paragraph, stopping before source/mechanics sections.
    lead = re.split(r"(?m)^##\s", body, maxsplit=1)[0]
    explicit = re.search(r"(?ims)^##\s*(?:\d+[.)]?\s*)?(?:Summary|Strategy Summary|Overview)\s*\n(.*?)(?=^##\s|\Z)", body)
    concepts = card["fm"].get("concepts") or []
    return "\n".join((lead, explicit.group(1) if explicit else "", section_one(body), str(concepts)))


def name_entry(context: str) -> dict:
    context = re.sub(r"(?<=[a-z])(?=[0-9])|(?<=[0-9])(?=[a-z])", " ", context.lower())
    for pattern, name, family, tagline in NAMING_RULES:
        if re.search(pattern, context):
            prefix = next((label for pattern, label in (
                (r"\bmonday\b|\bmon\b", "Monday"), (r"\btuesday\b|\btue\b", "Tuesday"),
                (r"\bweekly\b", "Weekly"), (r"\bmonthly\b", "Monthly"),
                (r"\bdaily\b", "Daily"), (r"\blondon\b", "London"),
                (r"\bnew.york\b", "New York"),
            ) if re.search(pattern, context)), "")
            return {"name": (prefix + " " + name).strip(), "tagline": tagline,
                    "family": family, "review_status": REVIEW, "naming_basis": "mechanism_vocabulary"}
    return {"name": "Price Pattern Study", "tagline": "A mechanical price pattern awaits an editorial description.",
            "family": "Price action", "review_status": REVIEW, "naming_basis": "source_description_gap"}


def load_cards(farm_root: Path) -> list[dict]:
    cards = []
    for path in sorted((farm_root / "artifacts/cards_approved").glob("QM5_*.md")):
        projected = legacy.project_card(path)
        if not projected or not re.fullmatch(r"QM5_\d+", projected["ea_id"]):
            continue
        fm, body = legacy._parse_frontmatter(path.read_text(encoding="utf-8", errors="replace"))
        cards.append({"ea": projected["ea_id"], "revision": projected["card_id"], "fm": fm, "body": body})
    if not cards:
        raise legacy.PublicSnapshotContractError("No readable EA cards")
    return cards


def families(cards: list[dict]) -> dict[str, list[dict]]:
    """Only explicit lineage or same-source revision spelling merges identities."""
    parent = {c["ea"]: c["ea"] for c in cards}

    def root(ea):
        while parent[ea] != ea:
            parent[ea] = parent[parent[ea]]
            ea = parent[ea]
        return ea

    def join(a, b):
        if b in parent:
            a, b = root(a), root(b)
            first, second = sorted((a, b), key=lambda x: int(x.split("_")[1]))
            parent[second] = first

    known = {}
    for c in cards:
        fm = c["fm"]
        for key in ("parent_ea_id", "recovered_from_ea_id", "variant_of"):
            m = re.fullmatch(r"(?:QM5_)?(\d+)", str(fm.get(key, "")))
            if m:
                join(c["ea"], "QM5_" + m.group(1))
        slug, source = str(fm.get("slug") or ""), str(fm.get("source_id") or "")
        if slug and source:
            key = (source, REVISION_SUFFIX.sub("", slug))
            if key in known:
                join(c["ea"], known[key])
            known[key] = c["ea"]
    result = defaultdict(list)
    for c in cards:
        result[root(c["ea"])].append(c)
    return dict(sorted(result.items()))


def timeframes(value) -> set[str]:
    if isinstance(value, list):
        return set().union(*(timeframes(x) for x in value)) if value else set()
    return {m.group(1).upper() for m in TF_RE.finditer(str(value or ""))}


def combine_timeframes(values) -> str:
    found = set().union(*(timeframes(x) for x in values))
    return next(iter(found)) if len(found) == 1 else "multi" if found else "UNKNOWN"


def read_set_timeframes(path: Path) -> set[str]:
    # Filename and timeframe-labelled metadata are governed inputs. Do not scan
    # arbitrary parameter values for numbers resembling timeframe enums.
    found = timeframes(path.name)
    if path.is_file():
        data = path.read_bytes()
        text = data.decode("utf-16" if data.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig", errors="replace")
        for line in text.splitlines():
            if re.match(r"(?i)^\s*;?\s*(?:period|timeframe|execution_timeframe|signal_timeframe)\s*[:=]", line):
                found.update(timeframes(line))
    return found


def build(db_path: Path, farm_root: Path, repo_root: Path, *, generated_at=None, previous_ledger=None):
    cards = load_cards(farm_root)
    grouped = families(cards)
    by_ea = defaultdict(list)
    for c in cards:
        by_ea[c["ea"]].append(c)
    folders = defaultdict(list)
    for p in sorted((repo_root / "framework/EAs").glob("QM5_*")):
        m = re.match(r"(QM5_\d+)_", p.name)
        if m and p.is_dir():
            folders[m.group(1)].append(p)

    con = open_ro(str(db_path))
    con.execute("PRAGMA query_only=ON")
    con.execute("BEGIN")
    try:
        pairs = legacy._build_public_pair_records(con)
        summaries = {k: summarise_pair(v) for k, v in pairs.items()}
        book_states = legacy._phase_three_pair_states(con, summaries)
        columns = {r[1] for r in con.execute("PRAGMA table_info(work_items)")}
        fields = ["ea_id", "symbol", "phase", "gate_contract_version", "status", "verdict", "created_at", "updated_at", "payload_json", "setfile_path"]
        select = ",".join(k if k in columns else "NULL AS " + k for k in fields)
        rows = [dict(r) for r in con.execute("SELECT " + select + " FROM work_items WHERE ea_id IS NOT NULL")]
    finally:
        con.close()
    rows_by_ea = defaultdict(list)
    resolve_gate = lru_cache(maxsize=None)(legacy._public_gate)
    for r in rows:
        if r["ea_id"] not in by_ea:
            continue
        r["gate"] = resolve_gate(str(r["phase"] or ""), r["gate_contract_version"])
        rows_by_ea[r["ea_id"]].append(r)
    old = (previous_ledger or {}).get("entries", {})
    entries, items, audit = {}, [], []
    for anchor, family_cards in grouped.items():
        members = sorted({c["ea"] for c in family_cards})
        pid = "strategy_" + digest("ea-family:" + anchor)[:16]
        specs, contexts = {}, []
        card_tfs = defaultdict(set)
        for c in family_cards:
            fm = c["fm"]
            # Summary/section one only; the rest of the private card is never copied.
            contexts.extend(str(fm.get(k) or "") for k in ("public_summary", "summary", "title", "name", "slug"))
            contexts.append(card_summary(c))
            for key in TF_KEYS:
                card_tfs[c["ea"]].update(timeframes(fm.get(key)))
        set_tfs = defaultdict(set)
        set_paths = set()
        for ea in members:
            for folder in folders[ea]:
                spec = folder / "SPEC.md"
                if spec.is_file():
                    specs[str(spec)] = hashlib.sha256(spec.read_bytes()).hexdigest()
                    contexts.insert(0, section_one(spec.read_text(encoding="utf-8", errors="replace")))
                for path in sorted((folder / "sets").glob("*.set")):
                    set_paths.add(str(path))
                    tfs = read_set_timeframes(path)
                    match = re.search(r"_([A-Z][A-Z0-9]{2,9})(?:\.DWX|\.CASH)?_", path.name)
                    set_tfs[(ea, match.group(1) if match else "")].update(tfs)
        ea_set_tfs = {ea: set().union(*(tfs for (owner, _), tfs in set_tfs.items() if owner == ea)) for ea in members}
        current_rows = [r for ea in members for r in rows_by_ea[ea]]
        provenance = {"spec_sha256": sorted(set(specs.values())),
                      "card_revision_ids": sorted({c["revision"] for c in family_cards})}
        proposed = name_entry("\n".join(contexts))
        proposed["provenance"] = provenance
        prior = old.get(pid)
        if prior and prior.get("provenance") == provenance:
            proposed = prior
        entries[pid] = proposed
        markets = defaultdict(set)
        cells = defaultdict(set)
        unresolved = []
        for ea in members:
            for c in by_ea[ea]:
                intended = c["fm"].get("target_symbols") or c["fm"].get("primary_target_symbols") or []
                if isinstance(intended, str):
                    intended = [intended]
                for s in intended:
                    if public_symbol := v3.market(s):
                        markets[public_symbol].update(set_tfs[(ea, public_symbol)] or card_tfs[ea] or ea_set_tfs[ea])
        for r in current_rows:
            symbol = v3.market(r["symbol"])
            if not symbol:
                continue
            try:
                payload = json.loads(r["payload_json"] or "{}")
            except (TypeError, ValueError):
                payload = {}
            if not isinstance(payload, dict):
                payload = {}
            tfs = set().union(*(timeframes(payload.get(k)) for k in TF_KEYS))
            set_path = r["setfile_path"] or payload.get("setfile") or payload.get("setfile_path")
            if set_path:
                p = Path(str(set_path))
                if not p.is_absolute():
                    p = repo_root / p
                if p.is_file():
                    tfs.update(read_set_timeframes(p))
                    if not tfs:
                        unresolved.append(str(p))
            if not tfs:
                tfs = set_tfs[(r["ea_id"], symbol)] or card_tfs[r["ea_id"]] or ea_set_tfs[r["ea_id"]]
            markets[symbol].update(tfs)
            state = vclass(r["verdict"], r["gate"])
            concluded = str(r["status"]).lower() == "done" or (str(r["status"]).lower() == "failed" and state == "ECON_FAIL")
            if r["gate"] and concluded and state in ("PASS", "ECON_FAIL"):
                cells[r["gate"]].add((symbol, combine_timeframes(tfs), "PASS" if state == "PASS" else "FAIL"))
        # Ensure card markets with no direct rows still resolve from symbol sets.
        for ea in members:
            for (owner, symbol), tfs in list(set_tfs.items()):
                if owner == ea and symbol:
                    declared = tfs or card_tfs[ea] or ea_set_tfs[ea]
                    # An untested, parameter-only legacy set has no timeframe
                    # contract. Do not fabricate a market/timeframe cell from it.
                    if declared:
                        markets[symbol].update(declared)
        frontiers = []
        for pair, summary in summaries.items():
            if pair[0] in members:
                states = legacy._pair_states(pairs[pair], summary)
                states.update(book_states.get(pair, {}))
                frontiers.extend(int(g[1:]) for g, state in states.items() if state == "PASS")
        frontier = max(frontiers, default=0)
        retired = all(str(c["fm"].get("g0_status") or c["fm"].get("status") or "").upper() in ("REJECTED", "RETIRED", "ARCHIVED") for c in family_cards)
        # A backtest/burn-in PASS is not evidence that a strategy is currently live.
        terminal = "retired" if retired else "book candidate" if frontier >= 14 else "optimization" if frontier >= 8 else "research frontier"
        journey = []
        for phase_id, phase_name, gates in PHASES:
            gate_rows = []
            for gate in gates:
                values = sorted(cells[gate])
                if not values:
                    continue
                passed = sorted({s for s, _, v in values if v == "PASS"})
                failed = sorted({s for s, _, v in values if v == "FAIL"})
                gate_rows.append({"gate": gate, "purpose": legacy.PUBLIC_GATE_PURPOSES[gate],
                                  "outcome": "mixed" if passed and failed else "passed" if passed else "failed",
                                  "passed_symbols": passed, "failed_symbols": failed,
                                  "backtests": [{"symbol_public": s, "timeframe": tf, "verdict": v} for s, tf, v in values]})
            journey.append({"phase": phase_id, "name": phase_name, "gates": gate_rows})
        dates = [v3.day(r["created_at"]) for r in current_rows if r["gate"]]
        updates = [v3.day(r["updated_at"]) for r in current_rows]
        item = {"public_id": pid, "slug": v3.name_slug(proposed["name"], pid), "display_name": proposed["name"],
                "tagline": proposed["tagline"], "family": proposed["family"], "review_status": REVIEW,
                "markets": [{"symbol_public": s, "timeframe": combine_timeframes(tfs)} for s, tfs in sorted(markets.items())],
                "first_tested": min(filter(None, dates), default=None), "last_updated": max(filter(None, updates), default=None),
                "terminal_status": terminal, "evidence_scope": SCOPE, "gate_journey": journey,
                "revision_history": sorted({c["revision"]: {"public_id": c["revision"], "recorded_at": v3.day(c["fm"].get("last_updated") or c["fm"].get("created"))} for c in family_cards}.values(), key=lambda x: (x["recorded_at"] or "", x["public_id"]))}
        items.append(item)
        audit.append({"public_id": pid, "members": members, "set_files": len(set_paths), "spec_files": len(specs),
                      "unresolved_set_metadata": sorted(set(unresolved)), "naming_basis": proposed["naming_basis"],
                      "unknown_markets": [m for m in item["markets"] if m["timeframe"] == "UNKNOWN"]})
    archive = {"schema_version": "3.1", "$schema_id": SCHEMA, "generated_at": generated_at or dt.datetime.now(dt.timezone.utc).isoformat(),
               "gate_contract_version": "v4", "disclosure": DISCLOSURE, "total": len(items), "items": sorted(items, key=lambda x: x["public_id"])}
    ledger = {"schema": "qm.strategy-names/v1", "review_status": REVIEW, "entries": entries}
    validate(archive)
    return archive, ledger, audit


def validate(archive):
    fail = legacy.PublicSnapshotContractError
    def exact(obj, keys):
        if not isinstance(obj, dict) or set(obj) != set(keys.split()):
            raise fail("archive v3.1 closed whitelist")
    def prose(value):
        if not isinstance(value, str) or not value or v3.PRIVATE.search(value) or re.search(r"\d", value) or v3.NUMBER_WORDS.search(value) or legacy.scrub_text(value) != value or legacy.REDACTED in value:
            raise fail("archive v3.1 unsafe prose")
    def market(row, verdict=False):
        exact(row, "symbol_public timeframe" + (" verdict" if verdict else ""))
        if v3.market(row["symbol_public"]) != row["symbol_public"] or (row["timeframe"] != "multi" and not v3.TIMEFRAME.fullmatch(row["timeframe"])):
            raise fail("archive v3.1 market")
        if verdict and row["verdict"] not in ("PASS", "FAIL"):
            raise fail("archive v3.1 result")
    exact(archive, "schema_version $schema_id generated_at gate_contract_version disclosure total items")
    if archive["schema_version"] != "3.1" or archive["$schema_id"] != SCHEMA or archive["disclosure"] != DISCLOSURE or archive["gate_contract_version"] != "v4":
        raise fail("archive v3.1 root")
    if type(archive["total"]) is not int or archive["total"] != len(archive["items"]):
        raise fail("archive v3.1 population")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|\+00:00)", archive["generated_at"]):
        raise fail("archive v3.1 timestamp")
    seen, revisions = set(), set()
    for item in archive["items"]:
        exact(item, "public_id slug display_name tagline family review_status markets first_tested last_updated terminal_status evidence_scope gate_journey revision_history")
        pid = item["public_id"]
        if not ID_RE.fullmatch(pid) or pid in seen or item["slug"] != v3.name_slug(item["display_name"], pid):
            raise fail("archive v3.1 identity")
        seen.add(pid)
        for key in ("display_name", "tagline", "family"):
            prose(item[key])
        if item["review_status"] != REVIEW or item["evidence_scope"] != SCOPE or item["terminal_status"] not in ("research frontier", "optimization", "book candidate", "retired"):
            raise fail("archive v3.1 unverified publication or live status")
        for key in ("first_tested", "last_updated"):
            if item[key] is not None and v3.day(item[key]) != item[key]:
                raise fail("archive v3.1 date")
        for row in item["markets"]:
            market(row)
        for revision in item["revision_history"]:
            exact(revision, "public_id recorded_at")
            if not legacy._PUBLIC_ID_RE.fullmatch(revision["public_id"]) or revision["public_id"] in revisions:
                raise fail("archive v3.1 repeated revision")
            revisions.add(revision["public_id"])
            if revision["recorded_at"] is not None and v3.day(revision["recorded_at"]) != revision["recorded_at"]:
                raise fail("archive v3.1 revision date")
        if len(item["gate_journey"]) != len(PHASES):
            raise fail("archive v3.1 phases")
        for row, (phase, name, gates) in zip(item["gate_journey"], PHASES):
            exact(row, "phase name gates")
            if row["phase"] != phase or row["name"] != name:
                raise fail("archive v3.1 phase mapping")
            seen_gates = set()
            for g in row["gates"]:
                exact(g, "gate purpose outcome passed_symbols failed_symbols backtests")
                if g["gate"] not in gates or g["gate"] in seen_gates or g["purpose"] != legacy.PUBLIC_GATE_PURPOSES[g["gate"]]:
                    raise fail("archive v3.1 gate purpose")
                seen_gates.add(g["gate"])
                for b in g["backtests"]:
                    market(b, True)
                passed = sorted({b["symbol_public"] for b in g["backtests"] if b["verdict"] == "PASS"})
                failed = sorted({b["symbol_public"] for b in g["backtests"] if b["verdict"] == "FAIL"})
                outcome = "mixed" if passed and failed else "passed" if passed else "failed"
                if not g["backtests"] or g["passed_symbols"] != passed or g["failed_symbols"] != failed or g["outcome"] != outcome:
                    raise fail("archive v3.1 invented outcome")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--db", type=Path, default=legacy.DEFAULT_DB)
    ap.add_argument("--farm-root", type=Path, default=legacy.DEFAULT_FARM_ROOT)
    ap.add_argument("--repo-root", type=Path, default=legacy.REPO_ROOT)
    ap.add_argument("--out-dir", type=Path, required=True)
    ap.add_argument("--ledger", type=Path)
    args = ap.parse_args(argv)
    legacy._assert_staging_only(args.out_dir)
    previous = json.loads(args.ledger.read_text(encoding="utf-8")) if args.ledger and args.ledger.exists() else None
    archive, ledger, audit = build(args.db, args.farm_root, args.repo_root, previous_ledger=previous)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    for name, value in (("strategy-archive-v31.json", archive), ("strategy_names.v1.json", ledger), ("audit.json", audit)):
        (args.out_dir / name).write_text(json.dumps(value, indent=2, ensure_ascii=True) + "\n", encoding="utf-8")
    sample = sorted(archive["items"], key=lambda x: (-len(x["revision_history"]), x["public_id"]))[:10]
    for status in ("book candidate", "optimization", "retired", "research frontier"):
        candidates = [x for x in archive["items"] if x["terminal_status"] == status and x not in sample]
        sample.extend(candidates[:5])
    sample.extend(x for x in archive["items"] if x not in sample and len(sample) < 30)
    lines = ["# Archive v3.1 editorial sample", "", "All entries require OWNER/CEO naming review before publication.", "", "| Name | Tagline | Markets and timeframe | Status | Revision records |", "|---|---|---|---|---|"]
    for x in sample[:30]:
        markets = "; ".join(m["symbol_public"] + " / " + m["timeframe"] for m in x["markets"])
        lines.append(f'| {x["display_name"]} | {x["tagline"]} | {markets} | {x["terminal_status"]} | {len(x["revision_history"])} |')
    (args.out_dir / "sample_30.md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(json.dumps({"strategies": archive["total"], "revisions": sum(len(x["revision_history"]) for x in archive["items"]),
                      "status": dict(Counter(x["terminal_status"] for x in archive["items"])),
                      "naming": dict(Counter(x["naming_basis"] for x in audit)),
                      "unknown_markets_with_sets": sum(len(x["unknown_markets"]) for x in audit if x["set_files"]),
                      "unknown_markets_without_sets": sum(len(x["unknown_markets"]) for x in audit if not x["set_files"]),
                      "out_dir": str(args.out_dir)}, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
