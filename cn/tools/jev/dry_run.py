"""Offline smoke test for the Jev calibration scaffold. No API key, no network.

Why this file exists
--------------------
calibrate.py needs a live OPENROUTER_API_KEY. On a machine without one (and for
anyone reviewing the scaffold) there is otherwise no way to tell whether the
scaffold itself is wired up: does build_state() emit the shape calibrate.py
expects, does the scorer turn model answers into hit rates, does report/ get
created, does the gate exit code fire.

This script answers that with ZERO network calls:

  1. --mode mock:labels  drives the REAL calibrate.py end to end with a fake
     responder that echoes the human labels. A 100% hit rate and MAE 0.0 is the
     *expected* result here -- it proves the scorer is wired correctly, and
     says nothing about Jev. Anything else means the scaffold is broken.
  2. --mode mock:probe   drives it with a deliberately wrong responder, so the
     miss / diff / gate-failure paths get exercised too.
  3. --selftest          (on by default) checks the transport layer against a
     patched urlopen (200 / 429-then-200 / 401 / 422-with-token-in-body /
     timeout), plus the build_state and build_rank_question contracts.

NOTHING HERE IS A CALIBRATION RESULT. No request leaves the machine, no token is
spent, and every mock response is tagged "mock": true. Mock runs write to
report/dry_run/<mode>/ so they can never be confused with a real
report/calibration.json.

The API key is never required, never printed and never written to disk.

Run:
    python cn/tools/jev/dry_run.py                     # mock:labels, all cases
    python cn/tools/jev/dry_run.py --mode mock:probe   # deliberately wrong mock
    python cn/tools/jev/dry_run.py --selftest-only
"""

from __future__ import annotations

import argparse
import io
import json
import os
import socket
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

# Keep the pre-import stream alive. io.TextIOWrapper closes its underlying
# buffer when it is garbage collected, and importing calibrate replaces
# sys.stdout with a new wrapper -- if the old one were dropped we would close
# the process's real stdout.
_PRE_IMPORT_STDOUT = sys.stdout

import calibrate  # noqa: E402  (rewraps sys.stdout to UTF-8 at import time)
import jev_client  # noqa: E402
from questions import JUDGE_QUESTIONS, build_rank_question  # noqa: E402

if (sys.stdout.encoding or "").lower().replace("-", "") != "utf8":
    _WRAPPED_STDOUT = sys.stdout
    sys.stdout = io.TextIOWrapper(
        _WRAPPED_STDOUT.buffer, encoding="utf-8", errors="replace"
    )

NOUL_KEYS = calibrate.NOUL_KEYS
CHOICE_KEYS = calibrate.CHOICE_KEYS
SCORE_KEYS = calibrate.SCORE_KEYS
N_BINS = 10

PROBE_NOUL = 0.42
PROBE_SCORE = 4
PROBE_CHOICE = {
    "true_intent": "casual_chat",
    "best_action": "say_less",
    "she_needs": "nothing",
}

# A value that is not shaped like a real credential, so a repo-wide scan for
# the live key prefix stays clean even with this file present.
SELFTEST_TOKEN = "offline-self-test-token"

BANNER = "=" * 72


# --------------------------------------------------------------------------
# mock responder
# --------------------------------------------------------------------------


def validate_state(state: dict) -> None:
    """Assert the contract build_state() promises to calibrate.py."""
    assert isinstance(state, dict), "state must be a dict"
    chat = state.get("chat")
    assert isinstance(chat, dict), "state.chat must be a dict"
    rel = chat.get("relationship")
    assert isinstance(rel, str) and rel.strip(), "chat.relationship must be a non-empty string"
    msgs = chat.get("messages")
    assert isinstance(msgs, list) and msgs, "chat.messages must be a non-empty list"
    assert len(msgs) <= 10, f"chat.messages must keep at most 10 rows, got {len(msgs)}"
    for i, m in enumerate(msgs):
        assert isinstance(m, dict) and set(m) == {"from", "text"}, f"messages[{i}] keys"
        assert m["from"] in ("her", "me"), f"messages[{i}].from={m['from']!r}"
        assert isinstance(m["text"], str) and m["text"], f"messages[{i}].text"
    assert chat.get("latest_from") == msgs[-1]["from"], "chat.latest_from must match the last row"


