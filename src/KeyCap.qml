import QtQuick

// A physical-looking key, used in the search field, the toolbar, the footer
// and the shortcut sheet so the same command always looks the same.
Item {
    id: cap

    property string label: ""
    property color accent: "#FFD60A"
    property color fill: "#1c1c20"
    property color stroke: "#34343b"
    property int corner: 0

    implicitWidth: labelText.implicitWidth + 14
    implicitHeight: 21

    Rectangle {
        anchors.fill: parent
        color: cap.fill
        border.color: cap.stroke
        border.width: 1
        radius: cap.corner

        // A one-pixel highlight gives the key a machined edge without a shadow.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 1
            height: 1
            color: Qt.rgba(1, 1, 1, 0.05)
            visible: cap.corner > 0
        }
    }

    Text {
        id: labelText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: cap.label
        color: cap.accent
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 0.3
    }
}
