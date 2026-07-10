import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    property var backendRef
    property color panel: "#111621"
    property color line: "#252C3A"
    property color textMain: "#F5F7FB"
    property color textMuted: "#8F99AA"

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        SectionCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 86
            panelColor: page.panel
            borderColor: page.line
            RowLayout {
                anchors.fill: parent
                anchors.margins: 18
                spacing: 14
                Rectangle {
                    width: 46; height: 46; radius: 15
                    color: "#211B35"
                    Text { anchors.centerIn: parent; text: "◷"; color: "#A89AFF"; font.pixelSize: 18 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    Text { text: "История выполнения"; color: page.textMain; font.pixelSize: 16; font.weight: Font.DemiBold }
                    Text { text: "Последние команды, результаты и ошибки сохраняются между запусками."; color: page.textMuted; font.pixelSize: 11 }
                }
                Button {
                    id: clearButton
                    text: "Очистить историю"
                    enabled: page.backendRef && page.backendRef.history.length > 0
                    implicitHeight: 38
                    leftPadding: 16; rightPadding: 16
                    onClicked: page.backendRef.clearHistory()
                    contentItem: Text { text: clearButton.text; color: clearButton.enabled ? page.textMain : "#596273"; font.pixelSize: 11; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 12; color: clearButton.hovered ? "#222A39" : "#1A202B"; border.color: page.line }
                }
            }
        }

        SectionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            panelColor: page.panel
            borderColor: page.line

            Item {
                anchors.fill: parent
                anchors.margins: 16

                Text {
                    anchors.centerIn: parent
                    visible: !page.backendRef || page.backendRef.history.length === 0
                    text: "История пока пуста\nЗдесь появятся результаты выполненных команд"
                    color: page.textMuted
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.4
                }

                ListView {
                    id: historyList
                    anchors.fill: parent
                    visible: page.backendRef && page.backendRef.history.length > 0
                    clip: true
                    spacing: 9
                    model: page.backendRef ? page.backendRef.history : []
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Rectangle {
                        required property var modelData
                        width: historyList.width
                        height: 72
                        radius: 14
                        color: historyMouse.containsMouse ? "#19202C" : "#141A25"
                        border.color: historyMouse.containsMouse ? "#354055" : "#202735"

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 15
                            spacing: 12
                            Rectangle {
                                width: 36; height: 36; radius: 12
                                color: modelData.tone === "error" ? "#2B1820" : modelData.tone === "warning" ? "#2B2418" : "#17281F"
                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.tone === "error" ? "!" : modelData.tone === "warning" ? "•" : "✓"
                                    color: modelData.tone === "error" ? "#FF8592" : modelData.tone === "warning" ? "#FFC46F" : "#63D991"
                                    font.pixelSize: 15
                                    font.weight: Font.Bold
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 4
                                Text { Layout.fillWidth: true; text: modelData.phrase; color: page.textMain; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: modelData.result; color: page.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                            }
                            Text { text: modelData.time || ""; color: "#687386"; font.pixelSize: 9; Layout.alignment: Qt.AlignTop }
                        }
                        MouseArea { id: historyMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                    }
                }
            }
        }
    }
}