def validate_questions(questions: dict) -> None:
    assert set(questions) == set(JUDGE_QUESTIONS), (
        "calibrate.py must send exactly the 7 judge questions, got " f"{sorted(questions)}"
    )


def _mock_noul(expect, mode: str) -> dict:
    if mode == "labels":
        return {"type": "noul", "noul": 0.97 if expect else 0.03}
    return {"type": "noul", "noul": PROBE_NOUL}


def _mock_choice(key: str, expect, mode: str) -> dict:
    if mode == "labels":
        value = str(expect)
        conf = 0.95
    else:
        value = PROBE_CHOICE[key]
        conf = 0.55
    return {
        "type": "choice",
        "choice": value,
        "confidence": conf,
        "probabilities": {value: conf},
    }


def _mock_score(expect, mode: str) -> dict:
    idx = int(expect) if mode == "labels" else PROBE_SCORE
    return {
        "type": "score",
        "score": idx,
        "confidence": 0.90,
        "probabilities": {str(idx): 1.0},
        "legend": {str(i): f"mock bin {i}" for i in range(N_BINS)},
    }


class MockResponder:
    """Stands in for jev_client.ask. Serial, deterministic, offline."""

    def __init__(self, mode: str, cases: list) -> None:
        # CLI spells the modes "mock:labels" / "mock:probe"; the answer
        # builders only care about the part after the colon.
        self.mode = mode.split(":")[-1]
        self.calls = 0
        self.by_state = {}
        for case in cases:
            state = calibrate.build_state(case["messages"], case["relationship"])
            self.by_state[self._key(state)] = case.get("expect") or {}

    @staticmethod
    def _key(state: dict) -> str:
        return json.dumps(state, sort_keys=True, ensure_ascii=False)

    def __call__(self, state: dict, questions: dict, timeout: float = 20) -> dict:
        self.calls += 1
        validate_state(state)
        validate_questions(questions)
        expect = self.by_state.get(self._key(state))
        if expect is None:
            raise AssertionError(
                "mock responder got a state that matches no case in the labeled set"
            )
        answers = {}
        for key in questions:
            if key in NOUL_KEYS:
                answers[key] = _mock_noul(expect.get(key), self.mode)
            elif key in CHOICE_KEYS:
                answers[key] = _mock_choice(key, expect.get(key), self.mode)
            elif key in SCORE_KEYS:
                answers[key] = _mock_score(expect.get(key), self.mode)
            else:
                raise AssertionError(f"unexpected question key {key!r}")
        return {
            "answers": answers,
            "usage": {"input_tokens": 0, "output_tokens": 0, "cost": 0.0},
            "provider": f"mock:{self.mode}",
            "mock": True,
        }


# --------------------------------------------------------------------------
# transport self-test (patched urlopen, still offline)
# --------------------------------------------------------------------------


class _FakeResponse:
    def __init__(self, payload: bytes, status: int = 200) -> None:
        self._payload = payload
        self.status = status

    def read(self) -> bytes:
        return self._payload

    def __enter__(self):
        return self

    def __exit__(self, *exc) -> bool:
        return False


def _http_error(code: int, body: bytes) -> urllib.error.HTTPError:
    return urllib.error.HTTPError(
        jev_client.API_URL, code, f"HTTP {code}", {}, io.BytesIO(body)
    )


class _ScriptedUrlopen:
    """Replays a fixed list of responses/exceptions for each urlopen() call."""

    def __init__(self, script: list) -> None:
        self.script = list(script)
        self.calls = 0

    def __call__(self, req, timeout=None):
        self.calls += 1
        if not self.script:
            raise AssertionError(f"urlopen called {self.calls} times, script exhausted")
        item = self.script.pop(0)
        if isinstance(item, BaseException):
            raise item
        return item


