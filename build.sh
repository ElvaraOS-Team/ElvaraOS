#!/bin/bash
# build.sh - 在当前目录构建 Arch Linux ISO

set -e
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK_DIR="/tmp/work"
OUT_DIR="./out"
TEMP_DIR="/tmp/elvaraos_build"
INSTALLER_DEST="$ROOT_DIR/airootfs/usr/local/share/ElvaraInstaller"
TOOLS_DEST="$ROOT_DIR/airootfs/usr/local/bin"

# 构建 ElvaraInstaller
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"
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

git clone --depth 1 https://github.com/ElvaraOS-Team/ElvaraOS-Toolbox.git || { echo "clone ElvaraOS-Toolbox 失败"; exit 1; }
cd ElvaraOS-Toolbox
dotnet publish ElvaraOSTools/ElvaraOSTools.csproj -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:PublishReadyToRun=true -p:PublishTrimmed=true -o publish || { echo "dotnet publish 失败"; exit 1; }
mkdir -p "$TOOLS_DEST"
cp -a publish/ElvaraOSTools "$TOOLS_DEST/ElvaraOSTools"
chmod +x "$TOOLS_DEST/ElvaraOSTools"

# 清理临时目录
cd "$ROOT_DIR"
rm -rf "$TEMP_DIR"

# 清理旧目录（避免冲突）
echo "清理旧的工作目录和输出目录..."
sudo rm -rf "$WORK_DIR" "$OUT_DIR"

# 运行 mkarchiso（需要 root 权限）
echo "开始构建 ISO，需要 root 权限..."
# 关闭 set -e 以正确捕获 mkarchiso 的退出码
set +e
sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" .
BUILD_EXIT_CODE=$?
set -e

# 检查构建结果
if [ $BUILD_EXIT_CODE -eq 0 ]; then
    echo "构建成功！ISO 文件位于 $OUT_DIR 目录下。"
    echo "正在将输出文件权限改为当前用户..."
    sudo chown -R "$USER":"$USER" "$OUT_DIR"
    
    echo "清理构建的 ElvaraInstaller 和 ElvaraOSTools..."
    rm -rf "$INSTALLER_DEST"
    rm -f "$TOOLS_DEST/ElvaraOSTools"
    
    echo "完成。"
else
    echo "构建失败，请检查错误信息。"
    exit 1
fi
