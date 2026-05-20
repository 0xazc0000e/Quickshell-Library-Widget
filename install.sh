#!/usr/bin/env bash

GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=== Quickshell Smart Library Widget Installer ===${NC}"

# 0. Configuration
echo -e "\n${BLUE}[0/3] Configuration${NC}"
read -p "What book extension should the widget scan for? (default: pdf): " BOOK_EXT
BOOK_EXT=${BOOK_EXT:-pdf}
BOOK_EXT=${BOOK_EXT#.} # strip leading dot if user provided one
echo "$BOOK_EXT" > ~/.config/quickshell_books_ext
echo -e "${GREEN}Configured to scan for: .$BOOK_EXT files.${NC}"

# 1. Install Dependencies
echo -e "\n${BLUE}[1/3] Checking dependencies (python3, poppler-utils)...${NC}"
if ! command -v pdftoppm &> /dev/null || ! command -v python3 &> /dev/null; then
    echo "Missing dependencies. Attempting to install..."
    if command -v apt &> /dev/null; then
        sudo apt update && sudo apt install -y python3 poppler-utils
    elif command -v pacman &> /dev/null; then
        sudo pacman -S --noconfirm python poppler
    elif command -v dnf &> /dev/null; then
        sudo dnf install -y python3 poppler-utils
    elif command -v zypper &> /dev/null; then
        sudo zypper install -y python3 poppler-tools
    elif command -v apk &> /dev/null; then
        sudo apk add python3 poppler-utils
    else
        echo -e "${RED}Could not detect package manager. Please install 'python3' and 'poppler-utils' manually.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}Dependencies already installed.${NC}"
fi

# 2. Install Python Scanner Script
echo -e "\n${BLUE}[2/3] Installing scanner script to ~/.local/bin...${NC}"
mkdir -p ~/.local/bin
cp scan_books.sh ~/.local/bin/
chmod +x ~/.local/bin/scan_books.sh
echo -e "${GREEN}Scanner script installed.${NC}"

# 3. Install Widget Files
echo -e "\n${BLUE}[3/3] Installing QML widget files...${NC}"
NOCTALIA_DIR="$HOME/.config/quickshell/ii"

if [ -d "$NOCTALIA_DIR" ]; then
    BOOKS_DIR="$NOCTALIA_DIR/modules/ii/sidebarLeft/books"
    mkdir -p "$BOOKS_DIR"
    cp BooksWidget.qml "$BOOKS_DIR/"
    echo -e "module qs.modules.ii.sidebarLeft.books\nBooksWidget 1.0 BooksWidget.qml" > "$BOOKS_DIR/qmldir"
    echo -e "${GREEN}Files copied to Noctalia/ii theme: $BOOKS_DIR${NC}"
    
    # Auto-inject into UI
    SIDEBAR_FILE="$NOCTALIA_DIR/modules/ii/sidebarLeft/SidebarLeftContent.qml"
    if [ -f "$SIDEBAR_FILE" ]; then
        if grep -q "BooksWidget" "$SIDEBAR_FILE"; then
            echo -e "${GREEN}Widget is already integrated in your UI.${NC}"
        else
            echo -e "\n${BLUE}Auto-injecting widget into SidebarLeftContent.qml...${NC}"
            
            # Inject import safely
            if ! grep -q "import qs.modules.ii.sidebarLeft.books" "$SIDEBAR_FILE"; then
                sed -i '/import QtQuick/i import qs.modules.ii.sidebarLeft.books' "$SIDEBAR_FILE"
            fi
            
            # Inject tab icon safely
            if ! grep -q "\"menu_book\"" "$SIDEBAR_FILE"; then
                awk '/property var tabButtonList: \[/ {
                    in_tab = 1
                    print
                    next
                }
                in_tab && /^[ \t]*\]/ {
                    print "        ,{\"icon\": \"menu_book\", \"name\": Translation.tr(\"Library\")}"
                    print
                    in_tab = 0
                    next
                }
                {print}' "$SIDEBAR_FILE" > /tmp/sidebar.tmp && mv /tmp/sidebar.tmp "$SIDEBAR_FILE"
            fi
            
            # Inject component block safely before the placeholder component
            awk '/Component \{/ { 
                if (getline next_line > 0) {
                    if (next_line ~ /id: placeholder/) {
                        print "        Component {\n            id: library\n            BooksWidget {}\n        }"
                    }
                    print $0
                    print next_line
                    next
                }
            }1' "$SIDEBAR_FILE" > /tmp/sidebar.tmp && mv /tmp/sidebar.tmp "$SIDEBAR_FILE"

            # Inject createObject() if needed (for newer Noctalia layouts)
            if grep -q "anime.createObject" "$SIDEBAR_FILE" && ! grep -q "library.createObject" "$SIDEBAR_FILE"; then
                sed -i 's/\(anime.createObject()\] : \[\])\)/\1,\n                    library.createObject()/g' "$SIDEBAR_FILE"
            fi
            
            echo -e "${GREEN}UI Injection successful!${NC}"
        fi
    fi
else
    # Generic installation
    BOOKS_DIR="$HOME/.config/quickshell/library-widget"
    mkdir -p "$BOOKS_DIR"
    cp BooksWidget.qml "$BOOKS_DIR/"
    echo -e "module library-widget\nBooksWidget 1.0 BooksWidget.qml" > "$BOOKS_DIR/qmldir"
    echo -e "${GREEN}Files copied to: $BOOKS_DIR${NC}"
    echo -e "\n${BLUE}Next Steps:${NC}"
    echo "1. This widget relies on Noctalia/ii theme components (Appearance.colors, MaterialSymbol, StyledText)."
    echo "2. You must adapt these components to your custom Quickshell theme."
    echo "3. Import the directory in your main QML file and instantiate 'BooksWidget {}'."
fi

echo -e "\n${GREEN}Installation finished!${NC}"
