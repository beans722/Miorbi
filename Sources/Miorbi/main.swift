import AppKit

if CommandLine.arguments.contains("--miorbi-connect-codex") {
    do {
        try CodexHookInstaller.install(executable: URL(fileURLWithPath: CommandLine.arguments[0]))
        UserDefaults.standard.set(true, forKey: "codexHooksConnected")
        print("Codex hooks connected")
        exit(0)
    } catch { print(error.localizedDescription); exit(1) }
}

if CommandLine.arguments.contains("--miorbi-music-probe") {
    let value = MusicBridge.read()
    let report: [String: Any] = ["provider": value.provider == .netease ? "netease" : "appleMusic",
                                "title": value.title, "trackID": value.trackID, "position": value.position,
                                "playing": value.isPlaying, "sampleAge": Date().timeIntervalSince(value.sampleDate)]
    if let data = try? JSONSerialization.data(withJSONObject: report, options: [.sortedKeys]),
       let text = String(data: data, encoding: .utf8) { print(text) }
    exit(0)
}

if CommandLine.arguments.count == 3,
   CommandLine.arguments[1] == "--miorbi-codex-event" {
    let data = FileHandle.standardInput.readDataToEndOfFile()
    if let event = CodexEvent.fromHook(name: CommandLine.arguments[2], input: data) {
        try? CodexEventFile.append(event)
    }
    exit(0)
}

let application = NSApplication.shared
let controller = ApplicationController()
application.delegate = controller
application.run()
