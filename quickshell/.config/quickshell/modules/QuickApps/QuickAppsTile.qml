import QtQuick
import "../../services"

// QuickAppsTile.qml — reusable tile delegate shared by all three
// QuickApps.qml layouts (grid/radial/hex).
//
// `hexShape` swaps the rendering from a rounded rectangle to a
// hexagonal outline via a Canvas-drawn path, keeping the same
// label/selection/click contract for all three layouts so QuickApps.qml
// doesn't need three separate tile implementations.
Item {
    id: root

    property string label: ""
    property bool selected: false
    property bool hexShape: false

    signal activated

    // ---- Rounded-rectangle variant (grid/radial) -----------------------
    Rectangle {
        visible: !root.hexShape
        anchors.fill: parent
        radius: Theme.radius * 0.5
        color: root.selected ? Theme.colors.accent : Theme.colors.surface
        border.color: root.selected ? Theme.colors.accent : Theme.colors.muted
        border.width: 1

        Text {
            anchors.centerIn: parent
            width: parent.width - 8
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.label
            color: root.selected ? Theme.colors.background : Theme.colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 11
            font.bold: root.selected
        }
    }

    // ---- Hexagon variant (hex layout) ----------------------------------
    Canvas {
        id: hexCanvas
        visible: root.hexShape
        anchors.fill: parent

        readonly property color fillColor: root.selected ? Theme.colors.accent : Theme.colors.surface
        readonly property color strokeColor: root.selected ? Theme.colors.accent : Theme.colors.muted

        onFillColorChanged: requestPaint()
        onStrokeColorChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const h = height;
            const cx = w / 2;
            const cy = h / 2;
            const rx = w / 2 - 2;
            const ry = h / 2 - 2;

            ctx.beginPath();
            for (let i = 0; i < 6; i++) {
                // Pointy-top hexagon: first vertex straight up.
                const angle = Math.PI / 2 + (i * Math.PI) / 3;
                const px = cx + rx * Math.cos(angle);
                const py = cy - ry * Math.sin(angle);
                if (i === 0)
                    ctx.moveTo(px, py);
                else
                    ctx.lineTo(px, py);
            }
            ctx.closePath();
            ctx.fillStyle = fillColor;
            ctx.fill();
            ctx.lineWidth = 1;
            ctx.strokeStyle = strokeColor;
            ctx.stroke();
        }

        Text {
            anchors.centerIn: parent
            width: parent.width - 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.label
            color: root.selected ? Theme.colors.background : Theme.colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: 10
            font.bold: root.selected
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.activated()
    }
}
