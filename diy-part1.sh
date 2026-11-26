#!/bin/bash
# ==============================================================================
# DIY Part 1: 在拉取 feeds 之前执行 (Feeds 订阅配置与自定义插件源初始化)
# ==============================================================================

set -e

echo "=================================================="
echo "--> 执行 DIY Part 1: 配置自定义 Feed 与插件源码..."
echo "=================================================="

# 1. 解除官方 Feeds 的 Commit 静态锁定，全面跟踪 openwrt-25.12 官方最新维护分支以获取最新包修复
sed -i -E 's/\^[0-9a-fA-F]+/;openwrt-25.12/g' feeds.conf.default

# 2. 准备 package/custom-apps 目录
mkdir -p package/custom-apps

# 3. 将仓库内内置的 package/custom-apps (如 luci-app-iptv-seven-days) 复制到构建树中
if [ -d "$GITHUB_WORKSPACE/package/custom-apps" ]; then
    echo "--> 正在导入本地自定义插件 (package/custom-apps)..."
    cp -r "$GITHUB_WORKSPACE/package/custom-apps/"* package/custom-apps/ 2>/dev/null || true
elif [ -d "$GITHUB_WORKSPACE/custom-apps" ]; then
    echo "--> 正在导入本地自定义插件 (custom-apps)..."
    cp -r "$GITHUB_WORKSPACE/custom-apps/"* package/custom-apps/ 2>/dev/null || true
fi

# 4. 克隆外部独立维护的自定义插件仓库
echo "--> 正在同步外部自定义插件仓库..."
[ ! -d "package/custom-apps/luci-app-lucky" ] && git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/custom-apps/luci-app-lucky || true
[ ! -d "package/custom-apps/openwrt-daede" ] && git clone --depth=1 https://github.com/kenzok8/openwrt-daede.git package/custom-apps/openwrt-daede || true
[ ! -d "package/custom-apps/rtp2httpd" ] && git clone --depth=1 https://github.com/stackia/rtp2httpd.git package/custom-apps/rtp2httpd || true
[ ! -d "package/custom-apps/openwrt-honk" ] && git clone --depth=1 https://github.com/kenzok8/openwrt-honk.git package/custom-apps/openwrt-honk || true

# SQM 使用官方 feeds 中的 sqm-scripts / luci-app-sqm，无需克隆源码
# 新增 LuCI 插件：gaobin89 的上网时间控制 (js 分支)、sirpdboy 的设备关机插件
# 仓库内 Makefile 位于同名子目录，feeds install -a 会递归扫描注册
echo "--> 正在同步时间控制与关机插件源码..."
[ ! -d "package/custom-apps/gaobin89-timecontrol/.git" ] && git clone --depth=1 -b js https://github.com/gaobin89/luci-app-timecontrol.git package/custom-apps/gaobin89-timecontrol || true
[ ! -d "package/custom-apps/luci-app-poweroffdevice/.git" ] && git clone --depth=1 -b master https://github.com/sirpdboy/luci-app-poweroffdevice.git package/custom-apps/luci-app-poweroffdevice || true

# Vantage 主题与实时仪表盘（anothaDev，main 分支，专为 25.12 构建）
# 仓库内 4 个平级包：luci-theme-vantage / luci-app-vantage / luci-app-vantage-aps / luci-app-vantage-traffic
# feeds install -a 会递归扫描注册；本次只启用主题+仪表盘，aps/traffic 保持未选
[ ! -d "package/custom-apps/luci-theme-vantage/.git" ] && git clone --depth=1 -b main https://github.com/anothaDev/luci-theme-vantage.git package/custom-apps/luci-theme-vantage || true

# 同步 Passwall 官方维护的最权威 Loyalsoldier v2ray-geodata 规则包 (支持 telegram 标签)
echo "--> 正在同步 Loyalsoldier v2ray-geodata 规则包定义..."
mkdir -p package/custom-apps/v2ray-geodata
curl -fsSL "https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall-packages/main/v2ray-geodata/Makefile" \
  -o package/custom-apps/v2ray-geodata/Makefile

# 规避 Alpine apk 因 12 位与 14 位时间戳判定失准导致的假更新：版本号尾部补齐 00 秒数对齐 14 位规范
sed -i -E 's/VERSION:=\$\(GEOSITE_VER\)\.\$\(PKG_RELEASE\)/VERSION:=\$\(GEOSITE_VER\)00.\$\(PKG_RELEASE\)/' package/custom-apps/v2ray-geodata/Makefile
sed -i -E 's/VERSION:=\$\(GEOIP_VER\)\.\$\(PKG_RELEASE\)/VERSION:=\$\(GEOIP_VER\)00.\$\(PKG_RELEASE\)/' package/custom-apps/v2ray-geodata/Makefile

# 5. 注册 custom 本地 Feed
sed -i -E '/^[[:space:]]*src-link[[:space:]]+custom[[:space:]]+/d' feeds.conf.default
printf '\nsrc-link custom %s/package/custom-apps\n' "$PWD" >> feeds.conf.default

echo "--> DIY Part 1 执行完成！feeds.conf.default 配置如下："
cat feeds.conf.default
