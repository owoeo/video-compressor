import os
import sys
import json
from PIL import Image, ImageDraw

# ------------------------- 配置 -------------------------
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192
}

IOS_SIZES = [
    (20, [1, 2, 3]),
    (29, [1, 2, 3]),
    (40, [1, 2, 3]),
    (60, [2, 3]),
    (76, [1, 2]),
    (83.5, [2]),
    (1024, [1])
]

MACOS_SIZES = [16, 32, 64, 128, 256, 512, 1024]
MACOS_PADDING_RATIO = 0.1
MACOS_CORNER_RATIO = 0.2
# -------------------------------------------------------

def resize_and_save(img, size, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    resized = img.resize((int(size), int(size)), Image.LANCZOS)
    resized.save(path, format="PNG")

# ------------------------- Android -------------------------
def generate_android_icons(img, flutter_project_path):
    res_dir = os.path.join(flutter_project_path, "android", "app", "src", "main", "res")
    if not os.path.exists(res_dir):
        return
    print("📱 Generating Android icons...")
    for folder, size in ANDROID_SIZES.items():
        folder_path = os.path.join(res_dir, folder)
        os.makedirs(folder_path, exist_ok=True)
        path = os.path.join(folder_path, "ic_launcher.png")
        resize_and_save(img, size, path)

# ------------------------- iOS -------------------------
def generate_ios_icons(img, flutter_project_path):
    ios_path = os.path.join(flutter_project_path, "ios", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if not os.path.exists(os.path.dirname(ios_path)):
        return
    print("🍏 Generating iOS icons...")
    os.makedirs(ios_path, exist_ok=True)
    images_json = []
    for base_size, scales in IOS_SIZES:
        for scale in scales:
            size_px = int(base_size * scale)
            filename = f"icon_{base_size}x{base_size}@{scale}x.png"
            path = os.path.join(ios_path, filename)
            resize_and_save(img, size_px, path)
            images_json.append({
                "size": f"{base_size}x{base_size}",
                "idiom": "ios-marketing" if base_size == 1024 else "iphone",
                "filename": filename,
                "scale": f"{scale}x"
            })
    generate_ios_contents_json(images_json, ios_path)

def generate_ios_contents_json(images, path):
    contents = {"images": images, "info": {"version": 1, "author": "xcode"}}
    with open(os.path.join(path, "Contents.json"), "w") as f:
        json.dump(contents, f, indent=2)
    print("✅ Contents.json generated.")

# ------------------------- macOS -------------------------
def add_rounded_corners_centered(im, target_size, padding, corner_ratio):
    """
    im: 缩放到 target_size 的原图
    target_size: 最终 canvas 尺寸（包括留白）
    padding: 留白大小
    corner_ratio: 圆角占图像显示区域比例
    """
    canvas = Image.new("RGBA", (target_size, target_size), (0, 0, 0, 0))
    # 将图像居中粘贴
    pos = (padding, padding)
    canvas.paste(im, pos)
    
    # 圆角半径
    radius = int((target_size - 2 * padding) * corner_ratio)
    
    mask = Image.new("L", (target_size, target_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle(
        [(padding, padding), (target_size - padding, target_size - padding)],
        radius=radius,
        fill=255
    )
    canvas.putalpha(mask)
    return canvas

def generate_macos_icons(img, flutter_project_path, padding_ratio=0.1, corner_ratio=0.2):
    print("💻 Generating macOS icons with centered rounded corners...")
    iconset_path = os.path.join(flutter_project_path, "macos", "Runner", "Assets.xcassets", "AppIcon.appiconset")
    if not os.path.exists(os.path.dirname(iconset_path)):
        return
    os.makedirs(iconset_path, exist_ok=True)

    for size in MACOS_SIZES:
        for scale in [1, 2]:
            size_px = size * scale
            padding = int(size_px * padding_ratio)
            display_size = size_px - 2 * padding
            resized = img.resize((display_size, display_size), Image.LANCZOS)
            
            final_img = add_rounded_corners_centered(resized, size_px, padding, corner_ratio)
            filename = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
            path = os.path.join(iconset_path, filename)
            final_img.save(path, format="PNG")

    # 生成 Contents.json
    images_json = []
    for size in MACOS_SIZES:
        for scale in [1, 2]:
            images_json.append({
                "size": f"{size}x{size}",
                "idiom": "mac",
                "filename": f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png",
                "scale": f"{scale}x"
            })
    generate_ios_contents_json(images_json, iconset_path)

# ------------------------- 自动检测 Flutter 项目路径 -------------------------
def detect_flutter_project():
    cwd = os.getcwd()
    if any(os.path.exists(os.path.join(cwd, d)) for d in ["android", "ios", "macos"]):
        return cwd
    print("❌ Cannot detect Flutter project in current directory.")
    sys.exit(1)

# ------------------------- 主函数 -------------------------
if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python generate_flutter_icons.py <path_to_512x512_image> [flutter_project_path]")
        sys.exit(1)

    input_path = sys.argv[1]
    if len(sys.argv) >= 3:
        flutter_project_path = sys.argv[2]
    else:
        flutter_project_path = detect_flutter_project()

    if not os.path.exists(input_path):
        print(f"❌ File not found: {input_path}")
        sys.exit(1)

    img = Image.open(input_path).convert("RGBA")

    generate_android_icons(img, flutter_project_path)
    generate_ios_icons(img, flutter_project_path)
    generate_macos_icons(img, flutter_project_path)

    print("🎯 All icons generated and placed into Flutter project successfully!")