#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import unicodedata
from typing import Any, Dict, List, Tuple


STOPWORDS = {
    "a", "an", "and", "are", "as", "at", "be", "but", "by",
    "for", "from", "had", "has", "have", "he", "her", "him",
    "his", "i", "if", "in", "into", "is", "it", "its", "me",
    "no", "not", "of", "on", "or", "our", "she", "so", "that",
    "the", "their", "then", "there", "they", "this", "to", "up",
    "was", "we", "were", "what", "when", "where", "which", "who",
    "will", "with", "without", "would", "you", "your",
}

PIECE_WORDS = {
    "king", "queen", "rook", "bishop", "knight", "pawn",
    "kings", "queens", "rooks", "bishops", "knights", "pawns",
}

RE_LINE_FILES = re.compile(r"^[a-h]$", re.IGNORECASE)
RE_LINE_RANKS = re.compile(r"^[1-8]$")
RE_GARBAGE_TAIL = re.compile(r"[\s_]*([0-9]\s*){1,10}[_\s]*$", re.MULTILINE)
RE_TRAIL_JUNK = re.compile(r"[_\s]+$", re.MULTILINE)

# Detect obvious split-word artifacts
RE_SPLIT_WORD = re.compile(r"\b([A-Za-z]{2,})\s+([A-Za-z]{2,})\b")

# Detect "R ook", "K ing" patterns
RE_SPLIT_PIECE_WORD = re.compile(r"\b([KQRBNP])\s+([a-z]{2,})\b")

# Detect "imme diately" style splits (short left piece)
RE_SPLIT_SHORT_LEFT = re.compile(r"\b([a-z]{1,3})\s+([a-z]{3,})\b")

# Detect common PDF artifacts like nonbreaking spaces
RE_NBSP = re.compile(r"[\u00A0\u2007\u202F]")


def load_lessons(path: str) -> Tuple[List[Dict[str, Any]], Any]:
    with open(path, "r", encoding="utf-8") as f:
        obj = json.load(f)

    if isinstance(obj, list):
        return obj, obj
    if isinstance(obj, dict) and isinstance(obj.get("lessons"), list):
        return obj["lessons"], obj
    raise ValueError("Expected lessons JSON to be a list or { 'lessons': [...] }")


def save_lessons(path: str, lessons: List[Dict[str, Any]], original: Any) -> None:
    out_obj = original
    if isinstance(original, dict) and isinstance(original.get("lessons"), list):
        out_obj = dict(original)
        out_obj["lessons"] = lessons
    elif isinstance(original, list):
        out_obj = lessons

    with open(path, "w", encoding="utf-8") as f:
        json.dump(out_obj, f, indent=2, ensure_ascii=False)


def normalize_text(t: str) -> str:
    # Normalize unicode and whitespace
    t = unicodedata.normalize("NFKC", t)
    t = RE_NBSP.sub(" ", t)

    # Normalize line endings
    t = t.replace("\r\n", "\n").replace("\r", "\n")

    # Remove zero-width and odd control chars (but keep \n and \t)
    cleaned = []
    for ch in t:
        if ch in ("\n", "\t"):
            cleaned.append(ch)
            continue
        cat = unicodedata.category(ch)
        if cat.startswith("C"):
            continue
        cleaned.append(ch)
    return "".join(cleaned)


def remove_board_coordinate_lines(t: str) -> str:
    lines = t.split("\n")
    out_lines = []
    for line in lines:
        s = line.strip()
        if not s:
            out_lines.append("")
            continue
        if RE_LINE_FILES.match(s) or RE_LINE_RANKS.match(s):
            # drop lone coordinate markers
            continue
        out_lines.append(line)
    return "\n".join(out_lines)


def fix_hyphenation_and_wrapping(t: str) -> str:
    # Join hyphenated line breaks: "imme-\ndiately" -> "immediately"
    t = re.sub(r"(\w)-\n(\w)", r"\1\2", t)
    # Join mid-word hard wraps: "imme\ndi" -> "immedi" only if it looks like a split
    t = re.sub(r"([A-Za-z]{3,})\n([a-z]{2,})", r"\1\2", t)
    return t


def looks_like_real_word(w: str) -> bool:
    if not w:
        return False
    if w.lower() in STOPWORDS:
        return True
    # accept if it is letters only and length >= 3
    if re.fullmatch(r"[A-Za-z]{3,}", w):
        return True
    return False


def should_join(left: str, right: str, combined: str) -> bool:
    l = left.lower()
    r = right.lower()
    c = combined.lower()

    # If either is a stopword, usually do not join (keeps "the rook" intact)
    if l in STOPWORDS or r in STOPWORDS:
        return False

    # If combined forms a known chess piece word, join
    if c in PIECE_WORDS:
        return True

    # If both parts are very short, do not join
    if len(left) <= 2 and len(right) <= 2:
        return False

    # Common artifact: left is 1-3 letters, right is 3+ letters, combined 6+
    # Example: obv ious, imme diately, cert ainly
    if len(left) <= 3 and len(right) >= 3 and len(combined) >= 6:
        return True

    # If neither side looks like a real word but combined does, join
    left_ok = looks_like_real_word(left)
    right_ok = looks_like_real_word(right)
    combined_ok = looks_like_real_word(combined)

    if not left_ok and not right_ok and combined_ok:
        return True

    # If left is short and not a real word, and combined is long, join
    if len(left) <= 4 and not left_ok and len(combined) >= 7:
        return True

    return False


