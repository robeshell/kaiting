#!/usr/bin/env python3
"""Generate every platform icon and launch mark from the Reverie v7 master.

The supplied artwork is full-bleed. System-masked platforms consume that
composition directly, while adaptive and unmasked platforms use extracted
foreground/background layers with platform-specific optical margins.
"""

from __future__ import annotations

import base64
import io
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
BRANDING = ROOT / "assets" / "branding"
LAYERS = BRANDING / "app_icon_layers"
MASTER = BRANDING / "app_icon_master-v7.png"

CANVAS = 1024
BRAND_RED = (255, 82, 67)
LAUNCH_TITLE = "Reverie"
LAUNCH_TAGLINE = "听自己的音乐"
LAUNCH_TITLE_COLOR = (28, 28, 34, 255)
LAUNCH_SUBTITLE_COLOR = (112, 112, 122, 255)


def smoothstep(low: float, high: float, values: np.ndarray) -> np.ndarray:
    values = np.clip((values - low) / (high - low), 0.0, 1.0)
    return values * values * (3.0 - 2.0 * values)


def extract_mark() -> Image.Image:
    source = np.asarray(Image.open(MASTER).convert("RGBA"), dtype=np.float32)
    red, green, blue, source_alpha = np.moveaxis(source, -1, 0)

    # The v7 artwork has a warm orange background and a neutral white mark.
    # The minimum RGB component cleanly separates the mark while leaving the
    # baked red drop shadow behind for platforms that render their own depth.
    whiteness = np.minimum(np.minimum(red, green), blue)
    neutrality = 255.0 - (np.maximum(np.maximum(red, green), blue) - whiteness)
    alpha = (
        smoothstep(142.0, 220.0, whiteness)
        * smoothstep(190.0, 244.0, neutrality)
        * (source_alpha / 255.0)
    )

    ys, xs = np.where(alpha > 0.04)
    if not len(xs):
        raise RuntimeError("Could not isolate the Reverie mark from the master")

    pad = 3
    left = max(0, int(xs.min()) - pad)
    top = max(0, int(ys.min()) - pad)
    right = min(source.shape[1], int(xs.max()) + pad + 1)
    bottom = min(source.shape[0], int(ys.max()) + pad + 1)
    alpha = alpha[top:bottom, left:right]

    color = source[top:bottom, left:right, :3]
    rgba = np.concatenate((color, (alpha * 255.0)[..., None]), axis=2)
    return Image.fromarray(np.clip(rgba, 0, 255).astype(np.uint8), "RGBA")


