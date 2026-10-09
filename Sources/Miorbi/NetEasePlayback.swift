import AppKit
import CommonCrypto
import CoreAudio
import Foundation

// Read-only adapter for Chromium's local lastPlaying record. No account data is queried.
struct NetEasePosition: Decodable, Equatable, Sendable {
    let current: Double
    let resourceDuration: Double
    let resourceId: String
}

enum NetEasePlayback {
    static func isOutputActive() -> Bool? {
        guard #available(macOS 14.2, *),
              let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.netease.163music" }),
              let appURL = app.bundleURL else { return nil }
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyProcessObjectList, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size) == noErr else { return nil }
        var objects = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &objects) == noErr else { return nil }
        for object in objects {
            var process: pid_t = 0
            var count = UInt32(MemoryLayout<pid_t>.size)
            address.mSelector = kAudioProcessPropertyPID
            guard AudioObjectGetPropertyData(object, &address, 0, nil, &count, &process) == noErr else { continue }
            var path = [CChar](repeating: 0, count: 4096)
            let pathLength = proc_pidpath(process, &path, UInt32(path.count))
            let executable = pathLength > 0 ? String(decoding: path.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) }, as: UTF8.self) : ""
            guard executable.hasPrefix(appURL.path + "/") else { continue }
            var active: UInt32 = 0
            count = 4
            address.mSelector = kAudioProcessPropertyIsRunningOutput
            if AudioObjectGetPropertyData(object, &address, 0, nil, &count, &active) == noErr, active != 0 { return true }
        }
        return false
    }
    static let root = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Containers/com.netease.163music/Data/Documents/storage")

    static func decodeRecord(_ data: Data) -> NetEasePosition? {
        let marker = Data("lastPlaying".utf8)
        var search = data.startIndex..<data.endIndex
        var latest: NetEasePosition?
        while let found = data.range(of: marker, options: [], in: search) {
            var cursor = found.upperBound
            var length = 0
            for shift in stride(from: 0, through: 28, by: 7) {
                guard cursor < data.endIndex else { break }
                let byte = data[cursor]; cursor += 1
                length |= Int(byte & 127) << shift
                if byte < 128 { break }
            }
            if length > 1, length < 2048, cursor + length <= data.endIndex,
               data[cursor] == 1,
               let encrypted = Data(base64Encoded: data.subdata(in: (cursor + 1)..<(cursor + length))) {
                var clear = [UInt8](repeating: 0, count: encrypted.count + 16)
                var written = 0
                let key = Array(")(13daqP@ssw0rd~".utf8) // Player's fixed format key, not a user credential.
                let result = CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES),
                                     CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding), key, key.count,
                                     nil, [UInt8](encrypted), encrypted.count, &clear, clear.count, &written)
                if result == kCCSuccess,
                   let state = try? JSONDecoder().decode(NetEasePosition.self, from: Data(clear.prefix(written))),
                   state.current.isFinite, state.current >= 0, state.current <= state.resourceDuration + 2,
                   state.resourceId.allSatisfy(\.isNumber), !state.resourceId.isEmpty {
                    latest = state
                }
            }
            search = found.upperBound..<data.endIndex
        }
        return latest
    }

    static func read() -> MusicSnapshot? {
        guard NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.netease.163music" }) else { return nil }
        let directory = root.appendingPathComponent("CEFCache/Local Storage/leveldb")
        let files: [URL]
        do {
            files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey])
        } catch {
            return MusicSnapshot(provider: .netease, error: "无法读取网易云播放数据：\(error.localizedDescription)")
        }
        // Current log wins over old compacted tables. Never open the live DB for writing or locking.
        let logs = files.filter { $0.pathExtension == "log" }.sorted { $0.lastPathComponent > $1.lastPathComponent }
        for file in logs {
            guard let attributes = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  (attributes.fileSize ?? 0) < 16_000_000 else { continue }
            let data: Data
            do { data = try Data(contentsOf: file) }
            catch { return MusicSnapshot(provider: .netease, error: "无法读取网易云进度文件：\(error.localizedDescription)") }
            guard let state = decodeRecord(data) else { continue }
            var result = MusicSnapshot()
            result.provider = .netease
            result.trackID = state.resourceId
            result.position = state.current
            result.duration = state.resourceDuration
            result.sampleDate = attributes.contentModificationDate ?? Date()
            result.playback = (isOutputActive() ?? (Date().timeIntervalSince(result.sampleDate) < 3)) ? .playing : .paused
            if result.isPlaying { result.position = min(result.duration, result.position + min(2, max(0, Date().timeIntervalSince(result.sampleDate)))) }
            if let queue = try? Data(contentsOf: root.appendingPathComponent("file_storage/webdata/file/playingList")),
               let json = try? JSONSerialization.jsonObject(with: queue) as? [String: Any],
               let list = json["list"] as? [[String: Any]],
               let track = list.first(where: { ($0["id"] as? String) == state.resourceId })?["track"] as? [String: Any] {
                result.title = track["name"] as? String ?? "网易云音乐"
                result.artist = (track["artists"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.joined(separator: " / ") ?? ""
            }
            return result
        }
        return MusicSnapshot(provider: .netease, error: "网易云未提供有效播放进度，请开始播放歌曲")
    }
}
