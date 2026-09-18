from __future__ import annotations

from math import atan2, cos, pi, sin
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps

FRAME_W = 48
FRAME_H = 64
PIVOT = (24, 60)
DIRECTIONS = ("S", "SW", "W", "NW", "N", "NE", "E", "SE")
DIRECTION_VECTOR = {
    "S": (0, 1),
    "SW": (-1, 1),
    "W": (-1, 0),
    "NW": (-1, -1),
    "N": (0, -1),
    "NE": (1, -1),
    "E": (1, 0),
    "SE": (1, 1),
}
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

WY = {
    "outline": (21, 24, 31, 255),
    "cloak_dark": (43, 50, 62, 255),
    "cloak": (58, 69, 84, 255),
    "armor_dark": (54, 60, 69, 255),
    "armor": (87, 95, 105, 255),
    "metal": (150, 157, 161, 255),
    "metal_hi": (193, 199, 198, 255),
    "leather": (105, 67, 45, 255),
    "claw": (180, 118, 48, 255),
    "claw_hi": (225, 165, 70, 255),
    "eye": (128, 166, 183, 255),
}
RV = {
    "outline": (28, 25, 35, 255),
    "hair": (47, 42, 57, 255),
    "hair_hi": (70, 61, 82, 255),
    "robe_shadow": (155, 155, 166, 255),
    "robe": (210, 207, 211, 255),
    "robe_hi": (239, 235, 231, 255),
    "skin": (214, 190, 179, 255),
    "gold": (168, 130, 67, 255),
    "gold_hi": (223, 187, 102, 255),
    "spirit": (168, 198, 225, 210),
    "spirit_hi": (226, 233, 244, 240),
}


def _canonical(direction: str) -> tuple[str, bool]:
    if direction in ("SW", "W", "NW"):
        return {"SW": "SE", "W": "E", "NW": "NE"}[direction], True
    return direction, False


def _rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill) -> None:
    draw.rectangle(box, fill=fill)


def _line(draw: ImageDraw.ImageDraw, points, fill, width: int = 1) -> None:
    draw.line(points, fill=fill, width=width)


def _poly(draw: ImageDraw.ImageDraw, points, fill) -> None:
    draw.polygon(points, fill=fill)


def _ellipse(draw: ImageDraw.ImageDraw, box, fill=None, outline=None, width: int = 1) -> None:
    draw.ellipse(box, fill=fill, outline=outline, width=width)


def _motion(animation: str, index: int) -> tuple[int, int, int]:
    if animation == "idle":
        return 0, (-1 if index == 1 else 0), 0
    if animation == "move":
        return (-1, 0, 1, 0)[index], (-1, -3, -1, 0)[index], (-1, 1, 1, 0)[index]
    if animation == "melee_attack":
        return (-1, 1, 2, 0)[index], (0, -2, -1, 0)[index], (-1, 1, 1, 0)[index]
    if animation == "hit":
        return (-2, 1)[index], (1, 0)[index], 0
    return 0, 0, 0


def _with_offset(points, dx: int, dy: int):
    return [(x + dx, y + dy) for x, y in points]


