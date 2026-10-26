# auto-im-abc

一个极简、零弹窗、零状态栏图标、无需「辅助功能（Accessibility）」权限的 macOS 自动输入法切换工具。

当你在 **Terminal / Ghostty / VS Code** 和 **微信 / 飞书** 之间高频 `Cmd + Tab` 切换窗口时，自动将输入法切换为预设的英文（`ABC`）或中文（简体拼音 / Rime 等），彻底告别在终端里敲出中文拼音的烦恼。

## 为什么造这个轮子？

| 对比维度 | `auto-im-abc` (本项目) | 传统 GUI 工具 (如 Input Source Pro) | 纯 CLI (`im-select`) |
| :--- | :--- | :--- | :--- |
| **二进制体积** | **~68 KB**（单文件原生 Swift） | ~25 MB+ | ~50 KB |
| **后台触发能力** | **支持**（`NSWorkspace` 焦点事件监听） | 支持 | 不支持（仅限 Shell/Vim 钩子） |
| **系统隐私权限** | **零额外权限**（无需无障碍/辅助功能权限） | 需授予系统级「辅助功能」权限 | 零额外权限 |
| **状态栏/Dock 占用** | **完全隐形**（纯 `LaunchAgent` 守护进程） | 常驻菜单栏图标 | 无 |
| **配置热更新** | **支持**（基于文件 `mtime` 缓存，保存即生效） | GUI 设置 | 无 |

## 核心特性

- **双模合一**：既可作为 `LaunchAgent` 后台守护进程（`--daemon`）监听应用窗口切换，也可作为单次命令行工具（类似 `im-select`）在 `.zshrc` 或 Vim/Neovim `InsertLeave` 中直接调用。
- **TSM 上下文交接补偿**：针对 macOS WindowServer 在窗口激活瞬间 `TSMDocument` 交接存在 10–30ms 延迟的底层特性，采用 `0ms + 60ms + 150ms` 幂等校验机制，杜绝中文/英文输入法偶发“假切换”。
- **智能应用名称解析**：支持直接用应用名称（如 `auto-im-abc add Ghostty en`、`auto-im-abc add WeChat zh`）自动解析对应的 `CFBundleIdentifier`，无需手动查 `Info.plist`。
- **实时热加载**：直接编辑 `~/.config/auto-im-abc/apps.txt` 保存即生效，内部通过文件修改时间戳（`mtime`）缓存避免重复磁盘读取。

---

## 快速安装

确保系统已安装 Xcode Command Line Tools（`xcode-select --install`）：

```bash
git clone https://github.com/matrdreams/auto-im-abc.git
cd auto-im-abc
make install
```

*(注：`make install` 会自动将二进制编译至 `~/.local/bin/auto-im-abc`，生成默认配置 `~/.config/auto-im-abc/apps.txt`，并注册启动 `~/Library/LaunchAgents/com.auto-im-abc.plist`。)*

---

## 使用指南

### 1. 查看当前状态与规则
```bash
auto-im-abc --status
```

### 2. 添加或修改应用规则（无需手动查 Bundle ID）
```bash
# 切到 Ghostty / Terminal / VS Code / Cursor 时自动切英文 (ABC)
auto-im-abc add Ghostty en
auto-im-abc add Terminal en
auto-im-abc add "Visual Studio Code" en
auto-im-abc add Cursor en

# 切到微信时自动切简体拼音
auto-im-abc add WeChat zh
```

### 3. 移除应用规则
```bash
auto-im-abc remove WeChat
```

### 4. 查看本机已启用的所有输入法 ID
如果你使用搜狗、鼠须管（Rime）、五笔或双拼，可运行以下命令查看对应的完整 `InputSourceID`：
```bash
auto-im-abc --list-im
```

### 5. 手动编辑配置文件（保存即生效）
配置文件位于 `~/.config/auto-im-abc/apps.txt`：
```ini
com.apple.Terminal = en
com.mitchellh.ghostty = en
com.microsoft.VSCode = en
com.tencent.xinWeChat = zh
```

---

## 进阶：配合 `.zshrc` 与 Neovim 使用

如果你在终端内部临时切换过中文，希望在**同一终端窗口内按 `Cmd + T` 新建 Tab / 分屏**时也自动切回英文，可在 `~/.zshrc` 末尾加上一行零阻塞异步调用：

```zsh
[[ -x "$HOME/.local/bin/auto-im-abc" ]] && "$HOME/.local/bin/auto-im-abc" en &!
```

在 **Neovim** 中退出插入模式（按 `Esc`）时自动切回英文：
```lua
vim.api.nvim_create_autocmd("InsertLeave", {
  callback = function()
    vim.fn.jobstart({ vim.fn.expand("~/.local/bin/auto-im-abc"), "en" }, { detach = true })
  end,
})
```

---

## 卸载

```bash
make uninstall
```

## License

[MIT](./LICENSE)
