#!/bin/bash

echo "Starting customization for Xiaomi CR8808 OpenWrt build..."
set -e  # 遇到错误立即退出

# 使用正确的仓库名
REPO_URL="https://github.com/xiaomude521/small-package"
BRANCH="main"  # 使用 main 分支
TEMP_DIR="package/lean/temp-repo"

# 1. 克隆整个仓库到临时目录
echo "Cloning packages from: ${REPO_URL}"
echo "Using branch: ${BRANCH}"
rm -rf "$TEMP_DIR" 2>/dev/null || true

# 尝试克隆，如果失败则尝试使用 master 分支
if ! git clone --depth=1 --branch="$BRANCH" "$REPO_URL" "$TEMP_DIR"; then
    echo "Failed to clone with branch '$BRANCH', trying 'master'..."
    BRANCH="master"
    if ! git clone --depth=1 --branch="$BRANCH" "$REPO_URL" "$TEMP_DIR"; then
        echo "Error: Failed to clone repository with both 'main' and 'master' branches"
        echo "Available branches:"
        git ls-remote --heads "$REPO_URL" | cut -f2 | cut -d'/' -f3
        exit 1
    fi
fi

echo "Successfully cloned repository with branch: $BRANCH"

# 2. 列出所有可用的包（调试信息）
echo "Available packages in the repository:"
find "$TEMP_DIR" -maxdepth 1 -type d -name "*" | sed 's|.*/||' | sort

# 3. 移动所有需要的包
move_package() {
    local pkg_name=$1
    local optional=${2:-0}  # 第二个参数表示是否可选（0=必需，1=可选）
    
    echo "Processing $pkg_name..."
    
    # 移除现有包（如果存在）
    rm -rf "package/lean/$pkg_name" 2>/dev/null || true
    
    # 检查并移动新包
    if [ -d "$TEMP_DIR/$pkg_name" ]; then
        mv "$TEMP_DIR/$pkg_name" "package/lean/"
        echo "Successfully added $pkg_name"
        return 0
    else
        echo "Warning: $pkg_name not found in the repo"
        if [ "$optional" -eq 0 ]; then
            echo "Error: Required package $pkg_name not found!"
            return 1
        else
            echo "Note: Optional package $pkg_name not found, continuing..."
            return 0
        fi
    fi
}

# 针对 CR8808 的特殊包处理
echo "Adding packages specific to Xiaomi CR8808..."

# 首先添加基础依赖包
move_package "luci-lib-xterm" 0

# 添加 Argon 主题
move_package "luci-theme-argon" 0

# 添加 iStoreOS 风格的元素
move_package "quickstart" 0
move_package "luci-app-store" 0
move_package "luci-app-quickstart" 0

# 添加 CR8808 特定的优化包
move_package "luci-app-turboacc" 1  # 网络加速（可选）
move_package "luci-app-argon-config" 1  # Argon 主题配置（可选）

# 4. 清理临时目录
rm -rf "$TEMP_DIR"

# 5. 确保依赖包也被包含在编译配置中
echo "Ensuring dependencies are included in build config..."
# 检查并添加 quickstart 到 .config
if [ -d "package/lean/quickstart" ]; then
    if grep -q "CONFIG_PACKAGE_quickstart" .config; then
        sed -i 's/^# *CONFIG_PACKAGE_quickstart/CONFIG_PACKAGE_quickstart/' .config
    else
        echo "CONFIG_PACKAGE_quickstart=y" >> .config
    fi
fi

# 检查并添加 luci-app-store 到 .config
if [ -d "package/lean/luci-app-store" ]; then
    if grep -q "CONFIG_PACKAGE_luci-app-store" .config; then
        sed -i 's/^# *CONFIG_PACKAGE_luci-app-store/CONFIG_PACKAGE_luci-app-store/' .config
    else
        echo "CONFIG_PACKAGE_luci-app-store=y" >> .config
    fi
fi

# 检查并添加 luci-app-quickstart 到 .config
if [ -d "package/lean/luci-app-quickstart" ]; then
    if grep -q "CONFIG_PACKAGE_luci-app-quickstart" .config; then
        sed -i 's/^# *CONFIG_PACKAGE_luci-app-quickstart/CONFIG_PACKAGE_luci-app-quickstart/' .config
    else
        echo "CONFIG_PACKAGE_luci-app-quickstart=y" >> .config
    fi
fi

# 6. 配置默认主题为 Argon
echo "Configuring default theme to Argon..."
if [ -d "package/lean/luci-theme-argon" ]; then
    # 修改 feeds 中的 Makefile
    if [ -f "feeds/luci/collections/luci/Makefile" ]; then
        sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile
    fi
    
    # 确保 .config 中包含 Argon 主题
    if grep -q "CONFIG_PACKAGE_luci-theme-argon" .config; then
        sed -i 's/^# *CONFIG_PACKAGE_luci-theme-argon/CONFIG_PACKAGE_luci-theme-argon/' .config
    else
        echo "CONFIG_PACKAGE_luci-theme-argon=y" >> .config
    fi
    
    # 移除 Bootstrap 主题（如果存在）
    if grep -q "CONFIG_PACKAGE_luci-theme-bootstrap" .config; then
        sed -i 's/CONFIG_PACKAGE_luci-theme-bootstrap=y/# CONFIG_PACKAGE_luci-theme-bootstrap is not set/' .config
    fi
    
    echo "Default theme set to Argon"
else
    echo "Warning: luci-theme-argon not found, cannot set as default theme"
fi

# 7. 针对 CR8808 的特殊配置
echo "Applying CR8808-specific configurations..."

# 确保无线驱动配置正确
if grep -q "CONFIG_PACKAGE_kmod-ath11k" .config; then
    echo "Ath11k wireless driver enabled for CR8808"
else
    echo "CONFIG_PACKAGE_kmod-ath11k=y" >> .config
fi

# 确保 NSS 驱动启用（针对高通芯片）
if grep -q "CONFIG_PACKAGE_kmod-qca-nss-drv" .config; then
    echo "NSS drivers enabled for CR8808"
else
    echo "CONFIG_PACKAGE_kmod-qca-nss-drv=y" >> .config
    echo "CONFIG_PACKAGE_kmod-qca-nss-drv-64=y" >> .config
fi

# 启用硬件加速
if grep -q "CONFIG_PACKAGE_kmod-qca-nss-dp" .config; then
    echo "NSS data plane enabled for hardware acceleration"
else
    echo "CONFIG_PACKAGE_kmod-qca-nss-dp=y" >> .config
fi

echo "Customization for Xiaomi CR8808 completed successfully!"