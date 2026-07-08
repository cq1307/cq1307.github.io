param(
  [Alias("Path")]
  [string]$MarkdownPath,
  [switch]$DryRun
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()

function Select-MarkdownFile {
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = [System.Windows.Forms.OpenFileDialog]::new()
  $dialog.Title = "Select a Markdown file to publish"
  $dialog.Filter = "Markdown files (*.md)|*.md|All files (*.*)|*.*"
  $dialog.Multiselect = $false
  if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    return $dialog.FileName
  }
  throw "No Markdown file selected."
}

function HtmlEncode([string]$Text) {
  return [System.Net.WebUtility]::HtmlEncode($Text)
}

function Get-Uncategorized {
  return "$([char]0x672A)$([char]0x5206)$([char]0x7C7B)"
}

function Clean-Scalar([string]$Value) {
  $v = $Value.Trim()
  if (($v.StartsWith('"') -and $v.EndsWith('"')) -or ($v.StartsWith("'") -and $v.EndsWith("'"))) {
    $v = $v.Substring(1, $v.Length - 2)
  }
  return $v.Trim()
}

function Parse-InlineList([string]$Value) {
  $v = $Value.Trim()
  if ($v.StartsWith("[") -and $v.EndsWith("]")) {
    $inner = $v.Substring(1, $v.Length - 2)
    if ([string]::IsNullOrWhiteSpace($inner)) { return @() }
    return @($inner.Split(",") | ForEach-Object { Clean-Scalar $_ } | Where-Object { $_ })
  }
  return @(Clean-Scalar $v)
}

function Parse-FrontMatter([string]$Raw) {
  $data = @{}
  $currentKey = $null
  foreach ($line in ($Raw -split "`r?`n")) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
      $currentKey = $matches[1]
      $value = $matches[2]
      if ([string]::IsNullOrWhiteSpace($value)) {
        $data[$currentKey] = @()
      } elseif ($value.Trim().StartsWith("[") -and $value.Trim().EndsWith("]")) {
        $data[$currentKey] = @(Parse-InlineList $value)
      } else {
        $data[$currentKey] = Clean-Scalar $value
      }
      continue
    }
    if ($line -match '^\s*-\s*(.+)$' -and $currentKey) {
      $existing = @($data[$currentKey])
      $data[$currentKey] = @($existing + (Clean-Scalar $matches[1]))
    }
  }
  return $data
}

function Get-FirstMarkdownTitle([string]$Markdown, [string]$Fallback) {
  foreach ($line in ($Markdown -split "`r?`n")) {
    if ($line -match '^#\s+(.+)$') { return $matches[1].Trim() }
  }
  return $Fallback
}

function Remove-MarkdownSyntax([string]$Text) {
  $s = $Text -replace '```[\s\S]*?```', ''
  $s = $s -replace '!\[[^\]]*\]\([^)]+\)', ''
  $s = $s -replace '\[([^\]]+)\]\([^)]+\)', '$1'
  $s = $s -replace '[#>*_`~-]', ''
  $s = $s -replace '\s+', ' '
  return $s.Trim()
}

function Get-Excerpt([string]$Markdown) {
  foreach ($part in ($Markdown -split "(`r?`n){2,}")) {
    $clean = Remove-MarkdownSyntax $part
    if ($clean.Length -gt 0) {
      if ($clean.Length -gt 110) { return $clean.Substring(0, 110) + "..." }
      return $clean
    }
  }
  return ""
}

