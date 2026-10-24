pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

Singleton {
    id: root

    property bool dnd: Config.doNotDisturb

    readonly property var model: server.trackedNotifications

    function dismissAll(): void {
        const all = []
        const values = server.trackedNotifications.values

        for (let i = 0; i < values.length; i++)
            all.push(values[i])

        for (const notification of all)
            notification.dismiss()
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true

        onNotification: notification => {
            const critical = notification.urgency === NotificationUrgency.Critical

            if (root.dnd && !(Config.dndAllowCritical && critical))
                return

            if (Config.ruleFor(notification).ignore === true)
                return

            notification.tracked = true
        }
    }
}
