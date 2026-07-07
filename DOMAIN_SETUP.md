# 自定义域名接入

这个目录已经可以作为 GitHub Pages 的网站根目录。

## 1. 设置域名

双击：

```text
set-domain.bat
```

按提示输入：

```text
你的域名
GitHub 用户名
```

脚本会生成 `CNAME` 文件，并在终端里打印 DNS 记录。

也可以用命令行：

```powershell
.\set-domain.ps1 -Domain "blog.example.com" -GitHubUser "your-github-name"
```

## 2. 上传到 GitHub Pages

把 `outputs` 里的所有文件上传到你的 GitHub Pages 仓库根目录。

推荐仓库名：

```text
your-github-name.github.io
```

仓库设置：

```text
Settings -> Pages -> Deploy from a branch -> main -> /root
```

然后在：

```text
Settings -> Pages -> Custom domain
```

填入你的域名。

## 3. DNS 填法

子域名，例如 `blog.example.com` 或 `www.example.com`：

```text
CNAME  blog/www  your-github-name.github.io
```

裸域名，例如 `example.com`：

```text
A  @  185.199.108.153
A  @  185.199.109.153
A  @  185.199.110.153
A  @  185.199.111.153
```

DNS 生效后，回到 GitHub Pages 勾选 `Enforce HTTPS`。