def _wylder_body(direction: str, animation: str, index: int) -> Image.Image:
    direction, mirror = _canonical(direction)
    dx, dy, stride = _motion(animation, index)
    img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # Five structural views, mirrored for left-facing rows. These are not scaled copies.
    side = direction in ("E", "NE", "SE")
    back = direction in ("N", "NE")
    diagonal = direction in ("SE", "NE")

    # Grounding shadow.
    _ellipse(d, (15 + dx, 57 + dy, 34 + dx, 61 + dy), fill=(7, 9, 13, 72))

    # Cloak is silhouette-first and changes ordering between front/back views.
    if back:
        cloak = _with_offset([(17, 34), (31, 34), (34, 52), (28, 56), (24, 53), (19, 56), (14, 51)], dx, dy)
    elif side:
        cloak = _with_offset([(18, 35), (28, 34), (33, 48), (30, 55), (20, 53), (16, 47)], dx, dy)
    else:
        cloak = _with_offset([(16, 35), (32, 35), (31, 51), (27, 55), (24, 52), (20, 55), (17, 50)], dx, dy)
    _poly(d, cloak, WY["outline"])
    inset = [(x + (1 if x < 24 else -1), y + 1) for x, y in cloak]
    _poly(d, inset, WY["cloak_dark"] if back else WY["cloak"])

    # Legs and boots. Move frames separate the feet instead of moving the whole source sprite.
    leg_shift = 2 * stride
    if side:
        _rect(d, (21 + dx - leg_shift, 48 + dy, 25 + dx - leg_shift, 57 + dy), WY["armor_dark"])
        _rect(d, (26 + dx + leg_shift, 48 + dy, 30 + dx + leg_shift, 57 + dy), WY["armor"])
        _rect(d, (20 + dx - leg_shift, 56 + dy, 25 + dx - leg_shift, 59 + dy), WY["outline"])
        _rect(d, (26 + dx + leg_shift, 56 + dy, 32 + dx + leg_shift, 59 + dy), WY["outline"])
    else:
        _rect(d, (18 + dx - leg_shift, 47 + dy, 23 + dx - leg_shift, 57 + dy), WY["armor_dark"])
        _rect(d, (26 + dx + leg_shift, 47 + dy, 31 + dx + leg_shift, 57 + dy), WY["armor"])
        _rect(d, (17 + dx - leg_shift, 56 + dy, 23 + dx - leg_shift, 59 + dy), WY["outline"])
        _rect(d, (26 + dx + leg_shift, 56 + dy, 32 + dx + leg_shift, 59 + dy), WY["outline"])

    # Torso armor and belt.
    torso = (18 + dx, 35 + dy, 31 + dx, 49 + dy) if not side else (19 + dx, 35 + dy, 30 + dx, 49 + dy)
    _rect(d, torso, WY["outline"])
    _rect(d, (torso[0] + 1, torso[1] + 1, torso[2] - 1, torso[3] - 2), WY["armor_dark"] if back else WY["armor"])
    _line(d, [(19 + dx, 44 + dy), (30 + dx, 44 + dy)], WY["leather"], 2)
    _rect(d, (23 + dx, 43 + dy, 26 + dx, 46 + dy), WY["metal"])

    # Shoulder plates make front/back/side silhouettes visibly different.
    if side:
        _rect(d, (17 + dx, 35 + dy, 21 + dx, 40 + dy), WY["metal"])
        _rect(d, (29 + dx, 36 + dy, 33 + dx, 40 + dy), WY["armor_dark"])
    else:
        _rect(d, (14 + dx, 35 + dy, 20 + dx, 40 + dy), WY["metal"])
        _rect(d, (30 + dx, 35 + dy, 35 + dx, 40 + dy), WY["metal"])

    # Head/hood. Back views deliberately omit face slit.
    head_x = 21 + (2 if side else 0) + dx
    _rect(d, (head_x - 2, 25 + dy, head_x + 7, 35 + dy), WY["outline"])
    _rect(d, (head_x - 1, 26 + dy, head_x + 6, 34 + dy), WY["cloak_dark"])
    _rect(d, (head_x, 28 + dy, head_x + 5, 33 + dy), WY["armor_dark"] if back else WY["metal"])
    if not back:
        slit_y = 30 + dy
        _line(d, [(head_x + 1, slit_y), (head_x + 5, slit_y)], WY["outline"], 1)
        if direction != "E":
            _rect(d, (head_x + 2, slit_y, head_x + 2, slit_y), WY["eye"])

    # Arms and the characteristic grappling-claw bracer.
    if back:
        _line(d, [(18 + dx, 38 + dy), (15 + dx, 47 + dy)], WY["armor"], 3)
        _line(d, [(31 + dx, 38 + dy), (34 + dx, 47 + dy)], WY["armor"], 3)
        _rect(d, (13 + dx, 45 + dy, 17 + dx, 50 + dy), WY["claw"])
    elif side:
        _line(d, [(20 + dx, 38 + dy), (18 + dx, 47 + dy)], WY["armor"], 3)
        _line(d, [(29 + dx, 38 + dy), (33 + dx, 46 + dy)], WY["armor"], 3)
        _rect(d, (16 + dx, 45 + dy, 20 + dx, 50 + dy), WY["claw"])
        _rect(d, (17 + dx, 45 + dy, 19 + dx, 47 + dy), WY["claw_hi"])
    else:
        _line(d, [(18 + dx, 38 + dy), (14 + dx, 48 + dy)], WY["armor"], 3)
        _line(d, [(31 + dx, 38 + dy), (35 + dx, 48 + dy)], WY["armor"], 3)
        _rect(d, (12 + dx, 46 + dy, 16 + dx, 51 + dy), WY["claw"])
        _rect(d, (13 + dx, 46 + dy, 15 + dx, 48 + dy), WY["claw_hi"])

    # Greatsword is part of the silhouette even at idle.
    if animation != "melee_attack":
        if back:
            _line(d, [(31 + dx, 29 + dy), (16 + dx, 52 + dy)], WY["outline"], 4)
            _line(d, [(31 + dx, 29 + dy), (16 + dx, 52 + dy)], WY["metal"], 2)
        elif side:
            _line(d, [(31 + dx, 31 + dy), (34 + dx, 53 + dy)], WY["outline"], 4)
            _line(d, [(31 + dx, 31 + dy), (34 + dx, 53 + dy)], WY["metal"], 2)
        else:
            _line(d, [(29 + dx, 31 + dy), (34 + dx, 52 + dy)], WY["outline"], 4)
            _line(d, [(29 + dx, 31 + dy), (34 + dx, 52 + dy)], WY["metal"], 2)
    else:
        vx, vy = DIRECTION_VECTOR[direction]
        base_angle = atan2(vy, vx)
        swing_offsets = (-1.65, -0.55, 0.10, 0.72)
        angle = base_angle + swing_offsets[index]
        hand = (27 + dx, 39 + dy)
        length = (19, 22, 23, 18)[index]
        tip = (round(hand[0] + cos(angle) * length), round(hand[1] + sin(angle) * length))
        _line(d, [hand, tip], WY["outline"], 5)
        _line(d, [hand, tip], WY["metal_hi"], 2)
        guard_angle = angle + pi / 2
        gx, gy = cos(guard_angle) * 4, sin(guard_angle) * 4
        _line(d, [(hand[0] - gx, hand[1] - gy), (hand[0] + gx, hand[1] + gy)], WY["leather"], 2)
        if index in (1, 2):
            arc = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
            ad = ImageDraw.Draw(arc)
            radius = 17
            box = (hand[0] - radius, hand[1] - radius, hand[0] + radius, hand[1] + radius)
            start = int((angle - 0.9) * 180 / pi)
            end = int((angle + 0.3) * 180 / pi)
            ad.arc(box, start=start, end=end, fill=(188, 205, 214, 150), width=2)
            img.alpha_composite(arc)

    if animation == "hit":
        flash = Image.new("RGBA", img.size, (215, 230, 235, 0))
        flash.putalpha(img.getchannel("A").point(lambda a: int(a * (0.18 if index == 0 else 0.08))))
        img = Image.alpha_composite(img, flash)

    if mirror:
        img = ImageOps.mirror(img)
    return img


