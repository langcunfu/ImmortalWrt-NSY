#!/bin/bash

# 修改默认IP
# sed -i 's/192.168.1.1/10.0.0.1/g' package/base-files/files/bin/config_generate

# 更改默认 Shell 为 zsh
# sed -i 's/\/bin\/ash/\/usr\/bin\/zsh/g' package/base-files/files/etc/passwd

# TTYD 免登录
# sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# 拉取仓库文件夹
merge_package() {
	# 参数1是分支名,参数2是库地址,参数3是所有文件下载到指定路径。
	# 同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开。
	# 示例:
	# merge_package master https://github.com/WYC-2020/openwrt-packages package/openwrt-packages luci-app-eqos luci-app-openclash luci-app-ddnsto ddnsto 
	# merge_package master https://github.com/lisaac/luci-app-dockerman package/lean applications/luci-app-dockerman
	if [[ $# -lt 3 ]]; then
		echo "Syntax error: [$#] [$*]" >&2
		return 1
	fi
	trap 'rm -rf "$tmpdir"' EXIT
	branch="$1" curl="$2" target_dir="$3" && shift 3
	rootdir="$PWD"
	localdir="$target_dir"
	[ -d "$localdir" ] || mkdir -p "$localdir"
	tmpdir="$(mktemp -d)" || exit 1
        echo "开始下载：$(echo $curl | awk -F '/' '{print $(NF)}')"
	git clone -b "$branch" --depth 1 --filter=blob:none --sparse "$curl" "$tmpdir"
	cd "$tmpdir"
	git sparse-checkout init --cone
	git sparse-checkout set "$@"
	# 使用循环逐个移动文件夹
	for folder in "$@"; do
		mv -f "$folder" "$rootdir/$localdir"
	done
	cd "$rootdir"
}

# Git稀疏克隆，只克隆指定目录到本地
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../package
  cd .. && rm -rf $repodir
}

# Themes
# git clone --depth=1 -b 18.06 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon
# git clone --depth=1 https://github.com/jerrykuku/luci-app-argon-config package/luci-app-argon-config
# merge_package master https://github.com/coolsnowwolf/luci feeds/luci/themes themes/luci-theme-design

# 更改 Argon 主题背景
rm -rf feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/background/*
# cp -f $GITHUB_WORKSPACE/images/bg1.jpg feeds/luci/themes/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg
# mkdir -p package/luci-theme-argon/htdocs/luci-static/argon/img
# cp -f $GITHUB_WORKSPACE/images/bg1.jpg package/luci-theme-argon/htdocs/luci-static/argon/img/bg1.jpg

# iStore
# git_sparse_clone main https://github.com/linkease/istore-ui app-store-ui
# git_sparse_clone main https://github.com/linkease/istore luci

# 为固件版本加上编译作者
author="xiaomeng9597"
sed -i "s/DISTRIB_DESCRIPTION.*/DISTRIB_DESCRIPTION='%D %V %C by ${author}'/g" package/base-files/files/etc/openwrt_release
sed -i "s/OPENWRT_RELEASE.*/OPENWRT_RELEASE=\"%D %V %C by ${author}\"/g" package/base-files/files/usr/lib/os-release
cp -f $GITHUB_WORKSPACE/configfiles/99-default-settings-chinese package/emortal/default-settings/files/99-default-settings-chinese

# 修改 Makefile
# find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/luci.mk/\$(TOPDIR)\/feeds\/luci\/luci.mk/g' {}
# find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/..\/..\/lang\/golang\/golang-package.mk/\$(TOPDIR)\/feeds\/packages\/lang\/golang\/golang-package.mk/g' {}
# find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHREPO/PKG_SOURCE_URL:=https:\/\/github.com/g' {}
# find package/*/ -maxdepth 2 -path "*/Makefile" | xargs -i sed -i 's/PKG_SOURCE_URL:=@GHCODELOAD/PKG_SOURCE_URL:=https:\/\/codeload.github.com/g' {}

# samba解除root限制
# sed -i 's/invalid users = root/#&/g' feeds/packages/net/samba4/files/smb.conf.template

# 最大连接数修改为65535
sed -i '/customized in this file/a net.netfilter.nf_conntrack_max=65535' package/base-files/files/etc/sysctl.conf

# 集成CPU性能跑分脚本
cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64 package/base-files/files/bin/coremark-arm64
cp -f $GITHUB_WORKSPACE/configfiles/coremark/coremark-arm64.sh package/base-files/files/bin/coremark.sh
chmod 755 package/base-files/files/bin/coremark-arm64
chmod 755 package/base-files/files/bin/coremark.sh

# 定时限速插件
git clone --depth=1 https://github.com/sirpdboy/luci-app-eqosplus package/luci-app-eqosplus

rm -rf package/OpenAppFilter
merge_package master https://github.com/destan19/OpenAppFilter.git package/OpenAppFilter
rm -rf feeds package/feeds
./scripts/feeds update -a

# Step1 修改ruby Makefile，移除YJIT带来的rust/host依赖（feeds install之前！）
sed -i '/^PKG_BUILD_DEPENDS:=/c\PKG_BUILD_DEPENDS:=ruby/host' feeds/packages/lang/ruby/Makefile

# Step2 校验：打印ruby Makefile的PKG_BUILD_DEPENDS行，方便在Action日志查看结果
echo "===== Check ruby Makefile PKG_BUILD_DEPENDS ====="
grep PKG_BUILD_DEPENDS feeds/packages/lang/ruby/Makefile
echo "=================================================="

# ===== 修改samba4镜像源，删除http地址 =====
sed -i '/http:\/\/www.nic.funet.fi/d' feeds/packages/net/samba4/Makefile
sed -i '/http:\/\/samba.mirror.bit.nl/d' feeds/packages/net/samba4/Makefile
# ===== feeds install =====

# 删除rust包源码，彻底杜绝rust host编译报错
rm -rf feeds/packages/lang/rust

rm -rf feeds/packages.tmp
./scripts/feeds install -a -f

# 查找所有包含 rust/host 的Makefile
echo "===== Search PKG_BUILD_DEPENDS rust/host ====="
grep -r "rust/host" package/ feeds/ || echo "Not found"
echo "=============================================="

# ========== 【重要】如果你保留 rm -rf rust，下面三行必须删掉！==========
# sed -i 's/ci-llvm=true/ci-llvm=false/g' feeds/packages/lang/rust/Makefile
# sed -i '/^PKG_VERSION:=/c\PKG_VERSION:=1.93.0' feeds/packages/lang/rust/Makefile
# sed -i '/^PKG_HASH:=/c\PKG_HASH:=e30d898272c587a22f77679f03c5e8192b5645c7c9ccc3407ad1106761507cea' feeds/packages/lang/rust/Makefile

export DOWNLOAD_METHOD="wget"
export DOWNLOAD_TIMEOUT=240
export DOWNLOAD_RETRY=5