def _run_check(name: str, fn, failures: list) -> None:
    try:
        detail = fn()
    except AssertionError as exc:
        failures.append(name)
        print(f"  FAIL  {name}: {exc}")
    except Exception as exc:  # noqa: BLE001 - report anything unexpected
        failures.append(name)
        print(f"  FAIL  {name}: {type(exc).__name__}: {exc}")
    else:
        print(f"  ok    {name}" + (f"  -> {detail}" if detail else ""))


def selftest_transport() -> list:
    print("-- transport (jev_client.ask, urlopen patched, no network) --")
    failures = []
    saved_key = os.environ.get("OPENROUTER_API_KEY")
    saved_sleep = jev_client.time.sleep
    saved_urlopen = urllib.request.urlopen
    slept = []
    os.environ["OPENROUTER_API_KEY"] = SELFTEST_TOKEN
    jev_client.time.sleep = lambda s: slept.append(s)

    def ok_body():
        return json.dumps(
            {
                "answers": {"true_intent": {"type": "choice", "choice": "casual_chat"}},
                "usage": {"input_tokens": 1, "output_tokens": 1, "cost": 0.0},
            },
            ensure_ascii=False,
        ).encode("utf-8")

    def check_200():
        scripted = _ScriptedUrlopen([_FakeResponse(ok_body())])
        urllib.request.urlopen = scripted
        out = jev_client.ask({"chat": {}}, {}, timeout=20)
        assert out["answers"]["true_intent"]["choice"] == "casual_chat"
        assert scripted.calls == 1
        return "1 call, no retry"

    def check_429_then_200():
        slept.clear()
        scripted = _ScriptedUrlopen(
            [_http_error(429, b'{"error":"rate limited"}'), _FakeResponse(ok_body())]
        )
        urllib.request.urlopen = scripted
        out = jev_client.ask({"chat": {}}, {}, timeout=20)
        assert "answers" in out, "retry did not recover"
        assert scripted.calls == 2, f"expected 2 calls, got {scripted.calls}"
        assert slept == [1], f"expected backoff [1], got {slept}"
        return "429 -> backoff 1s -> 200"

    def check_401():
        urllib.request.urlopen = _ScriptedUrlopen(
            [_http_error(401, b'{"error":"invalid api key"}')]
        )
        try:
            jev_client.ask({"chat": {}}, {}, timeout=20)
        except jev_client.JevError as exc:
            assert exc.status == 401, f"status={exc.status}"
            assert "API key rejected" in str(exc), str(exc)
            assert SELFTEST_TOKEN not in str(exc), "token leaked into the error text"
            return "readable 401, no token in message"
        raise AssertionError("401 did not raise JevError")

    def check_422_redacts():
        body = ('{"error":"bad body for key ' + SELFTEST_TOKEN + '"}').encode("utf-8")
        urllib.request.urlopen = _ScriptedUrlopen([_http_error(422, body)])
        try:
            jev_client.ask({"chat": {}}, {}, timeout=20)
        except jev_client.JevError as exc:
            assert exc.status == 422, f"status={exc.status}"
            assert SELFTEST_TOKEN not in str(exc), "token leaked through _error_body"
            assert "[REDACTED]" in str(exc), str(exc)
            return "422 body redacted"
        raise AssertionError("422 did not raise JevError")

    def check_timeout():
        slept.clear()
        urllib.request.urlopen = _ScriptedUrlopen([socket.timeout("boom")] * 4)
        try:
            jev_client.ask({"chat": {}}, {}, timeout=20)
        except jev_client.JevError as exc:
            assert "timed out" in str(exc), str(exc)
            assert slept == [1, 2, 4], f"expected backoff [1, 2, 4], got {slept}"
            return "4 attempts, backoff 1/2/4s"
        raise AssertionError("timeout did not raise JevError")

    def check_missing_key():
        os.environ.pop("OPENROUTER_API_KEY", None)
        try:
            jev_client.ask({"chat": {}}, {}, timeout=20)
        except jev_client.JevError as exc:
            assert "OPENROUTER_API_KEY is not set" in str(exc), str(exc)
            return "readable 'no key' error"
        finally:
            os.environ["OPENROUTER_API_KEY"] = SELFTEST_TOKEN
        raise AssertionError("missing key did not raise JevError")

    def check_redact_helper():
        text = jev_client.redact_secrets(f"before {SELFTEST_TOKEN} after")
        assert SELFTEST_TOKEN not in text, text
        assert "[REDACTED]" in text, text
        return "redact_secrets strips the live env value"

    try:
        for name, fn in [
            ("HTTP 200 returns parsed JSON", check_200),
            ("HTTP 429 then 200 retries once", check_429_then_200),
            ("HTTP 401 gives a readable error", check_401),
            ("HTTP 422 redacts the key from the body", check_422_redacts),
            ("timeout retries then fails readably", check_timeout),
            ("missing key fails before any request", check_missing_key),
            ("redact_secrets", check_redact_helper),
        ]:
            _run_check(name, fn, failures)
    finally:
        jev_client.time.sleep = saved_sleep
        urllib.request.urlopen = saved_urlopen
        if saved_key is None:
            os.environ.pop("OPENROUTER_API_KEY", None)
        else:
            os.environ["OPENROUTER_API_KEY"] = saved_key
    return failures