function Convert-YuqueInlineText([string]$Text) {
  $s = [regex]::Replace($Text, '<([A-Za-z0-9_./+-]+\.h)>', '&lt;$1&gt;')
  $s = [regex]::Replace($s, '</?(font|span|u)\b[^>]*>', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $s = [regex]::Replace($s, '<[^>]+>', '')
  return ([System.Net.WebUtility]::HtmlDecode($s)).Trim()
}

function Convert-YuqueMarkdown([string]$Markdown) {
  $text = $Markdown
  $text = [regex]::Replace($text, '<br\s*/?>', "`n", [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  $text = [regex]::Replace($text, '<h([1-6])\b[^>]*>(.*?)</h\1>', {
    param($match)
    $level = [int]$match.Groups[1].Value
    $heading = Convert-YuqueInlineText $match.Groups[2].Value
    if ([string]::IsNullOrWhiteSpace($heading)) { return "" }
    return "`n$([string]::new('#', $level)) $heading`n"
  }, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $text = [regex]::Replace($text, '<strong\b[^>]*>(.*?)</strong>', '**$1**', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $text = [regex]::Replace($text, '<em\b[^>]*>(.*?)</em>', '*$1*', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $text = [regex]::Replace($text, '<code\b[^>]*>(.*?)</code>', '`$1`', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::Singleline)
  $text = [regex]::Replace($text, '</?(font|span|u)\b[^>]*>', '', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
  return $text
}

function Get-HashText([string]$Text, [int]$Length = 8) {
  $sha = [System.Security.Cryptography.SHA1]::Create()
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
  $hash = $sha.ComputeHash($bytes)
  return (($hash | ForEach-Object { $_.ToString("x2") }) -join "").Substring(0, $Length)
}

function Get-Slug([string]$Text, [string]$DateText) {
  $s = $Text.ToLowerInvariant()
  $s = $s -replace '[^a-z0-9]+', '-'
  $s = $s.Trim('-')
  if ($s.Length -lt 3) {
    $stamp = ($DateText -replace '[^0-9]', '')
    if ($stamp.Length -gt 8) { $stamp = $stamp.Substring(0, 8) }
    if ($stamp.Length -lt 8) { $stamp = (Get-Date).ToString("yyyyMMdd") }
    $s = "$stamp-$(Get-HashText $Text 6)"
  }
  return $s
}

function Get-AnchorId([string]$Text) {
  $id = $Text.ToLowerInvariant() -replace '[^a-z0-9\u4e00-\u9fa5]+', '-'
  $id = $id.Trim('-')
  if ($id.Length -lt 1) { $id = "h-$(Get-HashText $Text 6)" }
  return $id
}

function Convert-InlineMarkdown([string]$Text) {
  $encoded = HtmlEncode $Text
  $encoded = [regex]::Replace($encoded, '!\[([^\]]*)\]\(([^)]+)\)', '<img src="$2" alt="$1">')
  $encoded = [regex]::Replace($encoded, '\[([^\]]+)\]\(([^)]+)\)', '<a href="$2">$1</a>')
  $encoded = [regex]::Replace($encoded, '`([^`]+)`', '<code>$1</code>')
  $encoded = [regex]::Replace($encoded, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
  $encoded = [regex]::Replace($encoded, '\*([^*]+)\*', '<em>$1</em>')
  return $encoded
}

function Close-Lists([System.Collections.Generic.List[string]]$Html, [ref]$InUl, [ref]$InOl) {
  if ($InUl.Value) {
    $Html.Add("</ul>")
    $InUl.Value = $false
  }
  if ($InOl.Value) {
    $Html.Add("</ol>")
    $InOl.Value = $false
  }
}

function Convert-MarkdownToHtml([string]$Markdown) {
  $lines = ($Markdown -replace "`r`n", "`n" -replace "`r", "`n") -split "`n"
  $html = [System.Collections.Generic.List[string]]::new()
  $paragraph = [System.Collections.Generic.List[string]]::new()
  $inCode = $false
  $inUl = $false
  $inOl = $false

  function Flush-Paragraph {
    if ($paragraph.Count -gt 0) {
      $html.Add("<p>$(Convert-InlineMarkdown (($paragraph.ToArray()) -join ' '))</p>")
      $paragraph.Clear()
    }
  }

  foreach ($line in $lines) {
    if ($inCode) {
      if ($line -match '^```\s*$') {
        $html.Add("</code></pre>")
        $inCode = $false
      } else {
        $html.Add((HtmlEncode $line))
      }
      continue
    }

    if ($line -match '^```\s*([A-Za-z0-9_-]+)?\s*$') {
      Flush-Paragraph
      Close-Lists $html ([ref]$inUl) ([ref]$inOl)
      $lang = $matches[1]
      $class = if ($lang) { " class=`"language-$lang`"" } else { "" }
      $html.Add("<pre><code$class>")
      $inCode = $true
      continue
    }

    if ([string]::IsNullOrWhiteSpace($line)) {
      Flush-Paragraph
      Close-Lists $html ([ref]$inUl) ([ref]$inOl)
      continue
    }

    if ($line -match '^(#{1,6})\s+(.+)$') {
      Flush-Paragraph
      Close-Lists $html ([ref]$inUl) ([ref]$inOl)
      $level = $matches[1].Length
      $text = $matches[2].Trim()
      $id = Get-AnchorId $text
      $html.Add("<h$level id=`"$id`">$(Convert-InlineMarkdown $text)</h$level>")
      continue
    }

    if ($line -match '^\s*[-*+]\s+(.+)$') {
      Flush-Paragraph
      if ($inOl) { $html.Add("</ol>"); $inOl = $false }
      if (-not $inUl) { $html.Add("<ul>"); $inUl = $true }
      $html.Add("<li>$(Convert-InlineMarkdown $matches[1])</li>")
      continue
    }

    if ($line -match '^\s*\d+\.\s+(.+)$') {
      Flush-Paragraph
      if ($inUl) { $html.Add("</ul>"); $inUl = $false }
      if (-not $inOl) { $html.Add("<ol>"); $inOl = $true }
      $html.Add("<li>$(Convert-InlineMarkdown $matches[1])</li>")
      continue
    }

    if ($line -match '^>\s*(.+)$') {
      Flush-Paragraph
      Close-Lists $html ([ref]$inUl) ([ref]$inOl)
      $html.Add("<blockquote><p>$(Convert-InlineMarkdown $matches[1])</p></blockquote>")
      continue
    }

    $paragraph.Add($line.Trim())
  }

  Flush-Paragraph
  Close-Lists $html ([ref]$inUl) ([ref]$inOl)
  if ($inCode) { $html.Add("</code></pre>") }
  return ($html.ToArray() -join "`n")
}

function Import-LocalImages([string]$Markdown, [string]$MarkdownDir, [string]$Slug, [string]$Root) {
  $assetDir = Join-Path $Root "assets\posts\$Slug"
  return [regex]::Replace($Markdown, '!\[([^\]]*)\]\(([^)]+)\)', {
    param($match)
    $alt = $match.Groups[1].Value
    $src = $match.Groups[2].Value.Trim()
    if ($src -match '^(https?:|data:|/|#)') { return $match.Value }
    $source = Join-Path $MarkdownDir $src
    if (-not (Test-Path -LiteralPath $source -PathType Leaf)) { return $match.Value }
    if (-not (Test-Path -LiteralPath $assetDir)) {
      New-Item -ItemType Directory -Force -Path $assetDir | Out-Null
    }
    $name = [System.IO.Path]::GetFileName($source)
    $target = Join-Path $assetDir $name
    Copy-Item -LiteralPath $source -Destination $target -Force
    $webPath = "assets/posts/$Slug/$name"
    return "![$alt]($webPath)"
  })
}

function Get-SearchModalHtml {
  return @'
  <div class="search-modal" data-search-modal hidden>
    <div class="search-panel" role="dialog" aria-modal="true" aria-labelledby="search-title">
      <div class="search-head">
        <h2 id="search-title">&#25628;&#32034;</h2>
        <button class="icon-button" type="button" data-close-search aria-label="Close search">&times;</button>
      </div>
      <label class="search-box">
        <span>&#20851;&#38190;&#35789;</span>
        <input type="search" data-search-input autocomplete="off">
      </label>
      <div class="search-results" data-search-results></div>
    </div>
  </div>
'@
}

function New-ArticleHtml($Title, $Date, $Categories, $Summary, $BodyHtml) {
  $categoryText = if (@($Categories).Count) { (@($Categories) -join " > ") } else { Get-Uncategorized }
  $safeTitle = HtmlEncode $Title
  $safeCategory = HtmlEncode $categoryText
  $safeSummary = HtmlEncode $Summary
  return @"
<!DOCTYPE html>
<html lang="zh-CN">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="theme-color" content="#10201f">
  <title>$safeTitle - CQ_ Lab</title>
  <link rel="stylesheet" href="assets/styles.css?v=20260708-empty-page-hero">
</head>
<body data-page="post">
  <div class="progress" id="progress"></div>
  <header class="site-header compact">
    <nav class="navbar" aria-label="Main navigation">
      <a class="brand" href="index.html">CQ_ Lab</a>
      <button class="nav-toggle" type="button" aria-label="Open navigation" aria-expanded="false">&#9776;</button>
      <div class="nav-menu">
        <a href="index.html">&#39318;&#39029;</a>
        <a href="archives.html">&#24402;&#26723;</a>
        <a href="categories.html">&#20998;&#31867;</a>
        <a href="tags.html">&#26631;&#31614;</a>
        <a href="links.html">&#21451;&#38142;</a>
        <a href="about.html">&#20851;&#20110;</a>
        <button class="icon-button" type="button" data-open-search aria-label="Search">&#8981;</button>
      </div>
    </nav>
    <section class="post-hero">
      <p class="eyebrow">$safeCategory</p>
      <h1>$safeTitle</h1>
      <p>$Date &middot; $safeSummary</p>
    </section>
  </header>

  <main class="article-layout">
    <article class="article-body" data-article>
$BodyHtml
    </article>

    <aside class="toc">
      <p>&#30446;&#24405;</p>
      <nav data-toc></nav>
    </aside>
  </main>

  <button class="top-button" type="button" data-back-top aria-label="Back to top">&uarr;</button>
$(Get-SearchModalHtml)
  <script src="assets/posts-data.js?v=20260708-python"></script>
  <script src="assets/app.js?v=20260708-book-toc"></script>
</body>
</html>
"@
}

function Read-PostsData([string]$DataFile) {
  if (-not (Test-Path -LiteralPath $DataFile)) { return @() }
  $raw = Get-Content -LiteralPath $DataFile -Raw -Encoding UTF8
  if ($raw -notmatch '(?s)window\.BLOG_POSTS\s*=\s*(\[.*\])\s*;?\s*$') { return @() }
  $json = $matches[1]
  $parsed = $json | ConvertFrom-Json
  if ($null -eq $parsed) { return @() }
  return @($parsed | Where-Object { $_ -and $_.url })
}

function Write-PostsData([string]$DataFile, $Posts) {
  $cleanPosts = @($Posts | Where-Object { $_ -and $_.url })
  $json = ConvertTo-Json -InputObject $cleanPosts -Depth 8
  $content = "window.BLOG_POSTS = $json;`n"
  [System.IO.File]::WriteAllText($DataFile, $content, [System.Text.UTF8Encoding]::new($false))
}

if (-not $MarkdownPath) {
  $MarkdownPath = Select-MarkdownFile
}

$MarkdownPath = (Resolve-Path -LiteralPath $MarkdownPath).Path
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$assets = Join-Path $root "assets"
$dataFile = Join-Path $assets "posts-data.js"
$mdDir = Split-Path -Parent $MarkdownPath
$rawText = Get-Content -LiteralPath $MarkdownPath -Raw -Encoding UTF8

$front = @{}
$body = $rawText
if ($rawText -match '(?s)^---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)$') {
  $front = Parse-FrontMatter $matches[1]
  $body = $matches[2]
}
$body = Convert-YuqueMarkdown $body

$title = if ($front.ContainsKey("title")) { [string]$front["title"] } else { Get-FirstMarkdownTitle $body ([System.IO.Path]::GetFileNameWithoutExtension($MarkdownPath)) }
$date = if ($front.ContainsKey("date")) { [string]$front["date"] } else { (Get-Date).ToString("yyyy-MM-dd") }
$date = $date.Trim()
if ($date.Length -ge 10) { $date = $date.Substring(0, 10) }
$categories = if ($front.ContainsKey("categories")) { @($front["categories"]) } elseif ($front.ContainsKey("category")) { @($front["category"]) } else { @(Get-Uncategorized) }
$tags = if ($front.ContainsKey("tags")) { @($front["tags"]) } elseif ($front.ContainsKey("tag")) { @($front["tag"]) } else { @() }
$summary = if ($front.ContainsKey("excerpt")) { [string]$front["excerpt"] } elseif ($front.ContainsKey("summary")) { [string]$front["summary"] } else { Get-Excerpt $body }
$slug = if ($front.ContainsKey("slug")) { Get-Slug ([string]$front["slug"]) $date } else { Get-Slug $title $date }
$fileName = if ($slug.StartsWith("post-")) { "$slug.html" } else { "post-$slug.html" }
$target = Join-Path $root $fileName

$bodyForHtml = if ($DryRun) { $body } else { Import-LocalImages $body $mdDir $slug $root }
$bodyHtml = Convert-MarkdownToHtml $bodyForHtml
$articleHtml = New-ArticleHtml $title $date $categories $summary $bodyHtml

$newPost = [ordered]@{
  title = $title
  url = $fileName
  date = $date
  categories = @($categories)
  tags = @($tags)
  summary = $summary
}

if ($DryRun) {
  $newPost | ConvertTo-Json -Depth 8
  exit 0
}

Set-Content -LiteralPath $target -Value $articleHtml -Encoding UTF8

$posts = @(Read-PostsData $dataFile | Where-Object { $_.url -ne $fileName })
$posts = @($newPost) + @($posts)
$posts = @($posts | Sort-Object @{ Expression = { [string]$_.date }; Descending = $true })
Write-PostsData $dataFile $posts

Write-Host "Published: $fileName"
Write-Host "Article: $target"
Write-Host "Index updated: $dataFile"