def _revenant_body(direction: str, animation: str, index: int) -> Image.Image:
    direction, mirror = _canonical(direction)
    dx, dy, stride = _motion(animation, index)
    img = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    side = direction in ("E", "NE", "SE")
    back = direction in ("N", "NE")

    _ellipse(d, (15 + dx, 57 + dy, 34 + dx, 61 + dy), fill=(8, 8, 13, 62))

    # Hair is drawn before robe so the long dark mass remains a readable silhouette.
    if back:
        hair = _with_offset([(18, 25), (30, 25), (34, 49), (28, 55), (24, 52), (19, 55), (14, 48)], dx, dy)
    elif side:
        hair = _with_offset([(20, 25), (30, 26), (32, 49), (27, 54), (20, 50), (17, 35)], dx, dy)
    else:
        hair = _with_offset([(18, 26), (30, 26), (32, 45), (28, 51), (20, 51), (16, 44)], dx, dy)
    _poly(d, hair, RV["outline"])
    inner_hair = [(x + (1 if x < 24 else -1), y + 1) for x, y in hair]
    _poly(d, inner_hair, RV["hair"])

    # Robe has a large pale triangular mass, intentionally opposite Wylder's armored silhouette.
    sway = 2 * stride
    robe = _with_offset(
        [(19, 39), (29, 39), (34 + sway, 57), (28, 59), (24, 56), (20, 59), (14 - sway, 57)],
        dx,
        dy,
    )
    _poly(d, robe, RV["outline"])
    robe_inner = [(x + (1 if x < 24 else -1), y + 1) for x, y in robe]
    _poly(d, robe_inner, RV["robe_shadow"] if back else RV["robe"])
    _line(d, [(18 + dx, 52 + dy), (31 + dx, 52 + dy)], RV["robe_hi"], 1)

    # Torso and sleeves.
    _rect(d, (19 + dx, 34 + dy, 29 + dx, 44 + dy), RV["outline"])
    _rect(d, (20 + dx, 35 + dy, 28 + dx, 43 + dy), RV["robe"] if not back else RV["robe_shadow"])
    if side:
        _line(d, [(20 + dx, 37 + dy), (16 + dx, 47 + dy)], RV["robe"], 4)
        _line(d, [(28 + dx, 37 + dy), (33 + dx, 45 + dy)], RV["robe_shadow"], 3)
    else:
        _line(d, [(19 + dx, 37 + dy), (14 + dx, 47 + dy)], RV["robe"], 4)
        _line(d, [(29 + dx, 37 + dy), (34 + dx, 47 + dy)], RV["robe"], 4)

    # Head, face and hair framing.
    head_x = 22 + (2 if side else 0) + dx
    _ellipse(d, (head_x - 4, 25 + dy, head_x + 5, 35 + dy), fill=RV["outline"])
    if back:
        _rect(d, (head_x - 3, 26 + dy, head_x + 4, 34 + dy), RV["hair"])
    else:
        _rect(d, (head_x - 2, 27 + dy, head_x + 3, 34 + dy), RV["skin"])
        _line(d, [(head_x - 3, 26 + dy), (head_x + 4, 27 + dy)], RV["hair_hi"], 2)
        if direction != "E":
            _rect(d, (head_x + 1, 30 + dy, head_x + 1, 30 + dy), RV["outline"])

    # Gold focus/lyre. At idle it sits at the hip; attack phases bring it to center and strum it.
    if animation == "melee_attack":
        focus_x = 24 + dx
        focus_y = 42 + dy
        phase_scale = (0, 1, 2, 1)[index]
        _ellipse(d, (focus_x - 6, focus_y - 7, focus_x + 6, focus_y + 6), outline=RV["gold_hi"], width=2)
        _line(d, [(focus_x - 3, focus_y - 5), (focus_x - 2, focus_y + 4)], RV["gold"], 1)
        _line(d, [(focus_x, focus_y - 6), (focus_x, focus_y + 5)], RV["gold_hi"], 1)
        _line(d, [(focus_x + 3, focus_y - 5), (focus_x + 2, focus_y + 4)], RV["gold"], 1)
        if index in (1, 2):
            for radius in (8 + phase_scale, 12 + phase_scale):
                _ellipse(
                    d,
                    (focus_x - radius, focus_y - radius, focus_x + radius, focus_y + radius),
                    outline=RV["spirit"],
                    width=1,
                )
            for sx, sy in ((13, 31), (35, 29), (37, 43), (11, 45)):
                _rect(d, (sx + dx, sy + dy, sx + 1 + dx, sy + 1 + dy), RV["spirit_hi"])
    else:
        hip_x = 30 + dx if not side else 31 + dx
        _ellipse(d, (hip_x - 3, 42 + dy, hip_x + 3, 49 + dy), outline=RV["gold"], width=1)
        _line(d, [(hip_x, 43 + dy), (hip_x, 48 + dy)], RV["gold_hi"], 1)

    if animation == "hit":
        flash = Image.new("RGBA", img.size, (224, 231, 245, 0))
        flash.putalpha(img.getchannel("A").point(lambda a: int(a * (0.22 if index == 0 else 0.08))))
        img = Image.alpha_composite(img, flash)

    if mirror:
        img = ImageOps.mirror(img)
    return img


