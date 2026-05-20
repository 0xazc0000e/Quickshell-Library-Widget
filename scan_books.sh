#!/usr/bin/env python3
"""
Smart book scanner: scans root folder, auto-categorizes PDFs by name keywords,
extracts covers, outputs categorized JSON.
"""
import os, sys, json, subprocess, hashlib, glob

# ── Configuration ──────────────────────────────────────────────
CONFIG_FILE = os.path.expanduser("~/.config/quickshell_books_path")
EXT_CONFIG_FILE = os.path.expanduser("~/.config/quickshell_books_ext")
COVERS_DIR  = "/tmp/book_covers"
OUT_FILE    = "/tmp/quickshell_books.json"

# ── Keyword → Category map (order matters: first match wins) ───
CATEGORIES = [
    ("🔐 Cybersecurity",     ["penetration", "hacking", "hack", "exploit", "cyber", "security",
                              "malware", "red team", "ctf", "reverse", "forensic", "threat"]),
    ("🤖 Artificial Intelligence", ["machine learning", "deep learning", "neural", "artificial intelligence",
                              "ai attack", "adversarial", "hands-on-machine", "data science",
                              "الذكاء"]),
    ("🐍 Programming",       ["python", "java", "programming", "software", "linux kernel",
                              "algorithm", "black hat python", "code", "developer"]),
    ("📡 Electronics & Signals", ["signal processing", "electronic", "dsp", "circuit",
                                    "communications", "ew ", "electronic warfare", "radar",
                                    "control engineering", "ogata", "proakis"]),
    ("📚 Operating Systems", ["operating system", "os concept", "silberschatz", "kernel"]),
    ("🚗 Automotive Eng.",   ["car hack", "automotive", "vehicle"]),
    ("🌍 Humanities",        ["geography", "social engineering", "الجغرافيا", "انتقام",
                              "الذكاء العبقري"]),
    ("📖 General",           []),  # catch-all
]

def get_category(name: str) -> str:
    lower = name.lower()
    for cat_name, keywords in CATEGORIES:
        if not keywords:
            continue
        if any(kw in lower for kw in keywords):
            return cat_name
    return "📖 General"

def extract_cover(pdf_path: str) -> str:
    if not pdf_path.lower().endswith(".pdf"):
        return ""  # Cover extraction only supported for PDFs via pdftoppm
    os.makedirs(COVERS_DIR, exist_ok=True)
    safe = hashlib.md5(pdf_path.encode()).hexdigest()[:10]
    cover = os.path.join(COVERS_DIR, f"{safe}.jpg")
    if not os.path.exists(cover):
        try:
            subprocess.run(
                ["pdftoppm", "-r", "72", "-f", "1", "-l", "1", "-jpeg",
                 pdf_path, os.path.join(COVERS_DIR, safe)],
                capture_output=True, timeout=15
            )
            # Rename generated file (pdftoppm adds -001 suffix)
            generated = glob.glob(os.path.join(COVERS_DIR, f"{safe}*.jpg"))
            if generated and generated[0] != cover:
                os.rename(generated[0], cover)
        except Exception as e:
            pass  # No cover, fallback icon will show
    return cover

def main():
    # Read root path
    root = ""
    if os.path.exists(CONFIG_FILE):
        root = open(CONFIG_FILE).read().strip()
    if not root or not os.path.isdir(root):
        root = os.path.expanduser("~/Documents")

    # Read extension
    ext = "pdf"
    if os.path.exists(EXT_CONFIG_FILE):
        ext_val = open(EXT_CONFIG_FILE).read().strip().lower()
        if ext_val:
            ext = ext_val[1:] if ext_val.startswith(".") else ext_val

    # Collect all books
    pdfs = []
    for dirpath, dirnames, filenames in os.walk(root):
        # Skip hidden directories
        dirnames[:] = [d for d in dirnames if not d.startswith('.')]
        for f in filenames:
            if f.lower().endswith(f".{ext}"):
                pdfs.append(os.path.join(dirpath, f))
    pdfs.sort()

    # Auto-categorize
    cat_map = {}
    for pdf in pdfs:
        name = os.path.splitext(os.path.basename(pdf))[0]
        cat  = get_category(name)
        if cat not in cat_map:
            cat_map[cat] = []
        cover = extract_cover(pdf)
        cat_map[cat].append({
            "name":  name,
            "path":  pdf,
            "cover": cover
        })

    # Build output preserving CATEGORIES order
    categories = []
    for cat_name, _ in CATEGORIES:
        if cat_name in cat_map:
            categories.append({
                "category": cat_name,
                "books":    cat_map[cat_name]
            })

    result = {"root": root, "categories": categories}

    with open(OUT_FILE, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print(f"Done: {len(pdfs)} books in {len(categories)} categories → {OUT_FILE}")

if __name__ == "__main__":
    main()