def contain(image: Image.Image, box: tuple[int, int], canvas: tuple[int, int]) -> Image.Image:
    ratio = min(box[0] / image.width, box[1] / image.height)
    size = (round(image.width * ratio), round(image.height * ratio))
    resized = image.resize(size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", canvas, (0, 0, 0, 0))
    output.alpha_composite(
        resized,
        ((canvas[0] - resized.width) // 2, (canvas[1] - resized.height) // 2),
    )
    return output


def gradient_background(size: int) -> Image.Image:
    """Rebuild the source's smooth background without its baked white mark."""
    source = np.asarray(Image.open(MASTER).convert("RGB"), dtype=np.float32)
    height, width, _ = source.shape
    step = max(1, min(height, width) // 96)
    ys, xs = np.mgrid[0:height:step, 0:width:step]
    samples = source[::step, ::step]
    x = (xs.astype(np.float32) / max(1, width - 1)) * 2.0 - 1.0
    y = (ys.astype(np.float32) / max(1, height - 1)) * 2.0 - 1.0

    # Fit only the outer frame. It contains uninterrupted background and is
    # enough to reproduce the gentle two-dimensional coral gradient.
    frame = (np.abs(x) > 0.72) | (np.abs(y) > 0.72)
    x_fit = x[frame]
    y_fit = y[frame]
    design = np.stack(
        (
            np.ones_like(x_fit),
            x_fit,
            y_fit,
            x_fit * y_fit,
            x_fit**2,
            y_fit**2,
            x_fit**3,
            y_fit**3,
        ),
        axis=1,
    )
    coefficients = np.linalg.lstsq(design, samples[frame], rcond=None)[0]

    out_y, out_x = np.mgrid[0:size, 0:size]
    out_x = (out_x.astype(np.float32) / max(1, size - 1)) * 2.0 - 1.0
    out_y = (out_y.astype(np.float32) / max(1, size - 1)) * 2.0 - 1.0
    output_design = np.stack(
        (
            np.ones_like(out_x),
            out_x,
            out_y,
            out_x * out_y,
            out_x**2,
            out_y**2,
            out_x**3,
            out_y**3,
        ),
        axis=-1,
    )
    pixels = output_design @ coefficients
    alpha = np.full((size, size, 1), 255.0, dtype=np.float32)
    return Image.fromarray(
        np.clip(np.concatenate((pixels, alpha), axis=2), 0, 255).astype(np.uint8),
        "RGBA",
    )


def monochrome(mark_layer: Image.Image, color: tuple[int, int, int]) -> Image.Image:
    result = Image.new("RGBA", mark_layer.size, (*color, 0))
    result.putalpha(mark_layer.getchannel("A"))
    return result


def rounded_plate(
    mark: Image.Image, inset: int, radius: int, *, draw_shadow: bool = True
) -> Image.Image:
    output = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    bounds = (inset, inset, CANVAS - inset, CANVAS - inset)
    if draw_shadow:
        shadow = Image.new("RGBA", output.size, (0, 0, 0, 0))
        shadow_draw = ImageDraw.Draw(shadow)
        shadow_draw.rounded_rectangle(
            (bounds[0], bounds[1] + 12, bounds[2], bounds[3] + 12),
            radius=radius,
            fill=(34, 24, 24, 70),
        )
        shadow = shadow.filter(ImageFilter.GaussianBlur(18))
        output.alpha_composite(shadow)

    plate_mask = Image.new("L", output.size, 0)
    ImageDraw.Draw(plate_mask).rounded_rectangle(bounds, radius=radius, fill=255)
    plate = gradient_background(CANVAS)
    plate.putalpha(plate_mask)
    output.alpha_composite(plate)
    output.alpha_composite(mark)
    return output


def launch_font(size: int, *, bold: bool = False, cjk: bool = False) -> ImageFont.FreeTypeFont:
    if cjk:
        candidates = (
            "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
            "/System/Library/Fonts/STHeiti Medium.ttc",
            "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
            "C:/Windows/Fonts/msyh.ttc",
        )
    elif bold:
        candidates = (
            "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
            "C:/Windows/Fonts/segoeuib.ttf",
        )
    else:
        candidates = (
            "/System/Library/Fonts/Supplemental/Arial.ttf",
            "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
            "C:/Windows/Fonts/segoeui.ttf",
        )
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    raise RuntimeError("A system font is required to generate launch branding")


def launch_branding(scale: int) -> Image.Image:
    image = Image.new("RGBA", (200 * scale, 80 * scale), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.text(
        (100 * scale, 24 * scale),
        LAUNCH_TITLE,
        anchor="mm",
        fill=LAUNCH_TITLE_COLOR,
        font=launch_font(22 * scale, bold=True),
    )
    draw.text(
        (100 * scale, 54 * scale),
        LAUNCH_TAGLINE,
        anchor="mm",
        fill=LAUNCH_SUBTITLE_COLOR,
        font=launch_font(12 * scale, cjk=True),
    )
    return image


def launch_lockup(mark: Image.Image, scale: int) -> Image.Image:
    image = Image.new("RGBA", (288 * scale, 288 * scale), (0, 0, 0, 0))
    mark_layer = contain(
        mark,
        (104 * scale, 104 * scale),
        (144 * scale, 144 * scale),
    )
    image.alpha_composite(mark_layer, (72 * scale, 28 * scale))
    draw = ImageDraw.Draw(image)
    draw.text(
        (144 * scale, 177 * scale),
        LAUNCH_TITLE,
        anchor="mm",
        fill=LAUNCH_TITLE_COLOR,
        font=launch_font(24 * scale, bold=True),
    )
    draw.text(
        (144 * scale, 210 * scale),
        LAUNCH_TAGLINE,
        anchor="mm",
        fill=LAUNCH_SUBTITLE_COLOR,
        font=launch_font(13 * scale, cjk=True),
    )
    return image


def png_data_uri(image: Image.Image) -> str:
    buffer = io.BytesIO()
    image.save(buffer, "PNG", optimize=True)
    return "data:image/png;base64," + base64.b64encode(buffer.getvalue()).decode("ascii")


def write_linux_svg(full_color: Image.Image, symbolic_mask: Image.Image) -> None:
    linux_dir = ROOT / "packaging" / "linux"
    linux_dir.mkdir(parents=True, exist_ok=True)
    scalable_apps = linux_dir / "hicolor" / "scalable" / "apps"
    symbolic_apps = linux_dir / "hicolor" / "symbolic" / "apps"
    scalable_apps.mkdir(parents=True, exist_ok=True)
    symbolic_apps.mkdir(parents=True, exist_ok=True)

    full_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 1024 1024">
  <title>Reverie</title>
  <image width="1024" height="1024" href="{png_data_uri(full_color)}"/>
</svg>
'''
    (linux_dir / "reverie.svg").write_text(full_svg, encoding="utf-8")
    (scalable_apps / "reverie.svg").write_text(full_svg, encoding="utf-8")

    symbolic_svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 1024 1024">
  <title>Reverie symbolic icon</title>
  <defs>
    <mask id="reverie-mark">
      <image width="1024" height="1024" href="{png_data_uri(symbolic_mask)}"/>
    </mask>
  </defs>
  <rect width="1024" height="1024" fill="currentColor" mask="url(#reverie-mark)"/>
</svg>
'''
    (linux_dir / "reverie-symbolic.svg").write_text(symbolic_svg, encoding="utf-8")
    (symbolic_apps / "reverie-symbolic.svg").write_text(
        symbolic_svg, encoding="utf-8"
    )


def source_icon(size: int = CANVAS) -> Image.Image:
    return Image.open(MASTER).convert("RGBA").resize(
        (size, size), Image.Resampling.LANCZOS
    )


def write_apple_catalog(catalog: Path, icon: Image.Image) -> None:
    contents = json.loads((catalog / "Contents.json").read_text(encoding="utf-8"))
    written: set[str] = set()
    for item in contents["images"]:
        filename = item.get("filename")
        if not filename or filename in written:
            continue
        points = float(item["size"].split("x")[0])
        scale = float(item["scale"].removesuffix("x"))
        pixels = round(points * scale)
        rendered = icon.resize((pixels, pixels), Image.Resampling.LANCZOS)
        if "ios" in str(catalog).lower():
            rendered = rendered.convert("RGB")
        rendered.save(catalog / filename, optimize=True)
        written.add(filename)


def main() -> None:
    LAYERS.mkdir(parents=True, exist_ok=True)
    mark = extract_mark()
    launch_source = monochrome(mark, BRAND_RED)

    # Launch surfaces use the brand mark without an app-icon plate. This keeps
    # the native canvas from showing a second, mismatched rectangle or circle.
    launch_mark = contain(launch_source, (176, 176), (256, 256))
    launch_mark.save(BRANDING / "launch_mark.png", optimize=True)
    launch_mark.save(ROOT / "web" / "icons" / "LaunchMark.png", optimize=True)

    ios_launch_dir = ROOT / "ios" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    for filename, size in (
        ("LaunchImage.png", 144),
        ("LaunchImage@2x.png", 288),
        ("LaunchImage@3x.png", 432),
    ):
        launch_mark.resize((size, size), Image.Resampling.LANCZOS).save(
            ios_launch_dir / filename, optimize=True
        )

    macos_launch_dir = (
        ROOT / "macos" / "Runner" / "Assets.xcassets" / "LaunchImage.imageset"
    )
    for filename, size in (("LaunchImage.png", 144), ("LaunchImage@2x.png", 288)):
        launch_mark.resize((size, size), Image.Resampling.LANCZOS).save(
            macos_launch_dir / filename, optimize=True
        )

    android_res = ROOT / "android" / "app" / "src" / "main" / "res"
    for density, scale in (
        ("mdpi", 1),
        ("hdpi", 1.5),
        ("xhdpi", 2),
        ("xxhdpi", 3),
        ("xxxhdpi", 4),
    ):
        pixel_scale = int(scale * 2)
        render_scale = pixel_scale
        directory = android_res / f"drawable-{density}"
        # Render at an integer multiple and resize once for half-step hdpi.
        launch_icon = contain(
            launch_source,
            (112 * render_scale, 112 * render_scale),
            (288 * render_scale, 288 * render_scale),
        )
        lockup = launch_lockup(launch_source, render_scale)
        branding = launch_branding(render_scale)
        target_scale = scale / render_scale
        for image, filename in (
            (launch_icon, "launch_image.png"),
            (lockup, "launch_lockup.png"),
            (branding, "launch_branding.png"),
        ):
            target_size = (
                round(image.width * target_scale),
                round(image.height * target_scale),
            )
            image.resize(target_size, Image.Resampling.LANCZOS).save(
                directory / filename, optimize=True
            )

    apple_mark = contain(mark, (640, 640), (CANVAS, CANVAS))
    apple_background = gradient_background(CANVAS)
    apple_monochrome = monochrome(apple_mark, (255, 255, 255))
    apple_background.save(LAYERS / "background.png", optimize=True)
    apple_mark.save(LAYERS / "foreground.png", optimize=True)
    apple_monochrome.save(LAYERS / "monochrome.png", optimize=True)

    # Preserve the supplied artwork exactly on system-masked Apple surfaces.
    ios = source_icon()
    ios.convert("RGB").save(BRANDING / "app_icon_ios.png", optimize=True)
    ios_catalog = ROOT / "ios" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    write_apple_catalog(ios_catalog, ios)

    # Icon Composer applies the current macOS/iOS mask to this full-bleed layer.
    composer_assets = LAYERS / "Reverie.icon" / "Assets"
    composer_assets.mkdir(parents=True, exist_ok=True)
    ios.save(composer_assets / "foreground.png", optimize=True)

    # Keep all distinctive parts inside Android's 66/108 dp guaranteed safe
    # zone. The extra breathing room also protects the thin wave tips.
    android_mark = contain(mark, (236, 236), (432, 432))
    android_background = gradient_background(432)
    android_mark.save(BRANDING / "app_icon_android_foreground.png", optimize=True)
    monochrome(android_mark, (255, 255, 255)).save(
        BRANDING / "app_icon_android_monochrome.png", optimize=True
    )

    density_scales = (
        ("mdpi", 1.0),
        ("hdpi", 1.5),
        ("xhdpi", 2.0),
        ("xxhdpi", 3.0),
        ("xxxhdpi", 4.0),
    )
    legacy_android = rounded_plate(
        contain(mark, (548, 548), (CANVAS, CANVAS)),
        inset=72,
        radius=220,
        draw_shadow=False,
    )
    for density, scale in density_scales:
        drawable = android_res / f"drawable-{density}"
        adaptive_size = round(108 * scale)
        for image, filename in (
            (android_background, "ic_launcher_background.png"),
            (android_mark, "ic_launcher_foreground.png"),
            (monochrome(android_mark, (255, 255, 255)), "ic_launcher_monochrome.png"),
        ):
            image.resize(
                (adaptive_size, adaptive_size), Image.Resampling.LANCZOS
            ).save(drawable / filename, optimize=True)

        legacy_size = round(48 * scale)
        mipmap = android_res / f"mipmap-{density}"
        rendered = legacy_android.resize(
            (legacy_size, legacy_size), Image.Resampling.LANCZOS
        )
        rendered.save(mipmap / "ic_launcher.png", optimize=True)
        rendered.save(mipmap / "ic_launcher_reverie.png", optimize=True)

    web_standard = source_icon(512)
    web_maskable = gradient_background(512)
    web_maskable.alpha_composite(contain(mark, (286, 286), (512, 512)))
    web_icons = ROOT / "web" / "icons"
    for filename, image, size in (
        ("Icon-192.png", web_standard, 192),
        ("Icon-512.png", web_standard, 512),
        ("Icon-maskable-192.png", web_maskable, 192),
        ("Icon-maskable-512.png", web_maskable, 512),
    ):
        image.resize((size, size), Image.Resampling.LANCZOS).save(
            web_icons / filename, optimize=True
        )
    web_standard.resize((64, 64), Image.Resampling.LANCZOS).save(
        ROOT / "web" / "favicon.png", optimize=True
    )
    web_standard.resize((64, 64), Image.Resampling.LANCZOS).save(
        ROOT / "website" / "assets" / "favicon.png", optimize=True
    )

    # Windows and Linux don't impose a consistent system mask. Keep a branded
    # plate with enough outer transparency for taskbars, launchers, and docks.
    # The Windows plate occupies about 78% of the canvas. Small taskbar/titlebar
    # frames get a separate optical master so their silhouette stays crisp and
    # does not crowd the 16/24/32 px bounds.
    windows_mark = contain(mark, (504, 504), (CANVAS, CANVAS))
    windows = rounded_plate(windows_mark, inset=112, radius=180)
    windows_small_mark = contain(mark, (464, 464), (CANVAS, CANVAS))
    windows_small = rounded_plate(windows_small_mark, inset=128, radius=168)
    windows.save(BRANDING / "app_icon_windows.png", optimize=True)
    windows_sizes = (16, 24, 32, 48, 64, 128, 256)
    windows_frames = [
        (windows_small if size <= 32 else windows).resize(
            (size, size), Image.Resampling.LANCZOS
        )
        for size in windows_sizes
    ]
    windows_frames[-1].save(
        ROOT / "windows" / "runner" / "resources" / "app_icon.ico",
        format="ICO",
        sizes=[(size, size) for size in windows_sizes],
        append_images=windows_frames[:-1],
        bitmap_format="png",
    )

    macos_mark = contain(mark, (520, 520), (CANVAS, CANVAS))
    macos = rounded_plate(macos_mark, inset=92, radius=210)
    macos.save(BRANDING / "app_icon_macos.png", optimize=True)
    macos_catalog = (
        ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    )
    write_apple_catalog(macos_catalog, macos)

    # GNOME expects app icons to leave space within the 128 px canvas and asks
    # apps not to bake shadows outside the main silhouette. KDE and other XDG
    # desktops also consume these neutral hicolor assets without a system mask.
    linux_mark = contain(mark, (504, 504), (CANVAS, CANVAS))
    linux = rounded_plate(linux_mark, inset=112, radius=180, draw_shadow=False)
    linux_small_mark = contain(mark, (464, 464), (CANVAS, CANVAS))
    linux_small = rounded_plate(
        linux_small_mark, inset=128, radius=168, draw_shadow=False
    )
    linux_dir = ROOT / "packaging" / "linux"
    linux_dir.mkdir(parents=True, exist_ok=True)
    for size in (16, 24, 32, 48, 64, 128, 256, 512):
        source = linux_small if size <= 48 else linux
        rendered = source.resize((size, size), Image.Resampling.LANCZOS)
        rendered.save(linux_dir / f"reverie-{size}.png", optimize=True)
        hicolor_apps = linux_dir / "hicolor" / f"{size}x{size}" / "apps"
        hicolor_apps.mkdir(parents=True, exist_ok=True)
        rendered.save(hicolor_apps / "reverie.png", optimize=True)
    linux_symbolic = contain(mark, (700, 700), (CANVAS, CANVAS))
    write_linux_svg(linux, monochrome(linux_symbolic, (255, 255, 255)))


if __name__ == "__main__":
    main()
