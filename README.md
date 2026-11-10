# Download Shelf

A tiny macOS menu bar shelf with your latest downloads. Drag files straight out of the menu bar, open them, or copy them to the clipboard with one click.

Built with SwiftUI and AppKit, no Electron, no dependencies.

## Features

- Menu bar icon showing the last downloads from `~/Downloads`
- **Drag out** any item into Finder, Mail, Telegram, a browser, or any app that accepts files
- **Multi-select** with Cmd-click and Shift-click, then drag the whole selection at once
- One-click **copy file to clipboard** with a green checkmark so you see the click landed
- Click a row to open the file with its default app
- Context menu: Open, Show in Finder, Open With..., Copy file, Copy path
- Shows 5 items, **"More 5"** adds five at a time, up to 100
- Auto-opens under the menu bar for 3/4/6/8 seconds when a new file arrives (configurable, can be turned off)
- Live updates via FSEvents, no polling
- Launch at login (SMAppService)
- Remembers a custom watched folder
- Menu bar icon switches to `tray.full` when something new arrived
- Non-activating panel: opening it never steals keyboard focus

## Requirements

- macOS 14 or later
- Xcode Command Line Tools: `xcode-select --install`

## Build and install

```bash
git clone https://github.com/guyfullin10-lgtm/download-shelf.git
cd download-shelf
chmod +x build.sh
./build.sh --install
```

`build.sh` compiles in release mode, assembles `DownloadShelf.app`, copies it to `/Applications`, and launches it.

Other modes:

```bash
./build.sh          # just build DownloadShelf.app in the repo folder
./build.sh --run    # build and run the local copy
```

## Usage

- Click the tray icon in the menu bar to open the shelf.
- Drag the handle on the right to move the actual file somewhere else.
- Cmd-click toggles selection, Shift-click selects a range. Drag the handle of a selected row to move the whole selection.
- The copy icon copies the file itself, not a path. With several rows selected it copies all of them.
- Settings (gear icon at the bottom): open on download (off / 3 / 4 / 6 / 8 s), launch at login, choose another folder.

## Notes

- If you rebuild the app, macOS may ask for access to `~/Downloads` again, because an ad-hoc signed build gets a new identity on every rebuild. Sign with a stable certificate to avoid this.
- "Open" uses the system default application for the file type. Change it in Finder with "Open With", or use "Open With..." in the context menu.
- Files still downloading (`.crdownload`, `.part`, `.download`) are hidden until they finish.

## Project layout

```
Sources/DownloadShelf/
  DownloadShelfApp.swift   App entry, status item, panel, auto-open logic
  DownloadsStore.swift     Folder watching (FSEvents), item list, clipboard, login item
  ShelfView.swift          SwiftUI UI, multi-select, drag handle
build.sh                   Build and install script
```

## Русский

Виджет в строке меню macOS со свежими загрузками. Файлы можно перетаскивать прямо из меню, открывать по клику или копировать в буфер одной кнопкой.

- 5 последних файлов, кнопка «Ещё 5» добавляет по пять, до 100
- Выделение нескольких файлов (Cmd-клик, Shift-клик) и перетаскивание всей пачки
- Перетаскивание настоящего файла в любое приложение
- Копирование файла одной кнопкой, с зелёной галочкой
- Автооткрытие после скачивания на 3/4/6/8 секунд (настраивается)
- Автозапуск при входе, своя папка для наблюдения
- Обновление без polling, через FSEvents
- Панель не забирает фокус клавиатуры

Сборка и установка:

```bash
chmod +x build.sh
./build.sh --install
```

## License

MIT
