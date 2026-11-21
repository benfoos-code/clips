import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A compact toolbar button with an icon, a label and the key that triggers it.
// Keeping the key on the button means the shortcuts are never a mystery.
Button {
    id: control

    property string glyph: ""
    property string keyHint: ""
    property color tint: "#FFD60A"
    property color surface: "#1c1c20"
    property color edge: Qt.rgba(1, 1, 1, 0.08)
    property color labelColor: "#f5f5f7"
    property int corner: 0
    // The footer already carries the keys on a narrow window, so the toolbar
    // buttons drop their keycaps to leave room for the search field.
    property bool showKey: true

    implicitHeight: 42
    padding: 0

    background: Rectangle {
        color: control.down ? Qt.rgba(1, 1, 1, 0.11)
                            : control.hovered ? Qt.rgba(1, 1, 1, 0.06)
                                              : control.surface
        border.color: control.hovered ? Qt.rgba(Qt.color(control.tint).r,
                                                 Qt.color(control.tint).g,
                                                 Qt.color(control.tint).b, 0.45)
                                      : control.edge
        border.width: 1
        radius: control.corner

        Behavior on color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 110; easing.type: Easing.OutCubic } }
    }

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8

        Icon {
            Layout.preferredWidth: 16
            Layout.preferredHeight: 16
            name: control.glyph
            width: 16
            height: 16
            weight: 1.5
            tint: control.tint
        }

        Text {
            textFormat: Text.PlainText
            text: control.text
            color: control.labelColor
            font.pixelSize: 13
            font.weight: Font.Medium
        }

        KeyCap {
            visible: control.showKey && control.keyHint.length > 0
            label: control.keyHint
            accent: control.tint
            fill: Qt.rgba(1, 1, 1, 0.06)
            stroke: Qt.rgba(1, 1, 1, 0.12)
            corner: control.corner
        }
    }
}
