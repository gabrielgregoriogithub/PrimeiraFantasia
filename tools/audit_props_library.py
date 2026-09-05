from __future__ import annotations

import csv
import json
import math
import sys
from collections import Counter, defaultdict
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(sys.argv[1])
OUT = Path(sys.argv[2])
OUT.mkdir(parents=True, exist_ok=True)

CATEGORIES = {
    "terrain": ("terrain", "grass", "dirt", "sand", "snow", "ground", "cliff", "mountain", "rock"),
    "vegetation": ("tree", "bush", "flower", "plant", "mushroom", "vine", "log", "stump", "reed"),
    "water": ("water", "bridge", "dock", "fish", "lily", "river", "boat", "ship"),
    "architecture": ("castle", "tower", "wall", "gate", "door", "house", "building", "ruin", "dungeon", "roof"),
    "props": ("barrel", "crate", "chest", "torch", "table", "chair", "statue", "bone", "banner", "cart", "sign", "candle", "rack", "shelf", "book"),
    "animals": ("bird", "fish", "frog", "rabbit", "deer", "insect", "butterfly", "bat", "animal", "sheep", "cow", "chicken", "horse"),
    "equipment": ("sword", "axe", "bow", "shield", "helmet", "armor", "staff", "potion", "weapon", "item"),
    "effects": ("fire", "smoke", "spark", "magic", "debris", "leaf", "particle", "effect"),
    "ui": ("icon", "ui", "button", "panel", "cursor"),
}


def category(path: Path) -> str:
    value = path.as_posix().lower().replace("_", " ").replace("-", " ")
    scores = {key: sum(token in value for token in tokens) for key, tokens in CATEGORIES.items()}
    winner, score = max(scores.items(), key=lambda item: item[1])
    return winner if score else "uncategorized"


def image_info(path: Path) -> dict:
    try:
        with Image.open(path) as image:
            has_alpha = "A" in image.getbands() or "transparency" in image.info
            extrema = image.getchannel("A").getextrema() if "A" in image.getbands() else None
            return {
                "width": image.width,
                "height": image.height,
                "mode": image.mode,
                "transparent": bool(extrema and extrema[0] < 255),
                "has_alpha": has_alpha,
                "animated": bool(getattr(image, "n_frames", 1) > 1),
                "frames": int(getattr(image, "n_frames", 1)),
            }
    except Exception as exc:
        return {"error": str(exc)}


records = []
for path in sorted(ROOT.rglob("*")):
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT)
    record = {
        "relative_path": rel.as_posix(),
        "name": path.name,
        "extension": path.suffix.lower(),
        "bytes": path.stat().st_size,
        "top_folder": rel.parts[0] if len(rel.parts) else "",
        "category": category(rel),
    }
    if path.suffix.lower() in {".png", ".jpg", ".jpeg", ".webp", ".gif"}:
        record.update(image_info(path))
    records.append(record)

fields = sorted({key for record in records for key in record})
with (OUT / "inventory.csv").open("w", newline="", encoding="utf-8-sig") as handle:
    writer = csv.DictWriter(handle, fieldnames=fields)
    writer.writeheader()
    writer.writerows(records)

summary = {
    "root": str(ROOT),
    "total_files": len(records),
    "extensions": Counter(record["extension"] for record in records),
    "top_folders": Counter(record["top_folder"] for record in records),
    "categories": Counter(record["category"] for record in records),
    "image_count": sum("width" in record for record in records),
    "transparent_images": sum(bool(record.get("transparent")) for record in records),
    "animated_container_images": sum(bool(record.get("animated")) for record in records),
}
summary = {key: dict(value) if isinstance(value, Counter) else value for key, value in summary.items()}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")

images_by_folder = defaultdict(list)
for record in records:
    if "width" in record:
        images_by_folder[record["top_folder"]].append(record)

font = ImageFont.load_default()
for folder, image_records in images_by_folder.items():
    cell_w, cell_h, columns = 220, 190, 5
    rows = math.ceil(len(image_records) / columns)
    sheet = Image.new("RGB", (columns * cell_w, rows * cell_h), (28, 31, 38))
    draw = ImageDraw.Draw(sheet)
    for index, record in enumerate(image_records):
        x, y = (index % columns) * cell_w, (index // columns) * cell_h
        source = ROOT / record["relative_path"]
        try:
            with Image.open(source) as opened:
                thumb = opened.convert("RGBA")
                thumb.thumbnail((200, 140), Image.Resampling.NEAREST)
                checker = Image.new("RGBA", thumb.size, (72, 76, 84, 255))
                checker.alpha_composite(thumb)
                sheet.paste(checker.convert("RGB"), (x + (cell_w - thumb.width) // 2, y + 4))
        except Exception:
            pass
        label = record["relative_path"]
        if len(label) > 34:
            label = "…" + label[-33:]
        draw.text((x + 5, y + 148), label, font=font, fill=(235, 232, 218))
        draw.text((x + 5, y + 164), f'{record.get("width", "?")}x{record.get("height", "?")} {record["category"]}', font=font, fill=(155, 196, 190))
    safe = "".join(ch if ch.isalnum() else "_" for ch in folder)[:70]
    sheet.save(OUT / f"contact_{safe}.jpg", quality=88)

print(json.dumps(summary, ensure_ascii=False, indent=2))
