#!/bin/bash
# 截图重命名与移动脚本
# 使用方法：
#   1. 将你的 5 张截图放到 docs/images/raw/ 目录中
#   2. 按拍摄顺序重命名为 1.png ~ 5.png（或保持原始文件名）
#   3. 运行此脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGES_DIR="$SCRIPT_DIR/images"
RAW_DIR="$IMAGES_DIR/raw"

# 创建目录
mkdir -p "$RAW_DIR"

# 定义目标文件名映射（按文档中引用的顺序）
declare -A FILE_MAP
FILE_MAP=(
    ["1"]="step2_select_any_mac"          # 图1: 选择 Any Mac 作为 Build Destination
    ["2"]="step3_product_archive"          # 图2: Product > Archive 菜单
    ["3"]="step3_organizer_archives"       # 图3: Organizer Archives 列表
    ["4"]="step4_distribute_method"        # 图4: 选择分发方式
    ["5"]="step5_app_store_connect"        # 图5: App Store Connect 提交页面
)

echo "============================================"
echo "  📸 Xcode 上传指南 - 截图重命名工具"
echo "============================================"
echo ""

# 检查 raw 目录是否有文件
if [ -z "$(ls -A "$RAW_DIR" 2>/dev/null)" ]; then
    echo "⚠️  请先将 5 张截图放入以下目录："
    echo "    $RAW_DIR"
    echo ""
    echo "📋 截图对应关系："
    echo "    1.png → 选择 Any Mac 作为 Build Destination"
    echo "    2.png → Product > Archive 菜单"
    echo "    3.png → Organizer Archives 列表"
    echo "    4.png → 选择分发方式（App Store Connect / TestFlight）"
    echo "    5.png → App Store Connect 提交审核页面"
    echo ""
    echo "将文件命名为 1.png、2.png ... 5.png 后再运行此脚本。"
    exit 1
fi

echo "🔍 检测到以下原始截图文件："
ls -1 "$RAW_DIR"
echo ""

# 遍历并重命名
RENAMED=0
for num in 1 2 3 4 5; do
    # 查找对应编号的文件（支持 png、jpg、jpeg、webp）
    SOURCE=""
    for ext in png jpg jpeg webp PNG JPG JPEG WEBP; do
        if [ -f "$RAW_DIR/$num.$ext" ]; then
            SOURCE="$RAW_DIR/$num.$ext"
            TARGET_EXT="$ext"
            break
        fi
    done

    if [ -n "$SOURCE" ]; then
        TARGET_NAME="${FILE_MAP[$num]}"
        TARGET="$IMAGES_DIR/${TARGET_NAME}.${TARGET_EXT}"
        cp "$SOURCE" "$TARGET"
        echo "  ✅ $num.$TARGET_EXT → ${TARGET_NAME}.${TARGET_EXT}"
        RENAMED=$((RENAMED + 1))
    else
        echo "  ⏭️  未找到 $num.* — 跳过 (${FILE_MAP[$num]})"
    fi
done

echo ""
echo "============================================"
echo "  处理完成！共重命名 $RENAMED 张截图"
echo "============================================"
echo ""

if [ "$RENAMED" -gt 0 ]; then
    echo "📂 截图已保存到: $IMAGES_DIR/"
    echo ""
    echo "📋 文件列表："
    ls -1 "$IMAGES_DIR"/*.* 2>/dev/null || echo "  （无文件）"
    echo ""
    echo "✨ 文档中的图片引用将自动生效！"
fi
