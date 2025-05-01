#!/usr/bin/env python
# -*- coding: utf-8 -*-

import re
import os
import json
import argparse

def extract_examples_cn(markdown_content):
    """从中文README提取案例信息"""
    examples = []
    
    pattern = r'## 案例 (\d+)：(.*?)（作者：\[@?([^()]+)\](?:\(([^()]+)\))?\）\s*\n\s*(?:\[原文链接\]\(([^\)]+)\))?\s*(?:\n\s*(?:\[原文链接\s*\d*\]\(([^\)]+)\))?)?\s*(?:\n\s*(?:\[原文链接\s*\d*\]\(([^\)]+)\))?)?\s*\n\s*<img src="(.*?)" width="(?:\d+)" alt="(.*?)">\s*\n\s*\*\*提示词(?:\s+模板)?：\*\*\s*\n```\s*([\s\S]*?)```'
    
    matches = re.finditer(pattern, markdown_content, re.DOTALL)
    
    for match in matches:
        try:
            case_num = match.group(1)
            title = match.group(2)
            author = match.group(3)
            author_link = match.group(4) if match.group(4) else ""
            original_link = match.group(5) if match.group(5) else ""
            if match.group(6):  # 处理可能存在的多个原文链接
                if isinstance(original_link, list):
                    original_link.append(match.group(6))
                else:
                    original_link = [original_link, match.group(6)]
                if match.group(7):
                    if isinstance(original_link, list):
                        original_link.append(match.group(7))
                    else:
                        original_link = [original_link, match.group(7)]
            
            image_path = match.group(8)
            image_alt = match.group(9)
            prompt = match.group(10).strip()
            
            example = {
                "case_number": int(case_num),
                "title": title,
                "author": author,
                "author_link": author_link,
                "original_link": original_link,
                "image_path": image_path,
                "image_alt": image_alt,
                "prompt": prompt
            }
            
            examples.append(example)
        except Exception as e:
            print(f"处理案例时出错，案例号: {case_num if 'case_num' in locals() else '未知'}: {e}")
    
    # 按案例编号排序
    examples.sort(key=lambda x: x['case_number'])
    
    return examples

def extract_examples_en(markdown_content):
    """从英文README提取案例信息"""
    examples = []
    
    pattern = r'## Example (\d+): (.*?) \(by \[@?([^()]+)\](?:\(([^()]+)\))?\)\s*\n\s*(?:\[Source Link(?:\s*\d*)\]\(([^\)]+)\))?\s*(?:\n\s*(?:\[Source Link(?:\s*\d*)\]\(([^\)]+)\))?)?\s*(?:\n\s*(?:\[Source Link(?:\s*\d*)\]\(([^\)]+)\))?)?\s*\n\s*<img src="(.*?)" width="(?:\d+)" alt="(.*?)">\s*\n\s*\*\*Prompt(?:\s+Template)?:?\*\*\s*\n```\s*([\s\S]*?)```'
    
    matches = re.finditer(pattern, markdown_content, re.DOTALL)
    
    for match in matches:
        try:
            case_num = match.group(1)
            title = match.group(2)
            author = match.group(3)
            author_link = match.group(4) if match.group(4) else ""
            original_link = match.group(5) if match.group(5) else ""
            if match.group(6):  # 处理可能存在的多个原文链接
                if isinstance(original_link, list):
                    original_link.append(match.group(6))
                else:
                    original_link = [original_link, match.group(6)]
                if match.group(7):
                    if isinstance(original_link, list):
                        original_link.append(match.group(7))
                    else:
                        original_link = [original_link, match.group(7)]
            
            image_path = match.group(8)
            image_alt = match.group(9)
            prompt = match.group(10).strip()
            
            example = {
                "case_number": int(case_num),
                "title": title,
                "author": author,
                "author_link": author_link,
                "original_link": original_link,
                "image_path": image_path,
                "image_alt": image_alt,
                "prompt": prompt
            }
            
            examples.append(example)
        except Exception as e:
            print(f"Error processing match for case {case_num if 'case_num' in locals() else 'unknown'}: {e}")
    
    # 按案例编号排序
    examples.sort(key=lambda x: x['case_number'])
    
    return examples

def main():
    # 添加命令行参数解析
    parser = argparse.ArgumentParser(description='从README文件中提取案例信息')
    parser.add_argument('-i', '--input', help='输入的README文件路径',
                        default=None)
    parser.add_argument('-o', '--output', help='输出的JSON文件路径',
                        default=None)
    parser.add_argument('-l', '--language', help='语言 (cn 或 en)',
                        choices=['cn', 'en'], default=None)
    args = parser.parse_args()
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    # 获取项目根目录
    root_dir = os.path.dirname(script_dir)
    
    # 如果没有指定输入文件，则根据语言选择默认路径
    if args.input is None:
        if args.language == 'en':
            readme_path = os.path.join(root_dir, "README_en.md")
            output_file = os.path.join(root_dir, "examples_en.json") if args.output is None else args.output
        elif args.language == 'cn':
            readme_path = os.path.join(root_dir, "README.md")
            output_file = os.path.join(root_dir, "examples.json") if args.output is None else args.output
        else:
            # 如果没有指定语言，则尝试根据文件名推断
            if os.path.exists(os.path.join(root_dir, "README_en.md")):
                readme_path = os.path.join(root_dir, "README_en.md")
                args.language = 'en'
                output_file = os.path.join(root_dir, "examples_en.json") if args.output is None else args.output
            else:
                readme_path = os.path.join(root_dir, "README.md")
                args.language = 'cn'
                output_file = os.path.join(root_dir, "examples.json") if args.output is None else args.output
    else:
        readme_path = args.input
        
        # 如果没有指定输出文件，则根据输入文件名生成
        if args.output is None:
            base_name = os.path.basename(readme_path)
            base_name_without_ext = os.path.splitext(base_name)[0]
            if base_name_without_ext.endswith('_en'):
                output_file = os.path.join(root_dir, "examples_en.json")
            else:
                output_file = os.path.join(root_dir, "examples.json")
        else:
            output_file = args.output
        
        # 如果没有指定语言，则尝试根据文件名推断
        if args.language is None:
            if '_en' in readme_path:
                args.language = 'en'
            else:
                args.language = 'cn'
    
    # 检查输入文件是否存在
    if not os.path.exists(readme_path):
        print(f"错误: 找不到输入文件 {readme_path}")
        return
    
    with open(readme_path, 'r', encoding='utf-8') as f:
        markdown_content = f.read()
    
    # 根据语言选择提取函数
    if args.language == 'en':
        examples = extract_examples_en(markdown_content)
        print(f"Extracted {len(examples)} examples from English README")
    else:
        examples = extract_examples_cn(markdown_content)
        print(f"从中文README中提取到 {len(examples)} 个案例")
    
    # 确保输出目录存在
    output_dir = os.path.dirname(output_file)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(examples, f, ensure_ascii=False, indent=2)
    
    if args.language == 'en':
        print(f"Examples saved to {output_file}")
    else:
        print(f"案例数据已保存至 {output_file}")

if __name__ == "__main__":
    main()