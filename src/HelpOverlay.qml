import QtQuick
import QtQuick.Layouts

// The `?` cheat sheet, faded in over the window. Tapping outside reports that
// it should close.
Rectangle {
    id: overlay

    property bool shown: false

    signal dismissed()

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.6)
    opacity: overlay.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
    }

    TapHandler { onTapped: overlay.dismissed() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 420)
        height: content.implicitHeight + 48
        radius: theme.radius
        color: "#1a1a1e"
        border.color: "#2e2e34"
        border.width: 1

        // Swallows taps on the panel so they do not close the overlay.
        TapHandler { }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 10

            Text {
                textFormat: Text.PlainText
                text: qsTr("Keyboard shortcuts")
                color: "#f2f2f4"
                font.pixelSize: 16
                font.bold: true
            }

            Repeater {
                model: [
                    { keys: "↑  ↓  J  K", what: qsTr("Move") },
                    { keys: "g  G", what: qsTr("First / last") },
                    { keys: "Space", what: qsTr("Copy") },
                    { keys: "Enter", what: qsTr("Open") },
                    { keys: "/", what: qsTr("Search") },
                    { keys: "Esc", what: qsTr("Clear search") },
                    { keys: "?", what: qsTr("Shortcuts") },
                    { keys: "Q", what: qsTr("Quit") }
                ]

                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        textFormat: Text.PlainText
                        text: modelData.keys
                        color: theme.accent
                        font.pixelSize: 13
                        Layout.preferredWidth: 120
                    }

                    Text {
                        textFormat: Text.PlainText
                        text: modelData.what
                        color: "#c8c8ce"
                        font.pixelSize: 13
                        Layout.fillWidth: true
                    }
                }
            }
        }
    }
}
