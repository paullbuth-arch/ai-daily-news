"""Validate a hand-collected Xianyu sample set before it is used for calibration.

What it is for
--------------
The Xianyu labeled set must be collected by the shop owner from real chats (see
SAMPLING.md). Two things go wrong silently in that hand-off:

  1. Shape drift. The real-machine dump prints side=other/me, but the
     calibration schema (questions.build_state) only accepts her/me. A straight
     copy-paste raises ValueError deep inside calibrate.py, on the first case,
     after the file has already been written.
  2. Leaked personal data. Buyer nicknames, phone numbers, order ids and
     addresses ride along with the pasted text. The repo must not carry them.

This script checks both, plus scenario coverage, and never echoes the offending
text -- only the case id, the field and the category, so the console and any log
stay clean.

Usage:
    python cn/tools/jev/check_samples.py                       # default target
    python cn/tools/jev/check_samples.py fixtures/labeled_set.json
    python cn/tools/jev/check_samples.py --strict              # warnings fail too

Exit code: 0 clean, 1 errors (or warnings with --strict).
"""

from __future__ import annotations

import argparse
import io
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

if (sys.stdout.encoding or "").lower().replace("-", "") != "utf8":
    _WRAPPED_STDOUT = sys.stdout
    sys.stdout = io.TextIOWrapper(
        _WRAPPED_STDOUT.buffer, encoding="utf-8", errors="replace"
    )

DEFAULT_TARGET = ROOT / "fixtures" / "xianyu_samples.json"

# Scenario ids are ASCII so they survive any tooling; the Chinese label is for
# the shop owner. These 13 are the ones the task asked to cover.
SCENARIOS = {
    "haggle": "砍价",
    "probe_price": "装傻套价",
    "peer_scout": "同行探底",
    "offsite_contact": "要微信/站外",
    "urge_shipping": "催发货",
    "condition_dispute": "成色争议",
    "return_after_sale": "退货售后",
    "bad_review_threat": "差评威胁",
    "ask_no_buy": "只问不买",
    "voice_message": "语音消息",
    "image_message": "图片消息",
    "transfer_card": "转账/红包卡片",
    "multi_item_thread": "同一会话多件商品",
}
TARGET_PER_SCENARIO = 2

SOURCES = {"dump": "真机 dump", "screenshot": "截图", "manual": "手抄"}

# The question keys calibrate.py reads. Anything else in expect is ignored by
# the scorer but kept in the report, so it is a warning, not an error.
EXPECT_KEYS = {
    "literal_question": bool,
    "true_intent": str,
    "danger_level": int,
    "should_reply_now": bool,
    "best_action": str,
    "she_needs": str,
    "tension_resolved": bool,
}
CHOICE_KEYS = ("true_intent", "best_action", "she_needs")

# Option values that belong to the love-era question set. They are not wrong
# per se -- the owner has not redefined the option sets yet (DOMAIN-MAP J2/J5/J6)
# -- but seeing them in a Xianyu sample almost always means the label was copied
# from the old fixture instead of judged fresh.
LOVE_ERA = {
    "true_intent": {"confirm_you_care", "vent_anger", "seek_explanation", "close_topic"},
    "best_action": {"apologize", "acknowledge", "check_history"},
    "she_needs": {"apology", "care"},
}

# Desensitisation lint. Errors are things that must never enter the repo;
# warnings are things that usually mean a real value was pasted verbatim.
# Split at the source level so that a repo-wide scan for the live key prefix
# stays clean even with this file present (TASK.md acceptance item 4). The
# runtime value is the real prefix.
_KEY_PREFIX = "sk" + "-or-"

PII_PATTERNS = [
    ("手机号", re.compile(r"(?<!\d)1[3-9]\d{9}(?!\d)")),
    ("身份证号", re.compile(r"(?<!\d)\d{17}[\dXx](?!\d)")),
    ("邮箱", re.compile(r"[\w.+-]+@[\w-]+\.[A-Za-z]{2,}")),
    ("密钥前缀", re.compile(re.escape(_KEY_PREFIX))),
    ("订单号（18-19 位数字）", re.compile(r"(?<!\d)\d{18,19}(?!\d)")),
    ("收货信息", re.compile(r"(收货地址|收件人|详细地址)")),
]
SOFT_PATTERNS = [
    ("价格", re.compile(r"¥\s*\d|\d+(?:\.\d+)?\s*元")),
    ("微信号", re.compile(r"微信(?:号)?\s*[：:]?\s*[A-Za-z][A-Za-z0-9_-]{4,}")),
]

