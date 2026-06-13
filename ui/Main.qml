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
    property string commandSearch: ""
    property int testedStepIndex: -1
    property string testedStepState: ""
    property string testedStepMessage: ""
    property string scenarioTestMessage: ""
    property color assistantStateColor: backend.recording ? "#FF9A62" : backend.listening ? "#65B8FF" : backend.busy ? "#8A6BFF" : backend.voiceSpeaking ? "#43D17C" : backend.wakeListening ? root.accent : "#536071"
    property string assistantStateLabel: backend.recording ? "Запись действий" : backend.listening ? "Микрофон активен" : backend.busy ? "Выполняю действие" : backend.voiceSpeaking ? "Отвечаю" : backend.wakeListening ? "Жду фразу «Аура»" : "Готов к работе"
    property bool orbRecognizing: backend.listening && backend.status.toLowerCase().indexOf("распозна") >= 0
    property real animationStrength: backend.animationIntensity === "low" ? 0.58 : backend.animationIntensity === "high" ? 1.28 : 1.0
    property real microphoneVisualLevel: backend.microphoneReactiveAnimation ? backend.audioLevel / 100.0 : 0.0
    property bool motionEnabled: !backend.reduceMotion

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

                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "МОИ КОМАНДЫ"
                        color: "#626C7E"
                        font.pixelSize: 10
                        font.bold: true
                        font.letterSpacing: 1.2
                        topPadding: 8
                    }
                    Text {
                        text: backend.commands.length
                        color: root.textMuted
                        font.pixelSize: 10
                    }
                }

                AppTextField {
                    id: commandSearchField
                    Layout.fillWidth: true
                    Layout.preferredHeight: 38
                    placeholderText: "Поиск команд"
                    onTextChanged: root.commandSearch = text.trim().toLowerCase()
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
                                property bool matchesSearch: root.commandSearch.length === 0
                                    || String(modelData.name).toLowerCase().indexOf(root.commandSearch) >= 0
                                    || String(modelData.phrases_text).toLowerCase().indexOf(root.commandSearch) >= 0
                                    || String(modelData.preview).toLowerCase().indexOf(root.commandSearch) >= 0
                                width: commandColumn.width
                                height: matchesSearch ? 54 : 0
                                visible: matchesSearch
                                radius: 12
                                color: commandMouse.containsMouse ? "#171D29" : "transparent"
                                opacity: modelData.enabled ? 1 : 0.45
                                Behavior on color { ColorAnimation { duration: 120 } }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 11
                                    anchors.rightMargin: 8
                                    spacing: 9
                                    Rectangle {
                                        width: 7; height: 7; radius: 4
                                        color: modelData.enabled ? root.accent : "#4F5867"
                                    }
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.name
                                            color: root.textMain
                                            font.pixelSize: 13
                                            font.weight: Font.DemiBold
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            text: modelData.preview || (modelData.steps_count + " действий")
                                            color: root.textMuted
                                            font.pixelSize: 9
                                            elide: Text.ElideRight
                                        }
                                    }
                                    Text { text: "›"; color: "#697386"; font.pixelSize: 18 }
                                }
                                MouseArea {
                                    id: commandMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
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

                SoftButton {
                    Layout.fillWidth: true
                    text: "⚙  Настройки"
                    onClicked: {
                        backend.refreshMicrophones()
                        settingsDialog.open()
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: root.line }

                RowLayout {
                    Layout.fillWidth: true
                    Rectangle {
                        width: 9; height: 9; radius: 5
                        color: root.assistantStateColor
                        SequentialAnimation on opacity {
                            running: backend.listening || backend.recording
                            loops: Animation.Infinite
                            NumberAnimation { to: 0.25; duration: 550 }
                            NumberAnimation { to: 1; duration: 550 }
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: root.assistantStateLabel
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
                                id: orbStage
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                Layout.minimumHeight: 300

                                property real breathScale: 1.0
                                property real eventScale: 1.0
                                property color eventColor: root.assistantStateColor
                                property real voiceLevel: backend.listening ? Math.max(root.microphoneVisualLevel, 0.06) : 0.0

                                function prepareEvent(colorValue) {
                                    eventColor = colorValue
                                    eventRing.opacity = 0
                                    eventRing.scale = 0.86
                                    flashOverlay.opacity = 0
                                    eventScale = 1
                                    orbShake.x = 0
                                }

                                function playEvent(eventName) {
                                    if (eventName === "wake") {
                                        prepareEvent("#76C8FF")
                                        root.motionEnabled ? wakeAnimation.restart() : reducedEventAnimation.restart()
                                    } else if (eventName === "success") {
                                        prepareEvent("#43D17C")
                                        root.motionEnabled ? successAnimation.restart() : reducedEventAnimation.restart()
                                    } else if (eventName === "error") {
                                        prepareEvent("#FF6B72")
                                        root.motionEnabled ? errorAnimation.restart() : reducedEventAnimation.restart()
                                    } else if (eventName === "step") {
                                        prepareEvent(root.accentSoft)
                                        root.motionEnabled ? stepAnimation.restart() : reducedEventAnimation.restart()
                                    }
                                }

                                transform: Translate { id: orbShake; x: 0 }
                                scale: breathScale * eventScale

                                SequentialAnimation on breathScale {
                                    running: root.motionEnabled && !backend.listening && !backend.busy && !backend.recording && !backend.voiceSpeaking
                                    loops: Animation.Infinite
                                    NumberAnimation { to: 1.0 + 0.026 * root.animationStrength; duration: 1750; easing.type: Easing.InOutSine }
                                    NumberAnimation { to: 1.0; duration: 1750; easing.type: Easing.InOutSine }
                                }

                                Rectangle {
                                    id: ambientGlow
                                    anchors.centerIn: parent
                                    width: 278; height: 278; radius: 139
                                    color: root.assistantStateColor
                                    opacity: backend.listening || backend.busy ? 0.055 + orbStage.voiceLevel * 0.07 : 0.035
                                    scale: 1 + orbStage.voiceLevel * 0.08 * root.animationStrength
                                    Behavior on opacity { NumberAnimation { duration: 260 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                                }

                                Rectangle {
                                    id: eventRing
                                    anchors.centerIn: parent
                                    width: 224; height: 224; radius: 112
                                    color: "transparent"
                                    border.width: 2
                                    border.color: orbStage.eventColor
                                    opacity: 0
                                    scale: 0.86
                                }

                                Rectangle {
                                    id: outerRing
                                    anchors.centerIn: parent
                                    width: 242; height: 242; radius: 121
                                    color: "transparent"
                                    border.width: backend.listening || backend.busy ? 2 : 1
                                    border.color: root.assistantStateColor
                                    opacity: backend.listening || backend.busy || backend.recording ? 0.78 : 0.42
                                    scale: 1 + orbStage.voiceLevel * 0.055 * root.animationStrength
                                    Behavior on border.color { ColorAnimation { duration: 220 } }
                                    Behavior on opacity { NumberAnimation { duration: 220 } }
                                    Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                                }

                                Item {
                                    id: orbitSystem
                                    anchors.centerIn: parent
                                    width: 226; height: 226
                                    visible: backend.busy || root.orbRecognizing || backend.voiceSpeaking
                                    opacity: visible ? 0.95 : 0
                                    Behavior on opacity { NumberAnimation { duration: 180 } }

                                    RotationAnimation on rotation {
                                        running: root.motionEnabled && orbitSystem.visible
                                        from: 0
                                        to: 360
                                        loops: Animation.Infinite
                                        duration: backend.busy ? 1250 : root.orbRecognizing ? 950 : 1800
                                    }

                                    Repeater {
                                        model: 3
                                        Rectangle {
                                            required property int index
                                            property real angle: index * Math.PI * 2 / 3
                                            width: index === 0 ? 9 : 7
                                            height: width
                                            radius: width / 2
                                            x: orbitSystem.width / 2 - width / 2 + Math.cos(angle) * 105
                                            y: orbitSystem.height / 2 - height / 2 + Math.sin(angle) * 105
                                            color: index === 0 ? "#E9E3FF" : root.assistantStateColor
                                            opacity: index === 0 ? 1 : 0.68
                                        }
                                    }
                                }

                                Rectangle {
                                    id: shell
                                    anchors.centerIn: parent
                                    width: 198; height: 198; radius: 99
                                    color: "#111725"
                                    border.width: 1
                                    border.color: Qt.lighter(root.assistantStateColor, 1.08)
                                    scale: 1 + orbStage.voiceLevel * 0.032 * root.animationStrength
                                    Behavior on border.color { ColorAnimation { duration: 220 } }
                                    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 9
                                        radius: width / 2
                                        color: "transparent"
                                        border.width: 1
                                        border.color: "#22FFFFFF"
                                    }
                                }

                                Rectangle {
                                    id: orb
                                    anchors.centerIn: parent
                                    width: 156; height: 156; radius: 78
                                    gradient: Gradient {
                                        GradientStop {
                                            position: 0.0
                                            color: backend.recording ? "#FFC091" : backend.voiceSpeaking ? "#86E8AB" : backend.listening ? "#B8D7FF" : backend.busy ? "#B6A7FF" : "#9582F2"
                                        }
                                        GradientStop {
                                            position: 0.43
                                            color: backend.recording ? "#EE7045" : backend.voiceSpeaking ? "#39B976" : backend.listening ? "#725CFF" : backend.busy ? "#704CF1" : "#5940CB"
                                        }
                                        GradientStop {
                                            position: 1.0
                                            color: backend.recording ? "#5B1D1A" : backend.voiceSpeaking ? "#123E31" : backend.listening ? "#24165B" : "#211643"
                                        }
                                    }
                                    scale: 1 + orbStage.voiceLevel * 0.095 * root.animationStrength
                                    Behavior on scale { NumberAnimation { duration: 105; easing.type: Easing.OutCubic } }

                                    Rectangle {
                                        width: 92; height: 52; radius: 26
                                        x: 20; y: 13
                                        rotation: -16
                                        color: "#FFFFFF"
                                        opacity: 0.075
                                    }

                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 126; height: 126; radius: 63
                                        color: "transparent"
                                        border.width: 1
                                        border.color: "#28FFFFFF"
                                    }

                                    Repeater {
                                        model: 9
                                        Rectangle {
                                            required property int index
                                            property real shapeFactor: 0.48 + ((index * 7) % 6) * 0.095
                                            property real activeLevel: backend.listening ? Math.max(orbStage.voiceLevel, 0.14) : backend.voiceSpeaking ? 0.22 : 0.06
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 3.5
                                            radius: 2
                                            height: 7 + activeLevel * (22 + shapeFactor * 30) * root.animationStrength
                                            x: orb.width / 2 - width / 2 + (index - 4) * 11
                                            color: "white"
                                            opacity: backend.listening || backend.voiceSpeaking ? 0.92 : 0.64
                                            Behavior on height { NumberAnimation { duration: 95; easing.type: Easing.OutCubic } }

                                            SequentialAnimation on scale {
                                                running: root.motionEnabled && backend.listening && root.microphoneVisualLevel < 0.04
                                                loops: Animation.Infinite
                                                PauseAnimation { duration: index * 34 }
                                                NumberAnimation { to: 1.35; duration: 170; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 0.72; duration: 210; easing.type: Easing.InOutSine }
                                                NumberAnimation { to: 1.0; duration: 180; easing.type: Easing.InOutSine }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    id: flashOverlay
                                    anchors.centerIn: parent
                                    width: 164; height: 164; radius: 82
                                    color: orbStage.eventColor
                                    opacity: 0
                                }

                                ParallelAnimation {
                                    id: wakeAnimation
                                    SequentialAnimation {
                                        NumberAnimation { target: orbStage; property: "eventScale"; to: 0.95; duration: 90; easing.type: Easing.OutCubic }
                                        NumberAnimation { target: orbStage; property: "eventScale"; to: 1.045; duration: 145; easing.type: Easing.OutBack }
                                        NumberAnimation { target: orbStage; property: "eventScale"; to: 1.0; duration: 180; easing.type: Easing.OutCubic }
                                    }
                                    SequentialAnimation {
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0.92; duration: 80 }
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0; duration: 360 }
                                    }
                                    NumberAnimation { target: eventRing; property: "scale"; to: 1.34; duration: 440; easing.type: Easing.OutCubic }
                                }

                                ParallelAnimation {
                                    id: successAnimation
                                    SequentialAnimation {
                                        NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.22; duration: 90 }
                                        NumberAnimation { target: flashOverlay; property: "opacity"; to: 0; duration: 420 }
                                    }
                                    SequentialAnimation {
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0.9; duration: 80 }
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0; duration: 480 }
                                    }
                                    NumberAnimation { target: eventRing; property: "scale"; to: 1.45; duration: 560; easing.type: Easing.OutCubic }
                                }

                                ParallelAnimation {
                                    id: stepAnimation
                                    SequentialAnimation {
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0.58; duration: 55 }
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0; duration: 230 }
                                    }
                                    NumberAnimation { target: eventRing; property: "scale"; to: 1.18; duration: 285; easing.type: Easing.OutCubic }
                                }

                                SequentialAnimation {
                                    id: reducedEventAnimation
                                    NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.17; duration: 70 }
                                    NumberAnimation { target: flashOverlay; property: "opacity"; to: 0; duration: 250 }
                                }

                                ParallelAnimation {
                                    id: errorAnimation
                                    SequentialAnimation {
                                        NumberAnimation { target: orbShake; property: "x"; to: -6; duration: 55 }
                                        NumberAnimation { target: orbShake; property: "x"; to: 6; duration: 80 }
                                        NumberAnimation { target: orbShake; property: "x"; to: -4; duration: 70 }
                                        NumberAnimation { target: orbShake; property: "x"; to: 0; duration: 80 }
                                    }
                                    SequentialAnimation {
                                        NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.19; duration: 70 }
                                        NumberAnimation { target: flashOverlay; property: "opacity"; to: 0; duration: 330 }
                                    }
                                    SequentialAnimation {
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0.82; duration: 70 }
                                        NumberAnimation { target: eventRing; property: "opacity"; to: 0; duration: 330 }
                                    }
                                    NumberAnimation { target: eventRing; property: "scale"; to: 1.25; duration: 400; easing.type: Easing.OutCubic }
                                }

                                Connections {
                                    target: backend
                                    function onOrbVisualEvent(eventName) {
                                        orbStage.playEvent(eventName)
                                    }
                                }
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: root.orbRecognizing ? "Распознаю…" : backend.listening ? "Говорите…" : backend.busy ? "Выполняю…" : backend.status
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
                                            height: 62
                                            radius: 12
                                            color: historyMouse.containsMouse ? "#181E2A" : "#151A25"
                                            border.color: historyMouse.containsMouse ? "#30394A" : "transparent"
                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 11
                                                anchors.rightMargin: 11
                                                spacing: 9
                                                Rectangle {
                                                    width: 7
                                                    height: 7
                                                    radius: 4
                                                    color: modelData.tone === "error" ? "#FF6B7A" : modelData.tone === "warning" ? "#FFB45E" : "#43D17C"
                                                }
                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 3
                                                    Text { Layout.fillWidth: true; text: modelData.phrase; color: root.textMain; font.pixelSize: 11; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                                    Text { Layout.fillWidth: true; text: modelData.result; color: root.textMuted; font.pixelSize: 10; elide: Text.ElideRight }
                                                }
                                                Text { text: modelData.time || ""; color: "#626C7E"; font.pixelSize: 9; Layout.alignment: Qt.AlignTop }
                                            }
                                            MouseArea { id: historyMouse; anchors.fill: parent; hoverEnabled: true }
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
        width: Math.min(700, root.width - 48)
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

        function addAction(type, value, delayAfter, enabled) {
            actionModel.append({
                "action_type": type || "open_url",
                "value": value || "",
                "delay_after": Number(delayAfter || 0),
                // The editor uses a dedicated role name because `enabled`
                // collides with Item.enabled inside a QML delegate.
                "step_enabled": enabled === undefined ? true : Boolean(enabled)
            })
        }

        function collectActions() {
            var actions = []
            for (var i = 0; i < actionModel.count; ++i) {
                var item = actionModel.get(i)
                actions.push({
                    "action_type": item.action_type,
                    "value": item.value,
                    "delay_after": Number(item.delay_after || 0),
                    "enabled": Boolean(item.step_enabled)
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
                "step_enabled": Boolean(item.step_enabled)
            })
        }

        function moveAction(from, to) {
            if (from < 0 || to < 0 || from >= actionModel.count || to >= actionModel.count || from === to)
                return
            actionModel.move(from, to, 1)
            root.testedStepIndex = -1
            root.testedStepState = ""
            root.testedStepMessage = ""
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
                    addAction(recordedStep.action_type, recordedStep.value, recordedStep.delay_after, recordedStep.enabled)
                }
            } else if (command && command.actions && command.actions.length > 0) {
                for (var i = 0; i < command.actions.length; ++i) {
                    var step = command.actions[i]
                    addAction(step.action_type, step.value, step.delay_after, step.enabled)
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
        }

        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: 26
            spacing: 11

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 48

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    Text { text: root.editingCommand ? "Редактировать команду" : "Новая команда"; color: root.textMain; font.pixelSize: 21; font.bold: true }
                    Text { text: "Программирование не требуется"; color: root.textMuted; font.pixelSize: 12; topPadding: 3 }
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
                    required property bool step_enabled
                    readonly property bool stepEnabled: step_enabled
                    property bool testSelected: root.testedStepIndex === actionCard.index
                    width: actionsList.width - (actionsList.ScrollBar.vertical.visible ? 12 : 0)
                    height: 154
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
                                }
                                indicator: Rectangle {
                                    implicitWidth: 18
                                    implicitHeight: 18
                                    radius: 6
                                    color: stepEnabledCheck.checked ? root.accent : "#0D111A"
                                    border.color: stepEnabledCheck.checked ? root.accent : root.line
                                    Text { anchors.centerIn: parent; visible: stepEnabledCheck.checked; text: "✓"; color: "white"; font.pixelSize: 11; font.bold: true }
                                }
                                contentItem: Text { leftPadding: 25; text: stepEnabledCheck.text; color: root.textMuted; font.pixelSize: 10; verticalAlignment: Text.AlignVCenter }
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
                                implicitWidth: 30
                                implicitHeight: 26
                                enabled: actionCard.index > 0
                                text: "↑"
                                ToolTip.visible: hovered
                                ToolTip.text: "Переместить выше"
                                onClicked: editor.moveAction(actionCard.index, actionCard.index - 1)
                                background: Rectangle { color: moveUpButton.hovered ? "#222A39" : "transparent"; radius: 8 }
                                contentItem: Text { text: moveUpButton.text; color: moveUpButton.enabled ? root.textMuted : "#424A58"; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                            }
                            ToolButton {
                                id: moveDownButton
                                implicitWidth: 30
                                implicitHeight: 26
                                enabled: actionCard.index < actionModel.count - 1
                                text: "↓"
                                ToolTip.visible: hovered
                                ToolTip.text: "Переместить ниже"
                                onClicked: editor.moveAction(actionCard.index, actionCard.index + 1)
                                background: Rectangle { color: moveDownButton.hovered ? "#222A39" : "transparent"; radius: 8 }
                                contentItem: Text { text: moveDownButton.text; color: moveDownButton.enabled ? root.textMuted : "#424A58"; font.pixelSize: 15; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
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

            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: root.line }

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
                SoftButton {
                    Layout.preferredHeight: 42
                    Layout.minimumWidth: 118
                    Layout.alignment: Qt.AlignVCenter
                    enabled: !backend.testingScenario && backend.testingActionIndex < 0
                    text: backend.testingScenario ? "Проверяю…" : "▶  Проверить всё"
                    onClicked: {
                        root.scenarioTestMessage = "Запускаю проверку сценария…"
                        backend.testScenario(editor.collectActionsJson())
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
                        var saved = backend.saveCommand(
                            root.editingCommand ? root.editingCommand.id : "",
                            nameField.text,
                            phrasesField.text,
                            editor.collectActionsJson(),
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

    Connections {
        target: backend
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
