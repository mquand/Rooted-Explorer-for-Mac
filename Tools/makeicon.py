#!/usr/bin/env python3
"""Generate the Rooted app icon set from Tools/icon-source.png.

The source artwork was exported with a checkerboard "transparency" background
baked into the pixels. This script removes that background with a flood fill
from the borders (keeping white areas enclosed by the artwork), fits the
artwork onto a square transparent canvas and writes every size macOS needs.

Usage:
    python3 Tools/makeicon.py [output-dir]

Requires Pillow.
"""

import json
import os
import sys
from collections import deque

from PIL import Image, ImageChops

MARGIN_RATIO = 0.04
CANVAS = 1024

# filename -> pixel size
SPECS = {
    "icon_16x16.png": 16,
    "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32,
    "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512,
    "icon_512x512@2x.png": 1024,
}


def is_background(pixel):
    r, g, b, a = pixel
    if a == 0:
        return True
    if max(r, g, b) - min(r, g, b) > 12:
        return False
    return (r + g + b) / 3 >= 225


def remove_checkerboard(image):
    """Make border-connected checkerboard pixels transparent."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    visited = bytearray(width * height)
    queue = deque()

    def enqueue(x, y):
        index = y * width + x
        if not visited[index] and is_background(pixels[x, y]):
            visited[index] = 1
            queue.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < width and 0 <= ny < height:
                enqueue(nx, ny)

    alpha = bytearray(b"\xff") * (width * height)
    for index, value in enumerate(visited):
        if value:
            alpha[index] = 0

    image.putalpha(Image.frombytes("L", (width, height), bytes(alpha)))
    return image


def fit_square(image, size):
    """Center the artwork on a transparent square canvas."""
    bbox = image.getbbox()
    if bbox is None:
        raise SystemExit("Source image is empty after removing the background.")

    content = image.crop(bbox)
    max_side = round(size * (1 - MARGIN_RATIO * 2))
    scale = min(max_side / content.width, max_side / content.height)
    new_size = (
        max(1, round(content.width * scale)),
        max(1, round(content.height * scale)),
    )

    # Resize in premultiplied alpha so the removed background cannot bleed
    # light fringes into the artwork edges.
    r, g, b, a = content.split()
    premultiplied = Image.merge(
        "RGBA",
        (ImageChops.multiply(r, a), ImageChops.multiply(g, a), ImageChops.multiply(b, a), a),
    ).resize(new_size, Image.LANCZOS)

    unpremultiplied = []
    for red, green, blue, alpha_value in premultiplied.getdata():
        if alpha_value == 0:
            unpremultiplied.append((0, 0, 0, 0))
            continue
        factor = 255 / alpha_value
        unpremultiplied.append(
            (
                min(255, round(red * factor)),
                min(255, round(green * factor)),
                min(255, round(blue * factor)),
                alpha_value,
            )
        )

    resized = Image.new("RGBA", new_size)
    resized.putdata(unpremultiplied)

    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(resized, ((size - new_size[0]) // 2, (size - new_size[1]) // 2))
    return canvas


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    source_path = os.path.join(root, "Tools", "icon-source.png")
    output_dir = (
        sys.argv[1]
        if len(sys.argv) > 1
        else os.path.join(root, "Resources", "Assets.xcassets", "AppIcon.appiconset")
    )
    os.makedirs(output_dir, exist_ok=True)

    source = Image.open(source_path).convert("RGBA")
    artwork = remove_checkerboard(source)

    cache = {}
    for name, size in SPECS.items():
        if size not in cache:
            cache[size] = fit_square(artwork, size)
        cache[size].save(os.path.join(output_dir, name))

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
