import AppKit
import SwiftUI

private struct ShelfSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct ShelfView: View {
    @ObservedObject var store: DownloadsStore
    var onHoverChange: ((Bool) -> Void)?
    var onSizeChange: ((CGSize) -> Void)?

    @State private var hoveredID: String?
    @State private var copiedID: String?
    @State private var expanded = false

    private var visibleItems: [DownloadItem] {
        expanded ? store.items : Array(store.items.prefix(store.collapsedCount))
    }

    private var hiddenCount: Int {
        max(store.items.count - store.collapsedCount, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            if hiddenCount > 0 {
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
        .onHover { hovering in
            onHoverChange?(hovering)
        }
        .onAppear {
            store.markSeen()
            store.refresh()
        }
        .onDisappear {
            expanded = false
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
            if !store.items.isEmpty {
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
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                expanded.toggle()
            }
        } label: {
            HStack(spacing: 4) {
                Text(expanded ? "Свернуть" : "Ещё \(hiddenCount)")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: expanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var listHeight: CGFloat {
        let rowHeight: CGFloat = 38
        let contentHeight = CGFloat(visibleItems.count) * rowHeight + 12
        return min(max(contentHeight, rowHeight + 12), 440)
    }

    private func row(for item: DownloadItem) -> some View {
        let isCopied = copiedID == item.id
        return HStack(spacing: 9) {
            Button {
                store.open(item)
            } label: {
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
                        Text(isCopied ? "Скопировано" : item.subtitle)
                            .font(.system(size: 10.5))
                            .foregroundStyle(isCopied ? Color.green : Color.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

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
            .help("Скопировать файл")

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.tertiary)
                .opacity(hoveredID == item.id ? 0.9 : 0.35)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(backgroundColor(itemID: item.id, isCopied: isCopied))
        )
        .contentShape(Rectangle())
        .onHover { isHovering in
            hoveredID = isHovering ? item.id : (hoveredID == item.id ? nil : hoveredID)
        }
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        }
        .contextMenu {
            Button("Открыть") { store.open(item) }
            Button("Показать в Finder") { store.revealInFinder(item) }
            Button("Открыть с помощью…") { openWith(item) }
            Divider()
            Button("Скопировать файл") { copy(item) }
            Button("Скопировать путь") { store.copyPath(item) }
        }
        .help(item.url.path)
    }

    private func backgroundColor(itemID: String, isCopied: Bool) -> Color {
        if isCopied { return Color.green.opacity(0.16) }
        if hoveredID == itemID { return Color.primary.opacity(0.07) }
        return Color.clear
    }

    private func copy(_ item: DownloadItem) {
        store.copyFile(item)
        withAnimation(.spring(response: 0.22, dampingFraction: 0.6)) {
            copiedID = item.id
        }
        let targetID = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            guard copiedID == targetID else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                copiedID = nil
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
