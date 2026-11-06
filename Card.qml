
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

Item {
    id: root

    required property var modelData
    required property int index

    readonly property var theme: Config.theme
    readonly property bool active: index < Config.maxVisible
    readonly property bool hovered: hover.hovered
    readonly property color urgencyColor: rule.accent || theme[Config.urgencyName(urgency)]
    readonly property bool hasActions: actionList.some(action => action.identifier !== "default")

    
    readonly property bool md: Config.md
    readonly property bool critical: Config.urgencyName(urgency) === "critical"
    readonly property bool tonal: md && critical          
    readonly property color cardColor: tonal ? theme.critical_container : theme.background
    readonly property color fgColor: tonal ? theme.on_critical_container : theme.foreground
    readonly property color bodyColor: tonal ? theme.on_critical_container : theme.body
    readonly property color subColor: tonal ? theme.on_critical_container : theme.subtext

    property string summary: ""
    property string body: ""
    property string appName: ""
    property string iconSource: ""
    property bool iconFull: false          
    property int urgency: 1
    property int timeout: 0
    property var rule: ({})
    property var actionList: []
    property real life: 1

    property bool removing: false
    property bool initialized: false
    property real collapse: 1

    
    property real iconIn: md ? 0 : 1
    property real swap: 0

    width: ListView.view ? ListView.view.width : Config.width
    height: active ? (card.height + Config.spacing) * collapse : 0
    visible: active

    Component.onCompleted: sync()

    function sync(): void {
        const n = modelData

        if (!n)
            return

        const list = []
        const source = n.actions || []

        for (let i = 0; i < source.length; i++) {
            list.push({
                identifier: source[i].identifier,
                text: source[i].text
            })
        }

        summary = n.summary || ""
        body = n.body || ""
        appName = n.appName || ""
        urgency = n.urgency
        rule = Config.ruleFor(n)
        timeout = Config.timeoutMs(n, rule)
        iconSource = resolveIcon(n)
        iconFull = Config.showIcons && n.image !== ""
        actionList = list
        removing = false
    }

    function resolveIcon(n: var): string {
        if (!Config.showIcons)
            return ""

        if (n.image !== "")
            return n.image

        const icon = n.appIcon

        if (!icon)
            return ""

        if (icon.indexOf("/") === 0)
            return "file://" + icon

        if (icon.indexOf("file://") === 0 || icon.indexOf("image://") === 0)
            return icon

        return Quickshell.iconPath(icon, true)
    }

    function dismiss(): void {
        if (modelData)
            modelData.dismiss()
    }

    function invokeAction(identifier: string): bool {
        if (!modelData)
            return false

        const list = modelData.actions

        for (let i = 0; i < list.length; i++) {
            if (list[i].identifier === identifier) {
                list[i].invoke()
                return true
            }
        }

        return false
    }

    function run(kind: string): void {
        if (kind === "dismiss")
            dismiss()
        else if (kind === "dismiss_all")
            Notifs.dismissAll()
        else if (kind === "invoke" && !invokeAction("default"))
            dismiss()
    }

    function refresh(): void {
        sync()
        life = 1

        if (active && timeout > 0)
            countdown.restart()

        
        if (md && card.enter >= 1) {
            pulseAnim.restart()
            swapAnim.restart()
        }
    }

    Connections {
        target: root.modelData
        ignoreUnknownSignals: true

        function onSummaryChanged() {
            root.refresh()
        }

        function onBodyChanged() {
            root.refresh()
        }

        function onAppNameChanged() {
            root.sync()
        }

        function onAppIconChanged() {
            root.sync()
        }

        function onImageChanged() {
            root.sync()
        }

        function onUrgencyChanged() {
            root.sync()
        }

        function onActionsChanged() {
            root.sync()
        }

        function onExpireTimeoutChanged() {
            root.sync()
        }
    }

    Connections {
        target: Config

        function onDataChanged() {
            root.sync()
        }
    }

    ListView.onRemove: exitAnimation.start()

    SequentialAnimation {
        id: exitAnimation

        PropertyAction {
            target: root
            property: "ListView.delayRemove"
            value: true
        }

        ParallelAnimation {
            NumberAnimation {
                target: card
                property: "leave"
                to: 1
                duration: 260
                easing.type: Easing.InCubic
            }

            SequentialAnimation {
                PauseAnimation {
                    duration: 140
                }

                NumberAnimation {
                    target: root
                    property: "collapse"
                    to: 0
                    duration: 260
                    easing.type: Easing.InOutCubic
                }
            }
        }

        PropertyAction {
            target: root
            property: "ListView.delayRemove"
            value: false
        }
    }

    
    SequentialAnimation {
        running: root.active && root.md

        PauseAnimation {
            duration: 120
        }

        NumberAnimation {
            target: root
            property: "iconIn"
            from: 0
            to: 1
            duration: 520
            easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
            easing.overshoot: 3
        }
    }

    NumberAnimation {
        id: swapAnim

        target: root
        property: "swap"
        from: 1
        to: 0
        duration: 480
        easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
        easing.overshoot: 2.2
    }

    NumberAnimation {
        id: pulseAnim

        target: card
        property: "pulse"
        from: 1
        to: 0
        duration: 620
        easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
        easing.overshoot: 4
    }

    Item {
        id: card

        width: parent.width
        height: content.implicitHeight + root.theme.padding * 2

        property real enter: 0
        property real leave: 0
        property real pulse: 0          
        property real dragX: 0          

        Behavior on dragX {
            enabled: root.md && !swipe.active

            NumberAnimation {
                duration: 420
                easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
                easing.overshoot: 1.6
            }
        }

        opacity: Math.max(0, Math.min(1, enter)) * (1 - leave)
                 * (1 - 0.7 * Math.min(1, Math.abs(dragX) / (width * 0.8)))
        scale: (Config.motion.scale + (1 - Config.motion.scale) * enter) * (1 - 0.08 * leave)
               * (1 + 0.035 * pulse)
        transformOrigin: Item.Center

        transform: Translate {
            x: (1 - card.enter) * Config.motion.x
               + card.leave * (Config.isLeft ? -56 : Config.isRight ? 56 : 0)
               + card.dragX
            y: (1 - card.enter) * Config.motion.y + card.leave * (Config.isCenter ? (Config.isTop ? -24 : 24) : 0)
        }

        NumberAnimation {
            target: card
            property: "enter"
            from: 0
            to: 1
            duration: Config.enterDuration
            easing.type: Config.easingType
            easing.overshoot: Config.overshoot
            running: root.active
        }

        NumberAnimation {
            id: countdown

            target: root
            property: "life"
            from: 1
            to: 0
            duration: root.timeout
            running: root.active && root.timeout > 0
                     && countdown.duration === root.timeout
                     && !!root.modelData
            paused: root.hovered && Config.pauseOnHover

            onFinished: {
                if (root.modelData)
                    root.modelData.expire()
            }
        }

        Rectangle {
            id: surface

            anchors.fill: parent
            radius: root.theme.radius
            color: Qt.alpha(root.cardColor, root.theme.opacity)
            border.width: root.theme.border_width
            border.color: root.theme.border

            Behavior on color {
                enabled: root.md

                ColorAnimation {
                    duration: 400
                }
            }

            
            scale: root.md && cardArea.pressed && !swipe.active ? 0.98 : 1

            Behavior on scale {
                enabled: root.md

                NumberAnimation {
                    duration: Config.springy ? 380 : 200
                    easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
                    easing.overshoot: 2.4
                }
            }

            MouseArea {
                id: cardArea

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        root.run(Config.leftClick)
                    else if (mouse.button === Qt.RightButton)
                        root.run(Config.rightClick)
                    else
                        root.run(Config.middleClick)
                }
            }

            HoverHandler {
                id: hover
            }

            
            DragHandler {
                id: swipe

                enabled: root.md
                target: null
                yAxis.enabled: false

                onActiveTranslationChanged: {
                    if (active)
                        card.dragX = activeTranslation.x
                }

                onActiveChanged: {
                    if (active)
                        return

                    if (Math.abs(card.dragX) > card.width * 0.3) {
                        card.dragX = (card.dragX < 0 ? -1 : 1) * (card.width + 40)
                        root.dismiss()
                    } else {
                        card.dragX = 0
                    }
                }
            }

            
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.fgColor
                opacity: root.md && root.hovered ? 0.06 : 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 150
                    }
                }
            }

            ColumnLayout {
                id: content

                width: parent.width - root.theme.padding * 2
                x: root.theme.padding
                y: root.theme.padding
                spacing: root.md ? 8 : 5

                
                opacity: root.md ? Math.min(1, 1 - 0.7 * root.swap) : 1

                transform: Translate {
                    y: root.md ? root.swap * 10 : 0
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.md ? 12 : 10

                    ClippingRectangle {
                        id: iconBox

                        visible: root.md ? Config.showIcons : root.iconSource !== ""
                        Layout.preferredWidth: root.md ? root.theme.icon_size : 36
                        Layout.preferredHeight: root.md ? root.theme.icon_size : 36
                        Layout.alignment: Qt.AlignTop
                        radius: root.md ? root.theme.icon_radius : 9
                        color: root.md ? (root.tonal ? root.theme.critical : root.theme.icon_bg) : "transparent"

                        scale: root.iconIn
                        opacity: Math.min(1, root.iconIn)

                        Behavior on color {
                            enabled: root.md

                            ColorAnimation {
                                duration: 300
                            }
                        }

                        Image {
                            id: iconImage

                            anchors.fill: parent
                            anchors.margins: root.md && !root.iconFull ? Math.round(root.theme.icon_size * 0.16) : 0
                            source: root.iconSource
                            fillMode: root.md && root.iconFull ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                            sourceSize.width: 96
                            sourceSize.height: 96
                            asynchronous: true
                            opacity: status === Image.Ready ? 1 : 0

                            Behavior on opacity {
                                enabled: root.md

                                NumberAnimation {
                                    duration: 200
                                }
                            }
                        }

                        
                        Text {
                            anchors.centerIn: parent
                            visible: root.md && (root.iconSource === "" || iconImage.status !== Image.Ready)
                            text: root.appName.charAt(0).toUpperCase()
                            color: root.tonal ? root.theme.critical_container : root.theme.icon_fg
                            font.family: root.theme.font_family
                            font.pixelSize: Math.round(root.theme.icon_size * 0.42)
                            font.weight: Font.Bold
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 1

                        Text {
                            Layout.fillWidth: true
                            visible: Config.showAppName
                            text: root.appName
                            color: root.subColor
                            opacity: root.md ? 0.8 : 1
                            elide: Text.ElideRight
                            font.family: root.theme.font_family
                            font.pixelSize: root.theme.font_size - 2
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.summary !== ""
                            text: root.summary
                            color: root.fgColor
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: root.theme.font_family
                            font.pixelSize: root.theme.summary_size
                            font.weight: root.md ? root.theme.summary_weight : Font.DemiBold
                        }
                    }

                    Rectangle {
                        id: closeButton

                        visible: Config.showClose
                        Layout.preferredWidth: root.md ? 32 : 26
                        Layout.preferredHeight: root.md ? 32 : 26
                        Layout.alignment: Qt.AlignTop
                        radius: root.md ? (closeArea.pressed ? 10 : 16) : 7
                        color: root.md
                               ? "transparent"
                               : (closeArea.containsMouse ? root.theme.button_hover : "transparent")

                        scale: root.md && closeArea.pressed ? 0.85 : 1

                        Behavior on radius {
                            enabled: root.md

                            NumberAnimation {
                                duration: 160
                                easing.type: Easing.OutCubic
                            }
                        }

                        Behavior on scale {
                            enabled: root.md

                            NumberAnimation {
                                duration: Config.springy ? 360 : 200
                                easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
                                easing.overshoot: 2.6
                            }
                        }

                        
                        Rectangle {
                            anchors.fill: parent
                            radius: parent.radius
                            color: root.fgColor
                            opacity: root.md ? (closeArea.pressed ? 0.14 : (closeArea.containsMouse ? 0.08 : 0)) : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 120
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.md ? "" : "×"
                            color: root.subColor
                            font.family: root.md ? Config.iconFont : root.theme.font_family
                            font.pixelSize: root.md ? 14 : 19
                        }

                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: root.dismiss()
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.topMargin: -2
                    visible: root.body !== ""
                    text: root.body
                    color: root.bodyColor
                    linkColor: root.theme.accent
                    textFormat: Text.StyledText
                    wrapMode: Text.Wrap
                    maximumLineCount: Config.maxBodyLines
                    elide: Text.ElideRight
                    font.family: root.theme.font_family
                    font.pixelSize: root.theme.font_size

                    onLinkActivated: link => Qt.openUrlExternally(link)
                }

                Flow {
                    Layout.fillWidth: true
                    visible: Config.showActions && root.hasActions
                    spacing: 8

                    Repeater {
                        model: root.actionList

                        delegate: Rectangle {
                            id: actionButton

                            required property var modelData

                            visible: modelData.identifier !== "default"
                            width: label.implicitWidth + (root.md ? 32 : 24)
                            height: root.md ? 36 : 30
                            radius: root.md ? (buttonArea.pressed ? 12 : height / 2) : 8
                            color: root.md
                                   ? (root.tonal ? root.theme.critical : root.theme.button)
                                   : (buttonArea.containsMouse
                                      ? root.theme.button_hover
                                      : root.theme.button)
                            border.width: root.md ? 0 : 1
                            border.color: root.theme.border

                            scale: root.md && buttonArea.pressed ? 0.93 : 1

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Behavior on radius {
                                enabled: root.md

                                NumberAnimation {
                                    duration: 180
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on scale {
                                enabled: root.md

                                NumberAnimation {
                                    duration: Config.springy ? 380 : 200
                                    easing.type: Config.springy ? Easing.OutBack : Easing.OutCubic
                                    easing.overshoot: 2.6
                                }
                            }

                            
                            Rectangle {
                                anchors.fill: parent
                                radius: parent.radius
                                color: label.color
                                opacity: root.md ? (buttonArea.pressed ? 0.14 : (buttonArea.containsMouse ? 0.08 : 0)) : 0

                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: actionButton.modelData.text
                                color: root.md
                                       ? (root.tonal ? root.theme.critical_container : root.theme.button_fg)
                                       : root.theme.foreground
                                font.family: root.theme.font_family
                                font.pixelSize: root.theme.font_size - 1
                                font.weight: Font.Medium
                            }

                            MouseArea {
                                id: buttonArea
                                anchors.fill: parent
                                hoverEnabled: true

                                onClicked: root.invokeAction(
                                    actionButton.modelData.identifier
                                )
                            }
                        }
                    }
                }

                Rectangle {
                    visible: Config.showProgress && root.timeout > 0
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.md ? root.theme.progress_height : 3
                    Layout.topMargin: root.md ? 2 : 0
                    radius: height / 2
                    color: root.tonal ? Qt.alpha(root.theme.on_critical_container, 0.18) : root.theme.progress_track

                    Rectangle {
                        width: parent.width * root.life
                        height: parent.height
                        radius: parent.radius
                        color: root.urgencyColor
                    }
                }
            }
        }
    }
}
