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
    property color stateColor: "#7C5CFF"
    property string stateLabel: "Готова к работе"
    property bool motionEnabled: true
    property real animationStrength: 1.0
    property real microphoneVisualLevel: 0.0

    signal createCommandRequested()
    signal openPaletteRequested()
    signal openCommandRequested(var command)
    signal runCommandRequested(string commandId)

    ColumnLayout {
        anchors.fill: parent
        spacing: 18

        SectionCard {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 390
            panelColor: page.panel
            borderColor: page.line

            RowLayout {
                anchors.fill: parent
                anchors.margins: 30
                spacing: 28

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumWidth: 330
                    spacing: 14

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.preferredWidth: stateRow.implicitWidth + 24
                        Layout.preferredHeight: 34
                        radius: 11
                        color: Qt.rgba(page.stateColor.r, page.stateColor.g, page.stateColor.b, 0.12)
                        border.color: Qt.rgba(page.stateColor.r, page.stateColor.g, page.stateColor.b, 0.36)
                        RowLayout {
                            id: stateRow
                            anchors.centerIn: parent
                            spacing: 8
                            Rectangle { width: 7; height: 7; radius: 4; color: page.stateColor }
                            Text { text: page.stateLabel; color: page.textMain; font.pixelSize: 11; font.weight: Font.DemiBold }
                        }
                    }

                    Text {
                        Layout.fillWidth: true
                        text: page.backendRef && page.backendRef.transcript.length
                              ? "«" + page.backendRef.transcript + "»"
                              : "Просто скажите «Аура»\nи назовите команду"
                        color: page.textMain
                        font.pixelSize: 30
                        font.weight: Font.DemiBold
                        lineHeight: 1.12
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 460
                        text: page.backendRef && page.backendRef.transcript.length
                              ? page.backendRef.status
                              : "AURA слушает локальную фразу активации и выполняет сохранённые сценарии."
                        color: page.textMuted
                        font.pixelSize: 13
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        spacing: 10
                        Button {
                            id: createButton
                            text: "+  Создать команду"
                            implicitHeight: 44
                            leftPadding: 19
                            rightPadding: 19
                            onClicked: page.createCommandRequested()
                            contentItem: Text {
                                text: createButton.text
                                color: "white"
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 14
                                gradient: Gradient {
                                    GradientStop { position: 0; color: createButton.down ? "#694FE0" : "#8B6CFF" }
                                    GradientStop { position: 1; color: createButton.down ? "#5034C7" : "#6948F2" }
                                }
                            }
                        }
                        Button {
                            id: paletteButton
                            text: "Найти команду"
                            implicitHeight: 44
                            leftPadding: 18
                            rightPadding: 18
                            onClicked: page.openPaletteRequested()
                            contentItem: Text {
                                text: paletteButton.text
                                color: page.textMain
                                font.pixelSize: 13
                                font.weight: Font.DemiBold
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                            }
                            background: Rectangle {
                                radius: 14
                                color: paletteButton.hovered ? "#202635" : "#191F2B"
                                border.color: paletteButton.hovered ? "#3A4458" : page.line
                            }
                        }
                    }

                    Text {
                        text: "Ctrl + K  быстрый запуск"
                        color: "#626C7E"
                        font.pixelSize: 10
                        font.family: "Consolas"
                    }

                    Item { Layout.fillHeight: true }
                }

                Item {
                    id: orbStage
                    Layout.preferredWidth: 330
                    Layout.fillHeight: true
                    Layout.minimumHeight: 330
                    property real breathScale: 1.0
                    property real eventScale: 1.0
                    property color eventColor: page.stateColor
                    property real voiceLevel: page.backendRef && page.backendRef.listening ? Math.max(page.microphoneVisualLevel, 0.06) : 0.0
                    scale: breathScale * eventScale

                    function prepareEvent(colorValue) {
                        eventColor = colorValue
                        eventRing.opacity = 0
                        eventRing.scale = 0.84
                        flashOverlay.opacity = 0
                        eventScale = 1
                        orbTranslate.x = 0
                    }

                    function playEvent(eventName) {
                        if (eventName === "wake") {
                            prepareEvent("#76C8FF")
                            page.motionEnabled ? wakeAnimation.restart() : reducedEventAnimation.restart()
                        } else if (eventName === "success") {
                            prepareEvent("#43D17C")
                            page.motionEnabled ? successAnimation.restart() : reducedEventAnimation.restart()
                        } else if (eventName === "error") {
                            prepareEvent("#FF6B72")
                            page.motionEnabled ? errorAnimation.restart() : reducedEventAnimation.restart()
                        } else if (eventName === "step") {
                            prepareEvent(page.accentSoft)
                            page.motionEnabled ? stepAnimation.restart() : reducedEventAnimation.restart()
                        }
                    }

                    transform: Translate { id: orbTranslate; x: 0 }

                    SequentialAnimation on breathScale {
                        running: page.motionEnabled && page.backendRef && !page.backendRef.listening && !page.backendRef.busy && !page.backendRef.recording && !page.backendRef.voiceSpeaking
                        loops: Animation.Infinite
                        NumberAnimation { to: 1.0 + 0.025 * page.animationStrength; duration: 1750; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 1750; easing.type: Easing.InOutSine }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 286; height: 286; radius: 143
                        color: page.stateColor
                        opacity: page.backendRef && (page.backendRef.listening || page.backendRef.busy) ? 0.07 + orbStage.voiceLevel * 0.08 : 0.035
                        scale: 1 + orbStage.voiceLevel * 0.08 * page.animationStrength
                        Behavior on opacity { NumberAnimation { duration: 240 } }
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
                        scale: 0.84
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: 244; height: 244; radius: 122
                        color: "transparent"
                        border.width: page.backendRef && (page.backendRef.listening || page.backendRef.busy) ? 2 : 1
                        border.color: page.stateColor
                        opacity: page.backendRef && (page.backendRef.listening || page.backendRef.busy || page.backendRef.recording) ? 0.78 : 0.4
                        scale: 1 + orbStage.voiceLevel * 0.055 * page.animationStrength
                        Behavior on border.color { ColorAnimation { duration: 220 } }
                        Behavior on scale { NumberAnimation { duration: 110; easing.type: Easing.OutCubic } }
                    }

                    Item {
                        id: orbitSystem
                        anchors.centerIn: parent
                        width: 226; height: 226
                        visible: page.backendRef && (page.backendRef.busy || page.backendRef.voiceSpeaking || (page.backendRef.listening && page.backendRef.status.toLowerCase().indexOf("распозна") >= 0))
                        opacity: visible ? 0.95 : 0
                        Behavior on opacity { NumberAnimation { duration: 180 } }
                        RotationAnimation on rotation {
                            running: page.motionEnabled && orbitSystem.visible
                            from: 0; to: 360; loops: Animation.Infinite
                            duration: page.backendRef && page.backendRef.busy ? 1250 : 980
                        }
                        Repeater {
                            model: 3
                            Rectangle {
                                required property int index
                                width: index === 0 ? 9 : 6
                                height: width
                                radius: width / 2
                                color: index === 0 ? "#C8BFFF" : "#7CBFFF"
                                x: parent.width / 2 - width / 2 + Math.cos(index * 2.094) * 105
                                y: parent.height / 2 - height / 2 + Math.sin(index * 2.094) * 105
                            }
                        }
                    }

                    Rectangle {
                        id: orb
                        anchors.centerIn: parent
                        width: 190; height: 190; radius: 95
                        scale: 1 + orbStage.voiceLevel * 0.035 * page.animationStrength
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: page.backendRef && page.backendRef.listening ? "#8ED7FF" : "#B7AAFF" }
                            GradientStop { position: 0.45; color: page.stateColor }
                            GradientStop { position: 1.0; color: "#36266F" }
                        }
                        border.width: 1
                        border.color: "#40FFFFFF"
                        Behavior on scale { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 220 } }

                        Rectangle {
                            width: 78; height: 42; radius: 22
                            x: 35; y: 24
                            rotation: -18
                            color: "#30FFFFFF"
                        }

                        Repeater {
                            model: 9
                            Rectangle {
                                required property int index
                                property real shapeFactor: 0.48 + ((index * 7) % 6) * 0.095
                                property real activeLevel: page.backendRef && page.backendRef.listening ? Math.max(orbStage.voiceLevel, 0.14) : page.backendRef && page.backendRef.voiceSpeaking ? 0.22 : 0.06
                                anchors.verticalCenter: parent.verticalCenter
                                width: 3.5
                                radius: 2
                                height: 7 + activeLevel * (22 + shapeFactor * 30) * page.animationStrength
                                x: orb.width / 2 - width / 2 + (index - 4) * 11
                                color: "white"
                                opacity: page.backendRef && (page.backendRef.listening || page.backendRef.voiceSpeaking) ? 0.92 : 0.64
                                Behavior on height { NumberAnimation { duration: 95; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    Rectangle {
                        id: flashOverlay
                        anchors.centerIn: parent
                        width: 190; height: 190; radius: 95
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
                            NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.2; duration: 90 }
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
                            NumberAnimation { target: orbTranslate; property: "x"; to: -6; duration: 55 }
                            NumberAnimation { target: orbTranslate; property: "x"; to: 6; duration: 80 }
                            NumberAnimation { target: orbTranslate; property: "x"; to: -4; duration: 70 }
                            NumberAnimation { target: orbTranslate; property: "x"; to: 0; duration: 80 }
                        }
                        SequentialAnimation {
                            NumberAnimation { target: flashOverlay; property: "opacity"; to: 0.18; duration: 70 }
                            NumberAnimation { target: flashOverlay; property: "opacity"; to: 0; duration: 330 }
                        }
                    }

                    Connections {
                        target: page.backendRef
                        function onOrbVisualEvent(eventName) { orbStage.playEvent(eventName) }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 152
            spacing: 18

            SectionCard {
                Layout.fillWidth: true
                Layout.fillHeight: true
                panelColor: page.panel
                borderColor: page.line
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 18
                    spacing: 9
                    Text { text: "Последнее действие"; color: page.textMuted; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
                    Item { Layout.fillHeight: true }
                    Text {
                        Layout.fillWidth: true
                        text: page.backendRef && page.backendRef.history.length ? page.backendRef.history[0].phrase : "История пока пуста"
                        color: page.textMain
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Rectangle {
                            width: 7; height: 7; radius: 4
                            color: page.backendRef && page.backendRef.history.length && page.backendRef.history[0].tone === "error" ? "#FF6B7A" : "#43D17C"
                        }
                        Text {
                            Layout.fillWidth: true
                            text: page.backendRef && page.backendRef.history.length ? page.backendRef.history[0].result : "После выполнения здесь появится результат"
                            color: page.textMuted
                            font.pixelSize: 11
                            elide: Text.ElideRight
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
                    anchors.margins: 18
                    spacing: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: "Быстрый доступ"; color: page.textMuted; font.pixelSize: 10; font.bold: true; font.letterSpacing: 0.8 }
                        Text { text: page.backendRef ? page.backendRef.commands.length + " команд" : ""; color: "#626C7E"; font.pixelSize: 9 }
                    }
                    Repeater {
                        model: page.backendRef ? Math.min(3, page.backendRef.commands.length) : 0
                        delegate: Rectangle {
                            required property int index
                            Layout.fillWidth: true
                            Layout.preferredHeight: 30
                            radius: 9
                            color: quickMouse.containsMouse ? "#1B2230" : "transparent"
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; color: page.accent }
                                Text { Layout.fillWidth: true; text: page.backendRef.commands[index].name; color: page.textMain; font.pixelSize: 11; elide: Text.ElideRight }
                                Text { text: "Запустить"; color: page.accentSoft; font.pixelSize: 9 }
                            }
                            MouseArea {
                                id: quickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.runCommandRequested(page.backendRef.commands[index].id)
                            }
                        }
                    }
                    Item { Layout.fillHeight: true }
                }
            }
        }
    }
}
