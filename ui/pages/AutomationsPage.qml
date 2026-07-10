import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"

Item {
    id: page
    property var backendRef
    property color accent: "#7C5CFF"
    property color accentSoft: "#A89AFF"
    property color panel: "#111621"
    property color line: "#252C3A"
    property color textMain: "#F5F7FB"
    property color textMuted: "#8F99AA"
    readonly property int automationCount: {
        var count = 0
        var rows = backendRef ? backendRef.commands : []
        for (var index = 0; index < rows.length; index++) {
            if (rows[index].command_type === "mode" || rows[index].trigger_type !== "voice")
                count++
        }
        return count
    }

    signal createAutomationRequested()
    signal openCommandRequested(var command)
    signal runCommandRequested(string commandId)
    signal templatesRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        SectionCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 118
            panelColor: page.panel
            borderColor: page.line

            RowLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 18
                Rectangle {
                    width: 54; height: 54; radius: 17
                    color: "#1B2930"
                    Text { anchors.centerIn: parent; text: "◇"; color: "#69D1E8"; font.pixelSize: 22 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text { text: "Режимы и автоматизации"; color: page.textMain; font.pixelSize: 17; font.weight: Font.DemiBold }
                    Text {
                        Layout.fillWidth: true
                        text: "Объединяйте несколько действий и запускайте их голосом, при старте AURA или по расписанию."
                        color: page.textMuted
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }
                Button {
                    id: templatesButton
                    text: "Готовые режимы"
                    implicitHeight: 42
                    leftPadding: 17; rightPadding: 17
                    onClicked: page.templatesRequested()
                    contentItem: Text { text: templatesButton.text; color: page.textMain; font.pixelSize: 12; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 13; color: templatesButton.hovered ? "#202635" : "#191F2B"; border.color: page.line }
                }
                Button {
                    id: createButton
                    text: "+  Создать автоматизацию"
                    implicitHeight: 42
                    leftPadding: 17; rightPadding: 17
                    onClicked: page.createAutomationRequested()
                    contentItem: Text { text: createButton.text; color: "white"; font.pixelSize: 12; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle {
                        radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0; color: createButton.down ? "#694FE0" : "#8B6CFF" }
                            GradientStop { position: 1; color: createButton.down ? "#5034C7" : "#6948F2" }
                        }
                    }
                }
            }
        }

        SectionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            panelColor: page.panel
            borderColor: page.line

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: "Активные сценарии"; color: page.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                    Text { text: page.automationCount; color: page.textMuted; font.pixelSize: 11 }
                }
                Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: page.line }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    Text {
                        anchors.centerIn: parent
                        visible: page.automationCount === 0
                        text: "Автоматизаций пока нет\nНачните с готового режима или создайте свой"
                        color: page.textMuted
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        lineHeight: 1.4
                    }

                    ListView {
                        id: automationList
                        anchors.fill: parent
                        clip: true
                        spacing: 10
                        model: page.backendRef ? page.backendRef.commands : []
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Rectangle {
                            id: automationCard
                            required property var modelData
                            property bool isAutomation: modelData.command_type === "mode" || modelData.trigger_type !== "voice"
                            width: automationList.width
                            height: isAutomation ? 86 : 0
                            visible: isAutomation
                            radius: 15
                            color: automationMouse.containsMouse ? "#19202C" : "#141A25"
                            border.color: automationMouse.containsMouse ? "#354055" : "#202735"
                            opacity: modelData.enabled ? 1 : 0.5

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 16
                                anchors.rightMargin: 14
                                spacing: 13
                                Rectangle {
                                    width: 42; height: 42; radius: 13
                                    color: modelData.trigger_type === "daily" ? "#2B2418" : modelData.trigger_type === "startup" ? "#1B2930" : "#211B35"
                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.trigger_type === "daily" ? "◷" : modelData.trigger_type === "startup" ? "↗" : "◇"
                                        color: modelData.trigger_type === "daily" ? "#FFC46F" : modelData.trigger_type === "startup" ? "#69D1E8" : page.accentSoft
                                        font.pixelSize: 17
                                    }
                                }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 4
                                    Text { Layout.fillWidth: true; text: modelData.name; color: page.textMain; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: modelData.trigger_label; color: page.accentSoft; font.pixelSize: 10; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: modelData.preview || "Нет действий"; color: page.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                                }
                                Text { text: modelData.steps_count + " шагов"; color: "#687386"; font.pixelSize: 10 }
                                Switch {
                                    id: enableSwitch
                                    checked: modelData.enabled
                                    onToggled: page.backendRef.setCommandEnabled(modelData.id, checked)
                                    indicator: Rectangle {
                                        width: 42; height: 23; radius: 12
                                        color: enableSwitch.checked ? page.accent : "#303747"
                                        Rectangle {
                                            width: 17; height: 17; radius: 9; y: 3
                                            x: enableSwitch.checked ? parent.width - width - 3 : 3
                                            color: "white"
                                            Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                    contentItem: Item {}
                                }
                                Button {
                                    id: runButton
                                    text: "Запустить"
                                    implicitHeight: 34
                                    enabled: modelData.enabled
                                    onClicked: page.runCommandRequested(modelData.id)
                                    contentItem: Text { text: runButton.text; color: runButton.enabled ? page.accentSoft : "#596273"; font.pixelSize: 10; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { radius: 10; color: runButton.hovered ? "#27203D" : "#201A32"; border.color: "#40345F" }
                                }
                                Button {
                                    id: editButton
                                    text: "Изменить"
                                    implicitHeight: 34
                                    onClicked: page.openCommandRequested(modelData)
                                    contentItem: Text { text: editButton.text; color: page.textMain; font.pixelSize: 10; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { radius: 10; color: editButton.hovered ? "#222A39" : "#1A202B"; border.color: page.line }
                                }
                            }
                            MouseArea { id: automationMouse; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
                        }
                    }
                }
            }
        }
    }
}
