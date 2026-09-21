"""Unit tests for the identity-equivalence proof tool.

These tests build *synthetic* MT5 HTML reports (UTF-16 and UTF-8, plain and
gz), tester.ini files and set files, then drive the pure comparison layer
(``gather_side_from_paths`` + ``build_proof`` + ``verify_proof``). No DB, no
production filesystem, no pipeline mutation.

Cases:
  * exact pair                       -> EQUIVALENT_EXACT
  * lot-normalised pair (-0.01 vol)  -> EQUIVALENT_LOT_NORMALISED
  * one differing entry time         -> NOT_EQUIVALENT
  * differing set-file parameter     -> NOT_EQUIVALENT
  * tampered report                  -> verify() detects it
"""
from __future__ import annotations

import gzip
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory

from tools.strategy_farm import identity_equivalence_proof as iep


# --------------------------------------------------------------------------- #
# Synthetic fixture builders                                                   #
# --------------------------------------------------------------------------- #
_HEADER = (
    '<tr align="center"><th colspan="13"><div><b>Deals</b></div></th></tr>\n'
    '<tr align="center" bgcolor="#E5F0FC">'
    '<td><b>Time</b></td><td><b>Deal</b></td><td><b>Symbol</b></td>'
    '<td><b>Type</b></td><td><b>Direction</b></td><td><b>Volume</b></td>'
    '<td><b>Price</b></td><td><b>Order</b></td><td><b>Commission</b></td>'
    '<td><b>Swap</b></td><td><b>Profit</b></td><td><b>Balance</b></td>'
    '<td><b>Comment</b></td></tr>\n'
)


def _row(cells):
    tds = "".join(f"<td>{c}</td>" for c in cells)
    return f'<tr bgcolor="#FFFFFF" align=right>{tds}</tr>\n'


def make_report(deals, deposit=100000.0):
    """deals: list of (time, symbol, type, direction, volume, price, profit).

    Returns full HTML string with an Orders stub and a Deals table. Balance is
    accumulated; the first row is the balance/deposit deal.
    """
    body = ["<html><body>",
            "<tr align=right><td>orders-stub</td></tr>",  # not a 13-cell row
            _HEADER]
    bal = deposit
    body.append(_row([_dt0(), 1, "", "balance", "", "", "", "", "0.00", "0.00",
                      "0.00", _fmt(bal), ""]))
    for i, (t, sym, typ, direction, vol, price, profit) in enumerate(deals, start=2):
        bal += profit
        body.append(_row([t, i, sym, typ, direction, vol, price, i,
                          "-2.00", "0.00", _fmt(profit), _fmt(bal), "QM_CMT"]))
    body.append("</body></html>")
    return "".join(body)


def _dt0():
    return "2018.07.02 00:00:00"


def _fmt(x):
    # MT5-style: space thousands separator, dot decimal.
    s = f"{x:,.2f}".replace(",", " ")
    return s


def _write(path: Path, text: str, encoding: str, gz: bool):
    if encoding == "utf-16":
        raw = text.encode("utf-16")  # adds BOM
    elif encoding == "utf-8-sig":
        raw = b"\xef\xbb\xbf" + text.encode("utf-8")
    else:
        raw = text.encode("utf-8")
    if gz:
        path = Path(str(path) + ".gz")
        path.write_bytes(gzip.compress(raw))
    else:
        path.write_bytes(raw)


_INI = (
    "[Tester]\nExpert=QM\\{expert}\nSymbol=EURUSD.DWX\nPeriod=H1\nModel=4\n"
    "FromDate=2018.07.02\nToDate=2022.12.31\nDeposit=100000\nCurrency=USD\n"
    "Report={report}\nExpertParameters={setname}\n"
)

_SET = (
    ";== QM5 Set File\n; ea_id: {eaid}\nqm_ea_id={eaid}\nRISK_FIXED=1000\n"
    "RISK_PERCENT=0\nstrategy_period={period}\nstrategy_threshold={thr}\n"
)


