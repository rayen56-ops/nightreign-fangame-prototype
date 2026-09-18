from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageOps

FRAME_W = 48
FRAME_H = 64
ATLAS_W = 192
ATLAS_H = 2560
PIVOT = (24, 60)
DIRECTIONS = ("S", "SW", "W", "NW", "N", "NE", "E", "SE")
CANONICAL = ("S", "SE", "E", "NE", "N")
ANIMATIONS = {
    "idle": (0, 2),
    "move": (8, 4),
    "melee_attack": (16, 4),
    "hit": (24, 2),
    "death": (32, 4),
}
ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ROOT = ROOT / "assets" / "nightreign" / "characters"
REPORT_PATH = ROOT / "docs" / "characters" / "M2_CHARACTER_ART_QA.json"


def frame(atlas: Image.Image, base_row: int, direction: str, index: int) -> Image.Image:
    row = base_row + DIRECTIONS.index(direction)
    return atlas.crop((index * FRAME_W, row * FRAME_H, (index + 1) * FRAME_W, (row + 1) * FRAME_H))


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").getbbox()


def alpha_hash(image: Image.Image) -> str:
    return hashlib.sha256(image.getchannel("A").tobytes()).hexdigest()


def rgba_hash(image: Image.Image) -> str:
    return hashlib.sha256(image.tobytes()).hexdigest()


def difference_ratio(a: Image.Image, b: Image.Image) -> float:
    aa = a.getchannel("A")
    bb = b.getchannel("A")
    diff = ImageChops.difference(aa, bb)
    changed = sum(1 for px in diff.getdata() if px != 0)
    return changed / float(FRAME_W * FRAME_H)


def mirror_difference_ratio(a: Image.Image, b: Image.Image) -> float:
    return difference_ratio(ImageOps.mirror(a), b)


def opaque_pixels(image: Image.Image) -> int:
    return sum(1 for px in image.getchannel("A").getdata() if px > 0)


