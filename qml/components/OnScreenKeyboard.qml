pragma ComponentBehavior: Bound

import QtQuick

FocusScope {
    id: keyboard

    property bool numericMode: false
    property bool doneEnabled: false
    property string fieldLabel: numericMode ? "PAIRING CODE" : "SERVER ADDRESS"
    property color accentColor: "#ff781f"
    property color accentBrightColor: "#ff964f"
    property color textColor: "#f6f6f3"
    property color secondaryTextColor: "#aaafb4"

    signal textRequested(string text)
    signal backspaceRequested()
    signal clearRequested()
    signal nextRequested()
    signal doneRequested()

    readonly property var addressKeys: [
        "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
        "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
        "a", "s", "d", "f", "g", "h", "j", "k", "l", "-",
        "z", "x", "c", "v", "b", "n", "m", ".", ":", "/"
    ]
    readonly property var addressActions: [
        {label: "HTTP://", value: "http://"},
        {label: "HTTPS://", value: "https://"},
        {label: ".LOCAL", value: ".local"},
        {label: "CLEAR", action: "clear"},
        {label: "DELETE", action: "backspace"},
        {label: "NEXT", action: "next", primary: true}
    ]
    readonly property var numberKeys: [
        {label: "1", value: "1"}, {label: "2", value: "2"},
        {label: "3", value: "3"}, {label: "4", value: "4"},
        {label: "5", value: "5"}, {label: "6", value: "6"},
        {label: "7", value: "7"}, {label: "8", value: "8"},
        {label: "9", value: "9"}, {label: "CLEAR", action: "clear"},
        {label: "0", value: "0"}, {label: "DELETE", action: "backspace"}
    ]

    implicitWidth: 594
    implicitHeight: 472

    function dispatch(value, action) {
        if (action === "backspace")
            backspaceRequested()
        else if (action === "clear")
            clearRequested()
        else if (action === "next")
            nextRequested()
        else if (action === "done")
            doneRequested()
        else if (value !== undefined && value !== null)
            textRequested(String(value))
    }

    function focusFirstKey() {
        Qt.callLater(function() {
            var first = numericMode ? numberPad.itemAt(0) : addressGrid.itemAt(0)
            if (first)
                first.forceActiveFocus()
        })
    }

    component KeyboardKey: FocusScope {
        id: keyControl

        required property string keyLabel
        property string keyValue: ""
        property string keyAction: ""
        property bool primary: false

        activeFocusOnTab: true

        function activate() {
            if (!enabled)
                return
            keyControl.forceActiveFocus()
            keyboard.dispatch(keyValue, keyAction)
        }

        Keys.onReturnPressed: event => { activate(); event.accepted = true }
        Keys.onEnterPressed: event => { activate(); event.accepted = true }
        Keys.onSpacePressed: event => { activate(); event.accepted = true }

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: !keyControl.enabled ? "#181a1e"
                   : keyControl.primary
                     ? (keyControl.activeFocus || pointer.containsMouse
                        ? keyboard.accentBrightColor : keyboard.accentColor)
                     : (keyControl.activeFocus || pointer.containsMouse
                        ? "#3a3f45" : "#292d32")
            border.width: keyControl.activeFocus ? 3 : 1
            border.color: keyControl.activeFocus ? keyboard.accentBrightColor
                                                 : (keyControl.primary ? "#ffab72" : "#494f56")

            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: parent.radius + 4
                color: "transparent"
                border.width: keyControl.activeFocus ? 2 : 0
                border.color: "#66ff7a1a"
            }
        }

        Text {
            anchors.centerIn: parent
            width: Math.max(0, parent.width - 12)
            horizontalAlignment: Text.AlignHCenter
            text: keyControl.keyLabel
            color: !keyControl.enabled ? "#666b70"
                   : keyControl.primary ? "#17100b" : keyboard.textColor
            font.pixelSize: keyControl.keyLabel.length > 5 ? 12 : 17
            font.weight: Font.Bold
            font.letterSpacing: keyControl.keyLabel.length === 1 ? 0.5 : 0.1
            elide: Text.ElideRight
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            enabled: keyControl.enabled
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: keyControl.activate()
        }
    }

    Column {
        anchors.fill: parent
        spacing: 14

        Column {
            width: parent.width
            spacing: 4

            Text {
                text: keyboard.fieldLabel
                color: keyboard.accentBrightColor
                font.pixelSize: 12
                font.weight: Font.Bold
                font.letterSpacing: 1.5
            }

            Text {
                text: keyboard.numericMode
                      ? "Enter the six-digit code shown by Tater Tube Server."
                      : "Type with the keyboard, or choose each key with the controls."
                color: keyboard.secondaryTextColor
                font.pixelSize: 13
            }
        }

        Item {
            width: parent.width
            height: 352

            Column {
                id: addressLayout
                anchors.fill: parent
                visible: !keyboard.numericMode
                spacing: 10

                Grid {
                    id: addressGridLayout
                    width: parent.width
                    columns: 10
                    columnSpacing: 7
                    rowSpacing: 8

                    Repeater {
                        id: addressGrid
                        model: keyboard.addressKeys

                        KeyboardKey {
                            required property string modelData
                            width: (addressGridLayout.width - 9 * addressGridLayout.columnSpacing) / 10
                            height: 55
                            keyLabel: modelData.toUpperCase()
                            keyValue: modelData
                        }
                    }
                }

                Grid {
                    id: addressActionLayout
                    width: parent.width
                    columns: 6
                    columnSpacing: 7

                    Repeater {
                        model: keyboard.addressActions

                        KeyboardKey {
                            required property var modelData
                            width: (addressActionLayout.width - 5 * addressActionLayout.columnSpacing) / 6
                            height: 58
                            keyLabel: String(modelData.label || "")
                            keyValue: String(modelData.value || "")
                            keyAction: String(modelData.action || "")
                            primary: modelData.primary === true
                        }
                    }
                }
            }

            Column {
                id: numberLayout
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                visible: keyboard.numericMode
                width: Math.min(390, parent.width)
                spacing: 12

                Grid {
                    id: numberPadLayout
                    width: parent.width
                    columns: 3
                    columnSpacing: 12
                    rowSpacing: 10

                    Repeater {
                        id: numberPad
                        model: keyboard.numberKeys

                        KeyboardKey {
                            required property var modelData
                            width: (numberPadLayout.width - 2 * numberPadLayout.columnSpacing) / 3
                            height: 62
                            keyLabel: String(modelData.label || "")
                            keyValue: String(modelData.value || "")
                            keyAction: String(modelData.action || "")
                        }
                    }
                }

                KeyboardKey {
                    width: parent.width
                    height: 58
                    keyLabel: "PAIR THIS SCREEN"
                    keyAction: "done"
                    primary: true
                    enabled: keyboard.doneEnabled
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ARROWS / WASD  MOVE    •    ENTER / A  SELECT    •    BACK / B  RETURN"
            color: "#777d83"
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 0.35
        }
    }
}