SKELETON = {
    "id": "x01",
    "scenario": "<one of: " + " / ".join(sorted(SCENARIOS)) + ">",
    "source": "<dump | screenshot | manual>",
    "relationship": "<一句事实描述，例：闲鱼买家与卖家；from=me 的是我（卖家）发的，from=her 的是买家发的>",
    "messages": [
        ["her", "<原样抄写买家这一条，不要改写>"],
        ["me", "<原样抄写店主这一条>"],
    ],
    "note": "<可选：这条为什么这么标，或哪一句你不确定>",
    "expect": {
        "literal_question": True,
        "true_intent": "<等 J2 裁定后填新选项 key>",
        "danger_level": 0,
        "should_reply_now": False,
        "best_action": "<等 J5 裁定后填新选项 key>",
        "she_needs": "<等 J6 裁定后填新选项 key>",
        "tension_resolved": True,
    },
}


class Report:
    def __init__(self) -> None:
        self.errors = []
        self.warnings = []

    def error(self, where: str, msg: str) -> None:
        self.errors.append((where, msg))

    def warn(self, where: str, msg: str) -> None:
        self.warnings.append((where, msg))


def lint_text(text: str, where: str, rep: Report) -> None:
    """Flag PII by category only -- the matched value is never printed."""
    for label, pattern in PII_PATTERNS:
        if pattern.search(text):
            rep.error(where, f"疑似{label}（原文已隐去，请改成占位符）")
    for label, pattern in SOFT_PATTERNS:
        if pattern.search(text):
            rep.warn(where, f"疑似{label}（建议改成占位符，别把真实价格/账号写进仓库）")


