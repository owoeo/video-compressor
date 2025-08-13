import os
import sys
import subprocess
import pathlib

def create_dmg(app_path: str):
    # 检查路径
    app_path = pathlib.Path(app_path).resolve()
    if not app_path.exists() or not app_path.suffix == ".app":
        print(f"❌ 路径无效: {app_path}")
        sys.exit(1)

    # 输出 DMG 文件名
    dmg_name = app_path.stem + ".dmg"
    dmg_path = app_path.parent / dmg_name

    # create-dmg 参数
    cmd = [
        "create-dmg",
        "--volname", app_path.stem,
        "--window-size", "600", "400",
        "--icon-size", "100",
        "--icon", app_path.name, "200", "200",
        "--hide-extension", app_path.name,
        "--app-drop-link", "400", "200",
        str(dmg_path),
        str(app_path)
    ]

    print(f"📦 正在生成 DMG: {dmg_path}")
    try:
        subprocess.run(cmd, check=True)
        print(f"✅ DMG 生成完成: {dmg_path}")
    except subprocess.CalledProcessError as e:
        print(f"❌ 生成 DMG 失败: {e}")
def build_macos_app(flutter_project_path):
    try:
        subprocess.run(["flutter", "build", "macos"], cwd=flutter_project_path, check=True)
    except subprocess.CalledProcessError as e:
        print(f"❌ 构建 macOS 应用失败: {e}")
        sys.exit(1)
    

if __name__ == "__main__":
    if len(sys.argv) != 1:
        print("用法: python create_dmg.py")
        sys.exit(1)
    build_macos_app('.')
    create_dmg('build/macos/Build/Products/Release/compress.app')