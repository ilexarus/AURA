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
    property color panelLight: "#171D2A"
    property color line: "#252C3A"
    property color textMain: "#F5F7FB"
    property color textMuted: "#8F99AA"
    property string commandSearch: ""

    signal createCommandRequested()
    signal openCommandRequested(var command)
    signal runCommandRequested(string commandId)
    signal templatesRequested()

    ColumnLayout {
        anchors.fill: parent
        spacing: 16

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            TextField {
                id: commandSearchField
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                placeholderText: "Поиск по названию или голосовой фразе"
                color: page.textMain
                placeholderTextColor: "#687386"
                selectionColor: page.accent
                leftPadding: 15
                rightPadding: 15
                font.pixelSize: 13
                onTextChanged: page.commandSearch = text.trim().toLowerCase()
                background: Rectangle {
                    radius: 13
                    color: "#0D111A"
                    border.color: commandSearchField.activeFocus ? page.accent : page.line
                    border.width: commandSearchField.activeFocus ? 1.5 : 1
                }
            }
            Button {
                id: templatesButton
                text: "Шаблоны"
                implicitHeight: 44
                leftPadding: 18
                rightPadding: 18
                onClicked: page.templatesRequested()
                contentItem: Text { text: templatesButton.text; color: page.textMain; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 13; color: templatesButton.hovered ? "#202635" : "#191F2B"; border.color: page.line }
            }
            Button {
                id: createButton
                text: "+  Создать команду"
                implicitHeight: 44
                leftPadding: 18
                rightPadding: 18
                onClicked: page.createCommandRequested()
                contentItem: Text { text: createButton.text; color: "white"; font.pixelSize: 13; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle {
                    radius: 13
                    gradient: Gradient {
                        GradientStop { position: 0; color: createButton.down ? "#694FE0" : "#8B6CFF" }
                        GradientStop { position: 1; color: createButton.down ? "#5034C7" : "#6948F2" }
                    }
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
                anchors.margins: 14

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 4
                        Layout.rightMargin: 4
                        Text { Layout.fillWidth: true; text: "Все команды"; color: page.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Text { text: page.backendRef ? page.backendRef.commands.length : 0; color: page.textMuted; font.pixelSize: 11 }
                    }

                    Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: page.line }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            visible: !page.backendRef || page.backendRef.commands.length === 0
                            text: "Пока нет команд\nСоздайте первую команду за несколько шагов"
                            color: page.textMuted
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 1.4
                        }

                        ListView {
                            id: commandList
                            anchors.fill: parent
                            visible: page.backendRef && page.backendRef.commands.length > 0
                            clip: true
                            spacing: 9
                            model: page.backendRef ? page.backendRef.commands : []
                            ScrollBar.vertical: ScrollBar {}

                            delegate: Rectangle {
                                id: commandCard
                                required property var modelData
                                property bool matchesSearch: page.commandSearch.length === 0
                                    || String(modelData.name || "").toLowerCase().indexOf(page.commandSearch) >= 0
                                    || String(modelData.phrases_text || "").toLowerCase().indexOf(page.commandSearch) >= 0
                                    || String(modelData.preview || "").toLowerCase().indexOf(page.commandSearch) >= 0
                                width: commandList.width
                                height: matchesSearch ? 82 : 0
                                visible: matchesSearch
                                radius: 15
                                color: commandMouse.containsMouse ? "#19202C" : "#141A25"
                                border.color: commandMouse.containsMouse ? "#354055" : "#202735"
                                opacity: modelData.enabled ? 1 : 0.48
                                Behavior on color { ColorAnimation { duration: 120 } }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 16
                                    anchors.rightMargin: 12
                                    spacing: 13

                                    Rectangle {
                                        width: 38; height: 38; radius: 12
                                        color: modelData.quality_tone === "error" ? "#2B1922" : modelData.command_type === "mode" ? "#1B2930" : "#211B35"
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.command_type === "mode" ? "◇" : "A"
                                            color: modelData.quality_tone === "error" ? "#FF8592" : modelData.command_type === "mode" ? "#69D1E8" : page.accentSoft
                                            font.pixelSize: 15
                                            font.weight: Font.DemiBold
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 4
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: page.textMain
                                            font.pixelSize: 14
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.phrases_text ? "«" + modelData.phrases_text + "»" : "Без голосовой фразы"
                                            color: page.textMuted
                                            font.pixelSize: 10
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.preview || "Нет действий"
                                            color: "#687386"
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }

                                    Rectangle {
                                        width: qualityText.implicitWidth + 16
                                        height: 26
                                        radius: 9
                                        color: modelData.quality_tone === "error" ? "#2B1820" : modelData.quality_tone === "warning" ? "#2B2418" : "#17281F"
                                        Text {
                                            id: qualityText
                                            anchors.centerIn: parent
                                            text: modelData.quality_label
                                            color: modelData.quality_tone === "error" ? "#FF8592" : modelData.quality_tone === "warning" ? "#FFC46F" : "#63D991"
                                            font.pixelSize: 9
                                        }
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

                                Menu {
                                    id: commandContextMenu
                                    MenuItem { text: "Открыть"; onTriggered: page.openCommandRequested(modelData) }
                                    MenuItem { text: "Запустить"; enabled: modelData.enabled; onTriggered: page.runCommandRequested(modelData.id) }
                                    MenuSeparator {}
                                    MenuItem { text: "Создать копию"; onTriggered: page.backendRef.duplicateCommand(modelData.id) }
                                    MenuItem { text: "Экспортировать"; onTriggered: page.backendRef.exportCommand(modelData.id) }
                                    MenuItem { text: modelData.enabled ? "Отключить" : "Включить"; onTriggered: page.backendRef.setCommandEnabled(modelData.id, !modelData.enabled) }
                                    MenuSeparator {}
                                    MenuItem { text: "Удалить"; onTriggered: page.backendRef.deleteCommand(modelData.id) }
                                }

                                MouseArea {
                                    id: commandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    acceptedButtons: Qt.RightButton
                                    onClicked: function(mouse) { if (mouse.button === Qt.RightButton) commandContextMenu.popup() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
