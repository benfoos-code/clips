import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win

    width: 760
    height: 660
    minimumWidth: 440
    minimumHeight: 420
    visible: true
    title: qsTr("Clips")
    color: ui.canvas

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    // One place for the palette and the scale of detail, so every surface in
    // the window agrees. The accent and corner radius stay live with the theme.
    property var ui: QtObject {
        readonly property color canvas: "#0b0b0d"
        readonly property color surface: "#151518"
        readonly property color raised: "#1c1c20"
        readonly property color floating: "#202025"
        readonly property color line: Qt.rgba(1, 1, 1, 0.08)
        readonly property color primaryText: "#f5f5f7"
        readonly property color subtext: "#a1a1a6"
        readonly property color faint: "#6e6e73"
        readonly property color accent: theme.accent
        // Corners follow the desktop: sharp by default, rounded when the
        // theme rounds its windows. Only circles keep a fixed radius.
        readonly property int radius: Math.min(18, theme.radius)
        readonly property int smallRadius: Math.min(4, theme.radius)

        function accentAlpha(alpha) {
            return Qt.rgba(Qt.color(accent).r, Qt.color(accent).g, Qt.color(accent).b, alpha)
        }
    }

    property bool helpVisible: false
    property string toast: ""
    property bool toastError: false
    property var filtered: []
    readonly property bool typing: searchField.activeFocus

    property var hints: [
        { key: "Space", what: qsTr("Copy") },
        { key: "Enter", what: qsTr("Open") },
        { key: "/", what: qsTr("Search") },
        { key: "?", what: qsTr("All shortcuts") }
    ]

    // Filters the history down to the entries matching the search box, keeping
    // each entry's original file index so copying and opening still address it.
    function recompute() {
        var query = searchField.text.trim().toLowerCase()
        var source = backend.entries
        if (query.length === 0) {
            win.filtered = source
        } else {
            var matches = []
            for (var i = 0; i < source.length; ++i) {
                var entry = source[i]
                var haystack = entry.search !== undefined ? entry.search : ""
                if (haystack.indexOf(query) !== -1)
                    matches.push(entry)
            }
            win.filtered = matches
        }

        if (win.filtered.length === 0)
            list.currentIndex = -1
        else if (list.currentIndex < 0 || list.currentIndex >= win.filtered.length)
            list.currentIndex = 0
    }

    function selectedEntry() {
        if (list.currentIndex < 0 || list.currentIndex >= win.filtered.length)
            return null
        return win.filtered[list.currentIndex]
    }

    function copyCurrent() {
        var entry = win.selectedEntry()
        if (entry)
            backend.copyEntry(entry.index)
    }

    function openCurrent() {
        var entry = win.selectedEntry()
        if (entry)
            backend.openEntry(entry.index)
    }

    function move(delta) {
        if (win.filtered.length === 0)
            return
        var next = list.currentIndex + delta
        if (next < 0)
            next = 0
        if (next >= win.filtered.length)
            next = win.filtered.length - 1
        list.currentIndex = next
        list.positionViewAtIndex(next, ListView.Contain)
    }

    function showToast(message, error) {
        win.toast = message
        win.toastError = !!error
        toastTimer.restart()
    }

    Component.onCompleted: win.recompute()

    Connections {
        target: backend
        function onEntriesChanged() { win.recompute() }
        function onCopied(index) { win.showToast(qsTr("Copied to clipboard"), false) }
        function onOpened(index) { win.showToast(qsTr("Opened"), false) }
        function onFailed(message) { win.showToast(message, true) }
    }

    Timer {
        id: toastTimer
        interval: 2400
        onTriggered: win.toast = ""
    }

    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: Qt.quit() }
    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.helpVisible = true }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.copyCurrent() }
    Shortcut { sequence: "Return"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.openCurrent() }
    Shortcut { sequence: "Enter"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.openCurrent() }
    Shortcut { sequence: "Down"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: win.move(1) }
    Shortcut { sequence: "Up"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: win.move(-1) }
    Shortcut { sequence: "PageDown"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: win.move(10) }
    Shortcut { sequence: "PageUp"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: win.move(-10) }
    Shortcut { sequence: "j"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.move(1) }
    Shortcut { sequence: "k"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.move(-1) }
    Shortcut { sequence: "J"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.move(1) }
    Shortcut { sequence: "K"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.move(-1) }
    Shortcut { sequence: "g"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.move(-win.filtered.length) }
    Shortcut { sequence: "G"; context: Qt.ApplicationShortcut; enabled: !win.typing && !win.helpVisible; onActivated: win.move(win.filtered.length) }
    Shortcut { sequence: "/"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: searchField.forceActiveFocus() }
    Shortcut { sequence: "Ctrl+F"; context: Qt.ApplicationShortcut; enabled: !win.helpVisible; onActivated: searchField.forceActiveFocus() }
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        onActivated: {
            if (win.helpVisible)
                win.helpVisible = false
            else if (searchField.text.length > 0)
                searchField.text = ""
            else
                searchField.focus = false
        }
    }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // Toolbar -------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                color: ui.surface
                implicitHeight: toolbar.implicitHeight + 30

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 1
                    color: ui.line
                }

                ColumnLayout {
                    id: toolbar
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 18
                    spacing: 14

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12

                        Rectangle {
                            width: 32
                            height: 32
                            radius: ui.smallRadius
                            color: ui.accentAlpha(0.13)
                            border.color: ui.accentAlpha(0.4)
                            border.width: 1

                            Icon {
                                anchors.centerIn: parent
                                name: "stack"
                                width: 19
                                height: 19
                                weight: 1.4
                                tint: ui.accent
                            }
                        }

                        ColumnLayout {
                            spacing: 1

                            Text {
                                textFormat: Text.PlainText
                                text: qsTr("Clips")
                                color: ui.primaryText
                                font.pixelSize: 16
                                font.bold: true
                                font.letterSpacing: 0.2
                            }

                            Text {
                                textFormat: Text.PlainText
                                text: qsTr("%n clips", "", win.filtered.length)
                                color: ui.faint
                                font.pixelSize: 12
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Item {
                            width: 32
                            height: 32
                            scale: helpButton.pressed ? 0.94 : 1

                            Behavior on scale {
                                NumberAnimation { duration: 100; easing.type: Easing.OutCubic }
                            }

                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: helpHover.hovered ? Qt.rgba(1, 1, 1, 0.09) : Qt.rgba(1, 1, 1, 0.04)
                                border.color: ui.line
                                border.width: 1
                            }

                            Text {
                                anchors.centerIn: parent
                                textFormat: Text.PlainText
                                text: "?"
                                color: ui.subtext
                                font.pixelSize: 15
                                font.bold: true
                            }

                            HoverHandler { id: helpHover }

                            TapHandler {
                                id: helpButton
                                onTapped: win.helpVisible = true
                            }

                            ToolTip {
                                visible: helpHover.hovered
                                delay: 400
                                text: qsTr("Shortcuts")
                            }
                        }
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            id: searchShell
                            Layout.fillWidth: true
                            height: 42
                            radius: ui.smallRadius
                            color: ui.raised
                            border.color: searchField.activeFocus ? ui.accentAlpha(0.55) : ui.line
                            border.width: 1

                            Behavior on border.color {
                                ColorAnimation { duration: 130; easing.type: Easing.OutCubic }
                            }

                            Icon {
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                name: "search"
                                width: 18
                                height: 18
                                tint: searchField.activeFocus ? ui.accent : ui.subtext
                            }

                            TextField {
                                id: searchField
                                anchors.fill: parent
                                anchors.leftMargin: 40
                                anchors.rightMargin: 44
                                background: null
                                color: ui.primaryText
                                placeholderText: qsTr("Search clips")
                                placeholderTextColor: ui.faint
                                font.pixelSize: 14
                                verticalAlignment: TextInput.AlignVCenter
                                selectByMouse: true
                                onTextChanged: win.recompute()
                            }

                            KeyCap {
                                anchors.right: parent.right
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text.length === 0
                                label: "/"
                                accent: ui.subtext
                                fill: Qt.rgba(1, 1, 1, 0.04)
                                stroke: Qt.rgba(1, 1, 1, 0.1)
                                corner: ui.smallRadius
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 26
                                height: 26
                                visible: searchField.text.length > 0

                                Icon {
                                    anchors.centerIn: parent
                                    name: "close"
                                    width: 14
                                    height: 14
                                    weight: 1.6
                                    tint: ui.subtext
                                }

                                TapHandler {
                                    onTapped: {
                                        searchField.text = ""
                                        searchField.forceActiveFocus()
                                    }
                                }
                            }
                        }

                        ToolAction {
                            text: qsTr("Copy")
                            glyph: "copy"
                            keyHint: "Space"
                            enabled: win.filtered.length > 0
                            tint: ui.accent
                            surface: ui.raised
                            edge: ui.line
                            labelColor: ui.primaryText
                            corner: ui.smallRadius
                            showKey: win.width >= 560
                            onClicked: win.copyCurrent()
                        }

                        ToolAction {
                            text: qsTr("Open")
                            glyph: "open"
                            keyHint: "Enter"
                            enabled: win.filtered.length > 0
                            tint: ui.accent
                            surface: ui.raised
                            edge: ui.line
                            labelColor: ui.primaryText
                            corner: ui.smallRadius
                            showKey: win.width >= 560
                            onClicked: win.openCurrent()
                        }
                    }
                }
            }

            // Content -------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: ui.canvas

                Rectangle {
                    id: listHeader
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 44

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: qsTr("Recent")
                        color: ui.faint
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.4
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 24
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 7

                        Rectangle {
                            width: 6
                            height: 6
                            radius: width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            color: ui.accent
                            opacity: backend.available ? 0.9 : 0.3
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            textFormat: Text.PlainText
                            text: qsTr("Live").toUpperCase()
                            color: ui.faint
                            font.pixelSize: 10
                            font.bold: true
                            font.letterSpacing: 1.1
                        }
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 24
                        anchors.rightMargin: 24
                        height: 1
                        color: ui.line
                    }
                }

                ListView {
                    id: list
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: listHeader.bottom
                    anchors.bottom: parent.bottom
                    clip: true
                    model: win.filtered
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    delegate: ClipRow {
                        width: list.width
                        tokens: win.ui
                        current: ListView.isCurrentItem
                        onSelected: list.currentIndex = index
                        onActivated: {
                            list.currentIndex = index
                            win.copyCurrent()
                        }
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    visible: win.filtered.length === 0

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 60
                        height: 60
                        radius: ui.radius
                        color: ui.raised
                        border.color: ui.line
                        border.width: 1

                        Icon {
                            anchors.centerIn: parent
                            name: "stack"
                            width: 26
                            height: 26
                            tint: ui.faint
                            weight: 1.3
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        text: !backend.available ? qsTr("Clipboard history not found")
                              : backend.count === 0 ? qsTr("No clipboard history yet")
                              : qsTr("No matches")
                        color: ui.primaryText
                        font.pixelSize: 15
                        font.bold: true
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        text: !backend.available ? backend.historyPath
                              : backend.count === 0 ? qsTr("Copied clips will appear here")
                              : qsTr("Try a different search")
                        color: ui.faint
                        font.pixelSize: 12
                        width: Math.min(360, win.width - 80)
                        elide: Text.ElideMiddle
                    }
                }

                // Floating confirmation: success and failure share the same
                // spot, but never the same colour.
                Rectangle {
                    id: toastPill
                    z: 2
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    height: 30
                    width: toastText.implicitWidth + 54
                    radius: ui.smallRadius
                    color: win.toastError ? Qt.rgba(0.72, 0.19, 0.23, 0.18) : ui.accentAlpha(0.14)
                    border.color: win.toastError ? Qt.rgba(0.86, 0.29, 0.33, 0.5) : ui.accentAlpha(0.45)
                    border.width: 1
                    opacity: win.toast.length > 0 ? 1 : 0
                    y: win.toast.length > 0 ? 10 : 2

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }
                    Behavior on y {
                        NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                    }

                    Icon {
                        anchors.left: parent.left
                        anchors.leftMargin: 11
                        anchors.verticalCenter: parent.verticalCenter
                        name: win.toastError ? "alert" : "check"
                        width: 15
                        height: 15
                        weight: 1.7
                        tint: win.toastError ? "#ff7b84" : ui.accent
                    }

                    Text {
                        id: toastText
                        anchors.left: parent.left
                        anchors.leftMargin: 33
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        textFormat: Text.PlainText
                        text: win.toast
                        color: ui.primaryText
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }
                }
            }

            // Footer --------------------------------------------------------
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 46
                color: ui.surface

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: ui.line
                }

                Row {
                    id: footer
                    anchors.centerIn: parent
                    spacing: 22

                    Repeater {
                        model: win.hints

                        delegate: Row {
                            spacing: 8
                            anchors.verticalCenter: parent.verticalCenter

                            KeyCap {
                                anchors.verticalCenter: parent.verticalCenter
                                label: modelData.key
                                accent: ui.accent
                                fill: Qt.rgba(1, 1, 1, 0.04)
                                stroke: Qt.rgba(1, 1, 1, 0.1)
                                corner: ui.smallRadius
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                textFormat: Text.PlainText
                                text: modelData.what
                                color: ui.subtext
                                font.pixelSize: 12
                            }
                        }
                    }
                }
            }
        }

        HelpOverlay {
            id: help
            shown: win.helpVisible
            tokens: win.ui
            onDismissed: win.helpVisible = false
        }
    }
}
