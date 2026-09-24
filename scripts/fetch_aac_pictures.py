#!/usr/bin/env python3
"""Fetch the AAC card pictures from Google's Noto Color Emoji (Apache 2.0).

Reads the card list (id + emoji) from lib/core/content.dart, downloads the
512 px PNG for each emoji from github.com/googlefonts/noto-emoji, and saves a
256 px copy to assets/aac/<id>.png. Originals are cached in art/noto/ so
reruns work offline.
"""
import pathlib
import re
import urllib.request

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
CONTENT = ROOT / "lib" / "core" / "content.dart"
CACHE = ROOT / "art" / "noto"
OUT = ROOT / "assets" / "aac"
URL = "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/2D/png/512/emoji_u{}.png"


def noto_name(emoji: str) -> str:
    # Noto file names drop the emoji variation selector (U+FE0F).
    return "_".join(f"{ord(ch):04x}" for ch in emoji if ord(ch) != 0xFE0F)


def main():
    cards = re.findall(r"AacCard\('([a-z_]+)', '[^']+', '([^']+)'", CONTENT.read_text(encoding="utf-8"))
    CACHE.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    for card_id, emoji in cards:
        name = noto_name(emoji)
        src = CACHE / f"emoji_u{name}.png"
        if not src.exists():
            with urllib.request.urlopen(URL.format(name), timeout=30) as r:
                src.write_bytes(r.read())
        im = Image.open(src).convert("RGBA").resize((256, 256), Image.LANCZOS)
        im.save(OUT / f"{card_id}.png", optimize=True)
        print(f"{card_id:10s} {emoji}  <- emoji_u{name}.png")
    print(f"{len(cards)} pictures in {OUT}")


if __name__ == "__main__":
    main()
