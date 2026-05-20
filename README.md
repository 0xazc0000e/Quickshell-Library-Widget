<h1 align="center">📚 Smart Quickshell Library Widget</h1>

<p align="center">
  <b>A highly automated, dynamic, and visually stunning library manager for Quickshell.</b><br>
  Built with love for <a href="https://github.com/outfoxxed/quickshell">Quickshell</a> and <a href="https://github.com/The-Noob-Dude/Noctalia">Noctalia Theme</a>.
</p>

---

## 🎬 Showcase

### Features & Usage Demo
Discover the smart categorization, renaming, and multi-select capabilities.


### Installation & Auto-Injection
Watch how the widget installs itself and magically appears in the UI without a single line of code!



https://github.com/user-attachments/assets/02eb9729-8117-40d8-a6f6-0cd74798bf2a

---




https://github.com/user-attachments/assets/2e0394e0-31be-4691-8aff-95df1ef4fadb





*(Note: Videos require a modern browser or viewing directly on GitHub. If they don't load, you can find them in the `assets/` folder.)*

---

## ✨ Features

- **🧠 Auto-Categorization:** Uses an intelligent Python scanner to automatically sort your books into categories based on keywords.
- **🖼️ Smart Cover Extraction:** Automatically extracts high-quality cover images from your PDF files (requires `poppler-utils`).
- **🗂️ Dynamic Multi-Selection:** Select multiple books at once, move them between categories, or delete them effortlessly.
- **📂 Easy Re-categorization:** Drag & drop (or move via context menu) books between folders or create new custom categories.
- **⚙️ Fully Automated Installer:** The installation script handles dependencies, prompts for your preferred file extension (PDF, EPUB, etc.), and **100% automatically injects** the widget into your Noctalia UI without requiring any manual QML coding!

---

## 🚀 Installation

It takes less than 5 seconds! Simply run the fully automated installer:

```bash
git clone https://github.com/0xazc0000e/Quickshell-Library-Widget.git
cd Quickshell-Library-Widget
chmod +x install.sh
./install.sh
```

**During installation, the script will:**
1. Check for required dependencies (`python3`, `poppler-utils`).
2. Ask you what file extension to scan for (e.g., `pdf`, `epub`, `cbz`). *(Note: Cover extraction currently only works for PDFs)*.
3. Automatically analyze your `SidebarLeftContent.qml` and safely inject the Library Tab Icon and the Widget Component.

Once it's done, just press `SUPER+ALT+R` (or reload your shell) and enjoy your new library!

---

## 🛠️ Requirements
- [Quickshell](https://github.com/outfoxxed/quickshell)
- Python 3
- `poppler-utils` (Automatically verified by the script, used for extracting PDF covers)

## 💡 Notes for Custom Themes
This widget relies heavily on Noctalia/ii aliases (like `Appearance.colors` and `MaterialSymbol`). If you are running a generic Quickshell setup without Noctalia, the installer will place the files in `~/.config/quickshell/library-widget` for you to manually adapt to your own UI styling.

---
