"""Generate app icon — just the mask logo, fully transparent background."""
from PIL import Image
import os, subprocess, shutil

BASE = os.path.dirname(__file__)
SRC = os.path.join(BASE, "..", "OffVeil", "Resources", "Assets.xcassets",
    "OffVeilLogoActive.imageset", "offveilactive.png")
RESOURCES = os.path.join(BASE, "..", "OffVeil", "Resources")
ICONSET = os.path.join(RESOURCES, "AppIcon.iconset")
ICNS = os.path.join(RESOURCES, "AppIcon.icns")

SIZE = 1024
LOGO_RATIO = 0.75

# Fully transparent background
canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

logo = Image.open(SRC).convert("RGBA")
new_w = int(SIZE * LOGO_RATIO)
new_h = int(new_w * logo.size[1] / logo.size[0])
logo_r = logo.resize((new_w, new_h), Image.LANCZOS)

x, y = (SIZE - new_w) // 2, (SIZE - new_h) // 2
canvas.paste(logo_r, (x, y), logo_r)

# Create .iconset
if os.path.exists(ICONSET):
    shutil.rmtree(ICONSET)
os.makedirs(ICONSET)

sizes = {
    "icon_16x16.png": 16, "icon_16x16@2x.png": 32,
    "icon_32x32.png": 32, "icon_32x32@2x.png": 64,
    "icon_128x128.png": 128, "icon_128x128@2x.png": 256,
    "icon_256x256.png": 256, "icon_256x256@2x.png": 512,
    "icon_512x512.png": 512, "icon_512x512@2x.png": 1024,
}
for name, px in sizes.items():
    canvas.resize((px, px), Image.LANCZOS).save(os.path.join(ICONSET, name), "PNG")

subprocess.run(["iconutil", "-c", "icns", ICONSET, "-o", ICNS], check=True)
shutil.rmtree(ICONSET)

# Also update asset catalog
ICON_DIR = os.path.join(BASE, "..", "OffVeil", "Resources", "Assets.xcassets", "AppIcon.appiconset")
for f in os.listdir(ICON_DIR):
    if f.startswith("icon_") and f.endswith(".png"):
        os.remove(os.path.join(ICON_DIR, f))
for sz in [16, 32, 64, 128, 256, 512, 1024]:
    canvas.resize((sz, sz), Image.LANCZOS).save(os.path.join(ICON_DIR, f"icon_{sz}x{sz}.png"), "PNG")

print("done")
