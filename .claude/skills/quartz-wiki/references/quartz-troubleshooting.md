# Quartz 问题排查与修复

## Frontmatter 修复脚本

在部署前对全部 md 文件批量修复 frontmatter。以下是经过验证的 Python 脚本。

### 脚本：全面修复 YAML frontmatter

```python
import os, re, yaml

wiki_dir = '/path/to/your/wiki'
fixed = []

for root, dirs, files in os.walk(wiki_dir):
    dirs[:] = [d for d in dirs if d not in ('raw', 'node_modules', '.git')]
    for fname in files:
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(root, fname)
        with open(fpath, 'r', encoding='utf-8') as f:
            content = f.read()
        if not content.startswith('---'):
            continue

        parts = content.split('---', 2)
        if len(parts) < 3:
            continue
        fm_raw = parts[1].strip()

        # 1. 修复 aliases: → also_known_as:（避免 Quartz alias 冲突）
        if 'aliases:' in fm_raw:
            fm_raw = fm_raw.replace('aliases:', 'also_known_as:')
            fixed.append((fpath, 'aliases→also_known_as'))

        # 2. 修复 YAML # 注释问题
        # "  - #6539" → '  - "6539"'
        fm_raw = re.sub(r'^(\s*-\s*)#(\d)', r'\1"\2"', fm_raw, flags=re.MULTILINE)
        # values containing # not in quotes
        fm_raw = re.sub(r':\s*(#[^\n]+)$', lambda m: f': "{m.group(1)}"' if not m.group(1).startswith('"') else m.group(0), fm_raw, flags=re.MULTILINE)

        # 3. 验证 YAML 可解析
        try:
            parsed = yaml.safe_load(fm_raw)
            if parsed is not None:
                new_content = '---\n' + fm_raw + '\n---\n' + parts[2]
                with open(fpath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
        except yaml.YAMLError as e:
            # 4. 如果仍然解析失败，强制重建为安全格式
            meta = {}
            for line in fm_raw.split('\n'):
                if not line.strip() or line.strip().startswith('#'):
                    continue
                if ':' in line:
                    key, _, val = line.partition(':')
                    key = key.strip()
                    val = val.strip()
                    if val.startswith('[') and val.endswith(']'):
                        items = [x.strip().strip("'\"") for x in val[1:-1].split(',')]
                        meta[key] = items
                    elif val:
                        meta[key] = val.strip("'\"")
                    else:
                        meta[key] = None
            fm_lines = ['---']
            for key, val in meta.items():
                if isinstance(val, list):
                    fm_lines.append(f'{key}:')
                    for item in val:
                        safe = item.replace('"', '\\"')
                        fm_lines.append(f'  - "{safe}"')
                elif val is None:
                    fm_lines.append(f'{key}:')
                else:
                    safe = str(val).replace('"', '\\"')
                    fm_lines.append(f'{key}: "{safe}"')
            fm_lines.append('---')
            new_content = '\n'.join(fm_lines) + '\n' + parts[2]
            with open(fpath, 'w', encoding='utf-8') as f:
                f.write(new_content)
            fixed.append((fpath, f'force-rebuilt: {e}'))

for fpath, reason in fixed:
    print(f'  Fixed {fpath}: {reason}')
print(f'\nTotal: {len(fixed)} files fixed')
```

## 构建错误速查

### 1. "missed comma between flow collection entries"

**原因**：YAML 值中包含 `#` 被当做注释。

```yaml
# 错误
aliases: [foo, #6539, bar]

# 修复
also_known_as:
  - foo
  - "6539"
  - bar
```

### 2. "ENOTEMPTY: directory not empty" / AliasRedirects 崩溃

**原因**：frontmatter 中的 `aliases:` 与 Quartz 的 URL 别名重定向功能冲突。

```yaml
# 错误
aliases: [SNOT, Studs Not On Top]

# 修复
also_known_as: [SNOT, Studs Not On Top]
```

### 3. "Invalid URL" (404 page emitter)

**原因**：`baseUrl` 为空字符串。

```typescript
// 错误
baseUrl: "",

// 修复
baseUrl: "https://your-domain.com",
```

### 4. 内容没更新 / 读到旧内容

**原因**：
- Windows symlink 缓存了旧文件内容
- `.quartz-cache` 缓存了旧的解析结果

```bash
# 修复
rm -rf .quartz-cache public
rm -rf content
cp -r /path/to/wiki content
npx quartz build
```

### 5. 图片不显示

**检查**：
- 图片 URL 是否以 `![](url)` 格式（不是 `[image](url)`）
- 外链图片的域名是否可访问（`curl -I <url>` 检查）
- Quartz 不会处理外链图片，直接透传给 HTML

### 6. [[wikilinks]] 不跳转

**检查**：
- 目标概念文件是否存在（文件名必须匹配 wikilink 中的文本）
- `markdownLinkResolution` 配置：`"shortest"` 最灵活，`"absolute"` 最精确
- 中文文件名中的 `[[SNOT技法]]` 会链接到 `content/SNOT技法.md`

### 7. 中文 URL 编码问题

Quartz 会对中文文件名进行 URL 编码：
- `SNOT技法.md` → `/concepts/SNOT%E6%8A%80%E6%B3%95`
- 浏览器中正常显示中文，这是标准行为
- 如需简短 URL，在 frontmatter 中添加 `slug: "snot"` （但注意与别名冲突的可能性）

## 性能优化

### 加速构建

```typescript
// 关闭 OG 图片生成（最大的性能消耗）
// Plugin.CustomOgImages(),

// 减少并发（默认使用所有 CPU 核心）
// 通过环境变量控制
// QUARTZ_BUILD_CONCURRENCY=2 npx quartz build
```

### 减小产物体积

- `ignorePatterns` 排除不需要的目录（如 `raw/`、`drafts/`）
- 检查是否意外包含了大文件（`.zip`、`.pdf`）
- 外链图片不会增加产物体积

### 图片数量过多

如果某个概念条目有数百张图片：
- 考虑裁剪到 50 张以内的精选图片
- 大量图片会影响页面加载速度