def check_character(character: str) -> tuple[int, list[str], dict]:
    checks = 0
    failures: list[str] = []
    metrics: dict = {}
    path = CHARACTER_ROOT / character / "t1-atlas.png"
    atlas = Image.open(path).convert("RGBA")

    def check(value: bool, label: str) -> None:
        nonlocal checks
        checks += 1
        if not value:
            failures.append(label)
        print(f"M2 CHARACTER ART QA {'PASS' if value else 'FAIL'}: {character}: {label}")

    check(atlas.size == (ATLAS_W, ATLAS_H), "atlas remains 192x2560")
    check(path.stat().st_size > 10_000, "atlas contains substantial pixel data")

    # Every declared animation/direction/frame must be materially present and foot-anchored.
    for animation, (base_row, count) in ANIMATIONS.items():
        for direction in DIRECTIONS:
            for index in range(count):
                img = frame(atlas, base_row, direction, index)
                bbox = alpha_bbox(img)
                check(bbox is not None, f"{animation}/{direction}/{index} is non-empty")
                if bbox is None:
                    continue
                check(bbox[2] - bbox[0] >= 6, f"{animation}/{direction}/{index} has readable width")
                check(bbox[3] - bbox[1] >= 8, f"{animation}/{direction}/{index} has readable height")
                if animation not in ("death",):
                    # Feet/shadow should remain close to the 60px pivot, but visual FX may overhang.
                    check(bbox[3] >= 56, f"{animation}/{direction}/{index} remains grounded near pivot")

    # Five authored canonical views must be structurally distinct.
    idle_views = {direction: frame(atlas, 0, direction, 0) for direction in CANONICAL}
    canonical_hashes = {direction: alpha_hash(img) for direction, img in idle_views.items()}
    check(len(set(canonical_hashes.values())) == len(CANONICAL), "five canonical idle directions have unique alpha structure")

    canonical_pairs = []
    for i, a_name in enumerate(CANONICAL):
        for b_name in CANONICAL[i + 1 :]:
            ratio = difference_ratio(idle_views[a_name], idle_views[b_name])
            canonical_pairs.append((a_name, b_name, ratio))
            check(ratio >= 0.025, f"{a_name} vs {b_name} differs by at least 2.5% of frame pixels")
    metrics["canonical_difference_min"] = min(r[2] for r in canonical_pairs)

    # Left/right rows may mirror, but must mirror cleanly from the intended counterpart rather than reuse one row.
    mirror_pairs = (("W", "E"), ("SW", "SE"), ("NW", "NE"))
    for left, right in mirror_pairs:
        l = frame(atlas, 0, left, 0)
        r = frame(atlas, 0, right, 0)
        check(alpha_hash(l) != alpha_hash(r), f"{left}/{right} are not byte-identical row reuse")
        check(mirror_difference_ratio(r, l) <= 0.02, f"{left}/{right} preserve deliberate mirrored structure")

    # Attack phases should visibly progress instead of translating a static body.
    attack = [frame(atlas, 16, "S", i) for i in range(4)]
    check(len({rgba_hash(img) for img in attack}) == 4, "four attack phases are visually unique")
    for i in range(3):
        check(difference_ratio(attack[i], attack[i + 1]) >= 0.02, f"attack phase {i}->{i+1} changes silhouette")
    check(opaque_pixels(attack[1]) != opaque_pixels(attack[0]) or difference_ratio(attack[1], attack[0]) >= 0.04, "swing/strum is not only a whole-body translation")

    # Move cycle must shift limb/silhouette structure over the four frames.
    move = [frame(atlas, 8, "S", i) for i in range(4)]
    check(len({alpha_hash(img) for img in move}) == 4, "move cycle has four distinct silhouettes")
    check(max(opaque_pixels(img) for img in move) - min(opaque_pixels(img) for img in move) >= 1, "move cycle changes limb coverage")

    # Front/back distinction must be more than brightness or palette.
    front = frame(atlas, 0, "S", 0)
    back = frame(atlas, 0, "N", 0)
    check(alpha_hash(front) != alpha_hash(back), "front and back have different geometry")
    check(difference_ratio(front, back) >= 0.04, "front/back geometry differs materially")

    metrics["atlas_bytes"] = path.stat().st_size
    metrics["canonical_alpha_hashes"] = canonical_hashes
    metrics["opaque_idle_front"] = opaque_pixels(front)
    return checks, failures, metrics


def main() -> int:
    total_checks = 0
    failures: list[str] = []
    metrics: dict = {}

    for character in ("wylder", "revenant"):
        checks, character_failures, character_metrics = check_character(character)
        total_checks += checks
        failures.extend(character_failures)
        metrics[character] = character_metrics

    wylder = Image.open(CHARACTER_ROOT / "wylder" / "t1-atlas.png").convert("RGBA")
    revenant = Image.open(CHARACTER_ROOT / "revenant" / "t1-atlas.png").convert("RGBA")
    wylder_front = frame(wylder, 0, "S", 0)
    revenant_front = frame(revenant, 0, "S", 0)
    identity_difference = difference_ratio(wylder_front, revenant_front)
    total_checks += 1
    identity_ok = identity_difference >= 0.06
    if not identity_ok:
        failures.append("Wylder and Revenant front silhouettes are insufficiently distinct")
    print(
        "M2 CHARACTER ART QA "
        f"{'PASS' if identity_ok else 'FAIL'}: cross-character silhouette difference {identity_difference:.3f}"
    )

    report = {
        "checks": total_checks,
        "failures": failures,
        "frame_size": [FRAME_W, FRAME_H],
        "pivot": list(PIVOT),
        "directions": list(DIRECTIONS),
        "canonical_directions": list(CANONICAL),
        "art_method": "directionally constructed pixel structures",
        "identity_difference": identity_difference,
        "metrics": metrics,
    }
    REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    REPORT_PATH.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print("M2 CHARACTER ART QA COMPLETE:", json.dumps(report, ensure_ascii=False))
    return 0 if not failures else 1


if __name__ == "__main__":
    raise SystemExit(main())
