import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import "components"
import "pages"

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
    property string commandSearch: ""
    property int testedStepIndex: -1
    property string testedStepState: ""
    property string testedStepMessage: ""
    property string scenarioTestMessage: ""
    property var editorValidation: ({ valid: false, errors: 0, warnings: 0, issues: [] })
    property string toastText: ""
    property string toastTone: "neutral"
    property string paletteSearch: ""
    property string actionPickerSearch: ""
    property color assistantStateColor: backend.recording ? "#FF9A62" : backend.listening ? "#65B8FF" : backend.busy ? "#8A6BFF" : backend.voiceSpeaking ? "#43D17C" : backend.wakeListening ? root.accent : "#536071"
    property string assistantStateLabel: backend.recording ? "Запись действий" : backend.listening ? "Микрофон активен" : backend.busy ? "Выполняю действие" : backend.voiceSpeaking ? "Отвечаю" : backend.wakeListening ? "Жду фразу «Аура»" : "Готов к работе"
    property bool orbRecognizing: backend.listening && backend.status.toLowerCase().indexOf("распозна") >= 0
    property real animationStrength: backend.animationIntensity === "low" ? 0.58 : backend.animationIntensity === "high" ? 1.28 : 1.0
    property real microphoneVisualLevel: backend.microphoneReactiveAnimation ? backend.audioLevel / 100.0 : 0.0
    property bool motionEnabled: !backend.reduceMotion
    property int currentPage: 0
    readonly property var pageTitles: ["Главная", "Команды", "Автоматизации", "История", "Настройки"]
    readonly property var pageSubtitles: ["Голосовое управление без лишних действий", "Создание и управление голосовыми командами", "Режимы, расписания и фоновые сценарии", "Результаты выполненных команд", "Основные параметры AURA"]

    function createCommand() {
        root.editingCommand = null
        easyBuilder.open()
    }

    function createAdvancedCommand() {
        root.editingCommand = null
        editor.open()
    }

    function openSettings() {
        root.currentPage = 4
        backend.refreshMicrophones()
    }

    function openAdvancedSettings() {
        backend.refreshMicrophones()
        settingsDialog.open()
    }

    function openCommandPalette() { commandPalette.open() }
    function openActionPicker() { actionPicker.open() }

    Shortcut { sequence: "Ctrl+K"; onActivated: root.openCommandPalette() }
    Shortcut { sequence: "Ctrl+N"; onActivated: root.createCommand() }
    Shortcut { sequence: "Ctrl+,"; onActivated: root.openSettings() }

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
        opacity: control.enabled ? 1.0 : 0.42
        Behavior on opacity { NumberAnimation { duration: 120 } }
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

    component AuraSwitch: Switch {
        id: control
        implicitWidth: 48
        implicitHeight: 28
        indicator: Rectangle {
            width: 44
            height: 24
            radius: 12
            x: Math.round((control.width - width) / 2)
            y: Math.round((control.height - height) / 2)
            color: control.checked ? root.accent : "#303747"
            border.color: control.checked ? "#9A85FF" : "#414A5C"
            Rectangle {
                width: 18
                height: 18
                radius: 9
                x: control.checked ? parent.width - width - 3 : 3
                y: 3
                color: "white"
                Behavior on x { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
            }
        }
        contentItem: Item {}
        background: Item {}
    }

    component AuraCloseButton: ToolButton {
        id: control
        implicitWidth: 38
        implicitHeight: 38
        hoverEnabled: true
        padding: 0
        ToolTip.visible: hovered
        ToolTip.text: "Закрыть"
        ToolTip.delay: 450

        background: Rectangle {
            radius: 12
            color: control.down ? "#2B3242" : control.hovered ? "#222938" : "transparent"
            border.width: control.hovered ? 1 : 0
            border.color: "#3A4458"
            Behavior on color { ColorAnimation { duration: 120 } }
        }

        contentItem: Item {
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 2
                radius: 1
                rotation: 45
                color: control.hovered ? root.textMain : "#A7B0C1"
                antialiasing: true
                Behavior on color { ColorAnimation { duration: 120 } }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 15
                height: 2
                radius: 1
                rotation: -45
                color: control.hovered ? root.textMain : "#A7B0C1"
                antialiasing: true
                Behavior on color { ColorAnimation { duration: 120 } }
            }
        }
    }


    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: "#090C12" }
            GradientStop { position: 0.72; color: "#0B0E16" }
            GradientStop { position: 1.0; color: "#10101B" }
        }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rectangle {
            Layout.preferredWidth: 216
            Layout.fillHeight: true
            color: "#0C1018"
            border.color: "#181E2A"

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 18
                anchors.bottomMargin: 18
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    Layout.rightMargin: 4
                    Layout.bottomMargin: 14
                    spacing: 10
                    Rectangle {
                        width: 38; height: 38; radius: 13
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#9A83FF" }
                            GradientStop { position: 1; color: "#6041D8" }
                        }
                        Text { anchors.centerIn: parent; text: "A"; color: "white"; font.pixelSize: 17; font.weight: Font.Bold }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text { text: "AURA"; color: root.textMain; font.pixelSize: 17; font.weight: Font.Bold; font.letterSpacing: 1.0 }
                        Text { text: "ГОЛОСОВОЙ АССИСТЕНТ"; color: "#626C7E"; font.pixelSize: 7; font.bold: true; font.letterSpacing: 0.8 }
                    }
                }

                Text {
                    text: "РАЗДЕЛЫ"
                    color: "#596375"
                    font.pixelSize: 9
                    font.bold: true
                    font.letterSpacing: 1.2
                    Layout.leftMargin: 12
                    Layout.topMargin: 4
                    Layout.bottomMargin: 4
                }

                NavigationButton { Layout.fillWidth: true; iconText: "⌂"; text: "Главная"; selected: root.currentPage === 0; onClicked: root.currentPage = 0 }
                NavigationButton { Layout.fillWidth: true; iconText: "▤"; text: "Команды"; selected: root.currentPage === 1; onClicked: root.currentPage = 1 }
                NavigationButton { Layout.fillWidth: true; iconText: "◇"; text: "Автоматизации"; selected: root.currentPage === 2; onClicked: root.currentPage = 2 }
                NavigationButton { Layout.fillWidth: true; iconText: "◷"; text: "История"; selected: root.currentPage === 3; onClicked: root.currentPage = 3 }
                NavigationButton { Layout.fillWidth: true; iconText: "⚙"; text: "Настройки"; selected: root.currentPage === 4; onClicked: root.openSettings() }

                Item { Layout.fillHeight: true }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 76
                    radius: 15
                    color: "#121722"
                    border.color: root.line
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 5
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Rectangle { width: 8; height: 8; radius: 4; color: root.assistantStateColor }
                            Text { Layout.fillWidth: true; text: root.assistantStateLabel; color: root.textMain; font.pixelSize: 10; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: backend.wakeEnabled ? "Скажите «" + backend.wakePhrase + "»" : "Горячая клавиша Ctrl + Shift + Space"
                            color: root.textMuted
                            font.pixelSize: 8
                            wrapMode: Text.WordWrap
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.currentPage = 4
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    Text { Layout.fillWidth: true; text: "AURA " + backend.version; color: "#596375"; font.pixelSize: 8 }
                    Text { text: "Ctrl + K"; color: "#687386"; font.pixelSize: 8; font.family: "Consolas" }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                anchors.fill: parent
                anchors.leftMargin: 28
                anchors.rightMargin: 28
                anchors.topMargin: 22
                anchors.bottomMargin: 24
                spacing: 18

                RowLayout {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 52
                    spacing: 14
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: root.pageTitles[root.currentPage]; color: root.textMain; font.pixelSize: 23; font.weight: Font.DemiBold }
                        Text { text: root.pageSubtitles[root.currentPage]; color: root.textMuted; font.pixelSize: 11 }
                    }
                    Rectangle {
                        height: 36
                        width: wakePillText.implicitWidth + 26
                        radius: 12
                        color: backend.wakeEnabled ? "#1E1932" : "#141925"
                        border.color: backend.wakeEnabled ? "#4A3A82" : root.line
                        Text {
                            id: wakePillText
                            anchors.centerIn: parent
                            text: backend.wakeEnabled ? "◉  «" + backend.wakePhrase + "»" : "Голос выключен"
                            color: backend.wakeEnabled ? root.accentSoft : root.textMuted
                            font.pixelSize: 10
                        }
                        ToolTip.visible: wakePillMouse.containsMouse
                        ToolTip.text: backend.wakeEnabled ? "Выключить голосовую активацию" : "Включить голосовую активацию"
                        MouseArea {
                            id: wakePillMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: backend.setWakeEnabled(!backend.wakeEnabled)
                        }
                    }
                    Button {
                        id: paletteTopButton
                        text: "Ctrl + K   Быстрый запуск"
                        implicitHeight: 36
                        leftPadding: 15
                        rightPadding: 15
                        onClicked: root.openCommandPalette()
                        contentItem: Text { text: paletteTopButton.text; color: "#AAB2C1"; font.pixelSize: 10; font.family: "Consolas"; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                        background: Rectangle { radius: 12; color: paletteTopButton.hovered ? "#1B2130" : "#141925"; border.color: paletteTopButton.hovered ? "#39445A" : root.line }
                    }
                }

                StackLayout {
                    id: pageStack
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: root.currentPage

                    HomePage {
                        backendRef: backend
                        accent: root.accent
                        accentSoft: root.accentSoft
                        panel: root.panel
                        panelLight: root.panelLight
                        line: root.line
                        textMain: root.textMain
                        textMuted: root.textMuted
                        stateColor: root.assistantStateColor
                        stateLabel: root.assistantStateLabel
                        motionEnabled: root.motionEnabled
                        animationStrength: root.animationStrength
                        microphoneVisualLevel: root.microphoneVisualLevel
                        onCreateCommandRequested: root.createCommand()
                        onOpenPaletteRequested: root.openCommandPalette()
                        onOpenCommandRequested: function(command) { root.editingCommand = command; editor.open() }
                        onRunCommandRequested: function(commandId) { backend.runCommandById(commandId) }
                    }

                    CommandsPage {
                        backendRef: backend
                        accent: root.accent
                        accentSoft: root.accentSoft
                        panel: root.panel
                        panelLight: root.panelLight
                        line: root.line
                        textMain: root.textMain
                        textMuted: root.textMuted
                        onCreateCommandRequested: root.createCommand()
                        onOpenCommandRequested: function(command) { root.editingCommand = command; editor.open() }
                        onRunCommandRequested: function(commandId) { backend.runCommandById(commandId) }
                        onTemplatesRequested: templateDialog.open()
                    }

                    AutomationsPage {
                        backendRef: backend
                        accent: root.accent
                        accentSoft: root.accentSoft
                        panel: root.panel
                        line: root.line
                        textMain: root.textMain
                        textMuted: root.textMuted
                        onCreateAutomationRequested: root.createAdvancedCommand()
                        onOpenCommandRequested: function(command) { root.editingCommand = command; editor.open() }
                        onRunCommandRequested: function(commandId) { backend.runCommandById(commandId) }
                        onTemplatesRequested: templateDialog.open()
                    }

                    HistoryPage {
                        backendRef: backend
                        panel: root.panel
                        line: root.line
                        textMain: root.textMain
                        textMuted: root.textMuted
                    }

                    SettingsPage {
                        backendRef: backend
                        accent: root.accent
                        accentSoft: root.accentSoft
                        panel: root.panel
                        line: root.line
                        textMain: root.textMain
                        textMuted: root.textMuted
                        onAdvancedSettingsRequested: {
                            backend.refreshMicrophones()
                            settingsDialog.open()
                        }
                    }
                }
            }
        }
    }


    Window {
        id: compactAssistant
        width: 360
        height: backend.busy ? 112 : 88
        visible: !root.visible && (backend.listening || backend.busy || backend.voiceSpeaking || backend.recording)
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        x: Screen.desktopAvailableWidth - width - 24
        y: Screen.desktopAvailableHeight - height - 24

        Rectangle {
            anchors.fill: parent
            radius: 20
            color: "#F0121721"
            border.color: "#39445A"

            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 13
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: root.assistantStateColor
                    opacity: 0.9
                    Rectangle {
                        anchors.centerIn: parent
                        width: 31; height: 31; radius: 16
                        color: "#45FFFFFF"
                    }
                    SequentialAnimation on scale {
                        running: root.motionEnabled && compactAssistant.visible
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.06; duration: 620; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text { Layout.fillWidth: true; text: backend.busy ? (backend.activeCommandName || "Выполняю команду") : root.assistantStateLabel; color: root.textMain; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: backend.busy ? (backend.executionText || backend.status) : backend.transcript.length ? "«" + backend.transcript + "»" : backend.status; color: root.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                    Rectangle {
                        visible: backend.busy
                        Layout.fillWidth: true
                        Layout.preferredHeight: 5
                        radius: 3
                        color: "#252C3A"
                        Rectangle {
                            width: parent.width * (backend.executionTotal > 0 ? Math.min(1, backend.executionCurrent / backend.executionTotal) : 0.08)
                            height: parent.height
                            radius: 3
                            color: root.accent
                            Behavior on width { NumberAnimation { duration: 160 } }
                        }
                    }
                }
                ToolButton {
                    id: compactStop
                    visible: backend.busy || backend.recording
                    text: "■"
                    onClicked: backend.stopExecution()
                    background: Rectangle { radius: 10; color: compactStop.hovered ? "#38202A" : "#231A23" }
                    contentItem: Text { text: compactStop.text; color: "#FF8C99"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }

        }
    }

    Rectangle {
        id: executionHud
        z: 80
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 76
        anchors.rightMargin: 26
        width: 310
        height: backend.busy ? 118 : 0
        visible: height > 0
        opacity: backend.busy ? 1 : 0
        radius: 18
        color: "#E9131823"
        border.color: "#3B4458"
        clip: true
        Behavior on height { NumberAnimation { duration: 190; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    width: 30; height: 30; radius: 10; color: "#241D42"
                    Text { anchors.centerIn: parent; text: "A"; color: root.accentSoft; font.bold: true; font.pixelSize: 14 }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 1
                    Text { Layout.fillWidth: true; text: backend.activeCommandName || "Выполнение сценария"; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { Layout.fillWidth: true; text: backend.executionText || backend.status; color: root.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                }
                ToolButton {
                    id: stopHudButton
                    implicitWidth: 30; implicitHeight: 30
                    text: "■"
                    ToolTip.visible: hovered
                    ToolTip.text: "Остановить сценарий"
                    onClicked: backend.stopExecution()
                    background: Rectangle { radius: 9; color: stopHudButton.hovered ? "#38202A" : "#231A23" }
                    contentItem: Text { text: stopHudButton.text; color: "#FF8C99"; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                radius: 3
                color: "#252C3A"
                Rectangle {
                    width: parent.width * (backend.executionTotal > 0 ? Math.min(1, backend.executionCurrent / backend.executionTotal) : 0.08)
                    height: parent.height
                    radius: 3
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#8A6BFF" }
                        GradientStop { position: 1; color: "#5CB7FF" }
                    }
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: backend.executionTotal > 0 ? (backend.executionCurrent + " из " + backend.executionTotal) : "Подготовка"; color: root.textMuted; font.pixelSize: 9 }
                Item { Layout.fillWidth: true }
                Text { text: "Ctrl + Shift + F12 для остановки"; color: "#626C7E"; font.pixelSize: 8 }
            }
        }
    }

    ListModel {
        id: actionModel
    }

    Dialog {
        id: easyBuilder
        width: Math.min(650, root.width - 42)
        height: Math.min(650, root.height - 44)
        anchors.centerIn: parent
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape
        padding: 0
        background: Rectangle { radius: 22; color: "#121722"; border.color: "#303747" }
        Overlay.modal: Rectangle { color: "#AA05070B" }

        property int step: 0
        property string selectedActionType: ""
        property var quickActions: [
            { type: "open_url", icon: "↗", title: "Открыть сайт", description: "YouTube, почта или любая страница" },
            { type: "open_app", icon: "▣", title: "Открыть программу", description: "Калькулятор, браузер или другое приложение" },
            { type: "open_path", icon: "▤", title: "Открыть файл или папку", description: "Документ, фотография или рабочая папка" },
            { type: "open_search", icon: "⌕", title: "Найти в интернете", description: "Открыть готовый поисковый запрос" },
            { type: "hotkey", icon: "⌘", title: "Нажать сочетание", description: "Например Ctrl + Shift + S" },
            { type: "type_text", icon: "T", title: "Вставить текст", description: "Ввести подготовленный текст в активное поле" }
        ]

        function actionTitle(type) {
            for (var i = 0; i < quickActions.length; ++i)
                if (quickActions[i].type === type) return quickActions[i].title
            return "Действие"
        }

        function targetTitle() {
            if (selectedActionType === "open_url") return "Адрес сайта"
            if (selectedActionType === "open_app") return "Программа"
            if (selectedActionType === "open_path") return "Файл или папка"
            if (selectedActionType === "open_search") return "Что найти"
            if (selectedActionType === "hotkey") return "Сочетание клавиш"
            if (selectedActionType === "type_text") return "Текст"
            return "Значение"
        }

        function targetHint() {
            if (selectedActionType === "open_url") return "youtube.com"
            if (selectedActionType === "open_app") return "Выберите EXE или напишите calc"
            if (selectedActionType === "open_path") return "Выберите файл или папку"
            if (selectedActionType === "open_search") return "Например: погода на завтра"
            if (selectedActionType === "hotkey") return "Например: ctrl+shift+s"
            if (selectedActionType === "type_text") return "Введите текст, который AURA должна вставить"
            return ""
        }

        function normalizedTarget() {
            var value = quickTargetField.text.trim()
            if (selectedActionType === "open_url" && value.length > 0 && value.indexOf("://") < 0)
                return "https://" + value
            return value
        }

        function prepareNames() {
            var suggestion = backend.suggestCommandDraft(selectedActionType, normalizedTarget())
            quickNameField.text = suggestion.name || actionTitle(selectedActionType)
            quickPhraseField.text = suggestion.phrase || quickNameField.text.toLowerCase()
        }

        function openAdvanced() {
            var actions = []
            if (selectedActionType.length > 0) {
                actions.push({
                    "action_type": selectedActionType,
                    "value": normalizedTarget(),
                    "delay_after": 0,
                    "enabled": true,
                    "retry_count": 0,
                    "continue_on_error": false
                })
            }
            root.recordedActions = actions.length > 0 ? actions : null
            root.recordingDraft = {
                "name": quickNameField.text,
                "phrases": quickPhraseField.text,
                "confirmation": false,
                "commandType": "command",
                "triggerType": "voice",
                "triggerValue": ""
            }
            close()
            editor.open()
        }

        function saveQuickCommand() {
            var actions = [{
                "action_type": selectedActionType,
                "value": normalizedTarget(),
                "delay_after": 0,
                "enabled": true,
                "retry_count": 0,
                "continue_on_error": false
            }]
            var saved = backend.saveAutomationCommand(
                "",
                quickNameField.text,
                quickPhraseField.text,
                JSON.stringify(actions),
                false,
                "command",
                "voice",
                ""
            )
            if (saved) close()
        }

        onOpened: {
            step = 0
            selectedActionType = ""
            quickTargetField.text = ""
            quickNameField.text = ""
            quickPhraseField.text = ""
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 12

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    Text { text: "Создать команду"; color: root.textMain; font.pixelSize: 22; font.bold: true }
                    Text { text: "Три простых шага, без лишних настроек"; color: root.textMuted; font.pixelSize: 12; topPadding: 4 }
                }
                AuraCloseButton { anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -14; anchors.rightMargin: -14; onClicked: easyBuilder.close() }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 7
                Repeater {
                    model: 3
                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 5
                        radius: 3
                        color: index <= easyBuilder.step ? root.accent : "#303747"
                        Behavior on color { ColorAnimation { duration: 140 } }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: easyBuilder.step

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12
                        Text { text: "1. Что должна сделать AURA?"; color: root.textMain; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "Выберите самое подходящее действие. Остальное AURA заполнит сама."; color: root.textMuted; font.pixelSize: 11 }
                        GridLayout {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            columns: 2
                            columnSpacing: 10
                            rowSpacing: 10
                            Repeater {
                                model: easyBuilder.quickActions
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.minimumHeight: 92
                                    radius: 15
                                    color: quickActionMouse.containsMouse ? "#1C2331" : "#151A25"
                                    border.color: quickActionMouse.containsMouse ? "#4B3A82" : root.line
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 13
                                        spacing: 11
                                        Rectangle {
                                            width: 42; height: 42; radius: 13; color: "#211B3B"
                                            Text { anchors.centerIn: parent; text: modelData.icon; color: root.accentSoft; font.pixelSize: 17; font.bold: true }
                                        }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 3
                                            Text { Layout.fillWidth: true; text: modelData.title; color: root.textMain; font.pixelSize: 13; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
                                            Text { Layout.fillWidth: true; text: modelData.description; color: root.textMuted; font.pixelSize: 9; wrapMode: Text.WordWrap }
                                        }
                                    }
                                    MouseArea {
                                        id: quickActionMouse
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            easyBuilder.selectedActionType = modelData.type
                                            easyBuilder.step = 1
                                            quickTargetField.forceActiveFocus()
                                        }
                                    }
                                }
                            }
                        }
                        SoftButton {
                            Layout.fillWidth: true
                            text: "●  Показать действия AURA"
                            ToolTip.visible: hovered
                            ToolTip.text: "Запишите клики и нажатия, затем AURA создаст шаги"
                            onClicked: {
                                root.recordingDraft = { "name": "", "phrases": "", "confirmation": false, "commandType": "command", "triggerType": "voice", "triggerValue": "" }
                                easyBuilder.close()
                                backend.startRecording()
                            }
                        }
                    }
                }

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 13
                        Text { text: "2. " + easyBuilder.targetTitle(); color: root.textMain; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "Укажите только главное. Технические параметры можно изменить позже."; color: root.textMuted; font.pixelSize: 11 }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 126
                            radius: 15
                            color: "#151A25"
                            border.color: root.line
                            ColumnLayout {
                                anchors.fill: parent
                                anchors.margins: 14
                                spacing: 8
                                Text { text: easyBuilder.actionTitle(easyBuilder.selectedActionType); color: root.accentSoft; font.pixelSize: 12; font.weight: Font.DemiBold }
                                RowLayout {
                                    Layout.fillWidth: true
                                    AppTextField {
                                        id: quickTargetField
                                        Layout.fillWidth: true
                                        placeholderText: easyBuilder.targetHint()
                                        onAccepted: if (text.trim().length > 0) { easyBuilder.prepareNames(); easyBuilder.step = 2 }
                                    }
                                    SoftButton {
                                        visible: easyBuilder.selectedActionType === "open_app"
                                        text: "Выбрать"
                                        onClicked: {
                                            var selected = backend.chooseProgram()
                                            if (selected.length > 0) quickTargetField.text = selected
                                        }
                                    }
                                    SoftButton {
                                        visible: easyBuilder.selectedActionType === "open_path"
                                        text: "Файл"
                                        onClicked: {
                                            var selected = backend.chooseFile()
                                            if (selected.length > 0) quickTargetField.text = selected
                                        }
                                    }
                                    SoftButton {
                                        visible: easyBuilder.selectedActionType === "open_path"
                                        text: "Папка"
                                        onClicked: {
                                            var selected = backend.chooseFolder()
                                            if (selected.length > 0) quickTargetField.text = selected
                                        }
                                    }
                                }
                                Text { Layout.fillWidth: true; text: easyBuilder.targetHint(); color: root.textMuted; font.pixelSize: 9; wrapMode: Text.WordWrap }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }

                Item {
                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 12
                        Text { text: "3. Как запускать команду?"; color: root.textMain; font.pixelSize: 16; font.weight: Font.DemiBold }
                        Text { text: "AURA уже предложила название и фразу. Их можно изменить."; color: root.textMuted; font.pixelSize: 11 }
                        Text { text: "Название"; color: root.textMain; font.pixelSize: 11; font.weight: Font.DemiBold }
                        AppTextField { id: quickNameField; Layout.fillWidth: true; placeholderText: "Название команды" }
                        Text { text: "Скажите после слова «Аура»"; color: root.textMain; font.pixelSize: 11; font.weight: Font.DemiBold }
                        AppTextField { id: quickPhraseField; Layout.fillWidth: true; placeholderText: "Например: открой YouTube"; onAccepted: if (text.trim().length > 0 && quickNameField.text.trim().length > 0) easyBuilder.saveQuickCommand() }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 76
                            radius: 14
                            color: "#151A25"
                            border.color: root.line
                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 13
                                spacing: 10
                                Rectangle { width: 36; height: 36; radius: 12; color: "#211B3B"; Text { anchors.centerIn: parent; text: "✓"; color: root.accentSoft; font.bold: true } }
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Text { Layout.fillWidth: true; text: easyBuilder.actionTitle(easyBuilder.selectedActionType); color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
                                    Text { Layout.fillWidth: true; text: easyBuilder.normalizedTarget(); color: root.textMuted; font.pixelSize: 9; elide: Text.ElideMiddle }
                                }
                            }
                        }
                        Item { Layout.fillHeight: true }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.line }
            RowLayout {
                Layout.fillWidth: true
                spacing: 9
                SoftButton {
                    visible: easyBuilder.step > 0
                    text: "Назад"
                    onClicked: easyBuilder.step--
                }
                SoftButton {
                    text: "Расширенный редактор"
                    onClicked: easyBuilder.openAdvanced()
                }
                Item { Layout.fillWidth: true }
                AccentButton {
                    text: easyBuilder.step === 2 ? "Создать команду" : "Далее"
                    enabled: easyBuilder.step === 0
                        ? easyBuilder.selectedActionType.length > 0
                        : easyBuilder.step === 1
                            ? quickTargetField.text.trim().length > 0
                            : quickNameField.text.trim().length > 0 && quickPhraseField.text.trim().length > 0
                    onClicked: {
                        if (easyBuilder.step === 1) {
                            easyBuilder.prepareNames()
                            easyBuilder.step = 2
                            quickPhraseField.forceActiveFocus()
                        } else if (easyBuilder.step === 2) {
                            easyBuilder.saveQuickCommand()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: editor
        width: Math.min(820, root.width - 32)
        height: Math.min(880, root.height - 20)
        anchors.centerIn: parent
        modal: true
        dim: true
        closePolicy: Popup.CloseOnEscape
        padding: 0
        property bool showAutomationSettings: false
        background: Rectangle {
            radius: 22
            color: "#121722"
            border.color: "#303747"
        }
        Overlay.modal: Rectangle { color: "#AA05070B" }

        function addAction(type, value, delayAfter, enabled, retryCount, continueOnError) {
            actionModel.append({
                "action_type": type || "open_url",
                "value": value || "",
                "delay_after": Number(delayAfter || 0),
                "step_enabled": enabled === undefined ? true : Boolean(enabled),
                "retry_count": Number(retryCount || 0),
                "continue_on_error": Boolean(continueOnError || false)
            })
            scheduleValidation()
        }

        function collectActions() {
            var actions = []
            for (var i = 0; i < actionModel.count; ++i) {
                var item = actionModel.get(i)
                actions.push({
                    "action_type": item.action_type,
                    "value": item.value,
                    "delay_after": Number(item.delay_after || 0),
                    "enabled": Boolean(item.step_enabled),
                    "retry_count": Number(item.retry_count || 0),
                    "continue_on_error": Boolean(item.continue_on_error)
                })
            }
            return actions
        }

        function collectActionsJson() {
            return JSON.stringify(collectActions())
        }

        function testAction(index) {
            if (index < 0 || index >= actionModel.count)
                return
            var item = actionModel.get(index)
            root.testedStepIndex = index
            root.testedStepState = "running"
            root.testedStepMessage = "Проверяю…"
            backend.testAction(index, String(item.action_type || ""), String(item.value || ""))
        }

        function duplicateAction(index) {
            if (index < 0 || index >= actionModel.count)
                return
            var item = actionModel.get(index)
            actionModel.insert(index + 1, {
                "action_type": item.action_type,
                "value": item.value,
                "delay_after": Number(item.delay_after || 0),
                "step_enabled": Boolean(item.step_enabled),
                "retry_count": Number(item.retry_count || 0),
                "continue_on_error": Boolean(item.continue_on_error)
            })
            scheduleValidation()
        }

        function moveAction(from, to) {
            if (from < 0 || to < 0 || from >= actionModel.count || to >= actionModel.count || from === to)
                return
            actionModel.move(from, to, 1)
            root.testedStepIndex = -1
            root.testedStepState = ""
            root.testedStepMessage = ""
            scheduleValidation()
        }

        function scheduleValidation() {
            validationTimer.restart()
        }

        function refreshValidation() {
            root.editorValidation = backend.validateDraft(
                nameField.text, phrasesField.text, collectActionsJson(),
                commandTypeCombo.currentValue, triggerCombo.currentValue, triggerTimeField.text
            )
        }

        Timer { id: validationTimer; interval: 130; repeat: false; onTriggered: editor.refreshValidation() }

        function actionIndex(type) {
            for (var i = 0; i < actionChoices.length; ++i) {
                if (actionChoices[i].value === type)
                    return i
            }
            return 0
        }

        function actionHint(type) {
            if (type === "open_url") return "https://youtube.com"
            if (type === "open_search") return "Что нужно найти"
            if (type === "open_app") return "calc или C:\\Путь\\app.exe"
            if (type === "open_path") return "C:\\Users\\Имя\\Documents"
            if (type === "create_folder") return "C:\\Проекты\\Новая папка"
            if (type === "copy_text") return "Текст для буфера обмена"
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
            if (type === "require_file") return "C:\\Путь\\к\\файлу"
            if (type === "require_window") return "Часть заголовка окна"
            if (type === "require_time") return "09:00-18:00"
            return "Команда PowerShell или CMD"
        }

        property var actionChoices: [
            { label: "Открыть сайт", value: "open_url" },
            { label: "Найти в интернете", value: "open_search" },
            { label: "Открыть программу", value: "open_app" },
            { label: "Открыть файл или папку", value: "open_path" },
            { label: "Создать папку", value: "create_folder" },
            { label: "Скопировать текст", value: "copy_text" },
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
            { label: "Условие: файл существует", value: "require_file" },
            { label: "Условие: окно открыто", value: "require_window" },
            { label: "Условие: время", value: "require_time" },
            { label: "Выполнить системную команду", value: "shell" }
        ]

        property var commandTypeChoices: [
            { label: "Обычная команда", value: "command" },
            { label: "Режим компьютера", value: "mode" }
        ]
        property var triggerChoices: [
            { label: "По голосовой фразе", value: "voice" },
            { label: "При запуске AURA", value: "startup" },
            { label: "Каждый день по времени", value: "daily" }
        ]
        function choiceIndex(items, value) {
            for (var i = 0; i < items.length; ++i)
                if (items[i].value === value) return i
            return 0
        }

        onOpened: {
            var command = root.editingCommand
            var draft = root.recordingDraft
            nameField.text = draft ? draft.name : (command ? command.name : "")
            phrasesField.text = draft ? draft.phrases : (command ? command.phrases_text : "")
            confirmSwitch.checked = draft ? draft.confirmation : (command ? command.require_confirmation : false)
            commandTypeCombo.currentIndex = choiceIndex(commandTypeChoices, draft ? draft.commandType : (command ? command.command_type : "command"))
            triggerCombo.currentIndex = choiceIndex(triggerChoices, draft ? draft.triggerType : (command ? command.trigger_type : "voice"))
            triggerTimeField.text = draft ? draft.triggerValue : (command ? command.trigger_value : "09:00")
            showAutomationSettings = Boolean(command && (command.command_type !== "command" || command.trigger_type !== "voice"))
            actionModel.clear()

            if (root.recordedActions && root.recordedActions.length > 0) {
                for (var recordedIndex = 0; recordedIndex < root.recordedActions.length; ++recordedIndex) {
                    var recordedStep = root.recordedActions[recordedIndex]
                    addAction(recordedStep.action_type, recordedStep.value, recordedStep.delay_after, recordedStep.enabled, recordedStep.retry_count, recordedStep.continue_on_error)
                }
            } else if (command && command.actions && command.actions.length > 0) {
                for (var i = 0; i < command.actions.length; ++i) {
                    var step = command.actions[i]
                    addAction(step.action_type, step.value, step.delay_after, step.enabled, step.retry_count, step.continue_on_error)
                }
            } else {
                addAction("open_url", "", 0)
            }
            root.recordedActions = null
            root.recordingDraft = null
            root.testedStepIndex = -1
            root.testedStepState = ""
            root.testedStepMessage = ""
            root.scenarioTestMessage = ""
            nameField.forceActiveFocus()
            scheduleValidation()
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 8

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    Text { text: root.editingCommand ? "Редактировать команду" : "Новая команда"; color: root.textMain; font.pixelSize: 21; font.bold: true }
                    Text { text: "Расширенные настройки можно не менять"; color: root.textMuted; font.pixelSize: 12; topPadding: 3 }
                }

                AuraCloseButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -14
                    anchors.rightMargin: -14
                    z: 20
                    onClicked: editor.close()
                }
            }

            Text { text: "Название"; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
            AppTextField { id: nameField; Layout.fillWidth: true; placeholderText: "Например: Открыть рабочие сайты"; onTextEdited: editor.scheduleValidation() }

            Text { text: "Что можно сказать"; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
            AppTextField {
                id: phrasesField
                Layout.fillWidth: true
                enabled: triggerCombo.currentValue === "voice"
                opacity: enabled ? 1 : 0.45
                placeholderText: "начать работу, открой рабочие сайты"
                onTextEdited: editor.scheduleValidation()
            }
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: triggerCombo.currentValue === "voice" ? "Несколько фраз разделяйте запятыми" : "Для автоматического запуска голосовая фраза необязательна"
                    color: root.textMuted
                    font.pixelSize: 10
                }
                ToolButton {
                    id: automationSettingsButton
                    text: editor.showAutomationSettings ? "Скрыть автоматизацию" : "Расписание и режим"
                    onClicked: editor.showAutomationSettings = !editor.showAutomationSettings
                    contentItem: Text { text: automationSettingsButton.text; color: root.accentSoft; font.pixelSize: 10; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                    background: Rectangle { radius: 9; color: automationSettingsButton.hovered ? "#211B3B" : "transparent" }
                }
            }

            Rectangle {
                visible: editor.showAutomationSettings
                Layout.fillWidth: true
                Layout.preferredHeight: visible ? 96 : 0
                radius: 14
                color: "#151A25"
                border.color: root.line
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 11
                    spacing: 9
                    ColumnLayout {
                        Layout.preferredWidth: 176
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Text { text: "Тип"; color: root.textMuted; font.pixelSize: 9 }
                        ComboBox {
                            id: commandTypeCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            model: editor.commandTypeChoices
                            textRole: "label"
                            valueRole: "value"
                            contentItem: Text { leftPadding: 11; text: commandTypeCombo.displayText; color: root.textMain; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 10; color: "#0D111A"; border.color: root.line }
                            onActivated: editor.scheduleValidation()
                        }
                        Text {
                            Layout.fillWidth: true
                            text: commandTypeCombo.currentValue === "mode"
                                ? "Режим объединяет несколько действий и подготавливает компьютер к задаче."
                                : "Команда выполняет отдельную задачу по вашему запросу."
                            color: root.textMuted
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Text { text: "Запуск"; color: root.textMuted; font.pixelSize: 9 }
                        ComboBox {
                            id: triggerCombo
                            Layout.fillWidth: true
                            Layout.preferredHeight: 36
                            model: editor.triggerChoices
                            textRole: "label"
                            valueRole: "value"
                            contentItem: Text { leftPadding: 11; text: triggerCombo.displayText; color: root.textMain; font.pixelSize: 11; verticalAlignment: Text.AlignVCenter }
                            background: Rectangle { radius: 10; color: "#0D111A"; border.color: root.line }
                            onActivated: editor.scheduleValidation()
                        }
                        Text {
                            Layout.fillWidth: true
                            text: triggerCombo.currentValue === "startup"
                                ? "Сценарий запустится автоматически после старта AURA."
                                : triggerCombo.currentValue === "daily"
                                    ? "Сценарий будет запускаться один раз в день в указанное время."
                                    : "Сценарий запустится после одной из голосовых фраз выше."
                            color: root.textMuted
                            font.pixelSize: 9
                            wrapMode: Text.WordWrap
                        }
                    }
                    ColumnLayout {
                        visible: triggerCombo.currentValue === "daily"
                        Layout.preferredWidth: visible ? 80 : 0
                        Layout.alignment: Qt.AlignTop
                        spacing: 4
                        Text { text: "Время"; color: root.textMuted; font.pixelSize: 9 }
                        AppTextField { id: triggerTimeField; Layout.fillWidth: true; Layout.preferredHeight: 36; placeholderText: "09:00"; onTextEdited: editor.scheduleValidation() }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 11
                color: root.editorValidation.valid ? "#14271F" : "#291922"
                border.color: root.editorValidation.valid ? "#27543D" : "#5C2B3A"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8
                    Text { text: root.editorValidation.valid ? "✓" : "!"; color: root.editorValidation.valid ? "#62E39B" : "#FF8C99"; font.bold: true }
                    Text {
                        Layout.fillWidth: true
                        text: root.editorValidation.valid
                            ? (root.editorValidation.warnings > 0 ? "Можно сохранить, замечаний: " + root.editorValidation.warnings : "Сценарий заполнен корректно")
                            : (root.editorValidation.issues && root.editorValidation.issues.length > 0
                                ? root.editorValidation.issues[0].message
                                : "Нужно исправить: " + root.editorValidation.errors)
                        color: root.textMain
                        font.pixelSize: 10
                    }
                    Text { text: "Проверяется автоматически"; color: root.textMuted; font.pixelSize: 9 }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: "Что нужно сделать"
                    color: root.textMain
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }
                SoftButton {
                    Layout.preferredHeight: 36
                    Layout.minimumWidth: 112
                    Layout.alignment: Qt.AlignVCenter
                    text: "●  Записать действия"
                    onClicked: {
                        root.recordingDraft = {
                            "name": nameField.text,
                            "phrases": phrasesField.text,
                            "confirmation": confirmSwitch.checked,
                            "commandType": commandTypeCombo.currentValue,
                            "triggerType": triggerCombo.currentValue,
                            "triggerValue": triggerTimeField.text
                        }
                        editor.close()
                        backend.startRecording()
                    }
                }
                SoftButton {
                    Layout.preferredHeight: 36
                    Layout.minimumWidth: 112
                    Layout.alignment: Qt.AlignVCenter
                    text: "+  Добавить шаг"
                    onClicked: root.openActionPicker()
                }
            }

            ListView {
                id: actionsList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: 148
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
                    required property bool step_enabled
                    required property int retry_count
                    required property bool continue_on_error
                    readonly property bool stepEnabled: step_enabled
                    property bool testSelected: root.testedStepIndex === actionCard.index
                    property bool advancedOpen: retry_count > 0 || continue_on_error
                    width: actionsList.width - (actionsList.ScrollBar.vertical.visible ? 12 : 0)
                    height: 150
                    radius: 14
                    color: actionHover.hovered ? "#181E2A" : "#151A25"
                    opacity: stepEnabled ? 1 : 0.55
                    border.width: testSelected || backend.testingActionIndex === actionCard.index ? 1.5 : 1
                    border.color: backend.testingActionIndex === actionCard.index
                        ? root.accent
                        : testSelected
                            ? (root.testedStepState === "success" ? "#43D17C" : "#FF6B7A")
                            : "#252C3A"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 11
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 7

                            Rectangle {
                                width: 27
                                height: 27
                                radius: 9
                                color: actionCard.testSelected
                                    ? (root.testedStepState === "success" ? "#193529" : "#3A2029")
                                    : "#211B3B"
                                Text {
                                    anchors.centerIn: parent
                                    text: actionCard.testSelected
                                        ? (root.testedStepState === "success" ? "✓" : root.testedStepState === "running" ? "…" : "!")
                                        : actionCard.index + 1
                                    color: actionCard.testSelected
                                        ? (root.testedStepState === "success" ? "#62E39B" : root.testedStepState === "running" ? "#9DD8FF" : "#FF8C99")
                                        : root.accentSoft
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
                                onActivated: {
                                    actionModel.setProperty(actionCard.index, "action_type", currentValue)
                                    root.testedStepIndex = -1
                                    editor.scheduleValidation()
                                }
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
                                id: testStepButton
                                implicitWidth: 34
                                implicitHeight: 34
                                // A disabled step may still be tested manually. The backend
                                // safely pauses wake-word listening before executing it.
                                enabled: !backend.recording
                                    && !backend.testingScenario
                                    && backend.testingActionIndex < 0
                                    && !(actionCard.testSelected && root.testedStepState === "running")
                                text: backend.testingActionIndex === actionCard.index || (actionCard.testSelected && root.testedStepState === "running") ? "…" : "▶"
                                ToolTip.visible: hovered
                                ToolTip.text: "Проверить этот шаг"
                                onClicked: editor.testAction(actionCard.index)
                                background: Rectangle { color: testStepButton.hovered ? "#222A39" : "transparent"; radius: 10 }
                                contentItem: Text { text: testStepButton.text; color: testStepButton.enabled ? "#9DD8FF" : "#586273"; font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }

                            ToolButton {
                                id: duplicateStepButton
                                implicitWidth: 34
                                implicitHeight: 34
                                text: "⧉"
                                ToolTip.visible: hovered
                                ToolTip.text: "Дублировать шаг"
                                onClicked: editor.duplicateAction(actionCard.index)
                                background: Rectangle { color: duplicateStepButton.hovered ? "#222A39" : "transparent"; radius: 10 }
                                contentItem: Text { text: duplicateStepButton.text; color: root.textMuted; font.pixelSize: 16; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }

                            ToolButton {
                                id: removeStepButton
                                visible: actionModel.count > 1
                                implicitWidth: 34
                                implicitHeight: 34
                                text: "×"
                                font.pixelSize: 20
                                ToolTip.visible: hovered
                                ToolTip.text: "Удалить шаг"
                                onClicked: {
                                    actionModel.remove(actionCard.index)
                                    root.testedStepIndex = -1
                                    editor.scheduleValidation()
                                }
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
                                onTextEdited: {
                                    actionModel.setProperty(actionCard.index, "value", text)
                                    root.testedStepIndex = -1
                                    editor.scheduleValidation()
                                }
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
                                        editor.scheduleValidation()
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            CheckBox {
                                id: stepEnabledCheck
                                checked: actionCard.step_enabled
                                text: "Включён"
                                onToggled: {
                                    actionModel.setProperty(actionCard.index, "step_enabled", checked)
                                    root.testedStepIndex = -1
                                    editor.scheduleValidation()
                                }
                                indicator: Rectangle {
                                    implicitWidth: 18; implicitHeight: 18; radius: 6
                                    color: stepEnabledCheck.checked ? root.accent : "#0D111A"
                                    border.color: stepEnabledCheck.checked ? root.accent : root.line
                                    Text { anchors.centerIn: parent; visible: stepEnabledCheck.checked; text: "✓"; color: "white"; font.pixelSize: 11; font.bold: true }
                                }
                                contentItem: Text { leftPadding: 25; text: stepEnabledCheck.text; color: root.textMuted; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                            }
                            ToolButton {
                                id: stepAdvancedButton
                                text: actionCard.advancedOpen ? "Скрыть настройки" : "Дополнительно"
                                onClicked: actionCard.advancedOpen = !actionCard.advancedOpen
                                contentItem: Text { text: stepAdvancedButton.text; color: root.accentSoft; font.pixelSize: 9; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 8; color: stepAdvancedButton.hovered ? "#211B3B" : "transparent" }
                            }
                            Text { visible: actionCard.advancedOpen; text: "Повторы"; color: root.textMuted; font.pixelSize: 9 }
                            ComboBox {
                                visible: actionCard.advancedOpen
                                id: retryCombo
                                Layout.preferredWidth: 58
                                Layout.preferredHeight: 28
                                model: [0, 1, 2, 3, 4, 5]
                                currentIndex: Math.max(0, Math.min(5, actionCard.retry_count))
                                onActivated: { actionModel.setProperty(actionCard.index, "retry_count", currentValue); editor.scheduleValidation() }
                                contentItem: Text { leftPadding: 9; text: retryCombo.displayText; color: root.textMain; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
                                background: Rectangle { radius: 8; color: "#0D111A"; border.color: root.line }
                            }
                            CheckBox {
                                id: continueOnErrorCheck
                                visible: actionCard.advancedOpen
                                checked: actionCard.continue_on_error
                                text: "Продолжить при ошибке"
                                onToggled: { actionModel.setProperty(actionCard.index, "continue_on_error", checked); editor.scheduleValidation() }
                                indicator: Rectangle {
                                    implicitWidth: 16; implicitHeight: 16; radius: 5
                                    color: continueOnErrorCheck.checked ? root.accent : "#0D111A"
                                    border.color: continueOnErrorCheck.checked ? root.accent : root.line
                                    Text { anchors.centerIn: parent; visible: continueOnErrorCheck.checked; text: "✓"; color: "white"; font.pixelSize: 9; font.bold: true }
                                }
                                contentItem: Text { leftPadding: 22; text: continueOnErrorCheck.text; color: root.textMuted; font.pixelSize: 9; verticalAlignment: Text.AlignVCenter }
                            }
                            Text {
                                Layout.fillWidth: true
                                visible: actionCard.testSelected
                                text: root.testedStepMessage
                                color: root.testedStepState === "success" ? "#62E39B" : "#FF8C99"
                                font.pixelSize: 9
                                elide: Text.ElideRight
                            }
                            ToolButton {
                                id: moveUpButton
                                implicitWidth: 28; implicitHeight: 26
                                enabled: actionCard.index > 0
                                text: "↑"
                                ToolTip.visible: hovered; ToolTip.text: "Переместить выше"
                                onClicked: editor.moveAction(actionCard.index, actionCard.index - 1)
                                background: Rectangle { color: moveUpButton.hovered ? "#222A39" : "transparent"; radius: 8 }
                                contentItem: Text { text: moveUpButton.text; color: moveUpButton.enabled ? root.textMuted : "#424A58"; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            ToolButton {
                                id: moveDownButton
                                implicitWidth: 28; implicitHeight: 26
                                enabled: actionCard.index < actionModel.count - 1
                                text: "↓"
                                ToolTip.visible: hovered; ToolTip.text: "Переместить ниже"
                                onClicked: editor.moveAction(actionCard.index, actionCard.index + 1)
                                background: Rectangle { color: moveDownButton.hovered ? "#222A39" : "transparent"; radius: 8 }
                                contentItem: Text { text: moveDownButton.text; color: moveDownButton.enabled ? root.textMuted : "#424A58"; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                        }
                    }

                    HoverHandler { id: actionHover }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: root.scenarioTestMessage.length > 0 ? 38 : 0
                visible: root.scenarioTestMessage.length > 0
                radius: 11
                color: root.scenarioTestMessage.indexOf("Ошибка") >= 0 || root.scenarioTestMessage.indexOf("остановлена") >= 0 ? "#2A1820" : "#162820"
                border.color: root.scenarioTestMessage.indexOf("Ошибка") >= 0 || root.scenarioTestMessage.indexOf("остановлена") >= 0 ? "#5A2935" : "#26533B"
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    Text {
                        text: root.scenarioTestMessage.indexOf("Ошибка") >= 0 || root.scenarioTestMessage.indexOf("остановлена") >= 0 ? "!" : "✓"
                        color: root.scenarioTestMessage.indexOf("Ошибка") >= 0 || root.scenarioTestMessage.indexOf("остановлена") >= 0 ? "#FF8C99" : "#62E39B"
                        font.bold: true
                    }
                    Text { Layout.fillWidth: true; text: root.scenarioTestMessage; color: root.textMain; font.pixelSize: 10; elide: Text.ElideRight }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 48
                radius: 12
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

            Rectangle {
                id: editorFooter
                Layout.fillWidth: true
                Layout.preferredHeight: 54
                Layout.minimumHeight: 54
                color: "transparent"

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: 1
                    color: root.line
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    height: 44
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
                    SoftButton {
                        Layout.preferredHeight: 42
                        Layout.minimumWidth: 132
                        Layout.alignment: Qt.AlignVCenter
                        enabled: !backend.testingScenario && backend.testingActionIndex < 0
                        text: backend.testingScenario ? "Проверяю…" : "▶  Пробный запуск"
                        onClicked: {
                            root.scenarioTestMessage = "Запускаю проверку сценария…"
                            backend.testScenario(editor.collectActionsJson())
                        }
                    }
                    Item { Layout.fillWidth: true }
                    SoftButton {
                        Layout.preferredHeight: 42
                        Layout.minimumWidth: 104
                        Layout.alignment: Qt.AlignVCenter
                        text: "Отмена"
                        onClicked: editor.close()
                    }
                    AccentButton {
                        Layout.preferredHeight: 42
                        Layout.minimumWidth: 120
                        Layout.alignment: Qt.AlignVCenter
                        text: "Сохранить"
                        enabled: Boolean(root.editorValidation.valid)
                        ToolTip.visible: hovered && !enabled
                        ToolTip.text: "Исправьте ошибки сценария"
                        onClicked: {
                            var saved = backend.saveAutomationCommand(
                                root.editingCommand ? root.editingCommand.id : "",
                                nameField.text,
                                phrasesField.text,
                                editor.collectActionsJson(),
                                confirmSwitch.checked,
                                commandTypeCombo.currentValue,
                                triggerCombo.currentValue,
                                triggerTimeField.text
                            )
                            if (saved)
                                editor.close()
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: settingsDialog
        width: Math.min(780, root.width - 60)
        height: Math.min(680, root.height - 50)
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape
        padding: 0
        property int microphoneComboIndex: 0

        function findMicrophoneIndex(value) {
            for (var i = 0; i < backend.microphones.length; ++i) {
                if (Number(backend.microphones[i].index) === Number(value))
                    return i
            }
            return 0
        }

        onOpened: {
            backend.refreshMicrophones()
            microphoneComboIndex = findMicrophoneIndex(backend.selectedMicrophoneIndex)
        }

        background: Rectangle { radius: 24; color: "#111621"; border.color: "#343C4D"; border.width: 1 }
        Overlay.modal: Rectangle { color: "#B005070B" }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 15

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: 3
                    Text { text: "Настройки"; color: root.textMain; font.pixelSize: 22; font.weight: Font.DemiBold }
                    Text { text: "AURA " + backend.version + "  •  все параметры сохраняются автоматически"; color: root.textMuted; font.pixelSize: 11 }
                }

                AuraCloseButton {
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.topMargin: -14
                    anchors.rightMargin: -14
                    z: 20
                    onClicked: settingsDialog.close()
                }
            }

            Flickable {
                id: settingsScroll
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: settingsColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                ColumnLayout {
                    id: settingsColumn
                    width: settingsScroll.width
                    spacing: 12

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 164
                        radius: 18
                        color: "#151A25"
                        border.color: root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 10
                            Text { text: "Микрофон"; color: root.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 9
                                ComboBox {
                                    id: settingsMicCombo
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 42
                                    model: backend.microphones
                                    textRole: "name"
                                    valueRole: "index"
                                    currentIndex: settingsDialog.microphoneComboIndex
                                    onActivated: {
                                        backend.setMicrophoneIndex(currentValue)
                                        settingsDialog.microphoneComboIndex = currentIndex
                                    }
                                    contentItem: Text {
                                        leftPadding: 13
                                        text: settingsMicCombo.displayText
                                        color: root.textMain
                                        verticalAlignment: Text.AlignVCenter
                                        elide: Text.ElideRight
                                        font.pixelSize: 12
                                    }
                                    background: Rectangle { radius: 12; color: "#0D111A"; border.color: settingsMicCombo.activeFocus ? root.accent : root.line }
                                }
                                SoftButton { text: "Обновить"; onClicked: backend.refreshMicrophones() }
                                AccentButton {
                                    text: backend.microphoneTesting ? "Слушаю…" : "Проверить"
                                    enabled: !backend.microphoneTesting
                                    onClicked: backend.startMicrophoneTest()
                                }
                            }
                            ProgressBar {
                                Layout.fillWidth: true
                                from: 0; to: 100; value: backend.microphoneLevel
                                background: Rectangle { implicitHeight: 7; radius: 4; color: "#282F3E" }
                                contentItem: Item {
                                    implicitHeight: 7
                                    Rectangle { width: parent.width * backend.microphoneLevel / 100; height: 7; radius: 4; color: backend.microphoneLevel > 55 ? "#43D17C" : root.accent }
                                }
                            }
                            Text {
                                Layout.fillWidth: true
                                text: backend.microphoneTestMessage.length ? backend.microphoneTestMessage : "Выберите устройство и нажмите «Проверить»"
                                color: root.textMuted
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 188
                        radius: 18
                        color: "#151A25"
                        border.color: root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 10
                            Text { text: "Голос"; color: root.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: "Активация голосом"; color: root.textMain; font.pixelSize: 13 }
                                AuraSwitch { checked: backend.wakeEnabled; onToggled: backend.setWakeEnabled(checked) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10
                                Text { text: "Фраза"; color: root.textMuted; font.pixelSize: 12 }
                                AppTextField {
                                    id: settingsWakePhrase
                                    Layout.fillWidth: true
                                    text: backend.wakePhrase
                                    placeholderText: "Аура"
                                    onEditingFinished: backend.setWakePhrase(text)
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: "Голосовые ответы"; color: root.textMain; font.pixelSize: 13 }
                                AuraSwitch { checked: backend.voiceFeedbackEnabled; onToggled: backend.setVoiceFeedbackEnabled(checked) }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 190
                        radius: 18
                        color: "#151A25"
                        border.color: root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 10
                            Text { text: "Анимация сферы"; color: root.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Интенсивность"; color: root.textMain; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                ComboBox {
                                    id: animationIntensityCombo
                                    Layout.preferredWidth: 190
                                    Layout.preferredHeight: 40
                                    model: ["Низкая", "Обычная", "Высокая"]
                                    currentIndex: backend.animationIntensity === "low" ? 0 : backend.animationIntensity === "high" ? 2 : 1
                                    onActivated: backend.setAnimationIntensity(currentIndex === 0 ? "low" : currentIndex === 2 ? "high" : "normal")
                                    contentItem: Text { leftPadding: 12; text: animationIntensityCombo.displayText; color: root.textMain; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12 }
                                    background: Rectangle { radius: 12; color: "#0D111A"; border.color: root.line }
                                }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "Реакция на микрофон"; color: root.textMain; font.pixelSize: 13 }
                                    Text { text: "Кольцо и волна реагируют на громкость речи"; color: root.textMuted; font.pixelSize: 10 }
                                }
                                AuraSwitch { checked: backend.microphoneReactiveAnimation; onToggled: backend.setMicrophoneReactiveAnimation(checked) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "Уменьшить движение"; color: root.textMain; font.pixelSize: 13 }
                                    Text { text: "Отключает вращение, дыхание и покачивание"; color: root.textMuted; font.pixelSize: 10 }
                                }
                                AuraSwitch { checked: backend.reduceMotion; onToggled: backend.setReduceMotion(checked) }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 174
                        radius: 18
                        color: "#151A25"
                        border.color: root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 10
                            Text { text: "Запуск и обновления"; color: root.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                            RowLayout {
                                Layout.fillWidth: true
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text { text: "Запускать вместе с Windows"; color: root.textMain; font.pixelSize: 13 }
                                    Text { text: "AURA запускается свёрнутой в системный трей"; color: root.textMuted; font.pixelSize: 10 }
                                }
                                AuraSwitch { checked: backend.autostartEnabled; onToggled: backend.setAutostartEnabled(checked) }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Text { text: "Канал обновлений"; color: root.textMain; font.pixelSize: 13 }
                                Item { Layout.fillWidth: true }
                                ComboBox {
                                    id: channelCombo
                                    Layout.preferredWidth: 190
                                    Layout.preferredHeight: 40
                                    model: ["Стабильный", "Тестовый"]
                                    currentIndex: backend.updateChannel === "beta" ? 1 : 0
                                    onActivated: backend.setUpdateChannel(currentIndex === 1 ? "beta" : "stable")
                                    contentItem: Text { leftPadding: 12; text: channelCombo.displayText; color: root.textMain; verticalAlignment: Text.AlignVCenter; font.pixelSize: 12 }
                                    background: Rectangle { radius: 12; color: "#0D111A"; border.color: root.line }
                                }
                                SoftButton { text: backend.updateBusy ? "Проверяю…" : "Проверить"; enabled: !backend.updateBusy; onClicked: backend.checkForUpdates() }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 142
                        radius: 18
                        color: "#151A25"
                        border.color: root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 10
                            Text { text: "Резервные копии"; color: root.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                            Text { Layout.fillWidth: true; text: "Команды и настройки сохраняются в ZIP. AURA хранит восемь последних копий."; color: root.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                            RowLayout {
                                Layout.fillWidth: true
                                AccentButton { text: "Создать копию"; onClicked: backend.createBackup() }
                                SoftButton { text: "Восстановить"; onClicked: backend.restoreBackup() }
                                SoftButton { text: "Импорт команд"; onClicked: backend.importCommands() }
                                SoftButton { text: "Экспорт команд"; onClicked: backend.exportAllCommands() }
                                SoftButton { text: "Открыть папку"; onClicked: backend.openBackupsFolder() }
                                Item { Layout.fillWidth: true }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.max(150, 96 + diagnosticsRepeater.count * 54)
                        radius: 18
                        color: "#151A25"
                        border.color: root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 17
                            spacing: 9
                            RowLayout {
                                Layout.fillWidth: true
                                Text { Layout.fillWidth: true; text: "Диагностика"; color: root.textMain; font.pixelSize: 15; font.weight: Font.DemiBold }
                                AccentButton {
                                    text: backend.diagnosticsRunning ? "Проверяю…" : "Проверить AURA"
                                    enabled: !backend.diagnosticsRunning
                                    onClicked: backend.runDiagnostics()
                                }
                            }
                            Text {
                                visible: backend.diagnostics.length === 0
                                Layout.fillWidth: true
                                text: "Проверка микрофона, моделей, обновлений, горячих клавиш и файлов данных."
                                color: root.textMuted
                                font.pixelSize: 11
                                wrapMode: Text.WordWrap
                            }
                            Repeater {
                                id: diagnosticsRepeater
                                model: backend.diagnostics
                                delegate: Rectangle {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 46
                                    radius: 11
                                    color: "#10151F"
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 12
                                        anchors.rightMargin: 12
                                        spacing: 10
                                        Rectangle { width: 8; height: 8; radius: 4; color: modelData.tone === "success" ? "#43D17C" : "#FF6B72" }
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 1
                                            Text { text: modelData.name; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold }
                                            Text { Layout.fillWidth: true; text: modelData.details; color: root.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                                        }
                                        Text { text: modelData.status; color: modelData.tone === "success" ? "#62DB91" : "#FF878C"; font.pixelSize: 11 }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Connections {
            target: backend
            function onSettingsChanged() {
                settingsDialog.microphoneComboIndex = settingsDialog.findMicrophoneIndex(backend.selectedMicrophoneIndex)
            }
        }
    }

    Dialog {
        id: firstRunDialog
        width: Math.min(650, root.width - 50)
        height: Math.min(570, root.height - 45)
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.NoAutoClose
        padding: 0
        property int step: 0
        property int micIndex: 0

        function findMicrophoneIndex(value) {
            for (var i = 0; i < backend.microphones.length; ++i) {
                if (Number(backend.microphones[i].index) === Number(value))
                    return i
            }
            return 0
        }

        onOpened: {
            backend.refreshMicrophones()
            micIndex = findMicrophoneIndex(backend.selectedMicrophoneIndex)
        }

        background: Rectangle { radius: 26; color: "#111621"; border.color: "#4A3A82"; border.width: 1 }
        Overlay.modal: Rectangle { color: "#D005070B" }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                Rectangle {
                    width: 42; height: 42; radius: 14
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#997FFF" }
                        GradientStop { position: 1; color: "#6240E8" }
                    }
                    Text { anchors.centerIn: parent; text: "A"; color: "white"; font.pixelSize: 20; font.bold: true }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text { text: "Первичная настройка AURA"; color: root.textMain; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { text: "Шаг " + (firstRunDialog.step + 1) + " из 5"; color: root.textMuted; font.pixelSize: 11 }
                }
                Row {
                    spacing: 5
                    Repeater {
                        model: 5
                        Rectangle { width: index === firstRunDialog.step ? 22 : 7; height: 7; radius: 4; color: index <= firstRunDialog.step ? root.accent : "#343B4B"; Behavior on width { NumberAnimation { duration: 150 } } }
                    }
                }
            }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: firstRunDialog.step

                ColumnLayout {
                    spacing: 15
                    Item { Layout.fillHeight: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "Добро пожаловать"; color: root.textMain; font.pixelSize: 28; font.weight: Font.DemiBold }
                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 500
                        Layout.alignment: Qt.AlignHCenter
                        text: "Мастер проверит микрофон, голосовую активацию и обновления. Настройки потом можно изменить в любое время."
                        color: root.textMuted
                        font.pixelSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                    }
                    Rectangle {
                        Layout.alignment: Qt.AlignHCenter
                        width: 250; height: 118; radius: 59
                        gradient: Gradient {
                            GradientStop { position: 0; color: "#282048" }
                            GradientStop { position: 1; color: "#15182B" }
                        }
                        border.color: "#5F4BA5"
                        Text { anchors.centerIn: parent; text: "Настроим за 2 минуты"; color: root.accentSoft; font.pixelSize: 15; font.weight: Font.DemiBold }
                    }
                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    spacing: 13
                    Text { text: "Выберите микрофон"; color: root.textMain; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; text: "AURA будет использовать это устройство для фразы активации и команд."; color: root.textMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    ComboBox {
                        id: wizardMicCombo
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        model: backend.microphones
                        textRole: "name"
                        valueRole: "index"
                        currentIndex: firstRunDialog.micIndex
                        onActivated: { backend.setMicrophoneIndex(currentValue); firstRunDialog.micIndex = currentIndex }
                        contentItem: Text { leftPadding: 14; text: wizardMicCombo.displayText; color: root.textMain; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; font.pixelSize: 13 }
                        background: Rectangle { radius: 13; color: "#0D111A"; border.color: root.line }
                    }
                    ProgressBar {
                        Layout.fillWidth: true
                        from: 0; to: 100; value: backend.microphoneLevel
                        background: Rectangle { implicitHeight: 9; radius: 5; color: "#282F3E" }
                        contentItem: Item { implicitHeight: 9; Rectangle { width: parent.width * backend.microphoneLevel / 100; height: 9; radius: 5; color: root.accent } }
                    }
                    Text { Layout.fillWidth: true; text: backend.microphoneTestMessage.length ? backend.microphoneTestMessage : "Нажмите кнопку и произнесите несколько слов"; color: root.textMuted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                    AccentButton { Layout.alignment: Qt.AlignHCenter; text: backend.microphoneTesting ? "Слушаю…" : "Проверить микрофон"; enabled: !backend.microphoneTesting; onClicked: backend.startMicrophoneTest() }
                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    spacing: 15
                    Text { text: "Голосовая активация"; color: root.textMain; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; text: "Назовите короткую фразу. Рекомендуемый вариант: «Аура». Обнаружение выполняется локально."; color: root.textMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    AppTextField { id: wizardWakePhrase; Layout.fillWidth: true; text: backend.wakePhrase; placeholderText: "Аура"; onEditingFinished: backend.setWakePhrase(text) }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 58; radius: 14; color: "#151A25"; border.color: root.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 12
                            Text { Layout.fillWidth: true; text: "Включить активацию голосом"; color: root.textMain; font.pixelSize: 13 }
                            AuraSwitch { checked: backend.wakeEnabled; onToggled: backend.setWakeEnabled(checked) }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 58; radius: 14; color: "#151A25"; border.color: root.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 12
                            Text { Layout.fillWidth: true; text: "Озвучивать результат команд"; color: root.textMain; font.pixelSize: 13 }
                            AuraSwitch { checked: backend.voiceFeedbackEnabled; onToggled: backend.setVoiceFeedbackEnabled(checked) }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    spacing: 15
                    Text { text: "Запуск и обновления"; color: root.textMain; font.pixelSize: 20; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; text: "Для большинства пользователей подходит стабильный канал. Тестовый получает новые версии раньше."; color: root.textMuted; font.pixelSize: 12; wrapMode: Text.WordWrap }
                    Rectangle {
                        Layout.fillWidth: true; Layout.preferredHeight: 66; radius: 14; color: "#151A25"; border.color: root.line
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 15
                            anchors.rightMargin: 12
                            ColumnLayout {
                                Layout.fillWidth: true
                                Text { text: "Запускать с Windows"; color: root.textMain; font.pixelSize: 13 }
                                Text { text: "Программа откроется свёрнутой в трей"; color: root.textMuted; font.pixelSize: 10 }
                            }
                            AuraSwitch { checked: backend.autostartEnabled; onToggled: backend.setAutostartEnabled(checked) }
                        }
                    }
                    ComboBox {
                        id: wizardChannel
                        Layout.fillWidth: true
                        Layout.preferredHeight: 46
                        model: ["Стабильный канал", "Тестовый канал"]
                        currentIndex: backend.updateChannel === "beta" ? 1 : 0
                        onActivated: backend.setUpdateChannel(currentIndex === 1 ? "beta" : "stable")
                        contentItem: Text { leftPadding: 14; text: wizardChannel.displayText; color: root.textMain; verticalAlignment: Text.AlignVCenter; font.pixelSize: 13 }
                        background: Rectangle { radius: 13; color: "#0D111A"; border.color: root.line }
                    }
                    Item { Layout.fillHeight: true }
                }

                ColumnLayout {
                    spacing: 15
                    Item { Layout.fillHeight: true }
                    Text { Layout.alignment: Qt.AlignHCenter; text: "AURA готова"; color: root.textMain; font.pixelSize: 28; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; Layout.maximumWidth: 500; Layout.alignment: Qt.AlignHCenter; text: "Скажите «" + backend.wakePhrase.charAt(0).toUpperCase() + backend.wakePhrase.slice(1) + ", открой браузер» или создайте свою команду."; color: root.textMuted; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap }
                    Rectangle { Layout.alignment: Qt.AlignHCenter; width: 86; height: 86; radius: 43; color: "#201A38"; border.color: root.accent; Text { anchors.centerIn: parent; text: "✓"; color: "#8FE0AD"; font.pixelSize: 36; font.bold: true } }
                    Item { Layout.fillHeight: true }
                }
            }

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.line }
            RowLayout {
                Layout.fillWidth: true
                SoftButton { visible: firstRunDialog.step > 0; text: "Назад"; onClicked: firstRunDialog.step-- }
                Item { Layout.fillWidth: true }
                Text { visible: firstRunDialog.step === 1 && backend.microphoneLevel < 3; text: "Тест можно пропустить"; color: root.textMuted; font.pixelSize: 10 }
                AccentButton {
                    text: firstRunDialog.step === 4 ? "Начать работу" : "Далее"
                    onClicked: {
                        if (firstRunDialog.step === 4) {
                            backend.completeFirstRun()
                            firstRunDialog.close()
                        } else {
                            firstRunDialog.step++
                        }
                    }
                }
            }
        }

        Connections {
            target: backend
            function onSettingsChanged() {
                firstRunDialog.micIndex = firstRunDialog.findMicrophoneIndex(backend.selectedMicrophoneIndex)
            }
        }
    }

    Timer {
        interval: 650
        running: !backend.firstRunCompleted
        repeat: false
        onTriggered: firstRunDialog.open()
    }

    Dialog {
        id: templateDialog
        width: Math.min(650, root.width - 60)
        height: Math.min(470, root.height - 70)
        anchors.centerIn: parent
        modal: true
        closePolicy: Popup.CloseOnEscape
        padding: 0
        background: Rectangle { radius: 22; color: "#121722"; border.color: "#303747" }
        Overlay.modal: Rectangle { color: "#AA05070B" }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 14
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Column {
                    anchors.left: parent.left
                    Text { text: "Шаблоны режимов"; color: root.textMain; font.pixelSize: 21; font.bold: true }
                    Text { text: "Добавьте готовый сценарий и настройте программы под себя"; color: root.textMuted; font.pixelSize: 11; topPadding: 3 }
                }
                AuraCloseButton { anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -12; anchors.rightMargin: -12; onClicked: templateDialog.close() }
            }
            GridView {
                id: templateGrid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: Math.floor(width / 2)
                cellHeight: 142
                model: backend.modeTemplates
                delegate: Item {
                    required property var modelData
                    width: templateGrid.cellWidth
                    height: templateGrid.cellHeight
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 6
                        radius: 16
                        color: templateMouse.containsMouse ? "#1A2030" : "#151A25"
                        border.color: templateMouse.containsMouse ? "#51428A" : root.line
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 15
                            spacing: 7
                            RowLayout {
                                Layout.fillWidth: true
                                Rectangle { width: 30; height: 30; radius: 10; color: "#241D42"; Text { anchors.centerIn: parent; text: "◇"; color: root.accentSoft; font.pixelSize: 15 } }
                                Text { Layout.fillWidth: true; text: modelData.name; color: root.textMain; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            }
                            Text { Layout.fillWidth: true; Layout.fillHeight: true; text: modelData.description; color: root.textMuted; font.pixelSize: 10; wrapMode: Text.WordWrap }
                            Text { text: "+ Добавить режим"; color: root.accentSoft; font.pixelSize: 10; font.weight: Font.DemiBold }
                        }
                        MouseArea {
                            id: templateMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                backend.createModeTemplate(modelData.id)
                                templateDialog.close()
                            }
                        }
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

    Window {
        id: recordingOverlay
        width: 330
        height: 78
        visible: backend.recording
        transientParent: null
        color: "transparent"
        flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
        x: Math.max(20, Screen.width - width - 28)
        y: Math.max(20, Screen.height - height - 72)

        Rectangle {
            anchors.fill: parent
            radius: 18
            color: "#151A25"
            border.color: "#56312B"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 11
                Rectangle {
                    width: 12
                    height: 12
                    radius: 6
                    color: "#FF765E"
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: recordingOverlay.visible
                        NumberAnimation { to: 0.3; duration: 520 }
                        NumberAnimation { to: 1; duration: 520 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    Text { text: "Идёт запись действий"; color: root.textMain; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: "Ctrl + Shift + F12 для остановки"; color: root.textMuted; font.pixelSize: 10 }
                }
                SoftButton {
                    Layout.preferredHeight: 36
                    text: "Стоп"
                    onClicked: backend.stopRecording()
                }
            }
        }
    }

    Dialog {
        id: actionPicker
        width: Math.min(680, root.width - 70)
        height: Math.min(620, root.height - 70)
        anchors.centerIn: parent
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { radius: 22; color: "#121722"; border.color: "#303747" }
        Overlay.modal: Rectangle { color: "#AA05070B" }
        onOpened: { root.actionPickerSearch = ""; actionPickerField.text = ""; actionPickerField.forceActiveFocus() }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 12
            Item {
                Layout.fillWidth: true; Layout.preferredHeight: 46
                Column { anchors.left: parent.left; Text { text: "Добавить действие"; color: root.textMain; font.pixelSize: 20; font.bold: true } Text { text: "Выберите безопасный блок для сценария"; color: root.textMuted; font.pixelSize: 11; topPadding: 3 } }
                AuraCloseButton { anchors.top: parent.top; anchors.right: parent.right; anchors.topMargin: -12; anchors.rightMargin: -12; onClicked: actionPicker.close() }
            }
            AppTextField { id: actionPickerField; Layout.fillWidth: true; placeholderText: "Поиск действия"; onTextChanged: root.actionPickerSearch = text.trim().toLowerCase() }
            Flickable {
                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                contentHeight: actionPickerColumn.height
                ScrollBar.vertical: ScrollBar {}
                Column {
                    id: actionPickerColumn; width: parent.width; spacing: 8
                    Repeater {
                        model: backend.actionCatalog
                        delegate: Rectangle {
                            required property var modelData
                            property bool matches: root.actionPickerSearch.length === 0
                                || String(modelData.label).toLowerCase().indexOf(root.actionPickerSearch) >= 0
                                || String(modelData.description).toLowerCase().indexOf(root.actionPickerSearch) >= 0
                                || String(modelData.category).toLowerCase().indexOf(root.actionPickerSearch) >= 0
                            width: actionPickerColumn.width
                            height: matches ? 66 : 0
                            visible: matches
                            radius: 13
                            color: actionPickMouse.containsMouse ? "#1B2230" : "#151A25"
                            border.color: modelData.dangerous ? "#5A3A2B" : root.line
                            RowLayout {
                                anchors.fill: parent; anchors.margins: 11; spacing: 11
                                Rectangle { width: 36; height: 36; radius: 11; color: modelData.dangerous ? "#30231C" : "#211B3B"; Text { anchors.centerIn: parent; text: modelData.icon; color: modelData.dangerous ? "#FFB27C" : root.accentSoft; font.pixelSize: 14; font.bold: true } }
                                ColumnLayout { Layout.fillWidth: true; spacing: 2
                                    RowLayout { Layout.fillWidth: true; Text { Layout.fillWidth: true; text: modelData.label; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold } Text { text: modelData.category; color: root.textMuted; font.pixelSize: 9 } }
                                    Text { Layout.fillWidth: true; text: modelData.description; color: root.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                                }
                            }
                            MouseArea { id: actionPickMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { editor.addAction(modelData.type, "", 0, true, 0, false); actionPicker.close() } }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: commandPalette
        width: Math.min(620, root.width - 80)
        height: Math.min(560, root.height - 90)
        x: Math.round((root.width - width) / 2)
        y: Math.max(26, (root.height - height) * 0.22)
        modal: true
        padding: 0
        closePolicy: Popup.CloseOnEscape
        background: Rectangle { radius: 22; color: "#121722"; border.color: "#394258" }
        Overlay.modal: Rectangle { color: "#9905070B" }
        onOpened: { root.paletteSearch = ""; paletteField.text = ""; paletteField.forceActiveFocus() }
        contentItem: ColumnLayout {
            anchors.fill: parent; anchors.margins: 18; spacing: 10
            RowLayout { Layout.fillWidth: true
                Text { Layout.fillWidth: true; text: "Быстрый запуск"; color: root.textMain; font.pixelSize: 18; font.bold: true }
                Text { text: "Ctrl + K"; color: root.textMuted; font.pixelSize: 10; font.family: "Consolas" }
            }
            AppTextField { id: paletteField; Layout.fillWidth: true; placeholderText: "Команда, настройка или действие"; onTextChanged: root.paletteSearch = text.trim().toLowerCase() }
            RowLayout { Layout.fillWidth: true; spacing: 8
                SoftButton { Layout.fillWidth: true; text: "+ Новая команда"; onClicked: { commandPalette.close(); root.createCommand() } }
                SoftButton { Layout.fillWidth: true; text: "⚙ Настройки"; onClicked: { commandPalette.close(); root.openSettings() } }
                SoftButton { Layout.fillWidth: true; text: "Шаблоны"; onClicked: { commandPalette.close(); templateDialog.open() } }
            }
            Text { text: "КОМАНДЫ"; color: "#626C7E"; font.pixelSize: 9; font.bold: true; font.letterSpacing: 1.1 }
            Flickable { Layout.fillWidth: true; Layout.fillHeight: true; clip: true; contentHeight: paletteColumn.height; ScrollBar.vertical: ScrollBar {}
                Column { id: paletteColumn; width: parent.width; spacing: 6
                    Repeater { model: backend.commands
                        delegate: Rectangle {
                            required property var modelData
                            property bool matches: root.paletteSearch.length === 0 || String(modelData.name).toLowerCase().indexOf(root.paletteSearch) >= 0 || String(modelData.phrases_text).toLowerCase().indexOf(root.paletteSearch) >= 0
                            width: paletteColumn.width; height: matches ? 54 : 0; visible: matches; radius: 12
                            color: paletteCommandMouse.containsMouse ? "#1B2230" : "transparent"; opacity: modelData.enabled ? 1 : 0.45
                            RowLayout { anchors.fill: parent; anchors.leftMargin: 11; anchors.rightMargin: 11; spacing: 9
                                Rectangle { width: 7; height: 7; radius: 4; color: modelData.quality_tone === "error" ? "#FF6B7A" : modelData.quality_tone === "warning" ? "#F4B860" : "#43D17C" }
                                ColumnLayout { Layout.fillWidth: true; spacing: 1
                                    Text { Layout.fillWidth: true; text: modelData.name; color: root.textMain; font.pixelSize: 12; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                    Text { Layout.fillWidth: true; text: modelData.preview; color: root.textMuted; font.pixelSize: 9; elide: Text.ElideRight }
                                }
                                Text { text: modelData.quality_label; color: root.textMuted; font.pixelSize: 8 }
                            }
                            MouseArea { id: paletteCommandMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { commandPalette.close(); backend.runCommandById(modelData.id) } }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: toast
        width: Math.min(390, Math.max(250, toastMessage.implicitWidth + 58))
        height: 52
        radius: 14
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 24
        anchors.bottomMargin: 24
        z: 200
        visible: opacity > 0
        opacity: root.toastText.length > 0 ? 1 : 0
        color: root.toastTone === "error" ? "#2A1820" : root.toastTone === "warning" ? "#2A2317" : root.toastTone === "success" ? "#15281F" : "#171D29"
        border.color: root.toastTone === "error" ? "#663040" : root.toastTone === "warning" ? "#665126" : root.toastTone === "success" ? "#2B5B42" : root.line
        Behavior on opacity { NumberAnimation { duration: 170 } }
        RowLayout { anchors.fill: parent; anchors.margins: 12; spacing: 9
            Text { text: root.toastTone === "error" ? "!" : root.toastTone === "warning" ? "•" : root.toastTone === "success" ? "✓" : "i"; color: root.toastTone === "error" ? "#FF8C99" : root.toastTone === "warning" ? "#FFD079" : root.toastTone === "success" ? "#62E39B" : root.accentSoft; font.bold: true }
            Text { id: toastMessage; Layout.fillWidth: true; text: root.toastText; color: root.textMain; font.pixelSize: 11; elide: Text.ElideRight }
        }
        Timer { id: toastTimer; interval: 3300; repeat: false; onTriggered: root.toastText = "" }
    }

    Connections {
        target: backend
        function onToastRequested(text, tone) {
            root.toastText = text
            root.toastTone = tone
            toastTimer.restart()
        }
        function onActionTestResult(index, success, message) {
            root.testedStepIndex = index
            root.testedStepState = success ? "success" : "error"
            root.testedStepMessage = message
        }
        function onScenarioTestProgress(current, total, message) {
            root.scenarioTestMessage = "Шаг " + current + " из " + total + ": " + message
        }
        function onScenarioTestFinished(success, message) {
            root.scenarioTestMessage = success ? message : "Проверка остановлена: " + message
        }
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