class _Case:
    """Builds a full original/rebuilt side pair inside a temp dir."""

    def __init__(self, tmp: Path, orig_deals, reb_deals, *,
                 orig_label="QM5_10000_alpha", reb_label="QM5_40000_alpha-symfix",
                 orig_enc="utf-16", reb_enc="utf-8-sig",
                 orig_gz=True, reb_gz=False, reb_thr="5"):
        self.tmp = tmp
        o = tmp / "orig"
        r = tmp / "reb"
        o.mkdir(exist_ok=True)
        r.mkdir(exist_ok=True)

        self.orig_report = o / "report.htm"
        self.reb_report = r / "report.htm"
        _write(self.orig_report, make_report(orig_deals), orig_enc, orig_gz)
        _write(self.reb_report, make_report(reb_deals), reb_enc, reb_gz)

        self.orig_ini = o / "tester.ini"
        self.reb_ini = r / "tester.ini"
        _write(self.orig_ini, _INI.format(expert=orig_label, report="o.htm",
                                          setname="o.set"), "utf-8", False)
        _write(self.reb_ini, _INI.format(expert=reb_label, report="r.htm",
                                         setname="r.set"), "utf-8", False)

        self.orig_set = o / "o.set"
        self.reb_set = r / "r.set"
        _write(self.orig_set, _SET.format(eaid="10000", period="20", thr="5"),
               "utf-8", False)
        _write(self.reb_set, _SET.format(eaid="40000", period="20", thr=reb_thr),
               "utf-8", False)

        self.orig_label = orig_label
        self.reb_label = reb_label

    def proof(self):
        o = iep.gather_side_from_paths(
            report_path=str(self.orig_report), tester_ini_path=str(self.orig_ini),
            setfile_path=str(self.orig_set), ea_label=self.orig_label)
        o["ea_id"] = self.orig_label
        o["symbol"] = "EURUSD.DWX"
        r = iep.gather_side_from_paths(
            report_path=str(self.reb_report), tester_ini_path=str(self.reb_ini),
            setfile_path=str(self.reb_set), ea_label=self.reb_label)
        r["ea_id"] = self.reb_label
        return iep.build_proof(o, r)


# base deal set (7-tuple rows)
_DEALS = [
    ("2018.07.04 20:00:00", "EURUSD.DWX", "buy", "in", "0.92", "1.17040", 0.0),
    ("2018.07.05 03:30:00", "EURUSD.DWX", "sell", "out", "0.92", "1.17250", 120.0),
    ("2018.07.09 20:00:00", "EURUSD.DWX", "sell", "in", "0.80", "1.17600", 0.0),
    ("2018.07.10 03:30:00", "EURUSD.DWX", "buy", "out", "0.80", "1.17400", 90.0),
]


def _scale(deals, dvol, pratio):
    out = []
    for (t, sym, typ, d, vol, price, profit) in deals:
        nv = round(float(vol) + dvol, 2)
        out.append((t, sym, typ, d, f"{nv}", price, round(profit * pratio, 2)))
    return out


class ExactPairTest(unittest.TestCase):
    def test_exact(self):
        with TemporaryDirectory() as td:
            c = _Case(Path(td), _DEALS, list(_DEALS))
            p = c.proof()
            self.assertEqual(p["verdict"], iep.VERDICT_EXACT, p["not_equivalent_reasons"])
            self.assertTrue(p["checks"]["deals"]["count_match"])
            self.assertEqual(p["checks"]["deals"]["field_mismatch_count"], 0)
            self.assertTrue(p["checks"]["deals"]["volume"]["exact"])


class LotNormalisedTest(unittest.TestCase):
    def test_lot_normalised(self):
        with TemporaryDirectory() as td:
            # every rebuilt volume one step (0.01) smaller; PnL scales with it.
            reb = _scale(_DEALS, -0.01, 0.99)
            c = _Case(Path(td), _DEALS, reb)
            p = c.proof()
            self.assertEqual(p["verdict"], iep.VERDICT_LOT,
                             p["not_equivalent_reasons"])
            vol = p["checks"]["deals"]["volume"]
            self.assertFalse(vol["exact"])
            self.assertTrue(vol["within_tolerance"])
            self.assertTrue(vol["sign_consistent"])
            self.assertLessEqual(vol["ratio_max"], 1.0 + 1e-9)


class DifferentTimeTest(unittest.TestCase):
    def test_entry_time_diff_is_not_equivalent(self):
        with TemporaryDirectory() as td:
            reb = list(_DEALS)
            t = list(reb[0])
            t[0] = "2018.07.04 21:00:00"  # different entry time
            reb[0] = tuple(t)
            c = _Case(Path(td), _DEALS, reb)
            p = c.proof()
            self.assertEqual(p["verdict"], iep.VERDICT_NOT)
            self.assertGreaterEqual(p["checks"]["deals"]["field_mismatch_count"], 1)