# --------------------------------------------------------------------------
# schema self-test (build_state / build_rank_question / labeled set coverage)
# --------------------------------------------------------------------------


def selftest_schema() -> list:
    print("-- schema (build_state / build_rank_question / fixture coverage) --")
    failures = []

    def check_state_ok():
        state = calibrate.build_state([["her", "在吗"], ["me", "在的"]], "闲鱼买家与卖家")
        assert state["chat"]["latest_from"] == "me"
        assert len(state["chat"]["messages"]) == 2
        return "shape ok"

    def check_state_keeps_last_10():
        msgs = [["her" if i % 2 == 0 else "me", f"m{i}"] for i in range(14)]
        state = calibrate.build_state(msgs, "x")
        got = [m["text"] for m in state["chat"]["messages"]]
        assert got == [f"m{i}" for i in range(4, 14)], got
        return "14 in -> last 10 kept"

    def check_state_rejects_other():
        # The real-machine dump (writeXianyuDiag) prints side=other/me, while
        # build_state only accepts her/me. Prove the mismatch is a hard error.
        try:
            calibrate.build_state([["other", "这个能操作吗"]], "x")
        except ValueError as exc:
            return f"rejects side=other ({exc})"
        raise AssertionError("build_state accepted from='other'")

    def check_rank_question():
        cands = ["哈哈好好好", "对不起", "我去翻一下记录"]
        q = build_rank_question(cands)
        assert set(q) == {"best_reply"}, sorted(q)
        crit = q["best_reply"]["criteria"]
        assert list(crit) == ["reply_a", "reply_b", "reply_c"], list(crit)
        assert crit["reply_c"] == cands[2], "Chinese candidate text must survive verbatim"
        try:
            build_rank_question(["a", "b"])
        except ValueError:
            return "3 candidates required, Chinese kept verbatim"
        raise AssertionError("build_rank_question accepted 2 candidates")

    def check_fixture_coverage():
        cases = calibrate.load_cases(None)
        assert isinstance(cases, list) and cases, "labeled_set.json is empty"
        expected = set(JUDGE_QUESTIONS)
        for case in cases:
            missing = expected - set(case.get("expect") or {})
            assert not missing, f"{case.get('id')} missing expect keys {sorted(missing)}"
        ids = [c["id"] for c in cases]
        assert len(ids) == len(set(ids)), "duplicate ids in labeled_set.json"
        limit = calibrate.load_cases(3)
        assert len(limit) == 3, "--limit must truncate"
        return f"{len(cases)} cases, all 7 expect keys present, ids unique"

    for name, fn in [
        ("build_state happy path", check_state_ok),
        ("build_state keeps the last 10 messages", check_state_keeps_last_10),
        ("build_state rejects side='other' (dump token)", check_state_rejects_other),
        ("build_rank_question contract", check_rank_question),
        ("fixtures/labeled_set.json coverage", check_fixture_coverage),
    ]:
        _run_check(name, fn, failures)
    return failures


