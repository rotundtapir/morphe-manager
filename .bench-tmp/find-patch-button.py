#!/usr/bin/env python3
"""Read a uiautomator XML dump on stdin, print 'X Y' for the exact "Patch" button.
Parsed per-node because grep -E has no non-greedy match: a regex spanning the
whole single-line XML silently returns another node's bounds, and "Patch source
used" would match a prefix test."""
import sys, re
xml = sys.stdin.read()
for node in re.findall(r'<node[^>]*?/?>', xml):
    t = re.search(r'text="([^"]*)"', node)
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
    if t and b and t.group(1) == "Patch":
        x1, y1, x2, y2 = map(int, b.groups())
        print((x1 + x2) // 2, (y1 + y2) // 2)
        sys.exit(0)
sys.exit(1)
