import QtQuick
import QtQuick.Layouts

// The `?` sheet, laid out like a settings pane: grouped sections, labels on the
// left and the keys on the right. It fades and lifts in over the window.
Rectangle {
    id: overlay

    property bool shown: false
    property var tokens: QtObject {
        readonly property color accent: "#FFD60A"
        readonly property color floating: "#1a1a1e"
        readonly property color line: Qt.rgba(1, 1, 1, 0.08)
        readonly property color primaryText: "#f5f5f7"
        readonly property color subtext: "#a1a1a6"
        readonly property color faint: "#6e6e73"
        readonly property int radius: 0
        readonly property int smallRadius: 0
    }

    property var sections: [
        {
            title: qsTr("Navigation"),
            items: [
                { keys: ["↑", "↓", "J", "K"], what: qsTr("Move") },
                { keys: ["g", "G"], what: qsTr("First / last") },
                { keys: ["/"], what: qsTr("Search") },
                { keys: ["Esc"], what: qsTr("Clear search") }
            ]
        },
        {
            title: qsTr("Actions"),
            items: [
                { keys: ["Space"], what: qsTr("Copy") },
                { keys: ["Enter"], what: qsTr("Open") }
            ]
        },
        {
            title: qsTr("General"),
            items: [
                { keys: ["?"], what: qsTr("Shortcuts") },
                { keys: ["Q"], what: qsTr("Quit") }
            ]
        }
    ]

    signal dismissed()

    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.74)
    opacity: overlay.shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
    }

    TapHandler { onTapped: overlay.dismissed() }

    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 480)
        height: Math.min(content.implicitHeight + 52, parent.height - 48)
        radius: overlay.tokens.radius
        color: overlay.tokens.floating
        border.color: overlay.tokens.line
        border.width: 1
        opacity: overlay.shown ? 1 : 0
        scale: overlay.shown ? 1 : 0.97

        Behavior on opacity {
            NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
        }
        Behavior on scale {
            NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
        }

        // Swallows taps on the panel so they do not close the overlay.
        TapHandler { }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 2
            color: overlay.tokens.accent
            opacity: 0.7
            visible: overlay.tokens.radius > 0
        }

        ColumnLayout {
            id: content
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 26
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 32
                    height: 32
                    radius: overlay.tokens.smallRadius
                    color: Qt.rgba(Qt.color(overlay.tokens.accent).r,
                                   Qt.color(overlay.tokens.accent).g,
                                   Qt.color(overlay.tokens.accent).b, 0.14)
                    border.color: Qt.rgba(Qt.color(overlay.tokens.accent).r,
                                          Qt.color(overlay.tokens.accent).g,
                                          Qt.color(overlay.tokens.accent).b, 0.4)
                    border.width: 1

                    Icon {
                        anchors.centerIn: parent
                        name: "text"
                        width: 18
                        height: 18
                        weight: 1.4
                        tint: overlay.tokens.accent
                    }
                }

                ColumnLayout {
                    spacing: 2

                    Text {
                        textFormat: Text.PlainText
                        text: qsTr("Keyboard shortcuts")
                        color: overlay.tokens.primaryText
                        font.pixelSize: 16
                        font.bold: true
                        font.letterSpacing: 0.2
                    }
                }
            }

            Repeater {
                model: overlay.sections

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    Text {
                        Layout.fillWidth: true
                        textFormat: Text.PlainText
                        text: modelData.title.toUpperCase()
                        color: overlay.tokens.faint
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.4
                    }

                    Repeater {
                        model: modelData.items

                        delegate: RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Text {
                                Layout.fillWidth: true
                                textFormat: Text.PlainText
                                text: modelData.what
                                color: overlay.tokens.subtext
                                font.pixelSize: 13
                            }

                            Row {
                                spacing: 5

                                Repeater {
                                    model: modelData.keys

                                    delegate: KeyCap {
                                        label: modelData
                                        accent: overlay.tokens.accent
                                        fill: Qt.rgba(1, 1, 1, 0.05)
                                        stroke: overlay.tokens.line
                                        corner: overlay.tokens.smallRadius
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
