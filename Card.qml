
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

    property string summary: ""
    property string body: ""
    property string appName: ""
    property string iconSource: ""
    property int urgency: 1
    property int timeout: 0
    property var rule: ({})
    property var actionList: []
    property real life: 1

    property bool removing: false
    property bool initialized: false
    property real collapse: 1

    width: ListView.view ? ListView.view.width : Config.width
    height: active
        ? Math.min(card.height + Config.spacing, root.ListView.view ? root.ListView.view.height : Infinity) * collapse
        : 0
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

    Item {
        id: card

        width: parent.width
        height: content.implicitHeight + root.theme.padding * 2

        property real enter: 0
        property real leave: 0

        opacity: Math.max(0, Math.min(1, enter)) * (1 - leave)
        scale: (Config.motion.scale + (1 - Config.motion.scale) * enter) * (1 - 0.08 * leave)
        transformOrigin: Item.Center

        transform: Translate {
            x: (1 - card.enter) * Config.motion.x + card.leave * (Config.isLeft ? -56 : Config.isRight ? 56 : 0)
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
            anchors.fill: parent
            radius: root.theme.radius
            color: Qt.alpha(root.theme.background, root.theme.opacity)
            border.width: root.theme.border_width
            border.color: root.theme.border

            MouseArea {
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

            ColumnLayout {
                id: content

                anchors.fill: parent
                anchors.margins: root.theme.padding
                spacing: 5

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                    ClippingRectangle {
                        visible: root.iconSource !== ""
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        Layout.alignment: Qt.AlignTop
                        radius: 9
                        color: "transparent"

                        Image {
                            anchors.fill: parent
                            source: root.iconSource
                            fillMode: Image.PreserveAspectFit
                            sourceSize.width: 72
                            sourceSize.height: 72
                            asynchronous: true
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
                            color: root.theme.subtext
                            elide: Text.ElideRight
                            font.family: root.theme.font_family
                            font.pixelSize: root.theme.font_size - 2
                            font.weight: Font.Medium
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: root.summary !== ""
                            text: root.summary
                            color: root.theme.foreground
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                            font.family: root.theme.font_family
                            font.pixelSize: root.theme.summary_size
                            font.weight: Font.DemiBold
                        }
                    }

                    Rectangle {
                        visible: Config.showClose
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        Layout.alignment: Qt.AlignTop
                        radius: 7
                        color: closeArea.containsMouse
                               ? root.theme.button_hover
                               : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: root.theme.subtext
                            font.family: root.theme.font_family
                            font.pixelSize: 19
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
                    color: root.theme.body
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
                            width: label.implicitWidth + 24
                            height: 30
                            radius: 8
                            color: buttonArea.containsMouse
                                   ? root.theme.button_hover
                                   : root.theme.button
                            border.width: 1
                            border.color: root.theme.border

                            Behavior on color {
                                ColorAnimation {
                                    duration: 120
                                }
                            }

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: actionButton.modelData.text
                                color: root.theme.foreground
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
                    Layout.preferredHeight: 3
                    radius: 2
                    color: root.theme.progress_track

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