def _fall(frame: Image.Image, index: int, direction: str) -> Image.Image:
    if index == 0:
        return frame
    side = -1 if direction in ("W", "NW", "SW") else 1
    angles = (0, 28, 58, 82)
    rotated = frame.rotate(angles[index] * side, resample=Image.Resampling.NEAREST, expand=False, center=PIVOT)
    if index >= 2:
        alpha = rotated.getchannel("A").point(lambda a: int(a * (0.82 if index == 2 else 0.56)))
        rotated.putalpha(alpha)
    return rotated


def _frame(character: str, direction: str, animation: str, index: int) -> Image.Image:
    if character == "wylder":
        frame = _wylder_body(direction, animation, index)
    else:
        frame = _revenant_body(direction, animation, index)
    if animation == "death":
        frame = _fall(frame, index, direction)
    return frame


def build(character: str) -> Path:
    folder = CHARACTER_ROOT / character
    output_path = folder / "t1-atlas.png"
    atlas = Image.new("RGBA", (FRAME_W * ATLAS_COLUMNS, FRAME_H * ATLAS_ROWS), (0, 0, 0, 0))

    for animation, (base_row, frame_count) in ANIMATIONS.items():
        for direction_index, direction in enumerate(DIRECTIONS):
            row = base_row + direction_index
            for frame_index in range(frame_count):
                frame = _frame(character, direction, animation, frame_index)
                atlas.alpha_composite(frame, (frame_index * FRAME_W, row * FRAME_H))

    atlas.save(output_path, optimize=True)
    print(f"{character}: {output_path.relative_to(ROOT)} {atlas.width}x{atlas.height}")
    return output_path


def main() -> None:
    for character in ("wylder", "revenant"):
        build(character)


if __name__ == "__main__":
    main()
