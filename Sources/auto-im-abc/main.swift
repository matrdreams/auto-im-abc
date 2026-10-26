import Cocoa
import Carbon

// MARK: - Constants & Paths

let defaultEnglishCandidateIDs = [
    "com.apple.keylayout.ABC",
    "com.apple.keylayout.US",
    "com.apple.keylayout.USInternational-PC",
    "com.apple.keylayout.British"
]

let defaultChineseCandidateIDs = [
    "com.apple.inputmethod.SCIM.ITABC",              // macOS 系统简体拼音
    "com.tencent.inputmethod.wetype.pinyin",         // 微信输入法
    "com.sogou.inputmethod.sogou.pinyin",            // 搜狗输入法
    "im.rime.inputmethod.Squirrel.Hans",             // 鼠须管 (Rime)
    "com.bytedance.inputmethod.doubaoime.pinyin",    // 豆包输入法
    "com.baidu.inputmethod.BaiduIM.pinyin",          // 百度输入法
    "com.apple.inputmethod.SCIM.WBX",                // macOS 系统五笔
    "com.apple.inputmethod.TCIM.Pinyin"              // macOS 繁体拼音
]

let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
let configDir = "\(homeDir)/.config/auto-im-abc"
let configPath = "\(configDir)/apps.txt"

let defaultAppRules: [String: String] = [
    "com.apple.Terminal": "en",
    "com.mitchellh.ghostty": "en",
    "com.microsoft.VSCode": "en",
    "com.tencent.xinWeChat": "zh"
]

// MARK: - Input Source Management (Carbon HIToolbox)

func listEnabledKeyboardInputSources() -> [(id: String, name: String)] {
    let filter = [
        kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
        kTISPropertyInputSourceIsSelectCapable as String: kCFBooleanTrue as Any
    ] as CFDictionary

    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource] else {
        return []
    }

    var results: [(id: String, name: String)] = []
    for source in list {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
            continue
        }
        let id = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        results.append((id: id, name: name))
    }
    return results
}

/// Dynamically resolves a logical token ("en", "zh", alias, or exact ID) against the input sources
/// actually installed and enabled on the current Mac, with graceful fallback.
func resolveInputSourceID(_ token: String) -> String {
    let enabledIDs = Set(listEnabledKeyboardInputSources().map { $0.id })

    func firstEnabled(from candidates: [String], fallbackPrefix: String? = nil) -> String {
        for id in candidates where enabledIDs.contains(id) {
            return id
        }
        if let prefix = fallbackPrefix,
           let match = enabledIDs.first(where: { $0.hasPrefix(prefix) }) {
            return match
        }
        return candidates[0]
    }

    switch token.lowercased() {
    case "en", "abc", "english", "us":
        return firstEnabled(from: defaultEnglishCandidateIDs, fallbackPrefix: "com.apple.keylayout.")
    case "zh", "cn", "pinyin", "chinese", "scim":
        return firstEnabled(from: defaultChineseCandidateIDs, fallbackPrefix: "com.apple.inputmethod.")
    case "wetype", "wechat":
        return firstEnabled(from: ["com.tencent.inputmethod.wetype.pinyin"] + defaultChineseCandidateIDs)
    case "sogou":
        return firstEnabled(from: ["com.sogou.inputmethod.sogou.pinyin"] + defaultChineseCandidateIDs)
    case "rime", "squirrel":
        return firstEnabled(from: ["im.rime.inputmethod.Squirrel.Hans", "im.rime.inputmethod.Squirrel.Hant"] + defaultChineseCandidateIDs)
    case "doubao":
        return firstEnabled(from: ["com.bytedance.inputmethod.doubaoime.pinyin"] + defaultChineseCandidateIDs)
    default:
        // If user wrote an explicit InputSourceID that isn't installed on this machine,
        // gracefully fall back if it looks like a keyboard layout or Chinese IME.
        if enabledIDs.contains(token) {
            return token
        }
        if token.hasPrefix("com.apple.keylayout.") {
            return firstEnabled(from: defaultEnglishCandidateIDs, fallbackPrefix: "com.apple.keylayout.")
        }
        return firstEnabled(from: defaultChineseCandidateIDs)
    }
}