class DifferentSetfileTest(unittest.TestCase):
    def test_setfile_param_diff_is_not_equivalent(self):
        with TemporaryDirectory() as td:
            # exact deals, but rebuilt set file has a different strategy_threshold
            c = _Case(Path(td), _DEALS, list(_DEALS), reb_thr="7")
            p = c.proof()
            self.assertEqual(p["verdict"], iep.VERDICT_NOT)
            self.assertFalse(p["checks"]["setfile"]["match"])
            keys = [m["key"] for m in p["checks"]["setfile"]["mismatches"]]
            self.assertIn("strategy_threshold", keys)
            # qm_ea_id must be ignored, not flagged
            self.assertNotIn("qm_ea_id", keys)


class SetfileIdIgnoredTest(unittest.TestCase):
    def test_id_bearing_ignored(self):
        with TemporaryDirectory() as td:
            c = _Case(Path(td), _DEALS, list(_DEALS))
            p = c.proof()
            ignored = [m["key"] for m in p["checks"]["setfile"]["ignored_id_bearing"]]
            self.assertIn("qm_ea_id", ignored)


class SymbolTransportInputTest(unittest.TestCase):
    def test_new_matching_host_symbol_is_non_economic_transport_input(self):
        with TemporaryDirectory() as td:
            c = _Case(Path(td), _DEALS, list(_DEALS))
            with c.reb_set.open("a", encoding="utf-8") as handle:
                handle.write("strategy_host_symbol=EURUSD\n")
            p = c.proof()
            self.assertEqual(p["verdict"], iep.VERDICT_EXACT,
                             p["not_equivalent_reasons"])
            ignored = p["checks"]["setfile"]["ignored_transport_inputs"]
            self.assertEqual([row["key"] for row in ignored],
                             ["strategy_host_symbol"])
            self.assertEqual(ignored[0]["tested_symbol"], "EURUSD.DWX")

    def test_new_nonmatching_host_symbol_remains_disqualifying(self):
        with TemporaryDirectory() as td:
            c = _Case(Path(td), _DEALS, list(_DEALS))
            with c.reb_set.open("a", encoding="utf-8") as handle:
                handle.write("strategy_host_symbol=GBPUSD\n")
            p = c.proof()
            self.assertEqual(p["verdict"], iep.VERDICT_NOT)
            mismatches = p["checks"]["setfile"]["mismatches"]
            self.assertEqual([row["key"] for row in mismatches],
                             ["strategy_host_symbol"])


class VerifyTamperTest(unittest.TestCase):
    def test_verify_detects_tampered_report(self):
        with TemporaryDirectory() as td:
            tmp = Path(td)
            c = _Case(tmp, _DEALS, list(_DEALS))
            p = c.proof()
            out = tmp / "out"
            proof_path, sha_path, _ = iep.write_proof(p, str(out), "EURUSD.DWX")

            # unmodified proof verifies clean
            res_ok = iep.verify_proof(proof_path)
            self.assertTrue(res_ok["ok"], res_ok["failures"])

            # tamper the rebuilt report on disk, then re-verify
            side = json.loads(Path(proof_path).read_text(encoding="utf-8"))
            rp = side["inputs"]["rebuilt"]["report_path"]
            new_bytes = make_report(_scale(_DEALS, -0.01, 0.99)).encode("utf-8")
            if rp.endswith(".gz"):
                new_bytes = gzip.compress(new_bytes)
            Path(rp).write_bytes(new_bytes)
            res_bad = iep.verify_proof(proof_path)
            self.assertFalse(res_bad["ok"])
            self.assertTrue(any("report sha mismatch" in f for f in res_bad["failures"]))

    def test_verify_detects_tampered_proof_json(self):
        with TemporaryDirectory() as td:
            tmp = Path(td)
            c = _Case(tmp, _DEALS, list(_DEALS))
            p = c.proof()
            out = tmp / "out"
            proof_path, sha_path, _ = iep.write_proof(p, str(out), "EURUSD.DWX")
            # edit proof.json without updating the sidecar
            data = json.loads(Path(proof_path).read_text(encoding="utf-8"))
            data["verdict"] = "TAMPERED"
            Path(proof_path).write_text(json.dumps(data, indent=2), encoding="utf-8")
            res = iep.verify_proof(proof_path)
            self.assertFalse(res["ok"])
            self.assertTrue(any("proof.sha256 mismatch" in f for f in res["failures"]))


if __name__ == "__main__":
    unittest.main()
