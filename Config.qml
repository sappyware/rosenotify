pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import "Toml.js" as Toml

Singleton {
    id: root

    readonly property string configDir: Quickshell.env("HOME") + "/.config/rosenotify"
    readonly property string path: configDir + "/config.toml"

    // Written to disk if config.toml is missing or empty.
    readonly property string defaultConfig: `[general]
monitor = "primary"
position = "top-right"
margin_x = 24
margin_y = 24
spacing = 12
width = 380
max_visible = 5
newest_first = true
layer = "overlay"
do_not_disturb = false
dnd_allow_critical = true

[timeout]
low = 4
normal = 8
critical = 0

[animation]
style = "slide"
enter_duration = 420
exit_duration = 260
reflow_duration = 300
distance = 48
easing = ""

[behavior]
left_click = "invoke"
right_click = "dismiss"
middle_click = "dismiss_all"
pause_on_hover = true
respect_app_timeout = true
show_icons = true
show_app_name = true
show_actions = true
show_close_button = true
show_progress = true
max_body_lines = 4

[theme]
active = "rose"
`

    property var data: ({})

    readonly property var defaults: ({
        general: {
            monitor: "primary",
            position: "top-right",
            margin_x: 24,
            margin_y: 24,
            spacing: 12,
            width: 380,
            max_visible: 5,
            newest_first: true,
            layer: "overlay",
            do_not_disturb: false,
            dnd_allow_critical: true
        },
        timeout: {
            low: 4,
            normal: 8,
            critical: 0
        },
        animation: {
            style: "slide",
            enter_duration: 420,
            exit_duration: 260,
            reflow_duration: 300,
            distance: 48,
            easing: ""
        },
        behavior: {
            left_click: "invoke",
            right_click: "dismiss",
            middle_click: "dismiss_all",
            pause_on_hover: true,
            respect_app_timeout: true,
            show_icons: true,
            show_app_name: true,
            show_actions: true,
            show_close_button: true,
            show_progress: true,
            max_body_lines: 4
        },
        theme: {
            active: "rose"
        }
    })

    readonly property var builtinThemes: ({
        rose: {
            background: "#1b1519",
            foreground: "#f5e6ea",
            body: "#d9c4ca",
            subtext: "#a8939a",
            border: "#3a2a31",
            accent: "#f4a6bd",
            low: "#8fb8c4",
            normal: "#f4a6bd",
            critical: "#f2556f",
            button: "#2a2026",
            button_hover: "#3a2c34",
            progress_track: "#2a2026",
            shadow_color: "#000000",
            shadow_opacity: 0.45,
            shadow_blur: 1.0,
            shadow_offset_y: 8,
            opacity: 0.95,
            radius: 16,
            border_width: 1,
            padding: 16,
            icon_size: 48,
            icon_radius: 12,
            accent_width: 4,
            progress_height: 3,
            font_family: "sans-serif",
            font_size: 13,
            summary_size: 14,
            summary_weight: 600
        },
        dawn: {
            background: "#faf4ed",
            foreground: "#575279",
            body: "#6e6a86",
            subtext: "#9893a5",
            border: "#dfdad9",
            accent: "#d7827e",
            low: "#56949f",
            normal: "#d7827e",
            critical: "#b4637a",
            button: "#f2e9e1",
            button_hover: "#ebdfd6",
            progress_track: "#ebdfd6",
            shadow_color: "#6e6a86",
            shadow_opacity: 0.3
        }
    })

    readonly property var easings: ({
        Linear: Easing.Linear,
        InCubic: Easing.InCubic,
        InBack: Easing.InBack,
        OutQuad: Easing.OutQuad,
        OutCubic: Easing.OutCubic,
        OutQuart: Easing.OutQuart,
        OutExpo: Easing.OutExpo,
        OutBack: Easing.OutBack,
        OutElastic: Easing.OutElastic,
        OutBounce: Easing.OutBounce,
        InOutCubic: Easing.InOutCubic
    })

    readonly property string monitor: v("general", "monitor")
    readonly property string position: v("general", "position")
    readonly property real marginX: v("general", "margin_x")
    readonly property real marginY: v("general", "margin_y")
    readonly property real spacing: v("general", "spacing")
    readonly property real width: v("general", "width")
    readonly property int maxVisible: v("general", "max_visible")
    readonly property bool newestFirst: v("general", "newest_first")
    readonly property string layer: v("general", "layer")
    readonly property bool doNotDisturb: v("general", "do_not_disturb")
    readonly property bool dndAllowCritical: v("general", "dnd_allow_critical")

    readonly property bool isTop: position.indexOf("top") === 0
    readonly property bool isLeft: position.slice(-4) === "left"
    readonly property bool isRight: position.slice(-5) === "right"
    readonly property bool isCenter: !isLeft && !isRight

    readonly property string animationStyle: v("animation", "style")
    readonly property real distance: v("animation", "distance")
    readonly property int enterDuration: animationStyle === "none" ? 0 : v("animation", "enter_duration")
    readonly property int exitDuration: animationStyle === "none" ? 0 : v("animation", "exit_duration")
    readonly property int reflowDuration: animationStyle === "none" ? 0 : v("animation", "reflow_duration")
    readonly property var motion: motionFor(animationStyle)
    readonly property int easingType: pick(v("animation", "easing"), motion.enter)
    readonly property int exitEasingType: pick("", motion.exit)
    readonly property real overshoot: motion.overshoot

    readonly property string leftClick: v("behavior", "left_click")
    readonly property string rightClick: v("behavior", "right_click")
    readonly property string middleClick: v("behavior", "middle_click")
    readonly property bool pauseOnHover: v("behavior", "pause_on_hover")
    readonly property bool respectAppTimeout: v("behavior", "respect_app_timeout")
    readonly property bool showIcons: v("behavior", "show_icons")
    readonly property bool showAppName: v("behavior", "show_app_name")
    readonly property bool showActions: v("behavior", "show_actions")
    readonly property bool showClose: v("behavior", "show_close_button")
    readonly property bool showProgress: v("behavior", "show_progress")
    readonly property int maxBodyLines: v("behavior", "max_body_lines")

    readonly property var theme: resolveTheme(v("theme", "active"), 0)

    function reload(): void {
        file.reload()
    }

    function apply(source: string): void {
        try {
            data = Toml.parse(source)
        } catch (error) {
            console.warn("rosenotify: config error: " + error.message)
        }
    }

    function v(section: string, key: string): var {
        const table = data[section]

        if (table !== undefined && table !== null && table[key] !== undefined)
            return table[key]

        return defaults[section][key]
    }

    function pick(name: string, fallback: string): int {
        if (name !== "" && easings[name] !== undefined)
            return easings[name]

        return easings[fallback]
    }

    function resolveTheme(name: string, level: int): var {
        const table = (data.themes || {})[name] || builtinThemes[name]

        if (table === undefined)
            return level === 0 ? resolveTheme("rose", 1) : builtinThemes.rose

        const parent = table["extends"] && level < 8 ? resolveTheme(table["extends"], level + 1) : builtinThemes.rose

        return Object.assign({}, parent, table)
    }

    function motionFor(style: string): var {
        const sx = isLeft ? -1 : isRight ? 1 : 0
        const sy = isTop ? -1 : 1
        const slide = sx !== 0
            ? { x: sx * (width + marginX + 40), y: 0 }
            : { x: 0, y: sy * (distance + 60) }

        switch (style) {
        case "none":
        case "fade":
            return { x: 0, y: 0, scale: 1, enter: "OutCubic", exit: "InCubic", overshoot: 1 }
        case "scale":
            return { x: 0, y: 0, scale: 0.82, enter: "OutCubic", exit: "InCubic", overshoot: 1 }
        case "pop":
            return { x: 0, y: 0, scale: 0.55, enter: "OutBack", exit: "InBack", overshoot: 2.4 }
        case "drop":
            return { x: 0, y: sy * distance, scale: 1, enter: "OutCubic", exit: "InCubic", overshoot: 1 }
        case "bounce":
            return { x: slide.x, y: slide.y, scale: 1, enter: "OutBack", exit: "InBack", overshoot: 1.6 }
        default:
            return { x: slide.x, y: slide.y, scale: 1, enter: "OutCubic", exit: "InCubic", overshoot: 1 }
        }
    }

    function urgencyName(level: int): string {
        if (level === NotificationUrgency.Critical)
            return "critical"

        return level === NotificationUrgency.Low ? "low" : "normal"
    }

    function matches(pattern: string, value: string): bool {
        try {
            return new RegExp(pattern, "i").test(value)
        } catch (error) {
            return false
        }
    }

    function ruleFor(notification: var): var {
        const rules = Array.isArray(data.rules) ? data.rules : []
        const result = {}

        for (const rule of rules) {
            if (rule.app !== undefined && !matches(rule.app, notification.appName))
                continue

            if (rule.summary !== undefined && !matches(rule.summary, notification.summary))
                continue

            if (rule.body !== undefined && !matches(rule.body, notification.body))
                continue

            if (rule.urgency !== undefined && rule.urgency !== urgencyName(notification.urgency))
                continue

            Object.assign(result, rule)
        }

        return result
    }

    function timeoutMs(notification: var, rule: var): int {
        if (rule.timeout !== undefined)
            return rule.timeout * 1000

        if (respectAppTimeout && notification.expireTimeout > 0)
            return notification.expireTimeout * 1000

        return v("timeout", urgencyName(notification.urgency)) * 1000
    }

    // One-shot: ensure ~/.config/rosenotify exists and seed it with
    // defaultConfig if config.toml is missing or zero-length. Never
    // overwrites an existing non-empty config.
    Process {
        id: setup

        command: ["/bin/sh", "-c", `
mkdir -p '${root.configDir}'
if [ ! -s '${root.path}' ]; then
    cat > '${root.path}' <<'ROSENOTIFY_DEFAULT_EOF'
${root.defaultConfig}
ROSENOTIFY_DEFAULT_EOF
fi
`]

        // Start exactly once. Do NOT bind `running: true`; that re-asserts
        // after exit and causes the process to restart forever.
        Component.onCompleted: running = true
        onExited: file.reload()
    }

    FileView {
        id: file

        path: root.path
        blockLoading: true
        watchChanges: true
        printErrors: false

        onFileChanged: file.reload()
        onLoaded: {
            const text = file.text()
            if (text.trim() !== "")
                root.apply(text)
        }
    }
}