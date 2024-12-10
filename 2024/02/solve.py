#!/usr/bin/env nix-shell
#! nix-shell -p python3 -i python3
import sys
from itertools import pairwise


def test_level(l):
    s = sorted(l)
    d = {abs(a - b) for a, b in pairwise(l)}
    return (l == s or l == s[::-1]) and (min(d) > 0 and max(d) < 4)


data = open("input").read().strip()
p1 = p2 = 0
for report in data.split("\n"):
    levels = [int(n) for n in report.split(" ")]
    did_pass = False;
    if test_level(levels):
        did_pass = True;
    else:
        for i in range(len(levels)):
            n = levels.pop(i)
            if test_level(levels):
                did_pass = True;
                break
            else:
                levels.insert(i, n)
    if did_pass:
        print("OK")
    else:
        print("ERR")
