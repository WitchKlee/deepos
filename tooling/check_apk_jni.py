#!/usr/bin/env python3
"""Verify DeepOS v2 (app.deepos) APK native libraries and compliance invariants."""
from __future__ import annotations

import sys
import zipfile

REQUIRED_LIBS = (
    "lib/arm64-v8a/libldlinux.so",
    "lib/arm64-v8a/libcc7zz.so",
    "lib/arm64-v8a/libccenosys.so",
    "lib/arm64-v8a/libccenosysrun.so",
    "lib/arm64-v8a/libccptyhost.so",
    "lib/arm64-v8a/libccexecshim.so",
    "lib/arm64-v8a/libccexecshimb.so",
    "lib/arm64-v8a/libccrun.so",
    "lib/arm64-v8a/libccnodump.so",
)

REQUIRED_ASSETS = (
    "assets/gateway/server.mjs",
    "assets/devkit-pin.json",
    "assets/claude-code/verified.json",
    "assets/claude-code/verified.json.sig",
)

FORBIDDEN_SUBSTRINGS = (
    "webrtc",
    "onnx",
    "sherpa",
    "proot",
    "tawcroot",
    "mlkit",
    "accessibility",
    "assets/phone/",
    "assets/speech/",
)


def verify_apk(path: str) -> None:
    with zipfile.ZipFile(path) as zf:
        names = set(zf.namelist())

    missing_libs = [lib for lib in REQUIRED_LIBS if lib not in names]
    if missing_libs:
        raise SystemExit(f"FAIL [{path}]: missing required native libraries: {missing_libs}")

    missing_assets = [asset for asset in REQUIRED_ASSETS if asset not in names]
    if missing_assets:
        raise SystemExit(f"FAIL [{path}]: missing required gateway assets: {missing_assets}")

    forbidden = sorted(
        n for n in names if any(tok in n.lower() for tok in FORBIDDEN_SUBSTRINGS)
    )
    if forbidden:
        raise SystemExit(f"FAIL [{path}]: forbidden artifacts present: {forbidden[:10]}")

    # Ensure Anthropic proprietary Claude Code ELF binary is never bundled inside the APK
    # (the tiny /system/bin/sh launcher script at assets/gateway/bin/claude is allowed).
    with zipfile.ZipFile(path) as zf:
        large_claude = [
            n for n in names
            if (n.endswith("/claude") or n == "claude")
            and (zf.getinfo(n).file_size > 1024 * 1024 or zf.read(n)[:4] == b"\x7fELF")
        ]
    if large_claude:
        raise SystemExit(f"FAIL [{path}]: proprietary claude binary must not be bundled: {large_claude}")

    arm64_libs = [n for n in names if n.startswith("lib/arm64-v8a/")]
    print(f"OK [{path}]: {len(arm64_libs)} arm64 native libs verified, 0 forbidden artifacts.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Usage: check_apk_jni.py <apk_path> [<apk_path> ...]")
    for apk in sys.argv[1:]:
        verify_apk(apk)
