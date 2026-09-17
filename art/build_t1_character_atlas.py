from __future__ import annotations

from pathlib import Path
from PIL import Image, ImageEnhance, ImageDraw, ImageOps

FRAME_W = 48
FRAME_H = 64
PIVOT = (24, 60)
DIRECTIONS = ("S", "SW", "W", "NW", "N", "NE", "E", "SE")
ANIMATIONS = {
    "idle": (0, 2),
    "move": (8, 4),
    "melee_attack": (16, 4),
    "hit": (24, 2),
    "death": (32, 4),
}
ATLAS_COLUMNS = 4
ATLAS_ROWS = 40

ROOT = Path(__file__).resolve().parents[1]
CHARACTER_ROOT = ROOT / "assets" / "nightreign" / "characters"


def _alpha(img: Image.Image, factor: float) -> Image.Image:
    result = img.copy()
    channel = result.getchannel("A").point(lambda value: int(value * factor))
    result.putalpha(channel)
    return result


def _direction_base(source: Image.Image, direction: str) -> Image.Image:
    image = source.resize((48, 48), Image.Resampling.NEAREST)
    params = {
        "S": (1.00, False, 1.00),
        "SW": (0.88, False, 0.98),
        "W": (0.68, False, 0.96),
        "NW": (0.86, False, 0.88),
        "N": (1.00, False, 0.78),
        "NE": (0.86, True, 0.88),
        "E": (0.68, True, 0.96),
        "SE": (0.88, True, 0.98),
    }
    scale_x, flip, brightness = params[direction]
    if flip:
        image = ImageOps.mirror(image)
    if scale_x != 1.0:
        image = image.resize((max(1, round(image.width * scale_x)), image.height), Image.Resampling.NEAREST)
    if brightness != 1.0:
        image = ImageEnhance.Brightness(image).enhance(brightness)
    return image


def _place(canvas: Image.Image, image: Image.Image, dx: int = 0, dy: int = 0, angle: float = 0.0) -> None:
    if angle:
        image = image.rotate(angle, resample=Image.Resampling.NEAREST, expand=True)
    bbox = image.getbbox()
    if bbox is None:
        return
    left, _top, right, bottom = bbox
    foot_x = (left + right) // 2
    foot_y = bottom
    canvas.alpha_composite(image, (PIVOT[0] - foot_x + dx, PIVOT[1] - foot_y + dy))


def _wylder_attack_fx(canvas: Image.Image, phase: int, direction: str) -> None:
    if phase not in (1, 2):
        return
    draw = ImageDraw.Draw(canvas)
    vectors = {
        "S": (0, 1), "SW": (-1, 1), "W": (-1, 0), "NW": (-1, -1),
        "N": (0, -1), "NE": (1, -1), "E": (1, 0), "SE": (1, 1),
    }
    starts = {"S": 35, "SW": 0, "W": -45, "NW": -90, "N": -135, "NE": -180, "E": 135, "SE": 90}
    vx, vy = vectors[direction]
    if phase == 1:
        cx, cy = PIVOT[0] + vx * 9, PIVOT[1] - 20 + vy * 7
        for radius in (10, 12):
            draw.arc((cx - radius, cy - radius, cx + radius, cy + radius), starts[direction], starts[direction] + 95, fill=(220, 230, 235, 220), width=2)
    else:
        cx, cy = PIVOT[0] + vx * 12, PIVOT[1] - 20 + vy * 9
        draw.line((PIVOT[0], PIVOT[1] - 18, cx, cy), fill=(160, 195, 220, 160), width=1)


def _revenant_attack_fx(canvas: Image.Image, phase: int) -> None:
    if phase not in (1, 2):
        return
    draw = ImageDraw.Draw(canvas)
    if phase == 1:
        cx, cy = PIVOT[0], PIVOT[1] - 24
        for radius in (7, 11):
            draw.ellipse((cx - radius, cy - radius, cx + radius, cy + radius), outline=(170, 205, 255, 170), width=1)
        draw.point((cx + 9, cy - 5), fill=(240, 245, 255, 255))
        draw.point((cx - 7, cy - 8), fill=(230, 220, 255, 255))
    else:
        for x, y in ((13, 22), (33, 19), (36, 31), (10, 34)):
            draw.rectangle((x, y, x + 1, y + 1), fill=(210, 225, 255, 180))


def _frame(source: Image.Image, character: str, direction: str, animation: str, index: int) -> Image.Image:
    base = _direction_base(source, direction)
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    dx = dy = 0
    angle = 0.0
    side = -1 if direction in ("W", "NW", "SW") else 1

    if animation == "idle":
        dy = -1 if index == 1 else 0
    elif animation == "move":
        dy = (-1, -3, -1, 0)[index]
        dx = (-1, 0, 1, 0)[index]
        angle = (-2, 1, 2, -1)[index]
    elif animation == "melee_attack":
        # The four frames are semantic phases: Windup -> Swing/Strum -> Release -> Recover.
        dx = (-2, 2, 1, 0)[index]
        dy = (0, -2, -1, 0)[index]
        angle = (-9, 16, 7, 0)[index] * side
    elif animation == "hit":
        dx = (-2, 1)[index]
        angle = (-7, 3)[index]
        base = ImageEnhance.Brightness(base).enhance(1.12)
    elif animation == "death":
        angle = (15, 40, 68, 88)[index] * side
        dy = (0, 4, 8, 12)[index]
        base = _alpha(ImageEnhance.Brightness(base).enhance(0.82), (1.0, 0.85, 0.65, 0.45)[index])

    _place(canvas, base, dx, dy, angle)
    if animation == "melee_attack":
        if character == "wylder":
            _wylder_attack_fx(canvas, index, direction)
        else:
            _revenant_attack_fx(canvas, index)
    return canvas


def build(character: str) -> Path:
    folder = CHARACTER_ROOT / character
    source_path = folder / "idle-selected.png"
    output_path = folder / "t1-atlas.png"
    source = Image.open(source_path).convert("RGBA")
    atlas = Image.new("RGBA", (FRAME_W * ATLAS_COLUMNS, FRAME_H * ATLAS_ROWS), (0, 0, 0, 0))

    for animation, (base_row, frame_count) in ANIMATIONS.items():
        for direction_index, direction in enumerate(DIRECTIONS):
            row = base_row + direction_index
            for frame_index in range(frame_count):
                frame = _frame(source, character, direction, animation, frame_index)
                atlas.alpha_composite(frame, (frame_index * FRAME_W, row * FRAME_H))

    atlas.save(output_path, optimize=True)
    print(f"{character}: {output_path.relative_to(ROOT)} {atlas.width}x{atlas.height}")
    return output_path


def main() -> None:
    for character in ("wylder", "revenant"):
        build(character)


if __name__ == "__main__":
    main()
