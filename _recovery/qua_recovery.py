"""SRC05 batch recovery — reroute QUA-376..QUA-387 from Pipeline-Op to QB2 G0 review."""
import json, os, urllib.request, urllib.error, sys

API = os.environ["PAPERCLIP_API_URL"]
KEY = os.environ["PAPERCLIP_API_KEY"]
RUN = os.environ["PAPERCLIP_RUN_ID"]

QB2 = "0ab3d743-e3fb-44e5-8d35-c05d0d78715d"
CEO = "7795b4b0-8ecd-46da-ab22-06def7c8fa2d"
V5_STRAT = "b2adcc7f-064f-47c7-8563-d1c917639231"

POLICY_CLASS2 = {
    "mode": "normal",
    "commentRequired": True,
    "stages": [
        {
            "type": "review",
            "participants": [
                {"type": "agent", "agentId": QB2},
                {"type": "agent", "agentId": CEO},
                {"type": "user", "userId": "local-board"},
            ],
        }
    ],
}

HEADERS = {
    "Authorization": f"Bearer {KEY}",
    "Content-Type": "application/json",
    "X-Paperclip-Run-Id": RUN,
}

def req(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(API + path, data=data, headers=HEADERS, method=method)
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def patch_card(ident, comment_body):
    body = {
        "assigneeAgentId": QB2,
        "projectId": V5_STRAT,
        "executionPolicy": POLICY_CLASS2,
        "status": "in_review",
        "blockedByIssueIds": [],
        "comment": comment_body,
    }
    code, resp = req("PATCH", f"/api/issues/{ident}", body)
    print(f"PATCH {ident}: {code}")
    if code >= 400:
        print("  body:", resp[:600] if isinstance(resp, str) else json.dumps(resp)[:600])
    return code


with open("C:/QM/worktrees/ceo/_recovery/qua376_comment.md", encoding="utf-8") as f:
    long_comment = f.read()
patch_card("QUA-376", long_comment)

short = (
    "Recovery sweep — rerouted from Pipeline-Operator to [Quality-Business 2](/QUA/agents/quality-business-2) "
    "G0 review per [DL-030](/QUA/issues/DL-030) Class 2. See [QUA-376](/QUA/issues/QUA-376) for the rationale, "
    "[QUA-438](/QUA/issues/QUA-438) for the QB G0 backlog, [QUA-452](/QUA/issues/QUA-452) for the recovery thread. "
    "CEO authority [DL-017](/QUA/issues/DL-017) v2 (operational routing)."
)
for ident in ["QUA-377", "QUA-378", "QUA-379", "QUA-380", "QUA-381", "QUA-382", "QUA-383", "QUA-384", "QUA-385", "QUA-386", "QUA-387"]:
    patch_card(ident, short)
