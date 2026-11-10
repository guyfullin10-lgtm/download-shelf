import AppKit
import SwiftUI
import UniformTypeIdentifiers

private struct ShelfSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ShelfView: View {
    @ObservedObject var store: DownloadsStore
    var onSizeChange: ((CGSize) -> Void)?

    @State private var hoveredID: String?
    @State private var copiedIDs: Set<String> = []
    @State private var visibleCount: Int = 5

    private var visibleItems: [DownloadItem] {
        Array(store.items.prefix(visibleCount))
    }

    private var remainingCount: Int {
        max(store.items.count - visibleCount, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if remainingCount > 0 || visibleCount > store.collapsedCount {
                expandToggle
            }
            Divider()
            footer
        }
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.30), radius: 16, x: 0, y: 8)
        )
        .padding(14)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: ShelfSizeKey.self, value: proxy.size)
            }
        )
        .onPreferenceChange(ShelfSizeKey.self) { size in
            onSizeChange?(size)
        }
        .onAppear {
            store.markSeen()
            store.refresh()
        }
        .onDisappear {
            visibleCount = store.collapsedCount
            store.clearSelection()
        }
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
                .font(.system(size: 13))
            Text("Загрузки")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            if !store.selectedIDs.isEmpty {
                Text("\(store.selectedIDs.count) выбрано")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tint)
            } else if !store.items.isEmpty {
                Text("\(store.items.count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .help("Обновить")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if store.items.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "tray")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("Пока пусто")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(store.folder.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 12)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
        } else {
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(visibleItems) { item in
                        row(for: item)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
            }
            .frame(height: listHeight)
        }
    }

    private var expandToggle: some View {
        HStack(spacing: 10) {
            if visibleCount > store.collapsedCount {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        visibleCount = store.collapsedCount
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .semibold))
                        Text("Свернуть")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            if remainingCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.16)) {
                        visibleCount = min(visibleCount + store.collapsedCount, store.items.count)
                    }
                } label: {
                    HStack(spacing: 3) {
                        Text("Ещё \(min(store.collapsedCount, remainingCount))")
                            .font(.system(size: 11, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }

    private var listHeight: CGFloat {
        let rowHeight: CGFloat = 38
        let contentHeight = CGFloat(visibleItems.count) * rowHeight + 12
        return min(max(contentHeight, rowHeight + 12), 440)
    }

    private func row(for item: DownloadItem) -> some View {
        let isCopied = copiedIDs.contains(item.id)
        let isSelected = store.selectedIDs.contains(item.id)
        return HStack(spacing: 8) {
            Button {
                store.toggleSelection(item)
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.8))
                    .frame(width: 16, height: 16)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(isSelected ? "Снять выбор" : "Выбрать")

            HStack(spacing: 9) {
                Image(nsImage: store.icon(for: item))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 26, height: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 12.5))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(isCopied ? copiedLabel : item.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(isCopied ? Color.green : Color.secondary)
                }
            }
            .contentShape(Rectangle())

            Spacer(minLength: 2)

            Button {
                copy(item)
            } label: {
                Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                    .font(.system(size: isCopied ? 13 : 11, weight: .medium))
                    .foregroundStyle(isCopied ? Color.green : Color.secondary)
                    .scaleEffect(isCopied ? 1.18 : 1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .opacity(hoveredID == item.id || isCopied ? 1 : 0.55)
            .help(store.selectedIDs.contains(item.id) && store.selectedIDs.count > 1 ? "Скопировать выбранные" : "Скопировать файл")

            ZStack {
                MultiDragSource(urls: { dragURLs(for: item) })
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .opacity(hoveredID == item.id ? 0.9 : 0.35)
                    .allowsHitTesting(false)
            }
            .frame(width: 18, height: 20)
            .help("Перетащить")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(itemID: item.id, isCopied: isCopied, isSelected: isSelected))
        )
        .contentShape(Rectangle())
        .onHover { isHovering in
            hoveredID = isHovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
        .onTapGesture {
            store.open(item)
        }
        .contextMenu {
            Button("Открыть") { store.open(item) }
            Button("Показать в Finder") { store.revealInFinder(item) }
            Button("Открыть с помощью…") { openWith(item) }
            Divider()
            if isSelected && store.selectedIDs.count > 1 {
                Button("Скопировать выбранные (\(store.selectedIDs.count))") { copy(item) }
            } else {
                Button("Скопировать файл") { copy(item) }
            }
            Button("Скопировать путь") { store.copyPath(item) }
        }
        .help(item.url.path)
    }

    private var copiedLabel: String {
        store.selectedIDs.count > 1 ? "Скопировано \(store.selectedIDs.count)" : "Скопировано"
    }

    private func dragURLs(for item: DownloadItem) -> [URL] {
        if store.selectedIDs.count > 1, store.selectedIDs.contains(item.id) {
            let selected = store.selectedItems.map(\.url)
            if !selected.isEmpty { return selected }
        }
        return [item.url]
    }

    private func backgroundColor(itemID: String, isCopied: Bool, isSelected: Bool) -> Color {
        if isSelected { return Color.accentColor.opacity(0.18) }
        if isCopied { return Color.green.opacity(0.16) }
        if hoveredID == itemID { return Color.primary.opacity(0.07) }
        return Color.clear
    }

    private func copy(_ item: DownloadItem) {
        let targets: Set<String>
        if store.selectedIDs.count > 1, store.selectedIDs.contains(item.id) {
            store.copySelected()
            targets = store.selectedIDs
        } else {
            store.copyFile(item)
            targets = [item.id]
        }
        withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
            copiedIDs.formUnion(targets)
        }
        let snapshot = targets
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard copiedIDs.isSuperset(of: snapshot) else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                copiedIDs.subtract(snapshot)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 0) {
            if let launchError = store.launchError {
                Text(launchError)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
            HStack(spacing: 8) {
                Button {
                    store.openFolder()
                } label: {
                    Label("Открыть папку", systemImage: "folder")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    Picker("Открывать при скачивании", selection: $store.autoOpenSeconds) {
                        Text("Не открывать").tag(0.0)
                        Text("3 секунды").tag(3.0)
                        Text("4 секунды").tag(4.0)
                        Text("6 секунд").tag(6.0)
                        Text("8 секунд").tag(8.0)
                    }
                    Divider()
                    Toggle("Запускать при входе", isOn: Binding(
                        get: { store.launchAtLogin },
                        set: { store.setLaunchAtLogin($0) }
                    ))
                    Button("Выбрать другую папку…") { chooseFolder() }
                    Divider()
                    Button("Выйти") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .help("Настройки")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }

    private func openWith(_ item: DownloadItem) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Открыть"
        panel.message = "Выбери приложение"
        if panel.runModal() == .OK, let appURL = panel.url {
            NSWorkspace.shared.open(
                [item.url],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.folder
        panel.prompt = "Выбрать"
        if panel.runModal() == .OK, let url = panel.url {
            store.setFolder(url)
        }
    }
}

private struct MultiDragSource: NSViewRepresentable {
    let urls: () -> [URL]

    func makeNSView(context: Context) -> DragHandleView {
        let view = DragHandleView()
        view.urlsProvider = urls
        return view
    }

    func updateNSView(_ nsView: DragHandleView, context: Context) {
        nsView.urlsProvider = urls
    }
}

final class DragHandleView: NSView, NSDraggingSource {
    var urlsProvider: () -> [URL] = { [] }
    private var downPoint: NSPoint?

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        downPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = downPoint else { return }
        let point = convert(event.locationInWindow, from: nil)
        guard hypot(point.x - start.x, point.y - start.y) >= 3 else { return }
        downPoint = nil

        let urls = urlsProvider()
        guard !urls.isEmpty else { return }

        let icon = NSWorkspace.shared.icon(forFile: urls[0].path)
        icon.size = NSSize(width: 32, height: 32)

        let draggingItems = urls.map { url -> NSDraggingItem in
            let pasteboardItem = NSPasteboardItem()
            pasteboardItem.setString(url.absoluteString, forType: .fileURL)
            let draggingItem = NSDraggingItem(pasteboardWriter: pasteboardItem)
            draggingItem.setDraggingFrame(
                NSRect(x: 0, y: 0, width: 32, height: 32),
                contents: icon
            )
            return draggingItem
        }

        beginDraggingSession(with: draggingItems, event: event, source: self)
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        .copy
    }
}
