这是一个为您整理的 **Tina SDK 编译专用容器（V3版）使用说明书**。

这个 V3 版容器是基于我们之前的调试经验，修复了所有依赖缺失（如 `fakeroot`, `liblzo2`, `busybox` 等）和权限问题的**终极版本**。

---

# 全志 Tina SDK 编译环境 (V3) 使用手册

## 1. 简介
本容器环境基于 **Ubuntu 18.04** 构建，专为 **全志 (Allwinner) Tina SDK 5.0** 设计。解决了官方环境搭建复杂、32位库依赖冲突、工具链缺失（repo, mksquashfs 依赖）以及文件权限混乱等问题。

**V3 版本核心特性：**
*   ✅ **预装核心工具**：集成了 `repo` (国内源), `fakeroot`, `bison`, `flex`。
*   ✅ **修复打包错误**：预装 `liblzo2-2`, `dos2unix`, `busybox`，解决 `pack` 和 `mksquashfs` 报错。
*   ✅ **权限无缝映射**：编译生成的文件归属当前用户，而非 root，方便在宿主机管理。
*   ✅ **网络优化**：默认使用清华大学镜像源 (TUNA)。

---

## 2. 构建镜像 (Build)

如果您还没有构建镜像，请在包含 `Dockerfile` 的目录下执行以下命令。

### 2.1 准备 Dockerfile
确保您的 `Dockerfile` 内容如下（V3 终极版）：

```dockerfile
FROM ubuntu:18.04
LABEL maintainer="UserLJC <T113-Builder>"

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en

# 换源 & 开启 i386
RUN sed -i 's/archive.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    sed -i 's/security.ubuntu.com/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list && \
    dpkg --add-architecture i386 && \
    apt-get update

# 安装全量依赖
RUN apt-get install -y --no-install-recommends --fix-missing \
    build-essential subversion git-core gawk flex bison quilt make gcc g++ \
    pkg-config autoconf automake libtool libncurses5-dev zlib1g-dev libssl-dev \
    libxml-parser-perl unzip wget cpio rsync bc time file u-boot-tools xsltproc fakeroot \
    liblzo2-2 dos2unix busybox \
    lib32z1 lib32stdc++6 libc6:i386 libstdc++6:i386 libncurses5:i386 \
    python python3 python3-distutils vim sudo locales ca-certificates curl

# 安装 Repo
RUN curl -o /usr/bin/repo https://gitee.com/oschina/repo/raw/fork_flow/repo && \
    chmod a+x /usr/bin/repo

# 环境配置
RUN locale-gen en_US.UTF-8 && \
    ln -sf /usr/bin/python3 /usr/bin/python && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /home/build
CMD ["/bin/bash"]
```

### 2.2 执行构建
```bash
# 构建镜像并命名为 tina-env-v3
sudo docker build -t tina-env-v3 .
```

---

## 3. 启动容器 (Run)

这是日常使用最频繁的步骤。请使用以下命令启动容器并挂载您的 SDK 源码。

**假设您的 SDK 源码路径为：** `/home/userljc/tina-sdk`

```bash
# 建议将此命令保存为脚本，例如 run_tina.sh
docker run -it --rm \
  --name tina-builder \
  -v /home/userljc/tina-sdk:/home/build \
  -u $(id -u):$(id -g) \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  tina-env-v3 \
  /bin/bash
```

**参数详解：**
*   `-v ...:/home/build`: 将宿主机的源码目录挂载到容器内的 `/home/build`。
*   `-u $(id -u):$(id -g)`: **关键参数**。让容器使用您宿主机的用户 ID 运行，避免生成 `root` 权限的文件。
*   `-v /etc/passwd...`: 让容器能解析用户名，显示 `userljc@...` 而不是 `I have no name!`。
*   `--rm`: 退出容器后自动删除容器实例（不删镜像），保持清洁。

---

## 4. 常用操作流程

进入容器后，您的操作逻辑与在官方虚拟机中完全一致。

### 场景 A：标准编译流程
```bash
# 1. 进入源码目录 (如果挂载的是父目录)
cd tina5.0_v1.0

# 2. 初始化环境
source build/envsetup.sh

# 3. 选择板型
# 创龙 T113 MiniEVM NAND 通常选 7 (tlt113-minievm-nand)
lunch

# 4. 编译 (全速)
make -j$(nproc)

# 5. 打包生成固件
pack
```

### 场景 B：OpenWrt 移花接木 (打包 OpenWrt 内核)
当您从 GitHub Actions 获得了 `OpenWrt_Transplant_Kit` 后：

```bash
# 假设您把移植包解压到了源码目录下的 openwrt_files 文件夹

# 1. 正常编译一遍 (确保 Boot0/U-Boot 存在)
# 参考场景 A

# 2. 替换文件
cd out/t113_i/tlt113-minievm-nand/

cp ../../../openwrt_files/zImage bImage
cp ../../../openwrt_files/sun8i-t113-tronlong-minievm.dtb sunxi.dtb
cp ../../../openwrt_files/rootfs.ext4 rootfs.ext4

# 3. 重新打包
croot  # 回到源码根目录
pack
```

### 场景 C：深度清理
如果遇到莫名其妙的编译错误，建议清理后重试：
```bash
# 清理编译产物
make distclean
# 或者手动删除 out 目录 (在容器里删很安全)
rm -rf out/
```

---

## 5. 常见问题解答 (FAQ)

**Q1: 为什么提示 `sudo: command not found` 或输入密码错误？**
**A:** 我们通过 `-u` 参数模拟了当前用户，但没有配置容器内的 sudo 免密。**编译 SDK 不需要 sudo 权限。** 如果您确实需要安装新软件，请另开一个终端执行：
```bash
docker exec -u 0 -it tina-builder /bin/bash
apt-get install xxx
```

**Q2: 为什么 `pack` 时提示找不到环境变量？**
**A:** 请确保您执行了 `source build/envsetup.sh` 和 `lunch`。`pack` 命令依赖这些环境变量来找到工具路径。

**Q3: 编译出来的固件在哪？**
**A:** 在宿主机的源码目录下：`tina-sdk/tina5.0_v1.0/out/t113_i/tlt113-minievm-nand/`。

**Q4: 我可以用这个容器拉取源码吗？**
**A:** 可以。容器内置了 `repo`。
```bash
mkdir new_sdk && cd new_sdk
repo init -u <git_url> ...
repo sync -l
```
