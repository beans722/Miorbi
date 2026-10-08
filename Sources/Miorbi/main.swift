import AppKit

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
