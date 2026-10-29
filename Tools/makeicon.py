#!/usr/bin/env python3
"""Generate the Rooted app icon set. Requires Pillow.

Usage: python3 Tools/makeicon.py Resources/Assets.xcassets/AppIcon.appiconset
"""

import json
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def make_icon():
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

    # Diagonal gradient clipped to a rounded square.
    top_left = (23, 62, 214)
    bottom_right = (8, 166, 170)
    gradient = Image.new("RGB", (SIZE, SIZE))
    pixels = gradient.load()
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x + y) / (2 * (SIZE - 1))
            pixels[x, y] = lerp(top_left, bottom_right, t)

    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([44, 44, SIZE - 44, SIZE - 44], radius=210, fill=255)
    image.paste(gradient, (0, 0), mask)

    # Soft highlight at the top.
    highlight = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(highlight).ellipse([90, 500, 810, 1080], fill=(255, 255, 255, 22))
    highlight = highlight.filter(ImageFilter.GaussianBlur(60))
    image = Image.alpha_composite(image, highlight)

    # Folder back tab and body.
    folder = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(folder)
    draw.rounded_rectangle([246, 508, 502, 634], radius=46, fill=(255, 255, 255, 235))
    draw.rounded_rectangle([228, 326, 796, 660], radius=54, fill=(255, 255, 255, 235))
    draw.rounded_rectangle([204, 262, 820, 604], radius=66, fill=(255, 255, 255, 255))

    # Small leaf, rotated.
    leaf = Image.new("RGBA", (260, 320), (0, 0, 0, 0))
    leaf_draw = ImageDraw.Draw(leaf)
    leaf_draw.ellipse([78, 40, 182, 280], fill=(69, 220, 128, 255))
    leaf = leaf.rotate(30, resample=Image.BICUBIC, expand=True)
    folder.alpha_composite(leaf, (655, 520))

    # Stem connecting the leaf to the folder.
    draw = ImageDraw.Draw(folder)
    draw.line([(676, 594), (690, 578), (706, 566)], fill=(56, 194, 112, 255), width=15, joint="curve")

    image = Image.alpha_composite(image, folder)

    # Subtle inner border for definition on light backgrounds.
    border = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ImageDraw.Draw(border).rounded_rectangle(
        [44, 44, SIZE - 44, SIZE - 44],
        radius=210,
        outline=(255, 255, 255, 34),
        width=4,
    )
    return Image.alpha_composite(image, border)


def main():
    output_dir = sys.argv[1] if len(sys.argv) > 1 else "Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)

    icon = make_icon()

    sizes = {
        16: "icon_16x16.png",
        32: "icon_16x16@2x.png",
        64: "icon_32x32@2x.png",
        128: "icon_128x128.png",
        256: "icon_128x128@2x.png",
        512: "icon_256x256@2x.png",
        1024: "icon_512x512@2x.png",
    }

    for size, name in sizes.items():
        icon.resize((size, size), Image.LANCZOS).save(os.path.join(output_dir, name))

    # 32x32 @1x, 256x256 @1x and 512x512 @1x share the same pixels as a 2x slot above.
    icon.resize((32, 32), Image.LANCZOS).save(os.path.join(output_dir, "icon_32x32.png"))
    icon.resize((256, 256), Image.LANCZOS).save(os.path.join(output_dir, "icon_256x256.png"))
    icon.resize((512, 512), Image.LANCZOS).save(os.path.join(output_dir, "icon_512x512.png"))

    contents = {
        "images": [
            {"idiom": "mac", "scale": "1x", "size": "16x16", "filename": "icon_16x16.png"},
            {"idiom": "mac", "scale": "2x", "size": "16x16", "filename": "icon_16x16@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "32x32", "filename": "icon_32x32.png"},
            {"idiom": "mac", "scale": "2x", "size": "32x32", "filename": "icon_32x32@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "128x128", "filename": "icon_128x128.png"},
            {"idiom": "mac", "scale": "2x", "size": "128x128", "filename": "icon_128x128@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "256x256", "filename": "icon_256x256.png"},
            {"idiom": "mac", "scale": "2x", "size": "256x256", "filename": "icon_256x256@2x.png"},
            {"idiom": "mac", "scale": "1x", "size": "512x512", "filename": "icon_512x512.png"},
            {"idiom": "mac", "scale": "2x", "size": "512x512", "filename": "icon_512x512@2x.png"},
        ],
        "info": {"author": "xcode", "version": 1},
    }

    with open(os.path.join(output_dir, "Contents.json"), "w", encoding="utf-8") as handle:
        json.dump(contents, handle, indent=2)
        handle.write("\n")

    print(f"Wrote icon set to {output_dir}")


if __name__ == "__main__":
    main()
