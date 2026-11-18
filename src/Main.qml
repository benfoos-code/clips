import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts

ApplicationWindow {
    id: win

    width: 760
    height: 640
    minimumWidth: 440
    minimumHeight: 360
    visible: true
    title: qsTr("Clips")
    color: "#0e0e10"

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius

    property bool helpVisible: false
    property string toast: ""
    property var filtered: []
    readonly property bool typing: searchField.activeFocus

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

    function showToast(message) {
        win.toast = message
        toastTimer.restart()
    }

    Component.onCompleted: win.recompute()

    Connections {
        target: backend
        function onEntriesChanged() { win.recompute() }
        function onCopied(index) { win.showToast(qsTr("Copied to clipboard")) }
        function onOpened(index) { win.showToast(qsTr("Opened")) }
        function onFailed(message) { win.showToast(message) }
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

            Rectangle {
                Layout.fillWidth: true
                color: "#141417"
                implicitHeight: header.implicitHeight + 24

                ColumnLayout {
                    id: header
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 12
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Text {
                            textFormat: Text.PlainText
                            text: qsTr("Clips")
                            color: "#f2f2f4"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            textFormat: Text.PlainText
                            text: qsTr("%n clips", "", win.filtered.length)
                            color: "#8a8a92"
                            font.pixelSize: 13
                            Layout.alignment: Qt.AlignBottom
                            Layout.bottomMargin: 2
                        }

                        Item { Layout.fillWidth: true }

                        Text {
                            textFormat: Text.PlainText
                            text: win.toast
                            color: theme.accent
                            font.pixelSize: 13
                            elide: Text.ElideRight
                            Layout.maximumWidth: 320
                        }
                    }

                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: qsTr("Search")
                        selectByMouse: true
                        onTextChanged: win.recompute()
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                color: "#0e0e10"

                ListView {
                    id: list
                    anchors.fill: parent
                    clip: true
                    model: win.filtered
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}

                    delegate: ClipRow {
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
                    spacing: 6
                    visible: win.filtered.length === 0

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        text: !backend.available ? qsTr("Clipboard history not found")
                              : backend.count === 0 ? qsTr("No clipboard history yet")
                              : qsTr("No matches")
                        color: "#c8c8ce"
                        font.pixelSize: 15
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        textFormat: Text.PlainText
                        visible: !backend.available
                        text: backend.historyPath
                        color: "#7a7a82"
                        font.pixelSize: 12
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: footer.implicitHeight + 14
                color: "#141417"

                Text {
                    id: footer
                    anchors.centerIn: parent
                    textFormat: Text.PlainText
                    text: qsTr("Press ? for shortcuts")
                    color: "#6f6f78"
                    font.pixelSize: 12
                }
            }
        }

        HelpOverlay {
            id: help
            shown: win.helpVisible
            onDismissed: win.helpVisible = false
        }
    }
}
