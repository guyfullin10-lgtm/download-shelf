import AppKit
import Combine
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: ShelfPanel!
    private let store = DownloadsStore()
    private var cancellables = Set<AnyCancellable>()
    private var autoCloseTimer: Timer?
    private var userInteracted = false
    private var lastAppliedHeight: CGFloat = 0
    private var outsideClickMonitor: Any?
    private var escapeMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = Self.icon(unseen: false)
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePanel(_:))
        }

        let root = ShelfView(
            store: store,
            onSizeChange: { [weak self] size in
                self?.resizePanel(to: size)
            }
        )

        panel = ShelfPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 280))
        panel.contentView = NSHostingView(rootView: root)

        store.$hasUnseen
            .receive(on: RunLoop.main)
            .sink { [weak self] unseen in
                self?.statusItem.button?.image = Self.icon(unseen: unseen)
            }
            .store(in: &cancellables)

        store.$lastAddedAt
            .compactMap { $0 }
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.handleNewDownload()
            }
            .store(in: &cancellables)
    }

    private static func icon(unseen: Bool) -> NSImage? {
        let name = unseen ? "tray.full.fill" : "tray.and.arrow.down"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Последние загрузки")
        image?.isTemplate = true
        return image
    }

    @objc private func togglePanel(_ sender: Any?) {
        cancelAutoClose()
        userInteracted = true
        if panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard !panel.isVisible else { return }
        positionPanel()
        panel.orderFrontRegardless()
        store.markSeen()
        installMonitors()
    }

    private func hidePanel() {
        panel.orderOut(nil)
        removeMonitors()
        store.clearSelection()
    }

    private func handleNewDownload() {
        let seconds = store.autoOpenSeconds
        guard seconds > 0 else { return }
        userInteracted = false
        showPanel()
        scheduleAutoClose(after: seconds)
    }

    private func scheduleAutoClose(after seconds: Double) {
        cancelAutoClose()
        autoCloseTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.userInteracted else { return }
                self.hidePanel()
            }
        }
    }

    private func cancelAutoClose() {
        autoCloseTimer?.invalidate()
        autoCloseTimer = nil
    }

    private func resizePanel(to size: CGSize) {
        let height = max(round(size.height), 120)
        guard abs(height - lastAppliedHeight) >= 0.5 else { return }
        lastAppliedHeight = height
        panel.setContentSize(NSSize(width: 360, height: height))
        if panel.isVisible {
            positionPanel()
        }
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        var x = buttonRect.midX - size.width / 2
        var y = buttonRect.minY - size.height + 12

        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
            y = max(y, visible.minY + 8)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installMonitors() {
        removeMonitors()

        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                let location = NSEvent.mouseLocation
                if self.panel.frame.contains(location) { return }
                if let button = self.statusItem.button,
                   let window = button.window,
                   window.convertToScreen(button.convert(button.bounds, to: nil)).contains(location) {
                    return
                }
                self.hidePanel()
            }
        }

        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown]) { [weak self] event in
            Task { @MainActor in
                guard let self, self.panel.isVisible else { return }
                if event.type != .keyDown {
                    self.userInteracted = true
                    self.cancelAutoClose()
                }
            }
            if event.type == .keyDown && event.keyCode == 53 {
                Task { @MainActor in
                    guard let self else { return }
                    if !self.store.selectedIDs.isEmpty {
                        self.store.clearSelection()
                    } else {
                        self.hidePanel()
                    }
                }
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
        if let escapeMonitor {
            NSEvent.removeMonitor(escapeMonitor)
            self.escapeMonitor = nil
        }
    }
}

final class ShelfPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        hidesOnDeactivate = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        animationBehavior = .utilityWindow
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@main
enum AppMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
