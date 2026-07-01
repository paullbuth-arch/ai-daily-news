from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
RES = ROOT / "android" / "app" / "src" / "main" / "res"
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}


def rounded_rect_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    return mask


def make_icon(size: int = 1024) -> Image.Image:
    scale = size / 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    box = [62 * scale, 62 * scale, 962 * scale, 962 * scale]
    shadow_draw.rounded_rectangle(
        box,
        radius=int(236 * scale),
        fill=(0, 0, 0, 190),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(int(30 * scale)))
    img.alpha_composite(shadow)

    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    bg_draw.rounded_rectangle(
        box,
        radius=int(228 * scale),
        fill=(11, 15, 22, 255),
        outline=(47, 58, 72, 255),
        width=max(1, int(8 * scale)),
    )
    img.alpha_composite(bg)

    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)
    glow_draw.ellipse(
        [112 * scale, 72 * scale, 852 * scale, 812 * scale],
        fill=(143, 234, 242, 52),
    )
    glow_draw.ellipse(
        [318 * scale, 268 * scale, 1004 * scale, 1010 * scale],
        fill=(197, 239, 166, 28),
    )
    glow = glow.filter(ImageFilter.GaussianBlur(int(52 * scale)))
    img.alpha_composite(glow)

    draw = ImageDraw.Draw(img)

    # Back plate: inventory surface.
    plate = [232 * scale, 242 * scale, 792 * scale, 768 * scale]
    draw.rounded_rectangle(
        plate,
        radius=int(118 * scale),
        fill=(24, 31, 43, 255),
        outline=(74, 88, 107, 255),
        width=max(1, int(10 * scale)),
    )

    # Three calm stock bars, intentionally abstract at small sizes.
    for rect in (
        [310, 330, 472, 444],
        [552, 330, 714, 444],
        [310, 566, 470, 680],
    ):
        draw.rounded_rectangle(
            [v * scale for v in rect],
            radius=int(38 * scale),
            fill=(43, 54, 70, 255),
        )

    # Main brand pulse: one continuous trade-flow path.
    pulse = [
        (268 * scale, 602 * scale),
        (392 * scale, 494 * scale),
        (496 * scale, 548 * scale),
        (600 * scale, 374 * scale),
        (738 * scale, 470 * scale),
        (850 * scale, 310 * scale),
    ]
    draw.line(
        pulse,
        fill=(25, 33, 43, 255),
        width=max(1, int(74 * scale)),
        joint="curve",
    )
    draw.line(
        pulse,
        fill=(143, 234, 242, 255),
        width=max(1, int(50 * scale)),
        joint="curve",
    )
    draw.line(
        pulse,
        fill=(197, 239, 166, 255),
        width=max(1, int(22 * scale)),
        joint="curve",
    )

    # Flow nodes.
    for idx, (x, y) in enumerate(pulse):
        outer = 31 if idx in (0, len(pulse) - 1) else 27
        inner = 15 if idx in (0, len(pulse) - 1) else 13
        draw.ellipse(
            [
                x - outer * scale,
                y - outer * scale,
                x + outer * scale,
                y + outer * scale,
            ],
            fill=(17, 23, 32, 255),
            outline=(143, 234, 242, 255),
            width=max(1, int(7 * scale)),
        )
        draw.ellipse(
            [
                x - inner * scale,
                y - inner * scale,
                x + inner * scale,
                y + inner * scale,
            ],
            fill=(197, 239, 166, 255),
        )

    # Subtle lower shelf grounds the mark without adding text.
    draw.rounded_rectangle(
        [348 * scale, 726 * scale, 676 * scale, 760 * scale],
        radius=int(17 * scale),
        fill=(143, 234, 242, 36),
    )

    return img


def main() -> None:
    master = make_icon()
    for folder, size in SIZES.items():
        out_dir = RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        icon = master.resize((size, size), Image.Resampling.LANCZOS)
        icon.save(out_dir / "ic_launcher.png")


if __name__ == "__main__":
    main()
