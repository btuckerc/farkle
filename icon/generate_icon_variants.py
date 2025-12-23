#!/usr/bin/env python3
"""
Generate iOS app icon variants (Light, Dark, Tinted) for iOS 18+.

Goals:
- Fix the LIGHT icon by cropping away the big white outer border from the original artwork,
  keeping the pleasant gradient background, and cropping in slightly to remove any halo/shadow.
- Generate DARK and TINTED variants that:
  - replace the background (dark gradient / pure black)
  - keep only the foreground glyph (dice + arrows + calculator), with appropriate contrast.
"""

from PIL import Image, ImageDraw
import os

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ORIGINAL_SOURCE = os.path.join(SCRIPT_DIR, "Gemini_Generated_Image_wmcpzywmcpzywmcp.png")
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "../FarkleScorer/Assets.xcassets/AppIcon.appiconset")

LIGHT_OUT = os.path.join(OUTPUT_DIR, "AppIcon-1024.png")
DARK_OUT = os.path.join(OUTPUT_DIR, "AppIcon-1024-dark.png")
TINTED_OUT = os.path.join(OUTPUT_DIR, "AppIcon-1024-tinted.png")

TARGET_SIZE = 1024

# Crop tuning (for the provided Gemini artwork)
# - Higher sat threshold (0.07) to find actual colored gradient, not off-white background
# - Minimal inset since saturation-based bounds are already tight to gradient
CROP_SAT_THRESH = 0.07
CROP_LUM_THRESH = 220.0
CROP_INSET_PERCENT = 2.0  # Small inset to clean up any edge artifacts
CROP_DOWNSCALE_MAX = 700

def create_dark_gradient(size):
    """Create a vertical gradient from #313131 (top) to #141414 (bottom)."""
    width, height = size
    gradient = Image.new('RGB', (width, height))
    draw = ImageDraw.Draw(gradient)
    
    # Top color: #313131 = (49, 49, 49)
    # Bottom color: #141414 = (20, 20, 20)
    top_color = (49, 49, 49)
    bottom_color = (20, 20, 20)
    
    for y in range(height):
        ratio = y / height
        r = int(top_color[0] + (bottom_color[0] - top_color[0]) * ratio)
        g = int(top_color[1] + (bottom_color[1] - top_color[1]) * ratio)
        b = int(top_color[2] + (bottom_color[2] - top_color[2]) * ratio)
        draw.line([(0, y), (width, y)], fill=(r, g, b))
    
    return gradient


