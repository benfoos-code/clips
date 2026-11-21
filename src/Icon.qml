import QtQuick

// Small line icons drawn on a 20x20 grid. Drawing them here keeps every glyph
// on the same stroke weight and lets the Omarchy accent colour flow through.
Canvas {
    id: icon

    property string name: "search"
    property color tint: "#a1a1a6"
    property real weight: 1.5

    width: 20
    height: 20
    antialiasing: true

    onNameChanged: requestPaint()
    onTintChanged: requestPaint()
    onWeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.save()
        ctx.scale(width / 20, height / 20)
        ctx.strokeStyle = tint
        ctx.fillStyle = tint
        ctx.lineWidth = weight
        ctx.lineCap = "round"
        ctx.lineJoin = "round"

        switch (name) {
        case "search":
            ctx.beginPath()
            ctx.arc(8.5, 8.5, 5.2, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(12.5, 12.5)
            ctx.lineTo(17, 17)
            ctx.stroke()
            break
        case "copy":
            ctx.strokeRect(6.5, 3.5, 10, 10)
            ctx.strokeRect(3.5, 6.5, 10, 10)
            break
        case "open":
            ctx.beginPath()
            ctx.moveTo(11, 3)
            ctx.lineTo(16.5, 3)
            ctx.lineTo(16.5, 8.5)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(16.5, 3)
            ctx.lineTo(9.5, 10)
            ctx.stroke()
            ctx.strokeRect(3.5, 9, 10, 8)
            break
        case "text":
            ctx.strokeRect(4.5, 2.5, 11, 15)
            ctx.beginPath()
            ctx.moveTo(7, 6.5)
            ctx.lineTo(13, 6.5)
            ctx.moveTo(7, 10)
            ctx.lineTo(13, 10)
            ctx.moveTo(7, 13.5)
            ctx.lineTo(11.5, 13.5)
            ctx.stroke()
            break
        case "image":
            ctx.strokeRect(2.5, 3.5, 15, 13)
            ctx.beginPath()
            ctx.arc(6.5, 7.5, 1.4, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(3.5, 14)
            ctx.lineTo(8, 9.5)
            ctx.lineTo(11, 12.5)
            ctx.lineTo(13.5, 10)
            ctx.lineTo(16.5, 13.5)
            ctx.stroke()
            break
        case "stack":
            ctx.strokeRect(6.5, 2.5, 11, 11)
            ctx.strokeRect(3.5, 6.5, 11, 11)
            break
        case "check":
            ctx.beginPath()
            ctx.moveTo(3.5, 10.5)
            ctx.lineTo(8, 15)
            ctx.lineTo(16.5, 5)
            ctx.stroke()
            break
        case "alert":
            ctx.beginPath()
            ctx.arc(10, 10, 7, 0, Math.PI * 2)
            ctx.stroke()
            ctx.beginPath()
            ctx.moveTo(10, 6)
            ctx.lineTo(10, 11)
            ctx.stroke()
            ctx.beginPath()
            ctx.arc(10, 14, 0.9, 0, Math.PI * 2)
            ctx.fill()
            break
        case "close":
            ctx.beginPath()
            ctx.moveTo(5, 5)
            ctx.lineTo(15, 15)
            ctx.moveTo(15, 5)
            ctx.lineTo(5, 15)
            ctx.stroke()
            break
        }

        ctx.restore()
    }
}
