#!/usr/bin/env python3
"""
eyeCatchers.py

Python rewrite of eyeCatchers.pl (IBM ACE diagnostic eyecatchers).

Behaviour:
- Reads the input as binary
- Splits on NUL bytes (0x00), like Perl: $/ = "\0"
- Extracts sequences of printable ASCII (0x20–0x7E) plus whitespace, length >= 4
- Writes the FULL matched sequence if it contains:
    >BIPdddd  or  >BIPwwww
"""

from __future__ import annotations

import argparse
import os
import re
from typing import BinaryIO, Iterable

PRINTABLE_SEQ_RE = re.compile(rb"[\x20-\x7E\s]{4,}")
BIP_IN_SEQ_RE = re.compile(rb">BIP(?:\d{4}|\w{4})")


def iter_null_separated_records(stream: BinaryIO, chunk_size: int) -> Iterable[bytes]:
    buf = b""
    while True:
        chunk = stream.read(chunk_size)
        if not chunk:
            if buf:
                yield buf
            break

        buf += chunk
        parts = buf.split(b"\x00")
        for rec in parts[:-1]:
            yield rec
        buf = parts[-1]


def extract_eyecatchers(input_path: str, output_path: str, chunk_size: int) -> int:
    written = 0

    with open(input_path, "rb") as fin, open(output_path, "w", encoding="utf-8", newline="\n") as fout:
        for rec in iter_null_separated_records(fin, chunk_size):
            for match in PRINTABLE_SEQ_RE.finditer(rec):
                seq = match.group(0)
                if BIP_IN_SEQ_RE.search(seq):
                    fout.write(seq.decode("ascii", errors="replace"))
                    fout.write("\n")
                    written += 1

    return written


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract ACE/MQ BIP eyecatchers from a binary dump file."
    )
    parser.add_argument(
        "--input-file",
        required=True,
        help="Path to the binary dump file",
    )
    parser.add_argument(
        "--output-file",
        required=True,
        help="Path to write extracted eyecatcher lines",
    )
    parser.add_argument(
        "--chunk-size",
        type=int,
        default=8 * 1024 * 1024,
        help="Read chunk size in bytes (default: 8MB)",
    )

    args = parser.parse_args()

    if not os.path.isfile(args.input_file):
        raise SystemExit(f"Input file not found: {args.input_file}")

    count = extract_eyecatchers(
        input_path=args.input_file,
        output_path=args.output_file,
        chunk_size=args.chunk_size,
    )

    print(f"Done. Wrote {count} eyecatcher line(s) to: {args.output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
