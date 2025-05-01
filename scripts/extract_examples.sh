#!/bin/bash

# extract_examples.sh
# 提取 README.md 中的案例信息并输出为 JSON 格式
# 用法：./scripts/extract_examples.sh > examples.json

set -e

# 定义输入文件
README="./README.md"

# 检查文件是否存在
if [ ! -f "$README" ]; then
    echo "错误：找不到 $README 文件" >&2
    exit 1
fi

# 开始 JSON 数组
echo "["

# 获取案例部分的开始行号
START_LINE=$(grep -n '<a id="examples-' "$README" | head -1 | cut -d: -f1)
if [ -z "$START_LINE" ]; then
    echo "错误：找不到案例部分的开始标记" >&2
    exit 1
fi

# 使用 awk 提取所有案例信息
awk -v start="$START_LINE" '
BEGIN {
    in_example = 0
    first_example = 1
    current_id = ""
    current_title = ""
    current_author = ""
    current_description = ""
    current_prompt = ""
    current_alt = ""
    current_sourceLink = ""
    current_requiresReference = "false"
    current_referenceNote = ""
    in_prompt = 0
    prompt_start = 0
    prompt_content = ""
    image_description = ""
}

# 检测案例开始
/^<a id="examples-[0-9]+"><\/a>$/ {
    if (in_example && current_id != "") {
        output_example()
        reset_variables()
    }
    
    in_example = 1
    current_id = gensub(/^<a id="examples-([0-9]+)"><\/a>$/, "\\1", "g")
}

