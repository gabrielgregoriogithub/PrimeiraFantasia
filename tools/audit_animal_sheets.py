from collections import deque
from pathlib import Path
import json
from PIL import Image
import numpy as np

SOURCE = Path(r"C:\Users\gabri\Downloads\evolução pvp 2d\animais")
DEST = Path(__file__).resolve().parents[1] / "assets" / "enemies" / "animals"

def remove_background(image):
    rgba = np.array(image.convert("RGBA"), dtype=np.uint8)
    rgb = rgba[:, :, :3]
    hi, lo = rgb.max(2), rgb.min(2)
    candidate = (lo >= 175) & ((hi.astype(np.int16) - lo.astype(np.int16)) <= 24)
    h, w = candidate.shape
    outside = np.zeros((h, w), dtype=bool)
    queue = deque([(x, y) for x in range(w) for y in (0, h-1)] + [(x, y) for y in range(h) for x in (0, w-1)])
    while queue:
        x, y = queue.popleft()
        if outside[y, x] or not candidate[y, x]: continue
        outside[y, x] = True
        if x: queue.append((x-1, y))
        if x+1 < w: queue.append((x+1, y))
        if y: queue.append((x, y-1))
        if y+1 < h: queue.append((x, y+1))
    rgba[outside, 3] = 0
    return Image.fromarray(rgba, "RGBA")

def runs(values, minimum=2):
    out, start = [], None
    for i, active in enumerate(values):
        if active and start is None: start = i
        elif not active and start is not None:
            if i-start >= minimum: out.append([start, i-1])
            start = None
    if start is not None: out.append([start, len(values)-1])
    return out

def audit(name):
    source = Image.open(SOURCE / name)
    cleaned = remove_background(source) if name in {"goo.png", "smile.png"} else source.convert("RGBA")
    output = "slime.png" if name == "smile.png" else name
    cleaned.save(DEST / output, optimize=True)
    alpha = np.array(cleaned.getchannel("A")) > 8
    row_runs = runs(alpha.sum(1) > 2)
    per_row_columns = []
    for y0, y1 in row_runs:
        # Merge tiny anti-alias gaps, but keep the broad whitespace between
        # authored frames. These are diagnostic boxes, not the runtime atlas.
        active = alpha[y0:y1+1].sum(0) > 0
        filled = active.copy()
        gap_start = None
        for x, value in enumerate(active):
            if not value and gap_start is None: gap_start = x
            elif value and gap_start is not None:
                if x-gap_start <= 12: filled[gap_start:x] = True
                gap_start = None
        per_row_columns.append(runs(filled, 2))
    return {"source": name, "output": output, "size": list(cleaned.size),
            "row_runs": row_runs, "per_row_columns": per_row_columns, "column_runs": runs(alpha.sum(0) > 2),
            "opaque_bounds": list(cleaned.getbbox() or (0,0,0,0))}

def main():
    DEST.mkdir(parents=True, exist_ok=True)
    report = [audit(n) for n in ["rat.png","snake.png","gnoll.png","smile.png","goo.png"]]
    (DEST / "audit.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    print(json.dumps(report, indent=2))

if __name__ == "__main__": main()