def join_split_words(t: str) -> str:
    # First fix "R ook" where right side becomes a piece word or general continuation
    def repl_piece(m: re.Match) -> str:
        return f"{m.group(1)}{m.group(2)}"

    t = RE_SPLIT_PIECE_WORD.sub(repl_piece, t)

    # Iteratively join split words using heuristics, a few passes
    for _ in range(4):
        changed = False

        def repl(m: re.Match) -> str:
            nonlocal changed
            left = m.group(1)
            right = m.group(2)
            combined = f"{left}{right}"
            if should_join(left, right, combined):
                changed = True
                return combined
            return m.group(0)

        new_t = RE_SPLIT_WORD.sub(repl, t)
        t = new_t
        if not changed:
            break

    # Also join the short-left cases that survive
    def repl_short(m: re.Match) -> str:
        left = m.group(1)
        right = m.group(2)
        combined = f"{left}{right}"
        if should_join(left, right, combined):
            return combined
        return m.group(0)

    t = RE_SPLIT_SHORT_LEFT.sub(repl_short, t)
    return t


def strip_trailing_garbage(t: str) -> str:
    # Remove repeated numeric/underscore junk at the end of the text
    t = RE_GARBAGE_TAIL.sub("", t)
    # Remove trailing underscores/spaces
    t = RE_TRAIL_JUNK.sub("", t)
    return t


def normalize_whitespace(t: str) -> str:
    # Replace multiple spaces (but keep newlines)
    t = re.sub(r"[ \t]{2,}", " ", t)
    # Trim each line
    lines = [ln.rstrip() for ln in t.split("\n")]
    # Collapse excessive blank lines
    out_lines: List[str] = []
    blank_run = 0
    for ln in lines:
        if ln.strip() == "":
            blank_run += 1
            if blank_run <= 2:
                out_lines.append("")
        else:
            blank_run = 0
            out_lines.append(ln)
    return "\n".join(out_lines).strip()


def clean_solution_text(t: str) -> str:
    t = normalize_text(t)
    t = remove_board_coordinate_lines(t)
    t = fix_hyphenation_and_wrapping(t)
    t = join_split_words(t)
    t = strip_trailing_garbage(t)
    t = normalize_whitespace(t)
    return t


def is_still_suspicious(t: str) -> List[str]:
    problems: List[str] = []

    if re.search(r"\b[a-h]\b", t) and re.search(r"\b[1-8]\b", t) and len(t) < 80:
        problems.append("possible leftover coordinates")

    if re.search(r"[_]{1,}", t):
        problems.append("contains underscore")

    if re.search(r"([0-9]\s*){6,}$", t.strip()):
        problems.append("ends with many digits")

    # Detect likely split word left: 2-3 letters then space then 2-3 letters inside a sentence
    if re.search(r"\b[a-z]{2,3}\s+[a-z]{2,3}\b", t.lower()):
        problems.append("possible remaining split-words")

    # Very short or empty
    if len(t.strip()) < 20:
        problems.append("very short solution text")

    return problems


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--in-json", required=True, help="Input endgame lessons JSON")
    ap.add_argument("--out-json", required=True, help="Output cleaned JSON")
    ap.add_argument("--report", required=True, help="Output report JSON")
    args = ap.parse_args()

    lessons, original = load_lessons(args.in_json)

    changed_count = 0
    suspicious: List[Dict[str, Any]] = []

    for lesson in lessons:
        raw = lesson.get("solutionText", "")
        if not isinstance(raw, str):
            continue

        cleaned = clean_solution_text(raw)
        if cleaned != raw:
            changed_count += 1
            lesson["solutionText"] = cleaned

        probs = is_still_suspicious(cleaned)
        if probs:
            suspicious.append(
                {
                    "id": lesson.get("id"),
                    "title": lesson.get("title"),
                    "problems": probs,
                }
            )

    save_lessons(args.out_json, lessons, original)

    report = {
        "input": os.path.abspath(args.in_json),
        "output": os.path.abspath(args.out_json),
        "totalLessons": len(lessons),
        "lessonsChanged": changed_count,
        "suspiciousCount": len(suspicious),
        "suspicious": suspicious,
    }

    with open(args.report, "w", encoding="utf-8") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)

    print(f"Wrote cleaned JSON: {args.out_json}")
    print(f"Wrote report JSON:  {args.report}")
    print(f"Changed lessons:    {changed_count} / {len(lessons)}")
    print(f"Suspicious lessons: {len(suspicious)} (see report)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
