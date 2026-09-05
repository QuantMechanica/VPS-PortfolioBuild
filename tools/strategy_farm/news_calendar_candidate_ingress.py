"""Hash-bound E1-A ingress. Copies verified bytes to a new refresh staging child."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import re

DECISION = "OWNER-DEC-CALENDAR-E1A-20260905"
SCHEMA = "qm.news-calendar-repair-e1a/v1"
GATES = ("6.1_anchor_shares", "6.2_coverage", "6.3_cross_file_identity", "6.4_nonusd_completeness",
         "6.5_tick_footprints", "6.6_no_row_loss", "6.7_detector_clean", "6.8_schema")


def strict_json(raw):
    def pairs(items):
        d={}
        for k,v in items:
            if k in d:raise ValueError("duplicate candidate JSON key: "+k)
            d[k]=v
        return d
    return json.loads(raw,object_pairs_hook=pairs)


def prepare(gate, directory: Path, expected_sha256: str, *, staging_dir=None, apply=False, policy=None):
    policy=gate._validated_policy(policy or gate._PRODUCTION_POLICY)
    source=gate._canonical_target(directory,label="verified candidate directory")
    if not re.fullmatch(r"[0-9a-f]{64}",expected_sha256):
        raise ValueError("candidate manifest SHA256 must be 64 lowercase hex characters")
    manifest_path=gate._canonical_target(source/"manifest.json",label="candidate manifest")
    raw_manifest=manifest_path.read_bytes()
    if hashlib.sha256(raw_manifest).hexdigest()!=expected_sha256:
        raise ValueError("candidate manifest SHA256 mismatch")
    manifest=strict_json(raw_manifest)
    if manifest.get('declared_inadmissible_ranges') or manifest.get('scoped_review_only'):
        raise ValueError('scoped calendar candidate has inadmissible ranges; full-scope publication refused')
    verification_path=gate._canonical_target(source/"verification.json",label="candidate verification")
    raw_verification=verification_path.read_bytes()
    if hashlib.sha256(raw_verification).hexdigest()!=manifest.get("verification_sha256"):
        raise ValueError("candidate verification SHA256 mismatch")
    verification=strict_json(raw_verification)
    checks=verification.get("gates")
    failed=[k for k in GATES if not isinstance(checks,dict) or not isinstance(checks.get(k),dict)
            or checks[k].get("pass") is not True]
    if failed:raise ValueError("candidate verification FAIL: "+", ".join(failed))
    if (set(checks)!=set(GATES) or manifest.get("schema")!=SCHEMA or verification.get("schema")!=SCHEMA
            or manifest.get("decision_id")!=DECISION or verification.get("decision_id")!=DECISION
            or manifest.get("publishable") is not True or verification.get("publishable") is not True
            or verification.get("status")!="PASS" or verification.get("exit_code")!=0
            or manifest.get("production_write") is not False):
        raise ValueError("candidate verification/authority envelope mismatch")
    entries=manifest.get("files")
    if not isinstance(entries,list) or len(entries)!=2 or {e.get("name") for e in entries}!=set(gate.CALENDAR_NAMES):
        raise ValueError("candidate manifest must bind the exact two canonical files")
    blobs={};bindings=[]
    for name in gate.CALENDAR_NAMES:
        path=gate._canonical_target(source/name,label="verified candidate file")
        entry=next(e for e in entries if e["name"]==name)
        raw=path.read_bytes();sha=hashlib.sha256(raw).hexdigest()
        parsed=gate._parse_calendar_file(path,name)
        if sha!=entry.get("sha256") or parsed.sha256!=sha or parsed.row_count!=entry.get("row_count"):
            raise ValueError("candidate file hash/row-count mismatch: "+name)
        blobs[name]=raw;bindings.append({"name":name,"sha256":sha,"size_bytes":len(raw)})
    if manifest_path.read_bytes()!=raw_manifest or verification_path.read_bytes()!=raw_verification:
        raise ValueError("candidate proof changed during validation")
    result={"schema":"qm.news-calendar-candidate-ingress/v1","decision_id":DECISION,
            "status":"VALIDATED","candidate_pair":str(source),"manifest_sha256":expected_sha256,
            "verification_sha256":hashlib.sha256(raw_verification).hexdigest(),"files":bindings,
            "production_write":False,"applied":False}
    if not apply:
        if staging_dir is not None:raise ValueError("staging destination requires --apply")
        return result
    if staging_dir is None:raise ValueError("candidate ingress --apply requires --staging-dir")
    target=gate._canonical_target(staging_dir,label="refresh staging directory")
    if target.parent!=policy.evidence_dir or not re.fullmatch(r"news-calendar-staging-[0-9a-f]{32}",target.name):
        raise ValueError("candidate ingress requires exact refresh staging root and child name")
    if target.exists():raise ValueError("candidate staging already exists; overwrite refused")
    target.mkdir()
    # Every output is create-only. Failed/partial staging is retained for audit;
    # without a success receipt it is never returned to the publication caller.
    for name,raw in {**blobs,"manifest.json":raw_manifest,"verification.json":raw_verification}.items():
        with (target/name).open("xb") as f:f.write(raw);f.flush()
        if (target/name).read_bytes()!=raw:raise ValueError("staged candidate byte verification failed")
    result.update(status="STAGED",applied=True,staging_dir=str(target))
    with (target/"candidate_ingress.json").open("x",encoding="utf-8") as f:json.dump(result,f,indent=2,sort_keys=True)
    return result