# 提取案例标题和作者 - 多种可能的格式
in_example && /^## 案例 [0-9]+[：:]\s*/ {
    title_line = $0
    
    # 尝试从标题行提取标题和作者
    if (match(title_line, /^## 案例 [0-9]+[：:]\s+(.*)\s+\(by\s+\[(.*)\]\((https?:\/\/[^)]+)\)\)/, arr)) {
        # 带URL的格式: "## 案例 N：标题 (by [@作者](url))"
        current_title = arr[1]
        current_author = arr[2]
    } else if (match(title_line, /^## 案例 [0-9]+[：:]\s+(.*)\s+\(by\s+\[(.*)\]/, arr)) {
        # 标准格式: "## 案例 N：标题 (by [@作者])"
        current_title = arr[1]
        current_author = arr[2]
    } else if (match(title_line, /^## 案例 [0-9]+[：:]\s+(.*)\s+\(by\s+(.*)\)/, arr)) {
        # 变体1: "## 案例 N：标题 (by 作者)"
        current_title = arr[1]
        current_author = arr[2]
    } else {
        # 只提取标题，作者未知
        match(title_line, /^## 案例 [0-9]+[：:]\s+(.*)/, arr)
        if (arr[1]) {
            current_title = arr[1]
            # 尝试从标题中分离作者信息
            if (match(current_title, /(.*)\s+\(by\s+(.*)\)$/, title_arr)) {
                current_title = title_arr[1]
                current_author = title_arr[2]
            } else {
                current_author = "未知"
            }
        } else {
            current_title = "未知标题"
            current_author = "未知"
        }
    }
    
    # 清理可能的尾部括号和多余空格
    gsub(/ \(by.*$/, "", current_title)
    gsub(/^[ \t]+|[ \t]+$/, "", current_title)
    gsub(/^[ \t]+|[ \t]+$/, "", current_author)
    
    # 清理可能的URL部分
    gsub(/\(https?:\/\/[^)]+\)/, "", current_author)
}

# 提取原文链接
in_example && /^\[原文链接.*\]/ {
    if (current_sourceLink == "") {
        match($0, /^\[原文链接.*\]\((.*)\)/, arr)
        if (arr[1]) {
            current_sourceLink = arr[1]
        }
    }
}

# 提取图片链接和替代文本
in_example && /<img src="(.*)" width="[0-9]+" alt="(.*)"/ {
    match($0, /<img src="(.*)" width="[0-9]+" alt="(.*)"/, arr)
    current_imageUrl = arr[1]
    current_alt = arr[2]
    # 保存图片描述作为可能的描述备用
    if (image_description == "" && current_alt != "") {
        image_description = current_alt
    }
}

# 提取提示词段落标记 - 方式1
in_example && /^\*\*提示词[：:]\*\*$|^\*\*提示词模板[：:]\*\*$|^提示词[：:]$/ {
    prompt_start = 1
    next_line = ""
    if (getline next_line > 0) {
        if (next_line == "```") {
            in_prompt = 1
        } else {
            # 直接使用这行作为提示词开始
            if (prompt_content == "") {
                prompt_content = next_line
            }
            prompt_start = 0
        }
    }
}

# 提取提示词块开始 - 方式2
in_example && /^```$/ && !in_prompt && !prompt_start {
    next_line = ""
    getline next_line
    if (next_line ~ /提示词[：:]/ || next_line ~ /提示词模板[：:]/) {
        in_prompt = 1
        # 提取提示词标识后的内容
        sub(/^提示词[：:]\s*/, "", next_line)
        sub(/^提示词模板[：:]\s*/, "", next_line)
        if (next_line != "" && prompt_content == "") {
            prompt_content = next_line
        }
    } else {
        # 如果下一行不是提示词标记，把两行都放回处理流
        $0 = "```\n" next_line
    }
}

# 检测提示词内容
in_example && in_prompt {
    if ($0 == "```") {
        in_prompt = 0
    } else if ($0 !~ /^提示词[：:]/ && $0 !~ /^提示词模板[：:]/) {
        if (prompt_content == "") {
            prompt_content = $0
        } else {
            prompt_content = prompt_content "\\n" $0
        }
    }
}

# 检测是否需要参考图片
in_example && /\*\*需上传参考图片：\*\*/ {
    current_requiresReference = "true"
    match($0, /\*\*需上传参考图片：\*\* (.*)/, arr)
    if (arr[1]) {
        current_referenceNote = arr[1]
    }
}

# 处理描述 - 检查可能的描述内容
in_example && /^[^<>*#\[].*[.。！？]$/ {
    if (current_description == "" && !in_prompt && $0 !~ /^\*注/) {
        current_description = $0
    }
}

# 检测案例结束（下一个案例开始或案例部分结束）
/^\[⬆️ 返回案例目录\]/ {
    if (in_example && current_id != "") {
        output_example()
        reset_variables()
    }
    in_example = 0
}

END {
    # 确保处理最后一个案例
    if (in_example && current_id != "") {
        output_example()
    }
}

# 函数：输出当前收集的案例数据
function output_example() {
    # 如果没有收集到提示词，尝试使用描述
    if (current_prompt == "" && prompt_content != "") {
        current_prompt = prompt_content
    }
    
    # 如果没有描述但有图像替代文本，使用它作为描述
    if (current_description == "" && image_description != "") {
        current_description = image_description
    }
    
    # 如果标题为空，尝试从alt提取
    if (current_title == "" && current_alt != "") {
        current_title = current_alt
    }
    
    if (first_example) {
        first_example = 0
    } else {
        printf ",\n"
    }
    
    printf "  {\n"
    printf "    \"id\": \"%s\",\n", current_id
    printf "    \"title\": \"%s\",\n", escape_json(current_title)
    printf "    \"author\": \"%s\",\n", escape_json(current_author)
    
    if (current_description != "") {
        printf "    \"description\": \"%s\",\n", escape_json(current_description)
    }
    
    printf "    \"prompt\": \"%s\",\n", escape_json(current_prompt)
    printf "    \"alt\": \"%s\",\n", escape_json(current_alt)
    
    if (current_imageUrl != "") {
        printf "    \"imageUrl\": \"%s\",\n", escape_json(current_imageUrl)
    }
    
    if (current_sourceLink != "") {
        printf "    \"sourceLink\": \"%s\",\n", escape_json(current_sourceLink)
    }
    
    printf "    \"requiresReference\": %s", current_requiresReference
    
    if (current_referenceNote != "" && current_requiresReference == "true") {
        printf ",\n    \"referenceNote\": \"%s\"", escape_json(current_referenceNote)
    }
    
    printf "\n  }"
}

# 函数：重置变量以处理下一个案例
function reset_variables() {
    current_id = ""
    current_title = ""
    current_author = ""
    current_description = ""
    current_prompt = ""
    current_alt = ""
    current_imageUrl = ""
    current_sourceLink = ""
    current_requiresReference = "false"
    current_referenceNote = ""
    in_prompt = 0
    prompt_start = 0
    prompt_content = ""
    image_description = ""
}

# 函数：转义 JSON 特殊字符
function escape_json(str) {
    gsub(/\\/, "\\\\", str)
    gsub(/"/, "\\\"", str)
    gsub(/\n/, "\\n", str)
    gsub(/\r/, "\\r", str)
    gsub(/\t/, "\\t", str)
    return str
}
' "$README"

# 结束 JSON 数组
echo -e "\n]"