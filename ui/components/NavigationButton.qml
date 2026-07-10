import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
    id: control
    property bool selected: false
    property string iconText: ""
    implicitHeight: 46
    leftPadding: 12
    rightPadding: 12
    hoverEnabled: true

    contentItem: RowLayout {
        spacing: 11
        Text {
            text: control.iconText
            color: control.selected ? "#C7BCFF" : control.hovered ? "#DDE2EC" : "#818B9D"
            font.pixelSize: 16
            font.family: "Segoe UI Symbol"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            Layout.preferredWidth: 22
        }
        Text {
            Layout.fillWidth: true
            text: control.text
            color: control.selected ? "#F5F7FB" : control.hovered ? "#E8EBF2" : "#9AA4B5"
            font.pixelSize: 13
            font.weight: control.selected ? Font.DemiBold : Font.Medium
            verticalAlignment: Text.AlignVCenter
        }
    }

    background: Rectangle {
        radius: 13
        color: control.selected ? "#211B35" : control.down ? "#1A202B" : control.hovered ? "#161C27" : "transparent"
        border.width: control.selected ? 1 : 0
        border.color: control.selected ? "#4B3D78" : "transparent"
        Rectangle {
            visible: control.selected
            width: 3
            height: 22
            radius: 2
            color: "#8B6CFF"
            anchors.left: parent.left
            anchors.leftMargin: 1
            anchors.verticalCenter: parent.verticalCenter
        }
        Behavior on color { ColorAnimation { duration: 120 } }
    }
}
