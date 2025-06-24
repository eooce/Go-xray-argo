#!/bin/bash

# 编译配置
BUILD_PATH="build"
APP_NAME="webssh"
MAIN_FILE="main.go"
COMPRESS_TYPE="zip"  # 可选 zip 或 tar.gz

# 支持的平台列表
PLATFORMS=(
    "linux/amd64"
    "linux/arm64"
    "linux/s390x"
    "windows/amd64"
    "windows/arm64"
    "darwin/amd64"
    "darwin/arm64"
    "freebsd/amd64"
)

# 清理并创建构建目录
rm -rf $BUILD_PATH
mkdir -p $BUILD_PATH

# 遍历所有平台进行编译
for platform in "${PLATFORMS[@]}"; do
    GOOS=${platform%/*}
    GOARCH=${platform#*/}
    
    # 设置输出文件名
    OUTPUT="$BUILD_PATH/${APP_NAME}_${GOOS}_${GOARCH}"
    if [ "$GOOS" = "windows" ]; then
        OUTPUT+=".exe"
    fi
    
    echo "正在编译 $GOOS/$GOARCH ..."
    
    # 执行编译
    GOOS=$GOOS GOARCH=$GOARCH CGO_ENABLED=0 \
    go build -ldflags "-extldflags -static" \
    -o $OUTPUT $MAIN_FILE
    
    # 检查是否编译成功
    if [ $? -ne 0 ]; then
        echo "编译失败: $GOOS/$GOARCH"
        exit 1
    else
        echo "编译成功: $GOOS/$GOARCH"
    fi
    
    chmod +x $OUTPUT
done

# 创建压缩包
echo "正在创建压缩包..."
cd $BUILD_PATH

case $COMPRESS_TYPE in
    "zip")
        zip -r ../${APP_NAME}.zip .
        ;;
    "tar.gz")
        tar -czvf ../${APP_NAME}.tar.gz .
        ;;
    *)
        echo "未知的压缩类型: $COMPRESS_TYPE"
        exit 1
        ;;
esac

cd ..

echo "构建完成！"
echo "压缩包已创建: ${APP_NAME}.$COMPRESS_TYPE"

# tar --exclude='web/node_modules' -czvf webssh.tar.gz -C /root/webssh . 