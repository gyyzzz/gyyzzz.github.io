#!/bin/bash
# AI博客文章生成脚本
# 每日生成一篇AI技术文章草稿到 _drafts 目录

BLOG_DIR="$HOME/gyyzzz.github.io"
DRAFTS_DIR="$BLOG_DIR/_drafts"
POSTS_DIR="$BLOG_DIR/_posts"
DATE=$(date +%Y-%m-%d)
TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

# 主题轮换：LLM动态、实战教程、论文解读
THEMES=("llm-dynamics" "tutorials" "paper-reading")
THEME_INDEX=$(($(date +%j) % 3))
THEME=${THEMES[$THEME_INDEX]}

# 根据主题设置标题前缀
case $THEME in
    "llm-dynamics")
        TITLE_PREFIX="LLM技术动态"
        ;;
    "tutorials")
        TITLE_PREFIX="AI实战教程"
        ;;
    "paper-reading")
        TITLE_PREFIX="论文解读"
        ;;
esac

# 生成文件名（使用时间戳避免冲突）
FILENAME="${DATE}-${THEME}-draft.md"
DRAFT_FILE="$DRAFTS_DIR/$FILENAME"

# 检查今天是否已有草稿
if [ -f "$DRAFT_FILE" ]; then
    echo "[$TIMESTAMP] 今日草稿已存在: $FILENAME"
    exit 0
fi

# 创建草稿模板
cat > "$DRAFT_FILE" << 'ARTICLE_EOF'
---
title: "待填写标题"
layout: post
category: CATEGORY_PLACEHOLDER
date: DATE_PLACEHOLDER
---

> 此文章由AI助手自动生成草稿，请审核后发布。

## 概述

[在此填写文章概述]

## 主要内容

[在此填写主要内容]

### 要点一

[详细说明]

### 要点二

[详细说明]

## 代码示例

```python
# 示例代码
```

## 实践建议

1. 建议一
2. 建议二
3. 建议三

## 总结

[总结内容]

---

*参考资料：*
- [参考链接1]()
- [参考链接2]()
ARTICLE_EOF

# 替换占位符
sed -i '' "s/CATEGORY_PLACEHOLDER/$THEME/g" "$DRAFT_FILE"
sed -i '' "s/DATE_PLACEHOLDER/$DATE/g" "$DRAFT_FILE"

echo "[$TIMESTAMP] 草稿已生成: $FILENAME"
echo "主题: $THEME"
echo "文件: $DRAFT_FILE"

# 可选：自动提交到git（创建草稿分支）
cd "$BLOG_DIR"
git checkout -b "draft/$DATE" 2>/dev/null || git checkout "draft/$DATE"
git add "$DRAFT_FILE"
git commit -m "docs: 添加 $DATE 草稿文章 ($THEME)"
git push origin "draft/$DATE" 2>/dev/null || git push -u origin "draft/$DATE"

echo "草稿已推送到分支: draft/$DATE"