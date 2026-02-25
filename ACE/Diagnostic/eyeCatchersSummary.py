#!/usr/bin/env python3
"""
eyeCatchersSummary.py

Python rewrite of eyeCatchersSummary.pl.

Behaviour:
- Reads eyecatchers file (one entry per line)
- Counts occurrences
- Writes "<eyecatcher> <count>" sorted by descending count
"""

from __future__ import annotations

import argparse
import os
from collections import Counter


def summarize(input_path: str, output_path: str) -> int:
    counts: Counter[str] = Counter()

    with open(input_path, "r", encoding="utf-8", errors="replace") as fin:
        for line in fin:
            line = line.rstrip("\r\n")
            if line:
                counts[line] += 1

    items = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)

    with open(output_path, "w", encoding="utf-8", newline="\n") as fout:
        for eyecatcher, cnt in items:
            fout.write(f"{eyecatcher} {cnt}\n")

    return len(items)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Summarize eyecatcher occurrences."
    )
    parser.add_argument(
        "--input-file",
        required=True,
        help="Path to eyecatchers text file",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Path to write summary output",
    )

    args = parser.parse_args()

    if not os.path.isfile(args.input_file):
        raise SystemExit(f"Input file not found: {args.input_file}")

    unique = summarize(
        input_path=args.input_file,
        output_path=args.output_file,
    )

    print(f"Done. Unique eyecatchers: {unique}. Output written to: {args.output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
