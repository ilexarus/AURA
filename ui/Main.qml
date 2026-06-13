import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    width: 1180
    height: 760
    minimumWidth: 980
    minimumHeight: 650
    visible: true
    title: "AURA"
    color: "#0A0D14"

    property color accent: "#7C5CFF"
    property color accentSoft: "#A89AFF"
    property color panel: "#111621"
    property color panelLight: "#171D2A"
    property color line: "#252C3A"
    property color textMain: "#F5F7FB"
    property color textMuted: "#8F99AA"
    property var editingCommand: null
    property var recordedActions: null
    property var recordingDraft: null

    font.family: "Segoe UI"

    component SoftButton: Button {
        id: control
        implicitHeight: 42
        leftPadding: 18
        rightPadding: 18
        font.pixelSize: 14
        font.weight: Font.DemiBold
        contentItem: Text {
            text: control.text
            font: control.font
            color: control.enabled ? root.textMain : "#596273"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 13
            color: control.down ? "#252C3B" : control.hovered ? "#202635" : "#191F2B"
            border.color: control.hovered ? "#384154" : root.line
            Behavior on color { ColorAnimation { duration: 130 } }
        }
    }

    component AccentButton: Button {
        id: control
        implicitHeight: 42
        leftPadding: 18
        rightPadding: 18
        font.pixelSize: 14
        font.weight: Font.DemiBold
        contentItem: Text {
            text: control.text
            font: control.font
            color: "white"
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 14
            gradient: Gradient {
                GradientStop { position: 0; color: control.down ? "#6547DD" : "#8A6BFF" }
                GradientStop { position: 1; color: control.down ? "#4D32C9" : "#6948F2" }
            }
            scale: control.down ? 0.97 : 1
            Behavior on scale { NumberAnimation { duration: 100 } }
        }
    }

    component AppTextField: TextField {
        id: control
        implicitHeight: 44
        leftPadding: 14
        rightPadding: 14
        color: root.textMain
        placeholderTextColor: "#697386"
        selectionColor: root.accent
        selectedTextColor: "white"
        font.pixelSize: 14
        background: Rectangle {
            radius: 12
            color: "#0D111A"
            border.color: control.activeFocus ? root.accent : root.line
            border.width: control.activeFocus ? 1.5 : 1
            Behavior on border.color { ColorAnimation { duration: 130 } }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#090C12" }
            GradientStop { position: 0.65; color: "#0B0E16" }
            GradientStop { position: 1.0; color: "#10101B" }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 238
            Layout.fillHeight: true
            color: "#0C1018"
            border.color: "#181E2A"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 22
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        width: 38; height: 38; radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#997FFF" }
                            GradientStop { position: 1; color: "#6240E8" }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: "A"
                            color: "white"
                            font.pixelSize: 19
                            font.bold: true
                        }
                    }
                    Column {
                        Layout.fillWidth: true
                        Text { text: "AURA"; color: root.textMain; font.pixelSize: 17; font.bold: true; font.letterSpacing: 1.1 }
                        Text { text: "voice assistant"; color: root.textMuted; font.pixelSize: 11 }
                    }
                }

                Item { height: 3 }

                Rectangle {
                    Layout.fillWidth: true
                    height: 46
                    radius: 13
                    color: "#19192A"
                    border.color: "#2D2850"
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        spacing: 11
                        Text { text: "◉"; color: root.accentSoft; font.pixelSize: 17 }
                        Text { text: "Ассистент"; color: root.textMain; font.pixelSize: 14; font.weight: Font.DemiBold }
                    }
                }

                Text {
                    text: "МОИ КОМАНДЫ"
                    color: "#626C7E"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                    topPadding: 8
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: commandColumn.height

                    Column {
                        id: commandColumn
                        width: parent.width
                        spacing: 7
                        Repeater {
                            model: backend.commands
                            delegate: Rectangle {
                                required property var modelData
                                width: commandColumn.width
                                height: 44
                                radius: 11
                                color: mouse.containsMouse ? "#151A25" : "transparent"
                                opacity: modelData.enabled ? 1 : 0.45
                                Behavior on color { ColorAnimation { duration: 120 } }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 7
                                    spacing: 9
                                    Rectangle {
                                        width: 7; height: 7; radius: 4
                                        color: modelData.enabled ? root.accent : "#4F5867"
                                    }
                                    Text {
                                        Layout.fillWidth: true
                                        text: modelData.name
                                        color: root.textMain
                                        font.pixelSize: 13
                                        elide: Text.ElideRight
                                    }
                                    Text { text: "›"; color: "#697386"; font.pixelSize: 18 }
                                }
                                MouseArea {
                                    id: mouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        root.editingCommand = modelData
                                        editor.open()
                                    }
                                }
                            }
                        }
                    }
                }

                SoftButton {
                    Layout.fillWidth: true
                    text: "+  Новая команда"
                    onClicked: {
                        root.editingCommand = null
                        editor.open()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.line }

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 9; height: 9; radius: 5
                        color: backend.recording ? "#FF9A62" : backend.listening ? "#43D17C" : backend.wakeListening ? root.accent : "#536071"
                        SequentialAnimation on opacity {
                            running: backend.listening || backend.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 550 }
                            NumberAnimation { to: 1; duration: 550 }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: backend.recording ? "Запись действий" : backend.listening ? "Микрофон активен" : backend.wakeListening ? "Жду фразу «Аура»" : "Готов к работе"
                        color: root.textMuted
                        font.pixelSize: 12
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 20

                RowLayout {
                    Layout.fillWidth: true
                    Column {
                        Layout.fillWidth: true
                        Text { text: "Добрый день"; color: root.textMain; font.pixelSize: 25; font.weight: Font.DemiBold }
                        Text { text: "Скажите команду или проверьте её текстом"; color: root.textMuted; font.pixelSize: 13; topPadding: 4 }
                    }
                    Rectangle {
                        height: 36
                        width: wakeText.width + 24
                        radius: 11
                        color: backend.wakeEnabled ? "#1E1932" : "#141925"
                        border.color: backend.wakeEnabled ? "#4A3A82" : root.line
                        Text {
                            id: wakeText
                            anchors.centerIn: parent
                            text: "◉  «Аура»"
                            color: backend.wakeEnabled ? root.accentSoft : root.textMuted
                            font.pixelSize: 11
                        }
                        ToolTip.visible: wakeMouse.containsMouse
                        ToolTip.text: backend.wakeEnabled ? "Выключить голосовую активацию" : "Включить голосовую активацию"
                        MouseArea {
                            id: wakeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.setWakeEnabled(!backend.wakeEnabled)
                        }
                    }
                    Rectangle {
                        height: 36
                        width: shortcutText.width + 24
                        radius: 11
                        color: "#141925"
                        border.color: root.line
                        Text {
                            id: shortcutText
                            anchors.centerIn: parent
                            text: "Ctrl  +  Shift  +  Space"
                            color: "#AAB2C1"
                            font.pixelSize: 11
                            font.family: "Consolas"
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: 20

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumWidth: 500
                        radius: 24
                        color: root.panel
                        border.color: root.line

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 26
                            spacing: 15

                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 280

                                Rectangle {
                                    id: outerRing
                                    anchors.centerIn: parent
                                    width: 238; height: 238; radius: 119
                                    color: "transparent"
                                    border.width: 1
                                    border.color: backend.listening ? "#544396" : "#232A38"
                                    opacity: backend.listening ? 0.85 : 0.7
                                    scale: 1
                                    SequentialAnimation on scale {
                                        running: backend.listening
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 1.11; duration: 950; easing.type: Easing.InOutSine }
                                        NumberAnimation { to: 1; duration: 950; easing.type: Easing.InOutSine }
                                    }
                                    SequentialAnimation on opacity {
                                        running: backend.listening
                                        loops: Animation.Infinite
                                        NumberAnimation { to: 0.15; duration: 950 }
                                        NumberAnimation { to: 0.85; duration: 950 }
                                    }
                                }

                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 192; height: 192; radius: 96
                                    color: "#121827"
                                    border.width: 1
                                    border.color: backend.listening ? "#7D63E8" : "#303747"

                                    Rectangle {
                                        id: orb
                                        anchors.centerIn: parent
                                        width: 152; height: 152; radius: 76
                                        gradient: Gradient {
                                            GradientStop { position: 0.0; color: backend.listening ? "#B49DFF" : "#8168E5" }
                                            GradientStop { position: 0.48; color: backend.listening ? "#7251F4" : "#5339C8" }
                                            GradientStop { position: 1.0; color: backend.listening ? "#2B185F" : "#24184D" }
                                        }
                                        scale: backend.listening ? 1.04 : 1
                                        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                                        Repeater {
                                            model: 7
                                            Rectangle {
                                                required property int index
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: 4
                                                radius: 2
                                                height: backend.listening ? 18 + (index % 4) * 10 : 8 + (index % 3) * 3
                                                x: orb.width / 2 - 2 + (index - 3) * 12
                                                color: "white"
                                                opacity: 0.9
                                                Behavior on height { NumberAnimation { duration: 180 } }
                                                SequentialAnimation on scale {
                                                    running: backend.listening
                                                    loops: Animation.Infinite
                                                    PauseAnimation { duration: index * 55 }
                                                    NumberAnimation { to: 1.5; duration: 240; easing.type: Easing.InOutSine }
                                                    NumberAnimation { to: 0.7; duration: 300; easing.type: Easing.InOutSine }
                                                    NumberAnimation { to: 1; duration: 220 }
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: backend.listening ? "Говорите…" : backend.status
                                color: root.textMain
                                font.pixelSize: 17
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                Layout.maximumWidth: 470
                                horizontalAlignment: Text.AlignHCenter
                                wrapMode: Text.WordWrap
                                text: backend.transcript.length ? "«" + backend.transcript + "»" : "Скажите «Аура» или нажмите кнопку"
                                color: root.textMuted
                                font.pixelSize: 13
                            }

                            AccentButton {
                                Layout.alignment: Qt.AlignHCenter
                                implicitWidth: 190
                                text: backend.listening ? "Слушаю" : "Начать говорить"
                                enabled: !backend.listening
                                onClicked: backend.toggleListening()
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                AppTextField {
                                    id: testInput
                                    Layout.fillWidth: true
                                    placeholderText: "Например: открой калькулятор"
                                    onAccepted: backend.executeText(text)
                                }
                                SoftButton {
                                    text: "Проверить"
                                    onClicked: backend.executeText(testInput.text)
                                }
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.preferredWidth: 300
                        Layout.fillHeight: true
                        spacing: 20

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 220
                            radius: 20
                            color: root.panel
                            border.color: root.line

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 13
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Быстрый старт"; color: root.textMain; font.pixelSize: 16; font.bold: true }
                                    Text { text: "3 шага"; color: root.accentSoft; font.pixelSize: 11 }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
                                Repeater {
                                    model: [
                                        ["1", "Создайте команду", "Укажите понятную голосовую фразу"],
                                        ["2", "Выберите действие", "Сайт, программа, клавиши или текст"],
                                        ["3", "Скажите фразу", "AURA выполнит действие за вас"]
                                    ]
                                    delegate: RowLayout {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        spacing: 11
                                        Rectangle {
                                            width: 27; height: 27; radius: 9
                                            color: "#211B3B"
                                            Text { anchors.centerIn: parent; text: modelData[0]; color: root.accentSoft; font.pixelSize: 12; font.bold: true }
                                        }
                                        Column {
                                            Layout.fillWidth: true
                                            Text { text: modelData[1]; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
                                            Text { width: 210; text: modelData[2]; color: root.textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap }
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 20
                            color: root.panel
                            border.color: root.line

                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 20
                                spacing: 11
                                RowLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: "Последние действия"; color: root.textMain; font.pixelSize: 16; font.bold: true }
                                    Text { text: backend.history.length; color: root.textMuted; font.pixelSize: 12 }
                                }
                                Rectangle { Layout.fillWidth: true; height: 1; color: root.line }
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Text {
                                        anchors.centerIn: parent
                                        visible: backend.history.length === 0
                                        text: "История пока пуста"
                                        color: "#606A7B"
                                        font.pixelSize: 12
                                    }
                                    ListView {
                                        anchors.fill: parent
                                        visible: backend.history.length > 0
                                        clip: true
                                        spacing: 9
                                        model: backend.history
                                        delegate: Rectangle {
                                            required property var modelData
                                            width: ListView.view.width
                                            height: 54
                                            radius: 11
                                            color: "#151A25"
                                            Column {
                                                anchors.left: parent.left
                                                anchors.right: parent.right
                                                anchors.verticalCenter: parent.verticalCenter
                                                anchors.margins: 11
                                                spacing: 3
                                                Text { width: parent.width; text: modelData.phrase; color: root.textMain; font.pixelSize: 11; elide: Text.ElideRight }
                                                Text { width: parent.width; text: modelData.result; color: root.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    ListModel {
        id: actionModel
    }

    Dialog {
        id: editor
        width: Math.min(640, root.width - 48)
        height: Math.min(720, root.height - 40)
        anchors.centerIn: parent
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape
        padding: 0
        background: Rectangle {
            radius: 22
            color: "#121722"
            border.color: "#303747"
        }
        Overlay.modal: Rectangle { color: "#AA05070B" }

        function addAction(type, value, delayAfter) {
            actionModel.append({
                "action_type": type || "open_url",
                "value": value || "",
                "delay_after": Number(delayAfter || 0),
                "enabled": true
            })
        }

        function actionIndex(type) {
            for (var i = 0; i < actionChoices.length; ++i) {
                if (actionChoices[i].value === type)
                    return i
            }
            return 0
        }

        function actionHint(type) {
            if (type === "open_url") return "https://youtube.com"
            if (type === "open_app") return "calc или C:\\Путь\\app.exe"
            if (type === "open_path") return "C:\\Users\\Имя\\Documents"
            if (type === "hotkey") return "ctrl+shift+s"
            if (type === "key") return "volumeup"
            if (type === "type_text") return "Текст, который нужно вставить"
            if (type === "wait") return "Количество секунд, например 2"
            if (type === "mouse_click") return "x,y,left,1"
            if (type === "mouse_scroll") return "Число шагов, например -5"
            if (type === "activate_window") return "Часть заголовка окна"
            if (type === "wait_window") return "Название окна|10"
            if (type === "minimize_window") return "Часть заголовка окна"
            if (type === "maximize_window") return "Часть заголовка окна"
            if (type === "close_window") return "Часть заголовка окна"
            return "Команда PowerShell или CMD"
        }

        property var actionChoices: [
            { label: "Открыть сайт", value: "open_url" },
            { label: "Открыть программу", value: "open_app" },
            { label: "Открыть файл или папку", value: "open_path" },
            { label: "Нажать сочетание клавиш", value: "hotkey" },
            { label: "Нажать одну клавишу", value: "key" },
            { label: "Вставить текст", value: "type_text" },
            { label: "Подождать", value: "wait" },
            { label: "Клик мышью", value: "mouse_click" },
            { label: "Прокрутить", value: "mouse_scroll" },
            { label: "Активировать окно", value: "activate_window" },
            { label: "Дождаться окна", value: "wait_window" },
            { label: "Свернуть окно", value: "minimize_window" },
            { label: "Развернуть окно", value: "maximize_window" },
            { label: "Закрыть окно", value: "close_window" },
            { label: "Выполнить системную команду", value: "shell" }
        ]

        onOpened: {
            var command = root.editingCommand
            var draft = root.recordingDraft
            nameField.text = draft ? draft.name : (command ? command.name : "")
            phrasesField.text = draft ? draft.phrases : (command ? command.phrases_text : "")
            confirmSwitch.checked = draft ? draft.confirmation : (command ? command.require_confirmation : false)
            actionModel.clear()

            if (root.recordedActions && root.recordedActions.length > 0) {
                for (var recordedIndex = 0; recordedIndex < root.recordedActions.length; ++recordedIndex) {
                    var recordedStep = root.recordedActions[recordedIndex]
                    addAction(recordedStep.action_type, recordedStep.value, recordedStep.delay_after)
                }
            } else if (command && command.actions && command.actions.length > 0) {
                for (var i = 0; i < command.actions.length; ++i) {
                    var step = command.actions[i]
                    addAction(step.action_type, step.value, step.delay_after)
                }
            } else {
                addAction("open_url", "", 0)
            }
            root.recordedActions = null
            root.recordingDraft = null
            nameField.forceActiveFocus()
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 11

            RowLayout {
                Layout.fillWidth: true
                Column {
                    Layout.fillWidth: true
                    Text { text: root.editingCommand ? "Редактировать команду" : "Новая команда"; color: root.textMain; font.pixelSize: 21; font.bold: true }
                    Text { text: "Программирование не требуется"; color: root.textMuted; font.pixelSize: 12; topPadding: 3 }
                }
                ToolButton {
                    id: closeEditorButton
                    Layout.preferredWidth: 36
                    Layout.preferredHeight: 36
                    Layout.alignment: Qt.AlignVCenter
                    text: "×"
                    font.pixelSize: 24
                    onClicked: editor.close()
                    background: Rectangle { color: closeEditorButton.hovered ? "#202635" : "transparent"; radius: 10 }
                    contentItem: Text { text: closeEditorButton.text; color: root.textMuted; font: closeEditorButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

            Text { text: "Название"; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
            AppTextField { id: nameField; Layout.fillWidth: true; placeholderText: "Например: Открыть рабочие сайты" }

            Text { text: "Что можно сказать"; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
            AppTextField {
                id: phrasesField
                Layout.fillWidth: true
                placeholderText: "начать работу, открой рабочие сайты"
            }
            Text { text: "Несколько фраз разделяйте запятыми"; color: root.textMuted; font.pixelSize: 10 }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Действия"
                    color: root.textMain
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                SoftButton {
                    Layout.preferredHeight: 36
                    Layout.minimumWidth: 112
                    Layout.alignment: Qt.AlignVCenter
                    text: "●  Записать"
                    onClicked: {
                        root.recordingDraft = {
                            "name": nameField.text,
                            "phrases": phrasesField.text,
                            "confirmation": confirmSwitch.checked
                        }
                        editor.close()
                        backend.startRecording()
                    }
                }
                SoftButton {
                    Layout.preferredHeight: 36
                    Layout.minimumWidth: 112
                    Layout.alignment: Qt.AlignVCenter
                    text: "+  Добавить"
                    onClicked: editor.addAction("open_url", "", 0)
                }
            }

            ListView {
                id: actionsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 210
                clip: true
                spacing: 10
                model: actionModel
                ScrollBar.vertical: ScrollBar { }

                delegate: Rectangle {
                    id: actionCard
                    required property int index
                    required property string action_type
                    required property string value
                    required property real delay_after
                    width: actionsList.width - (actionsList.ScrollBar.vertical.visible ? 12 : 0)
                    height: 126
                    radius: 13
                    color: "#151A25"
                    border.color: "#252C3A"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            Rectangle {
                                width: 25
                                height: 25
                                radius: 8
                                color: "#211B3B"
                                Text {
                                    anchors.centerIn: parent
                                    text: actionCard.index + 1
                                    color: root.accentSoft
                                    font.pixelSize: 11
                                    font.bold: true
                                }
                            }

                            ComboBox {
                                id: stepType
                                Layout.fillWidth: true
                                implicitHeight: 38
                                textRole: "label"
                                valueRole: "value"
                                model: editor.actionChoices
                                currentIndex: editor.actionIndex(actionCard.action_type)
                                onActivated: actionModel.setProperty(actionCard.index, "action_type", currentValue)
                                contentItem: Text {
                                    leftPadding: 12
                                    text: stepType.displayText
                                    color: root.textMain
                                    font.pixelSize: 13
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle { radius: 11; color: "#0D111A"; border.color: stepType.activeFocus ? root.accent : root.line }
                                popup: Popup {
                                    y: stepType.height + 5
                                    width: stepType.width
                                    implicitHeight: Math.min(contentItem.implicitHeight + 12, 270)
                                    padding: 6
                                    background: Rectangle { radius: 12; color: "#171D29"; border.color: root.line }
                                    contentItem: ListView {
                                        clip: true
                                        implicitHeight: contentHeight
                                        model: stepType.popup.visible ? stepType.delegateModel : null
                                        currentIndex: stepType.highlightedIndex
                                        ScrollIndicator.vertical: ScrollIndicator { }
                                    }
                                }
                                delegate: ItemDelegate {
                                    id: stepActionDelegate
                                    width: stepType.width - 12
                                    height: 38
                                    contentItem: Text { text: modelData.label; color: root.textMain; font.pixelSize: 13; verticalAlignment: Text.AlignVCenter }
                                    background: Rectangle { radius: 9; color: stepActionDelegate.highlighted ? "#28213F" : "transparent" }
                                }
                            }

                            ToolButton {
                                id: removeStepButton
                                visible: actionModel.count > 1
                                text: "×"
                                implicitWidth: 34
                                implicitHeight: 34
                                font.pixelSize: 20
                                onClicked: actionModel.remove(actionCard.index)
                                background: Rectangle { color: removeStepButton.hovered ? "#30202A" : "transparent"; radius: 10 }
                                contentItem: Text { text: removeStepButton.text; color: "#D88A98"; font: removeStepButton.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            AppTextField {
                                id: stepValue
                                Layout.fillWidth: true
                                Layout.preferredHeight: 40
                                Layout.alignment: Qt.AlignBottom
                                text: actionCard.value
                                placeholderText: editor.actionHint(stepType.currentValue)
                                onTextEdited: actionModel.setProperty(actionCard.index, "value", text)
                            }

                            ColumnLayout {
                                Layout.preferredWidth: 82
                                Layout.minimumWidth: 82
                                Layout.maximumWidth: 82
                                Layout.alignment: Qt.AlignBottom
                                spacing: 2

                                Text {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 12
                                    Layout.leftMargin: 3
                                    text: "Пауза"
                                    color: root.textMuted
                                    font.pixelSize: 9
                                    verticalAlignment: Text.AlignVCenter
                                }

                                AppTextField {
                                    id: stepDelay
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 40
                                    text: String(actionCard.delay_after)
                                    placeholderText: "0"
                                    inputMethodHints: Qt.ImhFormattedNumbersOnly
                                    onTextEdited: {
                                        var parsed = Number(text.replace(",", "."))
                                        actionModel.setProperty(actionCard.index, "delay_after", isNaN(parsed) ? 0 : parsed)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                radius: 13
                color: "#151A25"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 11
                    Text {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        text: "Запрашивать подтверждение"
                        color: root.textMain
                        font.pixelSize: 13
                        verticalAlignment: Text.AlignVCenter
                    }
                    Switch {
                        id: confirmSwitch
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 32
                        Layout.alignment: Qt.AlignVCenter
                        padding: 0
                        leftPadding: 0
                        rightPadding: 0
                        topPadding: 0
                        bottomPadding: 0
                        spacing: 0

                        indicator: Rectangle {
                            width: 42
                            height: 24
                            radius: 12
                            x: Math.round((confirmSwitch.width - width) / 2)
                            y: Math.round((confirmSwitch.height - height) / 2)
                            color: confirmSwitch.checked ? root.accent : "#303747"
                            Rectangle {
                                width: 18
                                height: 18
                                radius: 9
                                x: confirmSwitch.checked ? parent.width - width - 3 : 3
                                y: 3
                                color: "white"
                                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                            }
                        }
                        contentItem: Item {}
                        background: Item {}
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 42
                Layout.minimumHeight: 42
                spacing: 10
                SoftButton {
                    Layout.preferredHeight: 42
                    Layout.minimumWidth: 96
                    Layout.alignment: Qt.AlignVCenter
                    visible: root.editingCommand !== null
                    text: "Удалить"
                    onClicked: {
                        backend.deleteCommand(root.editingCommand.id)
                        editor.close()
                    }
                }
                Item { Layout.fillWidth: true }
                SoftButton {
                    Layout.preferredHeight: 42
                    Layout.minimumWidth: 96
                    Layout.alignment: Qt.AlignVCenter
                    text: "Отмена"
                    onClicked: editor.close()
                }
                AccentButton {
                    Layout.preferredHeight: 42
                    Layout.minimumWidth: 112
                    Layout.alignment: Qt.AlignVCenter
                    text: "Сохранить"
                    onClicked: {
                        var actions = []
                        for (var i = 0; i < actionModel.count; ++i) {
                            var item = actionModel.get(i)
                            actions.push({
                                "action_type": item.action_type,
                                "value": item.value,
                                "delay_after": Number(item.delay_after || 0),
                                "enabled": true
                            })
                        }
                        var saved = backend.saveCommand(
                            root.editingCommand ? root.editingCommand.id : "",
                            nameField.text,
                            phrasesField.text,
                            JSON.stringify(actions),
                            confirmSwitch.checked
                        )
                        if (saved)
                            editor.close()
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmDialog
        width: 430
        height: 260
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        property string commandName: ""
        property string commandValue: ""
        background: Rectangle { radius: 22; color: "#121722"; border.color: "#3B4252" }
        Overlay.modal: Rectangle { color: "#AA05070B" }
        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 13
            Text { text: "Подтвердите действие"; color: root.textMain; font.pixelSize: 20; font.bold: true }
            Text { text: confirmDialog.commandName; color: root.accentSoft; font.pixelSize: 15; font.weight: Font.DemiBold }
            Text { Layout.fillWidth: true; text: confirmDialog.commandValue; color: root.textMuted; font.pixelSize: 12; wrapMode: Text.WrapAnywhere }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                SoftButton { text: "Отмена"; onClicked: { confirmDialog.close(); backend.answerConfirmation(false) } }
                AccentButton { text: "Выполнить"; onClicked: { confirmDialog.close(); backend.answerConfirmation(true) } }
            }
        }
    }

    Dialog {
        id: updateDialog
        width: 470
        height: 310
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        property string availableVersion: ""
        property string releaseNotes: ""
        background: Rectangle { radius: 22; color: "#121722"; border.color: "#3B4252" }
        Overlay.modal: Rectangle { color: "#AA05070B" }
        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 25
            spacing: 13
            Text { text: "Доступно обновление"; color: root.textMain; font.pixelSize: 20; font.bold: true }
            Text {
                text: "AURA " + updateDialog.availableVersion
                color: root.accentSoft
                font.pixelSize: 15
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: updateDialog.releaseNotes.length ? updateDialog.releaseNotes : "Обновление уже скачано и проверено. Пользовательские команды сохранятся."
                color: root.textMuted
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                elide: Text.ElideRight
                maximumLineCount: 7
            }
            RowLayout {
                Layout.fillWidth: true
                Item { Layout.fillWidth: true }
                SoftButton { text: "Позже"; onClicked: updateDialog.close() }
                AccentButton {
                    text: "Установить"
                    onClicked: {
                        updateDialog.close()
                        backend.installUpdate()
                    }
                }
            }
        }
    }

    Connections {
        target: backend
        function onConfirmationRequested(name, value) {
            confirmDialog.commandName = name
            confirmDialog.commandValue = value
            confirmDialog.open()
        }
        function onUpdateReady(version, notes) {
            updateDialog.availableVersion = version
            updateDialog.releaseNotes = notes
            updateDialog.open()
        }
        function onRecordingChanged() {
            if (backend.recording) {
                root.showMinimized()
            } else if (root.recordingDraft !== null && root.recordedActions === null) {
                root.showNormal()
                root.raise()
                root.requestActivate()
            }
        }
        function onRecordingReady(actionsJson) {
            try {
                root.recordedActions = JSON.parse(actionsJson)
            } catch (error) {
                root.recordedActions = null
            }
            root.showNormal()
            root.raise()
            root.requestActivate()
            editor.open()
        }
    }
}
