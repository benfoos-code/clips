import QtQuick

// One clip in the list: a small, quiet card that becomes distinctly "active"
// when the keyboard lands on it. The backend still owns every action.
Item {
    id: row

    required property var modelData
    required property int index
    property bool current: false

    property var tokens: QtObject {
        readonly property color accent: "#FFD60A"
        readonly property color raised: "#1c1c20"
        readonly property color line: Qt.rgba(1, 1, 1, 0.08)
        readonly property color primaryText: "#f5f5f7"
        readonly property color subtext: "#a1a1a6"
        readonly property color faint: "#6e6e73"
        readonly property int smallRadius: 0
    }

    signal activated()
    signal selected()

    readonly property bool isImage: row.modelData.type === "image"
    readonly property string preview: row.modelData.preview !== undefined ? row.modelData.preview : ""
    readonly property string capturedAt: row.modelData.capturedAt !== undefined ? row.modelData.capturedAt : ""
    readonly property int bytes: row.modelData.bytes !== undefined ? row.modelData.bytes : 0

    implicitHeight: 72
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

    // The card sits inside the row so the list keeps a steady rhythm and the
    // selection reads as a layer rather than a block of colour.
    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        radius: row.tokens.smallRadius
        color: row.current ? Qt.rgba(Qt.color(row.tokens.accent).r,
                                     Qt.color(row.tokens.accent).g,
                                     Qt.color(row.tokens.accent).b, 0.13)
                           : hover.hovered ? Qt.rgba(1, 1, 1, 0.05)
                                           : Qt.rgba(1, 1, 1, 0.022)
        border.color: row.current ? Qt.rgba(Qt.color(row.tokens.accent).r,
                                             Qt.color(row.tokens.accent).g,
                                             Qt.color(row.tokens.accent).b, 0.5)
                                  : row.tokens.line
        border.width: 1

        Behavior on color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on border.color { ColorAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }

    Rectangle {
        visible: row.current
        width: 2
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        color: row.tokens.accent
    }

    // Hairline cell divider, inset like a table cell.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.right: parent.right
        anchors.rightMargin: 24
        height: 1
        color: row.tokens.line
        visible: ListView.view !== null && row.index < ListView.view.count - 1
    }

    Rectangle {
        id: thumb
        anchors.left: parent.left
        anchors.leftMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        width: 44
        height: 44
        radius: row.tokens.smallRadius
        color: row.tokens.raised
        border.color: row.tokens.line
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

        Icon {
            anchors.centerIn: parent
            visible: !row.isImage
            name: "text"
            width: 22
            height: 22
            weight: 1.4
            tint: row.tokens.accent
        }
    }

    Column {
        anchors.left: thumb.right
        anchors.leftMargin: 14
        anchors.right: meta.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4

        Text {
            width: parent.width
            textFormat: Text.PlainText
            text: row.isImage ? qsTr("Image") : row.preview
            color: row.tokens.primaryText
            font.pixelSize: 14
            font.weight: Font.Medium
            elide: Text.ElideRight
            maximumLineCount: 2
            wrapMode: Text.Wrap
        }

        Text {
            width: parent.width
            textFormat: Text.PlainText
            // Reading the language here re-formats the size after a language
            // switch, so numbers follow the desktop's locale.
            text: {
                translator.language
                return row.isImage ? row.capturedAt : row.formatBytes(row.bytes)
            }
            color: row.tokens.subtext
            font.pixelSize: 12
            elide: Text.ElideRight
        }
    }

    Row {
        id: meta
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: row.isImage ? row.modelData.mime : ""
            color: row.tokens.faint
            font.pixelSize: 11
        }

        KeyCap {
            anchors.verticalCenter: parent.verticalCenter
            visible: row.current
            label: "↵"
            accent: row.tokens.accent
            fill: Qt.rgba(1, 1, 1, 0.06)
            stroke: Qt.rgba(1, 1, 1, 0.12)
            corner: row.tokens.smallRadius
        }
    }

    HoverHandler { id: hover }

    TapHandler {
        onTapped: row.selected()
        onDoubleTapped: row.activated()
    }
}
