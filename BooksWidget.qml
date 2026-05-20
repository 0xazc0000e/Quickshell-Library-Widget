import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string homeDir: Quickshell.env("HOME")
    property string configPath: homeDir + "/.config/quickshell_books_path"
    property string catNamesPath: homeDir + "/.config/quickshell_books_catnames.json"
    property string overridesPath: homeDir + "/.config/quickshell_books_overrides.json"
    property string rootPath: homeDir + "/Documents"
    property string editPathText: ""
    property var categoriesData: []
    property var catRenames: ({})
    property var bookOverrides: ({})

    property string userCategoriesPath: homeDir + "/.config/quickshell_books_usercats.json"
    property var userCategories: []

    property var selectedBooks: []
    property bool selectionMode: false
    property string reclassBookName: ""
    property bool showReclassDialog: false

    function toggleSelection(path) {
        var arr = root.selectedBooks.slice();
        var idx = arr.indexOf(path);
        if (idx !== -1) arr.splice(idx, 1);
        else arr.push(path);
        root.selectedBooks = arr;
    }
    function clearSelection() {
        root.selectedBooks = [];
        root.selectionMode = false;
    }

    // ── File loaders ───────────────────────────────────────────
    FileView {
        id: pathConfig
        path: root.configPath
        onLoaded: {
            root.rootPath = pathConfig.text().trim()
            root.editPathText = root.rootPath
            fileReader.reload()
            scanProcess.running = true
        }
        onLoadFailed: {
            root.editPathText = root.rootPath
            scanProcess.running = true
        }
    }
    FileView {
        id: catNamesFile
        path: root.catNamesPath
        onLoaded: { try { root.catRenames = JSON.parse(catNamesFile.text()) } catch(e) {} }
    }
    FileView {
        id: overridesFile
        path: root.overridesPath
        onLoaded: { try { root.bookOverrides = JSON.parse(overridesFile.text()) } catch(e) {} }
    }
    FileView {
        id: userCatsFile
        path: root.userCategoriesPath
        onLoaded: { try { root.userCategories = JSON.parse(userCatsFile.text()) || [] } catch(e) {} }
    }
    FileView {
        id: fileReader
        path: "/tmp/quickshell_books.json"
        onLoaded: {
            try {
                var data = JSON.parse(fileReader.text())
                root.categoriesData = applyOverrides(data.categories || [])
            } catch(e) {}
        }
    }
    Process {
        id: scanProcess
        command: ["python3", root.homeDir + "/.local/bin/scan_books.sh"]
        running: false
        onExited: { scanProcess.running = false; fileReader.reload(); }
    }

    // ── Helpers ────────────────────────────────────────────────
    function applyOverrides(cats) {
        var result = JSON.parse(JSON.stringify(cats))
        var ov = root.bookOverrides
        if (Object.keys(ov).length > 0) {
            for (var i = 0; i < result.length; i++)
                result[i].books = result[i].books.filter(function(b) { return !ov[b.path] })
            for (var bp in ov) {
                var newCat = ov[bp], found = null
                for (var c = 0; c < cats.length && !found; c++)
                    for (var b = 0; b < cats[c].books.length; b++)
                        if (cats[c].books[b].path === bp) { found = cats[c].books[b]; break }
                if (!found) continue
                var ti = -1
                for (var j = 0; j < result.length; j++) if (result[j].category === newCat) { ti = j; break }
                if (ti === -1) { result.push({category: newCat, books: []}); ti = result.length - 1 }
                result[ti].books.push(found)
            }
        }
        var uCats = root.userCategories || []
        for (var u = 0; u < uCats.length; u++) {
            var exists = false
            for (var k = 0; k < result.length; k++) if (result[k].category === uCats[u]) { exists = true; break }
            if (!exists) result.push({category: uCats[u], books: []})
        }
        return result.filter(function(c) { 
            return c.books.length > 0 || (root.userCategories && root.userCategories.indexOf(c.category) !== -1)
        })
    }
    function displayCatName(orig) { return root.catRenames[orig] || orig }
    function saveCatRenames() { catNamesFile.setText(JSON.stringify(root.catRenames, null, 2)) }
    function saveOverrides() { overridesFile.setText(JSON.stringify(root.bookOverrides, null, 2)) }
    function saveUserCategories() { userCatsFile.setText(JSON.stringify(root.userCategories, null, 2)) }
    function reassignBook(newCat) {
        var o = root.bookOverrides
        for (var i = 0; i < root.selectedBooks.length; i++) {
            o[root.selectedBooks[i]] = newCat
        }
        root.bookOverrides = o
        saveOverrides()
        fileReader.reload()
        root.showReclassDialog = false
        root.clearSelection()
    }

    function deleteCategory(catName) {
        var arr = root.userCategories.slice()
        var idx = arr.indexOf(catName)
        if (idx !== -1) { arr.splice(idx, 1); root.userCategories = arr; root.saveUserCategories() }

        if (catName !== "📖 General") {
            var o = root.bookOverrides
            var catData = null
            for (var i = 0; i < root.categoriesData.length; i++) {
                if (root.categoriesData[i].category === catName) { catData = root.categoriesData[i]; break }
            }
            if (catData && catData.books) {
                var changed = false
                for (var j = 0; j < catData.books.length; j++) {
                    var p = catData.books[j].path
                    if (o[p] === catName) { delete o[p]; changed = true }
                    else { o[p] = "📖 General"; changed = true }
                }
                if (changed) { root.bookOverrides = o; saveOverrides() }
            }
        }

        var r = Object.assign({}, root.catRenames)
        if (r[catName]) { delete r[catName]; root.catRenames = r; saveCatRenames() }

        fileReader.reload()
    }

    // ══════════════════════════════════════════════════════════
    // MAIN LAYOUT — fills SwipeView page
    // ══════════════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 6
        spacing: 4

        // ── Header ─────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            MaterialSymbol {
                text: "menu_book"
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colPrimary
            }
            StyledText {
                text: root.selectionMode ? Translation.tr(root.selectedBooks.length + " Selected") : Translation.tr("My Library")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.bold: true
                color: Appearance.colors.colOnLayer1
                Layout.fillWidth: true
            }

            // Selection Actions
            RowLayout {
                visible: root.selectionMode
                spacing: 4
                Button {
                    enabled: root.selectedBooks.length > 0
                    implicitWidth: 24; implicitHeight: 24
                    background: Rectangle { color: parent.hovered && parent.enabled ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                    contentItem: MaterialSymbol { text: "drive_file_move"; iconSize: Appearance.font.pixelSize.small; color: parent.enabled ? Appearance.colors.colPrimary : Appearance.colors.colSubtext; horizontalAlignment: Text.AlignHCenter }
                    onClicked: {
                        root.reclassBookName = Translation.tr(root.selectedBooks.length + " books selected")
                        root.showReclassDialog = true
                    }
                    StyledToolTip { text: Translation.tr("Move Selected") }
                }
                Button {
                    implicitWidth: 24; implicitHeight: 24
                    background: Rectangle { color: parent.hovered ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                    contentItem: MaterialSymbol { text: "close"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colError; horizontalAlignment: Text.AlignHCenter }
                    onClicked: root.clearSelection()
                    StyledToolTip { text: Translation.tr("Cancel") }
                }
            }

            // Normal Actions
            RowLayout {
                visible: !root.selectionMode
                spacing: 4
                Button {
                    implicitWidth: 24; implicitHeight: 24
                    background: Rectangle { color: parent.hovered ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                    contentItem: MaterialSymbol { text: "checklist"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignHCenter }
                    onClicked: root.selectionMode = true
                    StyledToolTip { text: Translation.tr("Select") }
                }
                // Refresh
                Button {
                    id: refreshBtn; implicitWidth: 24; implicitHeight: 24
                    background: Rectangle { color: refreshBtn.hovered ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                    contentItem: MaterialSymbol { text: "refresh"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignHCenter }
                    onClicked: { root.categoriesData = []; scanProcess.running = false; scanProcess.running = true; }
                    StyledToolTip { text: "Rescan" }
                }
                // Add Category
                Button {
                    id: addCatBtn; implicitWidth: 24; implicitHeight: 24
                    background: Rectangle { color: addCatBtn.hovered || addCatPopup.visible ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                    contentItem: MaterialSymbol { text: "create_new_folder"; iconSize: Appearance.font.pixelSize.small; color: addCatPopup.visible ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignHCenter }
                    onClicked: addCatPopup.visible ? addCatPopup.close() : addCatPopup.open()
                    StyledToolTip { text: "Add Category" }

                    Popup {
                        id: addCatPopup
                        y: addCatBtn.height + 2
                        x: -(width - addCatBtn.width)
                        width: 220; padding: 8
                        background: Rectangle { color: Appearance.colors.colLayer2Base; radius: Appearance.rounding.normal; border.color: Qt.rgba(1,1,1,0.12); border.width: 1 }

                        ColumnLayout { anchors.fill: parent; spacing: 6
                            StyledText { text: Translation.tr("New Category Name:"); color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
                            TextField {
                                id: newCatNameField; Layout.fillWidth: true
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                background: Rectangle { color: Appearance.colors.colLayer1; radius: Appearance.rounding.small; border.color: newCatNameField.activeFocus ? Appearance.colors.colPrimary : "transparent"; border.width: 1 }
                                Keys.onEscapePressed: addCatPopup.close()
                            }
                            RowLayout { Layout.fillWidth: true; spacing: 6
                                Button { Layout.fillWidth: true; text: Translation.tr("Cancel"); implicitHeight: 26
                                    background: Rectangle { color: parent.hovered ? Appearance.colors.colLayer1 : "transparent"; radius: Appearance.rounding.small }
                                    contentItem: StyledText { text: parent.text; color: Appearance.colors.colSubtext; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Appearance.font.pixelSize.small }
                                    onClicked: { newCatNameField.text = ""; addCatPopup.close() }
                                }
                                Button { Layout.fillWidth: true; text: Translation.tr("Add"); implicitHeight: 26
                                    background: Rectangle { color: parent.hovered ? Qt.darker(Appearance.colors.colPrimary,1.1) : Appearance.colors.colPrimary; radius: Appearance.rounding.small }
                                    contentItem: StyledText { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Appearance.font.pixelSize.small; font.bold: true }
                                    onClicked: { 
                                        if (newCatNameField.text.trim() !== "") {
                                            var arr = root.userCategories.slice();
                                            if (arr.indexOf(newCatNameField.text.trim()) === -1) {
                                                arr.push(newCatNameField.text.trim());
                                                root.userCategories = arr;
                                                root.saveUserCategories();
                                                fileReader.reload();
                                            }
                                        }
                                        newCatNameField.text = ""; addCatPopup.close() 
                                    }
                                }
                            }
                        }
                    }
                }
                // Folder / path button
                Button {
                    id: folderBtn; implicitWidth: 24; implicitHeight: 24
                    background: Rectangle { color: folderBtn.hovered || pathPopup.visible ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                    contentItem: MaterialSymbol { text: "folder_open"; iconSize: Appearance.font.pixelSize.small; color: pathPopup.visible ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignHCenter }
                    onClicked: pathPopup.visible ? pathPopup.close() : pathPopup.open()
                    StyledToolTip { text: "Change folder" }

                    Popup {
                        id: pathPopup
                        y: folderBtn.height + 2
                        x: -(width - folderBtn.width)
                        width: 220; padding: 8
                        background: Rectangle { color: Appearance.colors.colLayer2Base; radius: Appearance.rounding.normal; border.color: Qt.rgba(1,1,1,0.12); border.width: 1 }

                        ColumnLayout { anchors.fill: parent; spacing: 6
                            StyledText { text: "Library folder:"; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
                            TextField {
                                id: pathField; Layout.fillWidth: true
                                text: root.editPathText
                                color: Appearance.colors.colOnLayer1
                                font.pixelSize: Appearance.font.pixelSize.small
                                background: Rectangle { color: Appearance.colors.colLayer1; radius: Appearance.rounding.small; border.color: pathField.activeFocus ? Appearance.colors.colPrimary : "transparent"; border.width: 1 }
                                onTextChanged: root.editPathText = text
                                Keys.onEscapePressed: pathPopup.close()
                            }
                            RowLayout { Layout.fillWidth: true; spacing: 6
                                Button { Layout.fillWidth: true; text: "Cancel"; implicitHeight: 26
                                    background: Rectangle { color: parent.hovered ? Appearance.colors.colLayer1 : "transparent"; radius: Appearance.rounding.small }
                                    contentItem: StyledText { text: parent.text; color: Appearance.colors.colSubtext; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Appearance.font.pixelSize.small }
                                    onClicked: { root.editPathText = root.rootPath; pathPopup.close() }
                                }
                                Button { Layout.fillWidth: true; text: "Apply"; implicitHeight: 26
                                    background: Rectangle { color: parent.hovered ? Qt.darker(Appearance.colors.colPrimary,1.1) : Appearance.colors.colPrimary; radius: Appearance.rounding.small }
                                    contentItem: StyledText { text: parent.text; color: "white"; horizontalAlignment: Text.AlignHCenter; font.pixelSize: Appearance.font.pixelSize.small; font.bold: true }
                                    onClicked: { 
                                        pathConfig.setText(root.editPathText+"\n"); 
                                        root.rootPath = root.editPathText; 
                                        root.categoriesData = [];
                                        scanProcess.running = false;
                                        scanProcess.running = true; 
                                        pathPopup.close();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── Book list ───────────────────────────────────────────
        Flickable {
            id: flick
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: width
            contentHeight: booksCol.height
            clip: true
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

            Column {
                id: booksCol
                width: flick.width
                spacing: 10

                // Empty state
                Item {
                    width: parent.width; height: 70
                    visible: root.categoriesData.length === 0
                    Column { anchors.centerIn: parent; spacing: 6
                        MaterialSymbol { anchors.horizontalCenter: parent.horizontalCenter; text: "hourglass_top"; iconSize: 28; color: Appearance.colors.colSubtext }
                        StyledText { anchors.horizontalCenter: parent.horizontalCenter; text: "Loading..."; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small }
                    }
                }

                Repeater {
                    model: root.categoriesData

                    Column {
                        required property var modelData
                        required property int index
                        id: catCol
                        width: booksCol.width
                        spacing: 5

                        // Category header
                        Column {
                            width: parent.width
                            spacing: 4
                            property bool editing: false
                            id: catHeader

                            // Normal row
                            RowLayout {
                                width: parent.width
                                height: 26
                                spacing: 4

                                Rectangle { width: 3; height: 16; radius: 2; color: Appearance.colors.colPrimary }
                                MaterialSymbol { text: "folder"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colPrimary }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.displayCatName(catCol.modelData.category)
                                    color: Appearance.colors.colOnLayer1
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    text: catCol.modelData.books ? catCol.modelData.books.length : 0
                                    color: Appearance.colors.colSubtext
                                    font.pixelSize: Appearance.font.pixelSize.small - 1
                                }
                                Button {
                                    id: renameBtn; implicitWidth: 20; implicitHeight: 20
                                    background: Rectangle { color: renameBtn.hovered ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                                    contentItem: MaterialSymbol {
                                        text: catHeader.editing ? "close" : "edit"
                                        iconSize: 13
                                        color: catHeader.editing ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    onClicked: {
                                        catHeader.editing = !catHeader.editing
                                        if (catHeader.editing) catEditField.forceActiveFocus()
                                    }
                                }
                                Button {
                                    id: delCatBtn; implicitWidth: 20; implicitHeight: 20
                                    visible: catCol.modelData.category !== "📖 General"
                                    background: Rectangle { color: delCatBtn.hovered ? Appearance.colors.colLayer2 : "transparent"; radius: Appearance.rounding.small }
                                    contentItem: MaterialSymbol {
                                        text: "delete"
                                        iconSize: 13
                                        color: delCatBtn.hovered ? Appearance.colors.colError : Appearance.colors.colSubtext
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    onClicked: root.deleteCategory(catCol.modelData.category)
                                    StyledToolTip { text: Translation.tr("Delete Category") }
                                }
                            }

                            // Edit row — expands below when editing
                            Rectangle {
                                width: parent.width
                                height: catHeader.editing ? 34 : 0
                                visible: height > 0
                                clip: true
                                color: "transparent"
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 4
                                    visible: catHeader.editing

                                    TextField {
                                        id: catEditField
                                        Layout.fillWidth: true
                                        implicitHeight: 28
                                        text: root.displayCatName(catCol.modelData.category)
                                        color: Appearance.colors.colOnLayer1
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.bold: true
                                        placeholderText: catCol.modelData.category
                                        background: Rectangle {
                                            color: Appearance.colors.colLayer1
                                            radius: Appearance.rounding.small
                                            border.color: Appearance.colors.colPrimary
                                            border.width: 1
                                        }
                                        Keys.onEscapePressed: catHeader.editing = false
                                        Keys.onReturnPressed: {
                                            var o = Object.assign({}, root.catRenames)
                                            o[catCol.modelData.category] = catEditField.text
                                            root.catRenames = o
                                            root.saveCatRenames()
                                            catHeader.editing = false
                                        }
                                        onVisibleChanged: if (visible) forceActiveFocus()
                                    }
                                    Button {
                                        id: applyRename; implicitWidth: 28; implicitHeight: 28
                                        background: Rectangle { color: applyRename.hovered ? Appearance.colors.colPrimary : Appearance.colors.colLayer2; radius: Appearance.rounding.small }
                                        contentItem: MaterialSymbol { text: "check"; iconSize: 14; color: applyRename.hovered ? "white" : Appearance.colors.colOnLayer1; horizontalAlignment: Text.AlignHCenter }
                                        onClicked: {
                                            var o = Object.assign({}, root.catRenames)
                                            o[catCol.modelData.category] = catEditField.text
                                            root.catRenames = o
                                            root.saveCatRenames()
                                            catHeader.editing = false
                                        }
                                    }
                                }
                            }
                        }

                        // Books Grid — 3 columns to fit narrow sidebar
                        Grid {
                            width: parent.width
                            columns: 3
                            spacing: 5

                            Repeater {
                                model: catCol.modelData.books || []

                                Item {
                                    required property var modelData
                                    required property int index
                                    // Explicit size: 3 cols with 2 gaps of 5px
                                    width: Math.floor((booksCol.width - 10) / 3)
                                    height: width * 1.35

                                    Rectangle {
                                        anchors.fill: parent
                                        radius: Appearance.rounding.small
                                        color: Appearance.colors.colLayer1
                                        clip: true

                                        Image {
                                            id: cov; anchors.fill: parent
                                            source: modelData.cover ? "file://" + modelData.cover : ""
                                            fillMode: Image.PreserveAspectCrop
                                            asynchronous: true
                                            visible: status === Image.Ready
                                        }
                                        Item {
                                            anchors.fill: parent
                                            visible: cov.status !== Image.Ready
                                            MaterialSymbol { anchors.centerIn: parent; text: "picture_as_pdf"; iconSize: 22; color: Appearance.colors.colPrimary }
                                        }
                                        // gradient
                                        Rectangle {
                                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                                            height: parent.height * 0.45
                                            gradient: Gradient {
                                                GradientStop { position: 0.0; color: "transparent" }
                                                GradientStop { position: 1.0; color: "#CC000000" }
                                            }
                                        }
                                        // title
                                        StyledText {
                                            anchors.bottom: parent.bottom; anchors.left: parent.left; anchors.right: parent.right
                                            anchors.margins: 3
                                            text: modelData.name; color: "white"
                                            font.pixelSize: 8; font.bold: true
                                            wrapMode: Text.NoWrap; elide: Text.ElideRight
                                        }
                                        // selection overlay
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.3)
                                            border.color: Appearance.colors.colPrimary
                                            border.width: 2
                                            radius: Appearance.rounding.small
                                            visible: root.selectedBooks.indexOf(modelData.path) !== -1
                                            
                                            MaterialSymbol {
                                                anchors.top: parent.top; anchors.right: parent.right
                                                anchors.margins: 4
                                                text: "check_circle"
                                                iconSize: 18
                                                color: "white"
                                            }
                                        }

                                        // hover
                                        Rectangle { anchors.fill: parent; radius: Appearance.rounding.small; color: Qt.rgba(1,1,1,0.08); visible: mc.containsMouse && root.selectedBooks.indexOf(modelData.path) === -1 }
                                        MouseArea {
                                            id: mc; anchors.fill: parent; hoverEnabled: true
                                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: (mouse) => {
                                                if (root.selectionMode) {
                                                    root.toggleSelection(modelData.path)
                                                } else {
                                                    if (mouse.button === Qt.RightButton) {
                                                        root.selectedBooks = [modelData.path]
                                                        root.reclassBookName = modelData.name
                                                        root.showReclassDialog = true
                                                    } else {
                                                        Quickshell.execDetached(["xdg-open", modelData.path])
                                                    }
                                                }
                                            }
                                            onPressAndHold: {
                                                if (!root.selectionMode) {
                                                    root.selectionMode = true
                                                    root.toggleSelection(modelData.path)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Separator
                        Rectangle {
                            width: parent.width; height: 1
                            color: Qt.rgba(1,1,1,0.07)
                            visible: index < root.categoriesData.length - 1
                        }
                    }
                }
            }
        }
    }

    // ── Reclassify overlay ─────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0,0,0,0.6)
        visible: root.showReclassDialog
        z: 200
        MouseArea { anchors.fill: parent; onClicked: root.showReclassDialog = false }

        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - 40, 280)
            height: dlgCol.implicitHeight + 24
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1Base
            border.color: Appearance.colors.colLayer2; border.width: 2
            MouseArea { anchors.fill: parent }

            Column {
                id: dlgCol
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12; topMargin: 12 }
                spacing: 12

                Column {
                    width: parent.width
                    spacing: 4
                    RowLayout {
                        spacing: 8
                        MaterialSymbol { text: "drive_file_move"; iconSize: Appearance.font.pixelSize.normal + 2; color: Appearance.colors.colPrimary }
                        StyledText { text: Translation.tr("Move to Category"); font.bold: true; color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.normal }
                    }
                    StyledText { width: parent.width; text: root.reclassBookName; color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.small; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                }

                Rectangle { width: parent.width; height: 1; color: Appearance.colors.colLayer2 }

                Flickable {
                    width: parent.width
                    height: Math.min(200, catListCol.implicitHeight)
                    contentWidth: width
                    contentHeight: catListCol.implicitHeight
                    clip: true
                    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                    
                    Column {
                        id: catListCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: root.categoriesData
                            Button {
                                required property var modelData
                                width: catListCol.width; implicitHeight: 36
                                background: Rectangle { 
                                    color: parent.hovered ? Appearance.colors.colLayer2 : "transparent"
                                    radius: Appearance.rounding.normal
                                    border.color: parent.hovered ? Appearance.colors.colPrimary : "transparent"
                                    border.width: 1
                                }
                                contentItem: RowLayout { 
                                    spacing: 10; anchors.leftMargin: 10; anchors.rightMargin: 10
                                    MaterialSymbol { text: "folder"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colPrimary }
                                    StyledText { text: root.displayCatName(modelData.category); color: Appearance.colors.colOnLayer1; font.pixelSize: Appearance.font.pixelSize.small; Layout.fillWidth: true; elide: Text.ElideRight }
                                }
                                onClicked: root.reassignBook(modelData.category)
                            }
                        }
                    }
                }

                // Add new category field
                RowLayout {
                    width: parent.width
                    spacing: 6
                    TextField {
                        id: moveNewCatField
                        Layout.fillWidth: true
                        implicitHeight: 32
                        placeholderText: Translation.tr("New Category...")
                        color: Appearance.colors.colOnLayer1
                        font.pixelSize: Appearance.font.pixelSize.small
                        background: Rectangle {
                            color: Appearance.colors.colLayer2
                            radius: Appearance.rounding.small
                            border.color: moveNewCatField.activeFocus ? Appearance.colors.colPrimary : "transparent"
                            border.width: 1
                        }
                        Keys.onReturnPressed: {
                            if (text.trim() !== "") {
                                var newCat = text.trim();
                                var arr = root.userCategories.slice();
                                if (arr.indexOf(newCat) === -1) { arr.push(newCat); root.userCategories = arr; root.saveUserCategories(); }
                                root.reassignBook(newCat)
                                text = ""
                            }
                        }
                    }
                    Button {
                        implicitWidth: 32; implicitHeight: 32
                        background: Rectangle { 
                            color: parent.hovered ? Qt.darker(Appearance.colors.colPrimary, 1.1) : Appearance.colors.colPrimary
                            radius: Appearance.rounding.small 
                        }
                        contentItem: MaterialSymbol { text: "add"; iconSize: Appearance.font.pixelSize.normal; color: "white"; horizontalAlignment: Text.AlignHCenter }
                        onClicked: {
                            if (moveNewCatField.text.trim() !== "") {
                                var newCat = moveNewCatField.text.trim();
                                var arr = root.userCategories.slice();
                                if (arr.indexOf(newCat) === -1) { arr.push(newCat); root.userCategories = arr; root.saveUserCategories(); }
                                root.reassignBook(newCat)
                                moveNewCatField.text = ""
                            }
                        }
                    }
                }

                Button {
                    width: parent.width; implicitHeight: 36
                    background: Rectangle { 
                        color: parent.hovered ? Qt.rgba(1, 0, 0, 0.1) : Appearance.colors.colLayer2
                        radius: Appearance.rounding.normal 
                    }
                    contentItem: StyledText { 
                        text: Translation.tr("Cancel")
                        color: parent.parent.hovered ? "#ff5555" : Appearance.colors.colSubtext
                        horizontalAlignment: Text.AlignHCenter
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.bold: true
                    }
                    onClicked: root.showReclassDialog = false
                }
            }
        }
    }
}
