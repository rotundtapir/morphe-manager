#!/usr/bin/env python3
"""find-node.py <exact-text> : read uiautomator XML on stdin, print 'X Y' centre.
Per-node parse: grep -E has no non-greedy match, so a regex over the single-line
XML returns another node's bounds; exact text match avoids prefix collisions
like "Patch" vs "Patch source used"."""
import sys, re
want = sys.argv[1]
xml = sys.stdin.read()
for node in re.findall(r'<node[^>]*?/?>', xml):
    t = re.search(r'text="([^"]*)"', node)
    b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', node)
    if t and b and t.group(1) == want:
        x1, y1, x2, y2 = map(int, b.groups())
        print((x1 + x2) // 2, (y1 + y2) // 2); sys.exit(0)
sys.exit(1)