func currentInputSourceID() -> String? {
    guard let current = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
          let ptr = TISGetInputSourceProperty(current, kTISPropertyInputSourceID) else {
        return nil
    }
    return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
}

func switchInputSourceIfNeeded(to targetTokenOrID: String) {
    let targetID = resolveInputSourceID(targetTokenOrID)
    if currentInputSourceID() == targetID {
        return
    }

    let filter = [kTISPropertyInputSourceID as String: targetID] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let source = list.first else {
        return
    }
    TISSelectInputSource(source)
}

// MARK: - Config File Parsing & Hot-Reload Cache

var cachedRules: [String: String] = defaultAppRules
var lastConfigModDate: Date? = nil

func loadAppRules(forceReload: Bool = false) -> [String: String] {
    if !forceReload,
       let attrs = try? FileManager.default.attributesOfItem(atPath: configPath),
       let modDate = attrs[.modificationDate] as? Date {
        if let lastMod = lastConfigModDate, lastMod == modDate {
            return cachedRules
        }
        lastConfigModDate = modDate
    }

    var rules = defaultAppRules
    if let content = try? String(contentsOfFile: configPath, encoding: .utf8) {
        var parsedRules: [String: String] = [:]
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            let parts = trimmed.split(separator: "=", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if parts.count == 2 {
                parsedRules[parts[0]] = parts[1]
            } else if parts.count == 1 {
                parsedRules[parts[0]] = "en"
            }
        }
        if !parsedRules.isEmpty {
            rules = parsedRules
        }
    }
    cachedRules = rules
    return rules
}

