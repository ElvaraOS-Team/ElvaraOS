#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
# 把工作目录和输出目录放在项目目录下，避免 /tmp 空间不足
WORK_DIR="$ROOT_DIR/work"
OUTPUT_DIR="$ROOT_DIR/output"
TEMP_DIR="$ROOT_DIR/temp_build"
INSTALLER_DEST="$ROOT_DIR/airootfs/usr/local/share/ElvaraInstaller"
TOOLS_DEST="$ROOT_DIR/airootfs/usr/local/bin"

# 版本核对：检查 profiledef.sh 的 iso_version 是否与 publish_info.md 第一行一致
PROFILE_VERSION=$(grep -oP '^iso_version="\K[^"]+' "$ROOT_DIR/profiledef.sh") || { echo "错误：无法从 profiledef.sh 读取 iso_version"; exit 1; }
PUBLISH_VERSION=$(head -1 "$ROOT_DIR/publish_info.md" | grep -oP 'v\K[0-9.]+') || { echo "错误：无法从 publish_info.md 第一行读取版本号"; exit 1; }

if [ "$PROFILE_VERSION" != "$PUBLISH_VERSION" ]; then
    echo "错误：版本不匹配！"
    echo "  profiledef.sh iso_version: $PROFILE_VERSION"
    echo "  publish_info.md 版本:     $PUBLISH_VERSION"
    exit 1
fi
echo "版本核对通过: v$PROFILE_VERSION"

# 清理之前的目录
rm -rf "$WORK_DIR" "$OUTPUT_DIR" "$TEMP_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR" "$TEMP_DIR"

# 安装依赖
for cmd in dotnet python3 git mkarchiso; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "$cmd 未找到，正在安装..."
    case "$cmd" in
      dotnet) pkg="dotnet-sdk" ;;
      python3) pkg="python" ;;
      git) pkg="git" ;;
      mkarchiso) pkg="archiso" ;;
    esac
    pacman -Sy --needed --noconfirm "$pkg" || { echo "安装 $pkg 失败"; exit 1; }
  fi
done

# 构建 ElvaraInstaller
cd "$TEMP_DIR"
git clone https://github.com/ElvaraOS-Team/ElvaraInstaller.git || { echo "clone ElvaraInstaller 失败"; exit 1; }
cd ElvaraInstaller
git checkout dev_custom
git clone https://github.com/EveGlowLuna/shorin-arch-setup-elvarainstaller custom/shorin-arch-setup

python3 -m venv venv
source venv/bin/activate
python3 -m pip install --upgrade pip
pip install -r requirements.txt
chmod +x ./package.sh
./package.sh
deactivate

mkdir -p "$INSTALLER_DEST"
cp -a dist/ElvaraInstaller "$INSTALLER_DEST/"
cp -a custom "$INSTALLER_DEST/"
chmod +x "$INSTALLER_DEST/ElvaraInstaller"

# 构建 ElvaraOSTools
cd "$TEMP_DIR"
rm -rf ElvaraInstaller

git clone https://github.com/ElvaraOS-Team/ElvaraOS-Toolbox.git || { echo "clone ElvaraOS-Toolbox 失败"; exit 1; }
cd ElvaraOS-Toolbox
dotnet publish ElvaraOSTools/ElvaraOSTools.csproj \
  -c Release -r linux-x64 --self-contained true \
  -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true \
  -p:PublishReadyToRun=true -p:PublishTrimmed=true -o publish || { echo "dotnet publish 失败"; exit 1; }

mkdir -p "$TOOLS_DEST"
cp -a publish/ElvaraOSTools "$TOOLS_DEST/ElvaraOSTools"
chmod +x "$TOOLS_DEST/ElvaraOSTools"

# 清理临时目录
rm -rf "$TEMP_DIR"

# 构建 ISO
cd "$ROOT_DIR"
mkdir -p "$WORK_DIR" "$OUTPUT_DIR"
mkarchiso -v -w "$WORK_DIR" -o "$OUTPUT_DIR" . || { echo "mkarchiso 构建失败"; exit 1; }
chmod +x "$OUTPUT_DIR"/*.iso

echo "构建成功，ISO 在 $OUTPUT_DIR"
exit 0