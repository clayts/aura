#!/usr/bin/env python3
# Print Firefox's toolbar layout version (kVersion in CustomizableUI.sys.mjs)
# from its omni.ja. Firefox's jars put the central directory first, which
# zipfile rejects, so walk the local file headers instead
import re
import sys
import zlib
from pathlib import Path

with Path(sys.argv[1]).open("rb") as jar:
    data = jar.read()
i = 0
while (i := data.find(b"PK\x03\x04", i)) >= 0:
    method = int.from_bytes(data[i + 8 : i + 10], "little")
    size = int.from_bytes(data[i + 18 : i + 22], "little")
    name_len = int.from_bytes(data[i + 26 : i + 28], "little")
    extra_len = int.from_bytes(data[i + 28 : i + 30], "little")
    name = data[i + 30 : i + 30 + name_len]
    if name.endswith(b"/CustomizableUI.sys.mjs"):
        start = i + 30 + name_len + extra_len
        body = data[start : start + size]
        text = (zlib.decompress(body, -15) if method == 8 else body).decode()
        version = re.search(r"\bvar kVersion = (\d+);", text)
        if version is None:
            sys.exit("kVersion not found in CustomizableUI.sys.mjs")
        print(version[1], end="")
        sys.exit()
    i += 4
sys.exit("CustomizableUI.sys.mjs not found")
