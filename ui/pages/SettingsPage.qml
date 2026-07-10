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

    signal advancedSettingsRequested()

    function selectedMicrophoneName() {
        if (!backendRef || !backendRef.microphones || backendRef.microphones.length === 0)
            return "Микрофон не найден"
        var selected = backendRef.selectedMicrophoneIndex
        for (var index = 0; index < backendRef.microphones.length; index++) {
            if (Number(backendRef.microphones[index].index) === Number(selected))
                return String(backendRef.microphones[index].name)
        }
        return "Устройство Windows по умолчанию"
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: settingsColumn.implicitHeight
        ScrollBar.vertical: ScrollBar {}

        ColumnLayout {
            id: settingsColumn
            width: parent.width
            spacing: 16

            SectionCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 96
                panelColor: page.panel
                borderColor: page.line
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14
                    Rectangle {
                        width: 48; height: 48; radius: 15
                        color: "#211B35"
                        Text { anchors.centerIn: parent; text: "⚙"; color: page.accentSoft; font.pixelSize: 19 }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { text: "Основные настройки"; color: page.textMain; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "Самые важные параметры доступны здесь. Все остальные находятся в расширенных настройках."; color: page.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    }
                    Button {
                        id: advancedButton
                        text: "Все настройки"
                        implicitHeight: 40
                        leftPadding: 17; rightPadding: 17
                        onClicked: page.advancedSettingsRequested()
                        contentItem: Text { text: advancedButton.text; color: page.textMain; font.pixelSize: 11; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 12; color: advancedButton.hovered ? "#222A39" : "#1A202B"; border.color: page.line }
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: width > 760 ? 2 : 1
                columnSpacing: 16
                rowSpacing: 16

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 152
                    panelColor: page.panel
                    borderColor: page.line
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 36; height: 36; radius: 12; color: "#1B2930"; Text { anchors.centerIn: parent; text: "◉"; color: "#69D1E8"; font.pixelSize: 15 } }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Голосовая активация"; color: page.textMain; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: backendRef ? "Фраза: «" + backendRef.wakePhrase + "»" : ""; color: page.textMuted; font.pixelSize: 10 }
                            }
                            Switch {
                                id: wakeSwitch
                                checked: backendRef ? backendRef.wakeEnabled : false
                                onToggled: if (backendRef) backendRef.setWakeEnabled(checked)
                                indicator: Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: wakeSwitch.checked ? page.accent : "#303747"
                                    Rectangle { width: 18; height: 18; radius: 9; y: 3; x: wakeSwitch.checked ? parent.width - width - 3 : 3; color: "white"; Behavior on x { NumberAnimation { duration: 140 } } }
                                }
                                contentItem: Item {}
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: page.line }
                        Text {
                            Layout.fillWidth: true
                            text: backendRef && backendRef.wakeEnabled ? "AURA ждёт фразу активации локально и не отправляет её в интернет." : "Голосовая активация выключена. Используйте Ctrl + Shift + Space."
                            color: page.textMuted
                            font.pixelSize: 10
                            wrapMode: Text.WordWrap
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 152
                    panelColor: page.panel
                    borderColor: page.line
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 36; height: 36; radius: 12; color: "#17281F"; Text { anchors.centerIn: parent; text: "♪"; color: "#63D991"; font.pixelSize: 15 } }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Голосовые ответы"; color: page.textMain; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: "Короткие фразы без задержки"; color: page.textMuted; font.pixelSize: 10 }
                            }
                            Switch {
                                id: voiceSwitch
                                checked: backendRef ? backendRef.voiceFeedbackEnabled : false
                                onToggled: if (backendRef) backendRef.setVoiceFeedbackEnabled(checked)
                                indicator: Rectangle {
                                    width: 44; height: 24; radius: 12
                                    color: voiceSwitch.checked ? page.accent : "#303747"
                                    Rectangle { width: 18; height: 18; radius: 9; y: 3; x: voiceSwitch.checked ? parent.width - width - 3 : 3; color: "white"; Behavior on x { NumberAnimation { duration: 140 } } }
                                }
                                contentItem: Item {}
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: page.line }
                        Text { Layout.fillWidth: true; text: "AURA может говорить «Выполняю», «Готово» и сообщать об ошибках."; color: page.textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 170
                    panelColor: page.panel
                    borderColor: page.line
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 36; height: 36; radius: 12; color: "#1B2930"; Text { anchors.centerIn: parent; text: "●"; color: "#69D1E8"; font.pixelSize: 12 } }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Микрофон"; color: page.textMain; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { Layout.fillWidth: true; text: page.selectedMicrophoneName(); color: page.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                            }
                        }
                        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 7; radius: 4; color: "#252C3A"; Rectangle { width: parent.width * ((backendRef ? backendRef.microphoneLevel : 0) / 100); height: parent.height; radius: 4; color: page.accent; Behavior on width { NumberAnimation { duration: 100 } } } }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: backendRef ? backendRef.microphoneTestMessage : ""; color: page.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                            Button {
                                id: micButton
                                text: backendRef && backendRef.microphoneTesting ? "Проверяю…" : "Проверить"
                                enabled: backendRef && !backendRef.microphoneTesting
                                implicitHeight: 34
                                onClicked: backendRef.startMicrophoneTest()
                                contentItem: Text { text: micButton.text; color: micButton.enabled ? page.textMain : "#596273"; font.pixelSize: 10; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 10; color: micButton.hovered ? "#222A39" : "#1A202B"; border.color: page.line }
                            }
                        }
                    }
                }

                SectionCard {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 170
                    panelColor: page.panel
                    borderColor: page.line
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 18
                        spacing: 10
                        RowLayout {
                            Layout.fillWidth: true
                            Rectangle { width: 36; height: 36; radius: 12; color: "#2B2418"; Text { anchors.centerIn: parent; text: "↻"; color: "#FFC46F"; font.pixelSize: 16 } }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 2
                                Text { text: "Обновления"; color: page.textMain; font.pixelSize: 14; font.weight: Font.DemiBold }
                                Text { text: backendRef ? "Канал: " + (backendRef.updateChannel === "beta" ? "тестовый" : "стабильный") : ""; color: page.textMuted; font.pixelSize: 10 }
                            }
                        }
                        Text { Layout.fillWidth: true; text: "AURA проверяет новые версии автоматически и сохраняет ваши команды."; color: page.textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap }
                        RowLayout {
                            Layout.fillWidth: true
                            Button {
                                id: updateButton
                                text: backendRef && backendRef.updateBusy ? "Проверяю…" : "Проверить обновления"
                                enabled: backendRef && !backendRef.updateBusy
                                implicitHeight: 34
                                onClicked: backendRef.checkForUpdates()
                                contentItem: Text { text: updateButton.text; color: updateButton.enabled ? page.textMain : "#596273"; font.pixelSize: 10; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 10; color: updateButton.hovered ? "#222A39" : "#1A202B"; border.color: page.line }
                            }
                            Item { Layout.fillWidth: true }
                            Text { text: backendRef ? "v" + backendRef.version : ""; color: "#687386"; font.pixelSize: 9 }
                        }
                    }
                }
            }

            SectionCard {
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                panelColor: page.panel
                borderColor: page.line
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 14
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 3
                        Text { text: "Запускать AURA вместе с Windows"; color: page.textMain; font.pixelSize: 13; font.weight: Font.DemiBold }
                        Text { text: "Ассистент запустится свёрнутым и будет готов к голосовой активации."; color: page.textMuted; font.pixelSize: 10 }
                    }
                    Switch {
                        id: autostartSwitch
                        checked: backendRef ? backendRef.autostartEnabled : false
                        onToggled: if (backendRef) backendRef.setAutostartEnabled(checked)
                        indicator: Rectangle {
                            width: 44; height: 24; radius: 12
                            color: autostartSwitch.checked ? page.accent : "#303747"
                            Rectangle { width: 18; height: 18; radius: 9; y: 3; x: autostartSwitch.checked ? parent.width - width - 3 : 3; color: "white"; Behavior on x { NumberAnimation { duration: 140 } } }
                        }
                        contentItem: Item {}
                    }
                }
            }
        }
    }
}
