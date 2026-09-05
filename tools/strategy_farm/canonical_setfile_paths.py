"""Canonical enqueue-path validation and read-only pending-successor proposals."""
from __future__ import annotations
from pathlib import Path
import argparse
import hashlib
import json
import sqlite3
import uuid

CANONICAL_REPO=Path('C:/QM/repo')
DATABASE=Path('D:/QM/strategy_farm/state/farm_state.sqlite')


def validate_enqueue_setfile(path: str | Path, repo_root: Path = CANONICAL_REPO) -> Path:
    """Refuse, rather than silently rewrite, foreign or escaped paths."""
    supplied=Path(path)
    if not supplied.is_absolute():raise ValueError('SETFILE_PATH_NOT_ABSOLUTE')
    root=repo_root.resolve(strict=True)/'framework/EAs'
    resolved=supplied.resolve(strict=True)
    try:relative=resolved.relative_to(root)
    except ValueError as exc:raise ValueError('SETFILE_PATH_NOT_CANONICAL') from exc
    if len(relative.parts)!=3 or relative.parts[1].casefold()!='sets' or resolved.suffix.casefold()!='.set':
        raise ValueError('SETFILE_PATH_NOT_CANONICAL_EA_SET')
    if not resolved.is_file():raise ValueError('SETFILE_PATH_NOT_FILE')
    return resolved


def digest(path: Path):
    return hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else None


def pending_successor_proposal(row: dict, repo_root: Path = CANONICAL_REPO) -> dict:
    """No authority, enqueue, or supersession is created by this function."""
    old=Path(row['setfile_path']);ea_dir=old.parent.parent.name
    if old.parent.name.casefold()!='sets' or not ea_dir.startswith(str(row['ea_id'])+'_'):
        raise ValueError('SOURCE_PATH_EA_IDENTITY_MISMATCH')
    canonical=repo_root/'framework/EAs'/ea_dir/'sets'/old.name
    ex5=canonical.parent.parent/(ea_dir+'.ex5')
    raw_payload=row.get('payload_json') or '{}'
    blockers=[]
    if row['status']!='pending' or row.get('claimed_by') is not None:blockers.append('PREDECESSOR_NOT_UNCLAIMED_PENDING')
    try:validate_enqueue_setfile(canonical,repo_root)
    except (ValueError,OSError) as exc:blockers.append(str(exc))
    if not ex5.is_file():blockers.append('CANONICAL_EX5_MISSING')
    old_sha=digest(old);canonical_sha=digest(canonical)
    if old_sha is None:blockers.append('ORIGINAL_SETFILE_UNAVAILABLE_EQUIVALENCE_UNPROVEN')
    elif old_sha!=canonical_sha:blockers.append('SETFILE_BYTES_DIFFER_SOURCE_REVIEW_REQUIRED')
    identity=f"{row['id']}|{canonical.as_posix()}|{canonical_sha}|{digest(ex5)}"
    return {'schema':'qm.pending-canonical-path-proposal/v1','dry_run':True,'apply_supported':False,
            'source_work_item_id':row['id'],'source_row_sha256':hashlib.sha256(json.dumps(row,sort_keys=True).encode()).hexdigest(),
            'source_payload_sha256':hashlib.sha256(raw_payload.encode()).hexdigest(),
            'ea_id':row['ea_id'],'phase':row['phase'],'symbol':row['symbol'],
            'old_setfile_path':str(old),'old_setfile_sha256':old_sha,
            'canonical_setfile_path':str(canonical),'canonical_setfile_sha256':canonical_sha,
            'canonical_ex5_path':str(ex5),'canonical_ex5_sha256':digest(ex5),
            'proposed_successor_id':str(uuid.uuid5(uuid.NAMESPACE_URL,identity)),
            'blockers':blockers,'authority_status':'PROPOSED_NOT_APPROVED',
            'required_apply_contract':[
                'OWNER-approved path-repair authority bound to this exact predecessor and both artifact hashes',
                'Factory mutation lock plus fresh OFF check and one BEGIN IMMEDIATE transaction',
                'Revalidate predecessor status, claimed_by and exact row/payload digest; no active predecessor',
                'Validate current canonical build, fixed-risk setfile and original phase/parent lineage',
                'Refuse any existing successor or competing pending/active canonical pair',
                'Append one canonical successor and one work_item_supersedes record atomically; preserve predecessor bytes/verdict',
                'Retain non-path holds; never bypass existing approval, registry or phase gates']}


def main(argv=None):
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['preview','apply'])
    selector=parser.add_mutually_exclusive_group(required=True)
    selector.add_argument('--work-item-id')
    selector.add_argument('--all-previewed',action='store_true')
    parser.add_argument('--apply',action='store_true',help='Explicit mutation flag; apply command otherwise only plans')
    parser.add_argument('--receipt-path',type=Path)
    args=parser.parse_args(argv)
    if args.command=='apply':
        try:
            from . import canonical_setfile_apply as repair
        except ImportError:
            import canonical_setfile_apply as repair
        if args.apply and Path(__file__).resolve().parents[2]!=CANONICAL_REPO.resolve():
            parser.error('Mutation requires the canonical checkout after reviewed integration')
        ids=sorted(repair.PREVIEW_HASHES) if args.all_previewed else [args.work_item_id]
        result=repair.run(ids,apply=args.apply,receipt_path=args.receipt_path)
        print(json.dumps(result,indent=2))
        return 0 if result['eligible'] else 2
    if args.all_previewed or args.apply or args.receipt_path:
        parser.error('preview accepts only --work-item-id')
    with sqlite3.connect('file:'+DATABASE.as_posix()+'?mode=ro',uri=True) as conn:
        conn.row_factory=sqlite3.Row;conn.execute('PRAGMA query_only=ON')
        row=conn.execute('SELECT * FROM work_items WHERE id=?',(args.work_item_id,)).fetchone()
        if row is None:raise SystemExit('source work item missing')
        print(json.dumps(pending_successor_proposal(dict(row)),indent=2))


if __name__=='__main__':raise SystemExit(main())
