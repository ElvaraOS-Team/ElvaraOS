#!/bin/bash

set -e

sed -i 's/#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

sed -i 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf

pacman-key --init
pacman-key --populate archlinux


# 启用服务
systemctl enable earlyoom

systemctl enable sddm
systemctl set-default graphical.target

systemctl enable NetworkManager
systemctl enable bluetooth

systemctl disable systemd-networkd.service systemd-networkd.socket 2>/dev/null || true
systemctl disable systemd-networkd-wait-online.service 2>/dev/null || true
systemctl disable iwd.service 2>/dev/null || true

systemctl enable systemd-resolved.service 2>/dev/null || true # # 让 NetworkManager 通过 systemd-resolved 处理 DNS

# 创建 go 缓存目录
mkdir -p /build/go-cache
chmod 777 /build/go-cache


groupadd -r autologin 2>/dev/null || true
if ! id "liveuser" >/dev/null 2>&1;
then
    useradd -m -p "" -g users -G wheel,video,audio,input,storage,autologin -s /usr/bin/zsh liveuser
fi
mkdir -p /home/liveuser
cp -rT /etc/skel /home/liveuser
mkdir -p /home/liveuser/Desktop
mkdir -p /home/liveuser/.config/systemd/user/graphical-session.target.wants
ln -sf /home/liveuser/.config/systemd/user/trust-installer-desktop.service \
    /home/liveuser/.config/systemd/user/graphical-session.target.wants/trust-installer-desktop.service
echo "liveuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/liveuser



# 安装 yay
cd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R nobody:nobody yay
cd yay
# 构建
sudo -u nobody env GOPROXY=https://goproxy.cn,direct GOCACHE=/build/go-cache GOPATH=/build/go-cache makepkg --noconfirm
# 安装（用 root，不需要密码）
pacman -U --noconfirm yay-*.pkg.tar.zst
cd ..
rm -rf yay

mkdir -p /etc/sddm.conf.d
cat > /etc/sddm.conf.d/autologin.conf <<'EOF'
[Autologin]
User=liveuser
Session=cinnamon
EOF

sed -i 's/#zh_CN.UTF-8/zh_CN.UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=zh_CN.UTF-8' > /etc/locale.conf

# 设置 Plymouth 主题
cp /usr/share/pixmaps/elvara-logo-text.png /usr/share/plymouth/themes/elvara/elvara-logo-text.png
plymouth-set-default-theme -R elvara

# 注册系统图标到图标主题，供 Cinnamon 设置"关于"页面使用
mkdir -p /usr/share/icons/hicolor/256x256/apps
mkdir -p /usr/share/icons/hicolor/scalable/apps
cp /usr/share/pixmaps/elvara.png /usr/share/icons/hicolor/256x256/apps/elvara.png
cp /usr/share/pixmaps/elvara.svg /usr/share/icons/hicolor/scalable/apps/elvara.svg
cp /usr/share/pixmaps/elvara-logo-text.svg /usr/share/icons/hicolor/scalable/apps/elvara-text.svg
cp /usr/share/pixmaps/elvara-logo-text-dark.svg /usr/share/icons/hicolor/scalable/apps/elvara-text-dark.svg
cp /usr/share/pixmaps/elvara-logo-text.png /usr/share/icons/hicolor/256x256/apps/elvara-text.png
cp /usr/share/pixmaps/elvara-logo-text-dark.png /usr/share/icons/hicolor/256x256/apps/elvara-text-dark.png

# 替换 Arch Linux 图标
cp /usr/share/pixmaps/elvara.png /usr/share/pixmaps/archlinux-logo.png
cp /usr/share/pixmaps/elvara.svg /usr/share/pixmaps/archlinux-logo.svg
cp /usr/share/pixmaps/elvara-logo-text.svg /usr/share/pixmaps/archlinux-logo-text.svg
cp /usr/share/pixmaps/elvara-logo-text-dark.svg /usr/share/pixmaps/archlinux-logo-text-dark.svg

chmod +x /home/liveuser/桌面/elvara-installer.desktop
chmod +x /home/liveuser/Desktop/elvara-installer.desktop

chmod 755 /home/liveuser

chown -R liveuser:users /home/liveuser
exit 0