# --------------------------------------------------------------------------
# mock calibration run
# --------------------------------------------------------------------------


def run_mock_calibration(mode: str, limit, out_dir: Path):
    cases = calibrate.load_cases(limit)
    responder = MockResponder(mode, cases)
    saved_ask = calibrate.ask
    saved_dir = calibrate.REPORT_DIR
    saved_argv = sys.argv
    calibrate.ask = responder  # calibrate.py bound the name at import time
    calibrate.REPORT_DIR = out_dir
    print()
    print(BANNER)
    print(" MOCK CALIBRATION RUN -- NOT A CALIBRATION RESULT")
    print(f" mode={mode}  cases={len(cases)}  limit={limit}")
    print(" no HTTP request was made; every answer is synthetic")
    print(f" out={out_dir}")
    print(BANNER)
    try:
        sys.argv = ["calibrate.py"] + (["--limit", str(limit)] if limit else [])
        code = calibrate.main()
    finally:
        calibrate.ask = saved_ask
        calibrate.REPORT_DIR = saved_dir
        sys.argv = saved_argv
    return code, cases


# --------------------------------------------------------------------------
# main
# --------------------------------------------------------------------------


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Offline smoke test for the Jev calibration scaffold (no API key)"
    )
    parser.add_argument(
        "--mode",
        choices=["mock:labels", "mock:probe", "none"],
        default="mock:labels",
        help="mock:labels echoes the human labels (expect 100%% hit); "
        "mock:probe answers wrong on purpose; none skips the mock run",
    )
    parser.add_argument("--limit", type=int, default=None, help="only run the first N cases")
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=None,
        help="where the mock writes calibration.json/.md (default report/dry_run/<mode>)",
    )
    parser.add_argument("--selftest-only", action="store_true", help="skip the mock run")
    args = parser.parse_args()

    mode_slug = args.mode.replace(":", "_")
    out_dir = args.out_dir or (calibrate.ROOT / "report" / "dry_run" / mode_slug)

    print(BANNER)
    print(" Jev calibration scaffold -- OFFLINE DRY RUN")
    print(f" python={sys.version.split()[0]}  root={ROOT}")
    print(" No API key required. No network call is made. Nothing here is a")
    print(" calibration result -- see report/dry_run/ for the mock artifacts.")
    print(BANNER)

    failures = selftest_schema() + selftest_transport()

    inner_code = None
    if not args.selftest_only and args.mode != "none":
        inner_code, _cases = run_mock_calibration(args.mode, args.limit, out_dir)
        print()
        print(f" mock calibration inner exit code: {inner_code}")
        if args.mode == "mock:probe":
            print("   (2 = metric gate not met, which is EXPECTED for mock:probe:")
            print("    a deliberately wrong responder must fail the gate.)")
        elif inner_code != 0:
            print("   (expected 0 for mock:labels -- the scorer or the fixture moved.)")

    print()
    print(BANNER)
    if failures:
        print(f" RESULT: {len(failures)} self-test failure(s): {failures}")
        print(BANNER)
        return 1
    print(" RESULT: all self-tests passed.")
    print(" Reminder: this proves the scaffold is wired up. It says NOTHING about")
    print(" Jev accuracy. Run calibrate.py with OPENROUTER_API_KEY for that.")
    print(BANNER)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
