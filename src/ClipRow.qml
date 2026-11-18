import QtQuick

// One row in the clipboard list. It only shows a preview and reports taps; the
// backend does the copying and the opening.
Item {
    id: row

    required property var modelData
    required property int index
    property bool current: false

    signal activated()
    signal selected()

    readonly property bool isImage: row.modelData.type === "image"
    readonly property string preview: row.modelData.preview !== undefined ? row.modelData.preview : ""
    readonly property string capturedAt: row.modelData.capturedAt !== undefined ? row.modelData.capturedAt : ""
    readonly property int bytes: row.modelData.bytes !== undefined ? row.modelData.bytes : 0

    implicitHeight: 58
    width: ListView.view ? ListView.view.width : implicitWidth

    function formatBytes(value) {
        if (value <= 0)
            return ""
        var units = ["B", "kB", "MB", "GB"]
        var scaled = value
        var unit = 0
        while (scaled >= 1024 && unit < units.length - 1) {
            scaled /= 1024
            ++unit
        }
        if (unit === 0)
            return scaled + " " + units[unit]
        return scaled.toLocaleString(Qt.locale(), 'f', 1) + " " + units[unit]
    }

    Rectangle {
        anchors.fill: parent
        color: row.current ? Qt.rgba(1, 1, 1, 0.07) : (hover.hovered ? Qt.rgba(1, 1, 1, 0.03) : "transparent")
    }

    Rectangle {
        visible: row.current
        width: 3
        color: theme.accent
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
    }

    // A thumbnail for an image entry, and a simple mark for a text one.
    Rectangle {
        id: chip
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: Math.min(6, theme.radius)
        color: "#26262c"
        border.color: "#33333a"
        border.width: 1
        clip: true

        Image {
            anchors.fill: parent
            visible: row.isImage
            source: row.isImage ? "file://" + row.modelData.path : ""
            sourceSize.width: 96
            sourceSize.height: 96
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
        }

        Text {
            anchors.centerIn: parent
            visible: !row.isImage
            text: "T"
            color: theme.accent
            font.pixelSize: 16
            font.bold: true
        }
    }

    Column {
        id: texts
        anchors.left: chip.right
        anchors.leftMargin: 12
        anchors.right: meta.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Text {
            width: parent.width
            textFormat: Text.PlainText
            text: row.isImage ? qsTr("Image") : row.preview
            color: "#ececee"
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
            font.pixelSize: 14
        }

        Text {
            width: parent.width
            textFormat: Text.PlainText
            text: row.isImage ? row.capturedAt : row.formatBytes(row.bytes)
            color: "#8a8a92"
            elide: Text.ElideRight
            font.pixelSize: 12
        }
    }

    Text {
        id: meta
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: row.isImage ? row.modelData.mime : ""
        color: "#6f6f78"
        font.pixelSize: 11
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: row.selected()
        onDoubleTapped: row.activated()
    }
}