func ensureConfigFileExists() {
    let fm = FileManager.default
    if !fm.fileExists(atPath: configDir) {
        try? fm.createDirectory(atPath: configDir, withIntermediateDirectories: true)
    }
    if !fm.fileExists(atPath: configPath) {
        let initialContent = """
        # 格式: BundleID = en (自动匹配本机英文输入法) | zh (自动匹配本机中文输入法) | <指定输入法别名或完整ID>
        # 支持别名: en, zh, wetype(微信输入法), sogou(搜狗), rime(鼠须管), doubao(豆包)
        # 若指定的输入法在当前电脑未安装，会自动降级回退到本机已启用的同语种输入法。
        # 本文件支持实时热加载，修改保存后立即生效，无需重启服务。

        com.apple.Terminal = en
        com.mitchellh.ghostty = en
        com.microsoft.VSCode = en
        com.tencent.xinWeChat = zh
        
        """
        try? initialContent.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - App Name / Path to Bundle ID Resolution

func resolveBundleID(_ input: String) -> String {
    if input.contains(".") && !input.hasSuffix(".app") && !input.contains("/") {
        return input
    }

    if input.hasSuffix(".app") || input.contains("/") {
        let expanded = NSString(string: input).expandingTildeInPath
        if let bundle = Bundle(path: expanded), let id = bundle.bundleIdentifier {
            return id
        }
    }

    for app in NSWorkspace.shared.runningApplications {
        if let name = app.localizedName, name.caseInsensitiveCompare(input) == .orderedSame,
           let id = app.bundleIdentifier {
            return id
        }
    }

    let candidateDirs = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        "\(homeDir)/Applications"
    ]
    let cleanName = input.hasSuffix(".app") ? String(input.dropLast(4)) : input
    for dir in candidateDirs {
        let appPath = "\(dir)/\(cleanName).app"
        if let bundle = Bundle(path: appPath), let id = bundle.bundleIdentifier {
            return id
        }
    }

    return input
}

// MARK: - CLI Rule Mutations

func addOrUpdateRule(appInput: String, targetToken: String) {
    ensureConfigFileExists()
    let bundleID = resolveBundleID(appInput)

    let content = (try? String(contentsOfFile: configPath, encoding: .utf8)) ?? ""
    var lines = content.components(separatedBy: .newlines)
    var updated = false

    for i in 0..<lines.count {
        let trimmed = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        let key = trimmed.split(separator: "=", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key == bundleID {
            lines[i] = "\(bundleID) = \(targetToken)"
            updated = true
            break
        }
    }

    if !updated {
        if !lines.isEmpty && !(lines.last?.isEmpty ?? true) {
            lines.append("\(bundleID) = \(targetToken)")
        } else if !lines.isEmpty {
            lines[lines.count - 1] = "\(bundleID) = \(targetToken)"
            lines.append("")
        } else {
            lines.append("\(bundleID) = \(targetToken)")
        }
    }

    let output = lines.joined(separator: "\n")
    try? output.write(toFile: configPath, atomically: true, encoding: .utf8)
    print("Updated rule: \(bundleID) = \(targetToken) (resolves on this Mac to: \(resolveInputSourceID(targetToken)))")
}

func removeRule(appInput: String) {
    ensureConfigFileExists()
    let bundleID = resolveBundleID(appInput)
    guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else { return }

    var removed = false
    let filtered = content.components(separatedBy: .newlines).filter { line in
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { return true }
        let key = trimmed.split(separator: "=", maxSplits: 1).first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if key == bundleID {
            removed = true
            return false
        }
        return true
    }

    if removed {
        try? filtered.joined(separator: "\n").write(toFile: configPath, atomically: true, encoding: .utf8)
        print("Removed rule for: \(bundleID)")
    } else {
        print("No rule found for: \(bundleID)")
    }
}

func printUsage() {
    print("""
    auto-im-abc — Ultra-lightweight macOS automatic input method switcher

    Usage:
      auto-im-abc [en|zh|<InputSourceID>]          Switch input source immediately (default: en)
      auto-im-abc --daemon                         Run background window-focus listener
      auto-im-abc --status                         Show current input source & configured app rules
      auto-im-abc --list-im                        List all enabled keyboard input sources on this Mac
      auto-im-abc add <AppName|BundleID> [en|zh]   Add or update an app rule in ~/.config/auto-im-abc/apps.txt
      auto-im-abc remove <AppName|BundleID>        Remove an app rule from ~/.config/auto-im-abc/apps.txt
    """)
}

// MARK: - Entry Point

let args = CommandLine.arguments
let firstArg = args.count > 1 ? args[1] : ""

switch firstArg {
case "--daemon":
    ensureConfigFileExists()
    let app = NSApplication.shared
    app.setActivationPolicy(.prohibited)

    NSWorkspace.shared.notificationCenter.addObserver(
        forName: NSWorkspace.didActivateApplicationNotification,
        object: nil,
        queue: .main
    ) { notification in
        let appRules = loadAppRules()
        guard let activeApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              let bundleID = activeApp.bundleIdentifier,
              let targetToken = appRules[bundleID] else {
            return
        }
        // Switch immediately and re-verify after WindowServer finishes TSM context handoff
        switchInputSourceIfNeeded(to: targetToken)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
            switchInputSourceIfNeeded(to: targetToken)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            switchInputSourceIfNeeded(to: targetToken)
        }
    }

    app.run()

case "--status", "status":
    print("Current input source : \(currentInputSourceID() ?? "unknown")")
    print("Config file          : \(configPath)")
    print("Configured app rules :")
    for (bundle, token) in loadAppRules(forceReload: true).sorted(by: { $0.key < $1.key }) {
        let resolved = resolveInputSourceID(token)
        print("  \(bundle) = \(token) -> \(resolved)")
    }

case "--list-im", "list-im":
    let current = currentInputSourceID()
    print("Enabled keyboard input sources:")
    for item in listEnabledKeyboardInputSources() {
        let marker = (item.id == current) ? "*" : " "
        print(" \(marker) \(item.id)  (\(item.name))")
    }

case "add":
    guard args.count >= 3 else {
        print("Usage: auto-im-abc add <AppName|BundleID> [en|zh|<InputSourceID>]")
        exit(1)
    }
    let target = args.count >= 4 ? args[3] : "en"
    addOrUpdateRule(appInput: args[2], targetToken: target)

case "remove", "rm":
    guard args.count >= 3 else {
        print("Usage: auto-im-abc remove <AppName|BundleID>")
        exit(1)
    }
    removeRule(appInput: args[2])

case "-h", "--help", "help":
    printUsage()

default:
    let target = !firstArg.isEmpty ? firstArg : "en"
    switchInputSourceIfNeeded(to: target)
}
