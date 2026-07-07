# CQ_ Lab Blog

这是一个纯静态博客，可以直接打开 `index.html` 预览。

## 发布 Markdown 文章

最省事的方式：

1. 按 `sample-post.md` 的格式写好 Markdown。
2. 双击 `publish-md.bat`。
3. 在弹出的文件选择框里选你的 `.md`。
4. 脚本会自动生成文章 HTML，并更新首页、归档、分类、标签和搜索数据。

也可以在 PowerShell 里手动运行：

```powershell
.\publish-md.ps1 -MarkdownPath "C:\path\to\your-post.md"
```

支持的 front matter：

```markdown
---
title: 文章标题
date: 2026-07-07
categories:
  - Reverse
tags:
  - CTF
  - 学习笔记
excerpt: 首页和搜索里显示的一句话摘要。
---
```

脚本会处理常见 Markdown：标题、段落、列表、引用、链接、图片、代码块。相对路径图片会被复制到 `assets/posts/文章slug/`。

文章索引在 `assets/posts-data.js`，页面渲染逻辑在 `assets/app.js`。

## 接入自定义域名

双击 `set-domain.bat`，输入你的域名和 GitHub 用户名。脚本会生成 GitHub Pages 需要的 `CNAME` 文件，并打印 DNS 记录。

详细步骤见 `DOMAIN_SETUP.md`。