def _luminance(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b


def _is_orange_accent(r: int, g: int, b: int) -> bool:
    # Broad heuristic for the orange buttons in the glyph.
    return r > 170 and g > 80 and b < 140 and (r - b) > 80


def crop_to_gradient_tile_square(
    img: Image.Image,
    sat_thresh: float = CROP_SAT_THRESH,
    lum_thresh: float = CROP_LUM_THRESH,
    inset_percent: float = CROP_INSET_PERCENT,
    downscale_max: int = CROP_DOWNSCALE_MAX,
) -> Image.Image:
    """
    Crop to the colorful gradient tile (removing the large white outer canvas).

    Strategy:
    - Downscale for speed
    - Find bounds of pixels that are either:
      - sufficiently saturated (the gradient tile)
      - sufficiently dark (the glyph outlines)
    - Scale bounds back up, inset slightly to remove halo/shadow, then square-crop.
    """
    rgb = img.convert("RGB")
    w, h = rgb.size

    scale = min(1.0, float(downscale_max) / float(max(w, h)))
    sw = max(1, int(round(w * scale)))
    sh = max(1, int(round(h * scale)))
    small = rgb.resize((sw, sh), Image.Resampling.BILINEAR)
    pixels = small.load()

    min_x, min_y = sw, sh
    max_x, max_y = 0, 0

    for y in range(sh):
        for x in range(sw):
            r, g, b = pixels[x, y]
            lum = _luminance(r, g, b)
            max_c = max(r, g, b)
            min_c = min(r, g, b)
            sat = (max_c - min_c) / 255.0 if max_c > 0 else 0.0

            if sat > sat_thresh or lum < lum_thresh:
                if x < min_x:
                    min_x = x
                if y < min_y:
                    min_y = y
                if x > max_x:
                    max_x = x
                if y > max_y:
                    max_y = y

    if max_x <= min_x or max_y <= min_y:
        return rgb

    # Convert small-image bounds back to original coordinates.
    inv = 1.0 / scale
    left = int(round(min_x * inv))
    top = int(round(min_y * inv))
    right = int(round((max_x + 1) * inv))
    bottom = int(round((max_y + 1) * inv))

    # Inset slightly to remove halo/shadow around the tile.
    side = max(right - left, bottom - top)
    inset_px = int(round(side * (inset_percent / 100.0)))
    left += inset_px
    top += inset_px
    right -= inset_px
    bottom -= inset_px

    # Center square crop.
    cx = (left + right) / 2.0
    cy = (top + bottom) / 2.0
    side2 = max(right - left, bottom - top)

    sq_left = int(round(cx - side2 / 2.0))
    sq_top = int(round(cy - side2 / 2.0))
    sq_right = sq_left + int(round(side2))
    sq_bottom = sq_top + int(round(side2))

    sq_left = max(0, sq_left)
    sq_top = max(0, sq_top)
    sq_right = min(w, sq_right)
    sq_bottom = min(h, sq_bottom)

    cropped = rgb.crop((sq_left, sq_top, sq_right, sq_bottom))

    # Ensure square (pad with white if clamping made it rectangular).
    cw, ch = cropped.size
    if cw != ch:
        new_side = max(cw, ch)
        square = Image.new("RGB", (new_side, new_side), (255, 255, 255))
        square.paste(cropped, ((new_side - cw) // 2, (new_side - ch) // 2))
        cropped = square

    return cropped


def create_light_icon(original_img: Image.Image) -> Image.Image:
    cropped = crop_to_gradient_tile_square(original_img)
    return cropped.resize((TARGET_SIZE, TARGET_SIZE), Image.Resampling.LANCZOS).convert("RGB")


def is_foreground_pixel(r: int, g: int, b: int) -> bool:
    """
    Foreground detection tuned for this icon:
    - outlines/arrows: darker pixels
    - calculator buttons: mid-gray pixels
    - orange accent: orange pixels
    Background gradient is very light, so a luminance threshold works well.
    """
    lum = _luminance(r, g, b)
    if _is_orange_accent(r, g, b):
        return True
    return lum < 205


def create_dark_icon(source_img):
    """
    Create dark mode icon:
    - Dark gradient background
    - Foreground elements with inverted/adjusted colors for contrast
    """
    size = source_img.size
    
    # Create dark gradient background
    dark_bg = create_dark_gradient(size)
    
    src = source_img.convert("RGB")
    result = dark_bg.convert("RGB")
    
    width, height = size
    src_pixels = src.load()
    result_pixels = result.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b = src_pixels[x, y]
            if not is_foreground_pixel(r, g, b):
                continue

            lum = _luminance(r, g, b)
            # Preserve orange accent.
            if _is_orange_accent(r, g, b):
                result_pixels[x, y] = (min(255, int(r * 1.05)), min(255, int(g * 1.05)), b)
                continue

            # Outlines/arrows -> white
            if lum < 120:
                result_pixels[x, y] = (240, 240, 240)
            else:
                # Mid-gray buttons -> darker gray for dark mode
                v = max(70, min(140, int(lum * 0.55)))
                result_pixels[x, y] = (v, v, v)

    return result


def create_tinted_icon(source_img):
    """
    Create tinted mode icon:
    - Black background
    - Grayscale foreground elements (lighter = more visible when tinted)
    - The system will apply the user's chosen tint color
    """
    size = source_img.size
    
    src = source_img.convert("RGB")
    result = Image.new("RGB", size, (0, 0, 0))
    result_pixels = result.load()
    
    width, height = size
    src_pixels = src.load()
    
    for y in range(height):
        for x in range(width):
            r, g, b = src_pixels[x, y]
            if not is_foreground_pixel(r, g, b):
                continue

            lum = _luminance(r, g, b)
            if _is_orange_accent(r, g, b):
                # Make the accent bright so it tints strongly.
                result_pixels[x, y] = (255, 255, 255)
            elif lum < 120:
                # Outlines/arrows -> white
                result_pixels[x, y] = (255, 255, 255)
            else:
                # Buttons/filled areas -> mid gray (still tints, but with depth).
                v = max(140, min(220, int(lum)))
                result_pixels[x, y] = (v, v, v)
    
    return result


def main():
    print("Loading original artwork...")
    original = Image.open(ORIGINAL_SOURCE)
    print(f"Original size: {original.size}, mode: {original.mode}")

    print("\nCreating LIGHT icon (crop away white border, keep gradient)...")
    light = create_light_icon(original)
    light.save(LIGHT_OUT, "PNG")
    print(f"✓ Saved: {LIGHT_OUT}")

    print("\nCreating DARK icon...")
    dark_icon = create_dark_icon(light)
    dark_icon.save(DARK_OUT, "PNG")
    print(f"✓ Saved: {DARK_OUT}")

    print("\nCreating TINTED icon...")
    tinted_icon = create_tinted_icon(light)
    tinted_icon.save(TINTED_OUT, "PNG")
    print(f"✓ Saved: {TINTED_OUT}")
    
    print("\n✅ All icon variants created successfully!")
    print("\nVariants:")
    print("  - AppIcon-1024.png (Light/Normal)")
    print("  - AppIcon-1024-dark.png (Dark mode)")
    print("  - AppIcon-1024-tinted.png (Tinted mode)")


if __name__ == "__main__":
    main()

