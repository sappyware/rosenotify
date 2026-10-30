#!/bin/sh
set -eu
BACKUP_DIR=".backup-real-fix"
mkdir -p "$BACKUP_DIR"
[ -f "$BACKUP_DIR/Card.qml" ] || cp Card.qml "$BACKUP_DIR/Card.qml"
[ -f "$BACKUP_DIR/shell.qml" ] || cp shell.qml "$BACKUP_DIR/shell.qml"

python3 - <<'PY'
import re, pathlib, sys

p = pathlib.Path("Card.qml")
src = p.read_text()
orig = src

# 1. Remove my earlier bad 'anchors.fill: parent' on the outer card Item, if present.
m = re.search(r'\bid:\s*card\b', src)
if m:
    start = m.end()
    rect = src.find('Rectangle', start)
    if rect < 0: rect = start + 3000
    chunk = src[start:rect]
    if re.search(r'\banchors\.fill:\s*parent\b', chunk):
        src = src[:start] + re.sub(r'[ \t]*anchors\.fill:\s*parent[ \t]*\n', '', chunk) + src[rect:]
        print("Card.qml: removed stray 'anchors.fill: parent' from outer card Item")

# 2. Break the delegate-height feedback loop.
patterns = [
    re.compile(r'    height: active\s*\n'
               r'        \? Math\.min\(card\.height \+ Config\.spacing, root\.ListView\.view \? root\.ListView\.view\.height : Infinity\) \* collapse\s*\n'
               r'        : 0\s*\n'),
    re.compile(r'    height: active\s*\n'
               r'        \? Math\.min\(card\.height \+ Config\.spacing, ListView\.view \? ListView\.view\.height : Infinity\) \* collapse\s*\n'
               r'        : 0\s*\n'),
]
new = '    height: active ? (card.height + Config.spacing) * collapse : 0\n'

fixed = False
for pat in patterns:
    if pat.search(src):
        src = pat.sub(new, src, count=1)
        print("Card.qml: broke delegate-height feedback loop")
        fixed = True
        break

if not fixed:
    if new in src:
        print("Card.qml: already fixed")
        fixed = True
    else:
        print("ERROR: could not locate delegate height binding. Current 'height:' lines:", file=sys.stderr)
        for m in re.finditer(r'.*height:.*', src):
            print("  " + m.group(0), file=sys.stderr)
        sys.exit(1)

if src != orig:
    p.write_text(src)

# 3. Normalize mask back to 'item: list' (it works once list has real height).
sp = pathlib.Path("shell.qml")
s = sp.read_text()
before = s
s = s.replace('item: list.contentItem', 'item: list')
if s != before:
    sp.write_text(s)
    print("shell.qml: mask reverted to 'item: list'")
else:
    print("shell.qml: mask unchanged")
PY

echo
echo "Done. Backup in $BACKUP_DIR"
echo "Reload rosenotify."