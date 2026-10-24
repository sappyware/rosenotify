import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    function targets(): var {
        const screens = Array.from(Quickshell.screens)

        if (Config.monitor === "all")
            return screens

        if (Config.monitor === "primary")
            return screens.slice(0, 1)

        return screens.filter(screen => screen.name === Config.monitor)
    }

    Variants {
        model: root.targets()

        PanelWindow {
            id: window

            required property var modelData

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "rosenotify"
            WlrLayershell.layer: Config.layer === "top" ? WlrLayer.Top : WlrLayer.Overlay

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            mask: Region {
                item: list
            }

            ListView {
                id: list

                model: Notifs.model
                interactive: false
                width: Config.width
                height: Math.max(0, Math.min(contentHeight, window.height - Config.marginY * 2))

                verticalLayoutDirection: Config.isTop === Config.newestFirst ? ListView.BottomToTop : ListView.TopToBottom

                x: Config.isLeft ? Config.marginX
                 : Config.isRight ? window.width - Config.width - Config.marginX
                 : (window.width - Config.width) / 2
                y: Config.isTop ? Config.marginY
                 : window.height - height - Config.marginY
                delegate: Card {}

                displaced: Transition {
                    NumberAnimation {
                        properties: "x,y"
                        duration: Config.reflowDuration
                        easing.type: Easing.OutCubic
                    }
                }

                remove: Transition {
                    ParallelAnimation {
                        NumberAnimation {
                            property: "opacity"
                            to: 0
                            duration: Config.exitDuration
                            easing.type: Easing.OutCubic
                        }

                        NumberAnimation {
                            property: "x"
                            to: Config.motion.x
                            duration: Config.exitDuration
                            easing.type: Config.exitEasingType
                        }

                        NumberAnimation {
                            property: "scale"
                            to: Config.motion.scale
                            duration: Config.exitDuration
                            easing.type: Config.exitEasingType
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "notify"

        function dismissAll(): void {
            Notifs.dismissAll()
        }

        function toggleDnd(): void {
            Notifs.dnd = !Notifs.dnd
        }

        function setDnd(enabled: bool): void {
            Notifs.dnd = enabled
        }

        function dnd(): bool {
            return Notifs.dnd
        }

        function reload(): void {
            Config.reload()
        }

        function test(urgency: string): void {
            Quickshell.execDetached([
                "notify-send",
                "-a", "rosenotify",
                "-u", urgency || "normal",
                "-A", "open=Open",
                "-A", "later=Later",
                "Rose notifications",
                "Urgency: " + (urgency || "normal") + ". Edit config.toml and watch it change live."
            ])
        }
    }
}
