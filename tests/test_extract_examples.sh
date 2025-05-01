#!/bin/bash

# test_extract_examples.sh
# 测试提取脚本是否正确工作
# 用法: ./tests/test_extract_examples.sh

set -e

# 颜色定义
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "开始测试案例提取脚本..."

# 检查提取脚本是否存在
if [ ! -f "./scripts/extract_examples.sh" ]; then
    echo -e "${RED}错误：extract_examples.sh 脚本不存在${NC}"
    exit 1
fi

# 执行提取脚本并将输出保存到临时文件
TEMP_FILE=$(mktemp)
./scripts/extract_examples.sh > "$TEMP_FILE"

# 检查输出是否为有效的JSON
if ! jq empty "$TEMP_FILE" 2>/dev/null; then
    echo -e "${RED}错误：输出不是有效的JSON${NC}"
    rm "$TEMP_FILE"
    exit 1
fi

# 获取案例数量
EXAMPLE_COUNT=$(jq length "$TEMP_FILE")
if [ "$EXAMPLE_COUNT" -eq 0 ]; then
    echo -e "${RED}错误：未提取到任何案例${NC}"
    rm "$TEMP_FILE"
    exit 1
fi

echo -e "${GREEN}成功提取了 $EXAMPLE_COUNT 个案例${NC}"

# 验证案例字段
echo "验证案例数据完整性..."

# 检查必需字段
MISSING_FIELDS=0
for field in "id" "title" "author" "prompt" "alt" "requiresReference"; do
    FIELD_COUNT=$(jq "[.[] | has(\"$field\")] | all" "$TEMP_FILE")
    if [ "$FIELD_COUNT" != "true" ]; then
        echo -e "${RED}错误：有案例缺少必需字段 '$field'${NC}"
        MISSING_FIELDS=$((MISSING_FIELDS + 1))
    fi
done

if [ "$MISSING_FIELDS" -gt 0 ]; then
    echo -e "${RED}错误：发现 $MISSING_FIELDS 个缺失字段问题${NC}"
    # 显示第一个有问题的案例作为示例
    PROBLEM_EXAMPLE=$(jq '[.[] | select(has("id") and has("title") and has("author") and has("prompt") and has("alt") and has("requiresReference") | not)] | first' "$TEMP_FILE")
    echo "问题案例示例: $PROBLEM_EXAMPLE"
    rm "$TEMP_FILE"
    exit 1
fi

# 检查reference字段的一致性
REFERENCE_ISSUES=$(jq '[.[] | select(.requiresReference == true and (has("referenceNote") | not))] | length' "$TEMP_FILE")
if [ "$REFERENCE_ISSUES" -gt 0 ]; then
    echo -e "${RED}警告：有 $REFERENCE_ISSUES 个案例标记为需要参考图片但没有referenceNote字段${NC}"
fi

# 打印几个样本案例以供人工检查
echo -e "\n样本案例 (前2个):"
jq '.[0:2]' "$TEMP_FILE"

# 检查案例ID序列是否连续
echo -e "\n检查案例ID序列..."
EXPECTED_COUNT=$(jq '.[].id | tonumber' "$TEMP_FILE" | sort -n | tail -1)
if [ "$EXAMPLE_COUNT" -ne "$EXPECTED_COUNT" ]; then
    echo -e "${RED}警告：案例数量 ($EXAMPLE_COUNT) 与最大ID ($EXPECTED_COUNT) 不一致，可能有ID缺失${NC}"
    echo "缺失的ID: $(jq -c 'map(.id | tonumber) as $ids | range(1; ($ids | max) + 1) | select(. as $i | $ids | index($i) | not)' "$TEMP_FILE")"
fi

echo -e "\n${GREEN}测试完成！${NC}"
rm "$TEMP_FILE"