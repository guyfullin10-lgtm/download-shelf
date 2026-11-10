import AppKit
import Combine
import Foundation
import ServiceManagement


struct DownloadItem: Identifiable, Equatable {
    let url: URL
    let name: String
    let addedAt: Date
    let size: Int64
    let modifiedAt: Date

    var id: String { url.path }

    var subtitle: String {
        var parts: [String] = []
        if size > 0 {
            parts.append(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
        }
        parts.append(Self.relativeFormatter.localizedString(for: addedAt, relativeTo: Date()))
        return parts.joined(separator: " · ")
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

@MainActor
final class DownloadsStore: ObservableObject {

    @Published private(set) var items: [DownloadItem] = []
    @Published private(set) var hasUnseen: Bool = false
    @Published var selectedIDs: Set<String> = []
    @Published var folder: URL
    @Published private(set) var launchAtLogin: Bool = false
    @Published private(set) var lastAddedAt: Date?
    @Published var autoOpenSeconds: Double {
        didSet { UserDefaults.standard.set(autoOpenSeconds, forKey: Self.autoOpenKey) }
    }
    @Published private(set) var launchError: String?

    var maxItems: Int = 100
    let collapsedCount: Int = 5

    private var watcher: DirectoryWatcher?
    private var reloadWorkItem: DispatchWorkItem?
    private var iconCache: [String: NSImage] = [:]
    private var seenPaths: Set<String> = []
    private var didPrimeSeen = false

    private static let folderDefaultsKey = "watchedFolderPath"
    private static let autoOpenKey = "autoOpenSeconds"
    private static let skippedExtensions: Set<String> = [
        "crdownload", "download", "part", "partial", "tmp", "opdownload"
    ]
    private static let skippedNames: Set<String> = [
        ".DS_Store", ".localized", "Icon\r"
    ]

    init() {
        if let saved = UserDefaults.standard.string(forKey: Self.folderDefaultsKey) {
            folder = URL(fileURLWithPath: saved, isDirectory: true)
        } else {
            folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads", isDirectory: true)
        }
        autoOpenSeconds = UserDefaults.standard.object(forKey: Self.autoOpenKey) as? Double ?? 4
        launchAtLogin = SMAppService.mainApp.status == .enabled
        startWatching()
        reload()
        didPrimeSeen = true

    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchError = nil
        } catch {
            launchError = enabled
                ? "Не удалось включить автозапуск: \(error.localizedDescription)"
                : "Не удалось отключить автозапуск: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            launchError = "Нужно разрешить в System Settings → Login Items"
        }
    }

    func setFolder(_ url: URL) {
        folder = url
        UserDefaults.standard.set(url.path, forKey: Self.folderDefaultsKey)
        iconCache.removeAll()
        startWatching()
        reload()
    }

    func revealInFinder(_ item: DownloadItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func open(_ item: DownloadItem) {
        NSWorkspace.shared.open(item.url)
    }

    var selectedItems: [DownloadItem] {
        items.filter { selectedIDs.contains($0.id) }
    }

    func toggleSelection(_ item: DownloadItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectOnly(_ item: DownloadItem) {
        selectedIDs = [item.id]
    }

    func selectRange(to item: DownloadItem, from anchorID: String?) {
        guard let anchorID,
              let start = items.firstIndex(where: { $0.id == anchorID }),
              let end = items.firstIndex(where: { $0.id == item.id }) else {
            selectOnly(item)
            return
        }
        let range = start <= end ? start...end : end...start
        selectedIDs = Set(items[range].map(\.id))
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func copyFile(_ item: DownloadItem) {
        Clipboard.copyFiles(at: [item.url])
    }

    func copySelected() {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }
        Clipboard.copyFiles(at: urls)
    }

    func copyPath(_ item: DownloadItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.url.path, forType: .string)
    }

    func openFolder() {
        NSWorkspace.shared.open(folder)
    }

    func markSeen() {
        hasUnseen = false
    }

    func refresh() {
        reload()
    }

    func icon(for item: DownloadItem) -> NSImage {
        let key = "\(item.url.path)#\(item.modifiedAt.timeIntervalSince1970)"
        if let cached = iconCache[key] {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: item.url.path)
        image.size = NSSize(width: 32, height: 32)
        iconCache[key] = image
        return image
    }

    private func startWatching() {
        watcher?.stop()
        watcher = DirectoryWatcher(url: folder) { [weak self] in
            Task { @MainActor in
                self?.scheduleReload()
            }
        }
        watcher?.start()
    }

    private func scheduleReload() {
        reloadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.reload() }
        }
        reloadWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func reload() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .contentModificationDateKey, .creationDateKey, .isRegularFileKey,
            .fileSizeKey, .isDirectoryKey, .nameKey
        ]
        guard let contents = try? fm.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            items = []
            return
        }

        var fresh: [DownloadItem] = []
        for url in contents {
            let name = url.lastPathComponent
            if Self.skippedNames.contains(name) { continue }
            if Self.skippedExtensions.contains(url.pathExtension.lowercased()) { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isRegularFile == false { continue }

            let created = values.creationDate ?? values.contentModificationDate ?? .distantPast
            let modified = values.contentModificationDate ?? created
            let size = Int64(values.fileSize ?? 0)
            fresh.append(DownloadItem(url: url, name: name, addedAt: created, size: size, modifiedAt: modified))
        }

        fresh.sort { $0.addedAt > $1.addedAt }
        let limited = Array(fresh.prefix(maxItems))

        if didPrimeSeen {
            let newPaths = Set(limited.map(\.id)).subtracting(seenPaths)
            if !newPaths.isEmpty {
                hasUnseen = true
                lastAddedAt = Date()
            }
        }
        seenPaths = Set(limited.map(\.id))

        selectedIDs = selectedIDs.intersection(Set(limited.map(\.id)))

        let keptKeys = Set(limited.map { "\($0.url.path)#\($0.modifiedAt.timeIntervalSince1970)" })
        iconCache = iconCache.filter { keptKeys.contains($0.key) }

        items = limited
    }
}

final class DirectoryWatcher {
    private let url: URL
    private let onChange: () -> Void
    private var stream: FSEventStreamRef?

    init(url: URL, onChange: @escaping () -> Void) {
        self.url = url
        self.onChange = onChange
    }

    private static let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
        guard let info else { return }
        let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
        watcher.onChange()
    }

    func start() {
        stop()
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let paths = [url.path] as CFArray
        let flags = UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer)
        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            Self.callback,
            &context,
            paths,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        ) else {
            return
        }
        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }

    deinit {
        stop()
    }
}

enum Clipboard {
    static func copyFiles(at urls: [URL]) {
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let items = urls.map { url -> NSPasteboardItem in
            let pasteItem = NSPasteboardItem()
            pasteItem.setString(url.absoluteString, forType: .fileURL)
            return pasteItem
        }
        pasteboard.writeObjects(items)
    }
}