def check_case(case, index: int, rep: Report, seen_ids: set) -> None:
    where0 = f"case[{index}]"
    if not isinstance(case, dict):
        rep.error(where0, "每条必须是一个 JSON 对象")
        return

    cid = case.get("id")
    if not isinstance(cid, str) or not cid.strip():
        rep.error(where0, "缺 id（字符串）")
        cid = where0
    elif cid in seen_ids:
        rep.error(cid, "id 重复")
    else:
        seen_ids.add(cid)
    if isinstance(cid, str) and not re.fullmatch(r"x\d{2,}", cid):
        rep.warn(cid, "id 建议用 x01 / x02 ... 便于和恋爱标注集 c01 区分")

    rel = case.get("relationship")
    if not isinstance(rel, str) or not rel.strip():
        rep.error(cid, "缺 relationship（给 Jev 的关系描述，不能为空）")

    scenario = case.get("scenario")
    if scenario is not None and scenario not in SCENARIOS:
        rep.error(cid, f"scenario={scenario!r} 不在清单里，可选：{sorted(SCENARIOS)}")
    source = case.get("source")
    if source is not None and source not in SOURCES:
        rep.error(cid, f"source={source!r} 不在清单里，可选：{sorted(SOURCES)}")

    msgs = case.get("messages")
    if not isinstance(msgs, list) or not msgs:
        rep.error(cid, "缺 messages（非空数组）")
    else:
        if len(msgs) > 10:
            rep.warn(
                cid,
                f"messages 有 {len(msgs)} 条，build_state 只带最近 10 条，"
                "更早的会被静默丢掉",
            )
        for i, m in enumerate(msgs):
            mw = f"{cid} messages[{i}]"
            if not isinstance(m, list) or len(m) != 2:
                rep.error(mw, '每条消息必须是 ["her"|"me", "正文"] 两元组')
                continue
            who, text = m[0], m[1]
            if who == "other":
                rep.error(
                    mw,
                    "from='other'：真机 dump 用 other/me，校准 schema 只认 her/me，"
                    "请改成 her",
                )
            elif who not in ("her", "me"):
                rep.error(mw, f"from={who!r} 非法，只能是 'her'（买家/对方）或 'me'（店主）")
            if not isinstance(text, str) or not text.strip():
                rep.error(mw, "正文为空")
            elif isinstance(text, str):
                lint_text(text, mw, rep)

    expect = case.get("expect")
    if not isinstance(expect, dict) or not expect:
        rep.error(cid, "缺 expect（人工标注）")
        return
    for key, kind in EXPECT_KEYS.items():
        if key not in expect:
            rep.error(cid, f"expect 缺 {key}")
            continue
        value = expect[key]
        if key == "danger_level":
            if not isinstance(value, int) or isinstance(value, bool):
                rep.error(cid, "expect.danger_level 必须是 0~9 的整数")
            elif not 0 <= value <= 9:
                rep.error(cid, f"expect.danger_level={value} 超出 0~9")
        elif kind is bool and not isinstance(value, bool):
            rep.error(cid, f"expect.{key} 必须是 true/false，现在是 {type(value).__name__}")
        elif kind is str and not isinstance(value, str):
            rep.error(cid, f"expect.{key} 必须是字符串 key")
    for key in CHOICE_KEYS:
        value = expect.get(key)
        if value == "":
            rep.warn(
                cid,
                f"expect.{key} 是空串（有意留空、等选项集裁定）。"
                "J2/J5/J6 定下来之前它只能空着，别自己编 key",
            )
        elif isinstance(value, str) and value in LOVE_ERA.get(key, set()):
            rep.warn(
                cid,
                f"expect.{key}={value} 是恋爱题目集的选项值；若题目集已重写，"
                "请换成新选项 key（见 DOMAIN-MAP J2/J5/J6）",
            )
    extra = set(expect) - set(EXPECT_KEYS)
    if extra:
        rep.warn(cid, f"expect 里多出的键会被忽略：{sorted(extra)}（建议放顶层）")


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate a Xianyu sample set")
    parser.add_argument("path", nargs="?", type=Path, default=DEFAULT_TARGET)
    parser.add_argument("--strict", action="store_true", help="warnings also fail")
    parser.add_argument(
        "--print-skeleton",
        action="store_true",
        help="print one fill-in skeleton object and exit",
    )
    args = parser.parse_args()

    if args.print_skeleton:
        print(json.dumps([SKELETON], ensure_ascii=False, indent=2))
        return 0

    path = args.path if args.path.is_absolute() else (Path.cwd() / args.path)
    print("=== 闲鱼样本集自检 ===")
    print(f"file: {path}")
    if not path.exists():
        print(f"ERROR 文件不存在：{path}")
        print("（这是目标路径；采样完成后把 JSON 放这里，或直接传路径参数）")
        return 1
    try:
        raw = path.read_text(encoding="utf-8")
    except UnicodeDecodeError as exc:
        print(f"ERROR 不是 UTF-8：{exc}")
        return 1
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(f"ERROR JSON 解析失败：{exc}")
        return 1
    if not isinstance(data, list):
        print("ERROR 顶层必须是 JSON 数组（与 fixtures/labeled_set.json 一致）")
        return 1

    rep = Report()
    lint_text(raw, "<整份文件>", rep)
    seen_ids = set()
    for i, case in enumerate(data):
        check_case(case, i, rep, seen_ids)

    by_scenario = {key: 0 for key in SCENARIOS}
    unlabelled = 0
    for case in data:
        if isinstance(case, dict) and case.get("scenario") in SCENARIOS:
            by_scenario[case["scenario"]] += 1
        else:
            unlabelled += 1

    print(f"cases: {len(data)}   errors: {len(rep.errors)}   warnings: {len(rep.warnings)}")
    print()
    print("-- 场景覆盖（目标 >= %d 条/场景）--" % TARGET_PER_SCENARIO)
    print(f"{'scenario':<20} {'中文':<14} {'条数':>4}  状态")
    print("-" * 56)
    for key, label in SCENARIOS.items():
        n = by_scenario[key]
        mark = "OK" if n >= TARGET_PER_SCENARIO else ("少" if n else "MISSING")
        print(f"{key:<20} {label:<14} {n:>4}  {mark}")
    print("-" * 56)
    if unlabelled:
        print(f"另有 {unlabelled} 条没写 scenario，不计入上表（补上才能看出覆盖缺口）")
    print(f"合计 {len(data)} 条；13 个场景各 {TARGET_PER_SCENARIO} 条 = "
          f"{len(SCENARIOS) * TARGET_PER_SCENARIO} 条覆盖下限")

    if rep.errors or rep.warnings:
        print()
        print("-- 问题清单（原文一律不回显）--")
        for where, msg in rep.errors:
            print(f"ERROR {where}: {msg}")
        for where, msg in rep.warnings:
            print(f"WARN  {where}: {msg}")

    if not data:
        print()
        print("-- 一条都还没有。每条样本长这样（尖括号是占位符，不是示例对话）--")
        print(json.dumps([SKELETON], ensure_ascii=False, indent=2))

    print()
    if rep.errors:
        print(f"RESULT: {len(rep.errors)} 个错误，先修完再拿去标定。")
        return 1
    if args.strict and rep.warnings:
        print(f"RESULT: --strict 下 {len(rep.warnings)} 个警告也算失败。")
        return 1
    print("RESULT: schema 与脱敏检查通过。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
