import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Claude Code usage and background sessions, for a Plasma panel (or the system tray).
// Left click = panel: background sessions (left column) + usage (limits, pace, tokens by
// day, tokens by model, model switch; right column);
// right click = open Claude Code. All data and actions go through ~/.local/bin/claude-usage.
PlasmoidItem {
    id: root

    readonly property string tool: "\"$HOME/.local/bin/claude-usage\""
    readonly property string pollCmd: tool + " --running"
    readonly property string usageCmd: tool + " --json"
    readonly property string refreshCmd: tool + " --json --refresh"
    readonly property string openCmd: tool + " --open"
    readonly property string modelCmd: tool + " --set-model "
    readonly property string restartCmd: tool + " --restart"
    readonly property string sessionsCmd: tool + " --sessions"
    readonly property var modelChoices: usage && usage.model_choices ? usage.model_choices : []
    property bool running: false
    property var usage: null
    property var sessionData: null
    property bool showAllDone: false
    property string confirmRemove: ""   // id whose remove button was clicked once
    // Replacing sessionData rebuilds every session row. Rebuilding the row under the pointer
    // (polls every 3 s while open) left the panel ignoring clicks, so: skip identical results,
    // hold new data while the pointer is over the list, and run one poll at a time.
    property string sessionsKey: ""
    property var pendingSessions: null
    property bool sessionsHovered: false
    property real sessionsBusySince: 0
    property string usageKey: ""
    property real now: Date.now()       // ticks every 30 s for the "ago" labels

    readonly property var sessions: sessionData && sessionData.sessions ? sessionData.sessions : []
    readonly property int needsCount: sessions.filter(s => s.group === "needs").length
    readonly property var sessionGroups: [
        { key: "needs", title: "NEEDS INPUT", icon: "dialog-question", color: Kirigami.Theme.neutralTextColor },
        { key: "working", title: "WORKING", icon: "media-playback-start", color: Kirigami.Theme.highlightColor },
        { key: "done", title: "COMPLETED", icon: "dialog-ok-apply", color: Kirigami.Theme.positiveTextColor },
        { key: "failed", title: "FAILED", icon: "dialog-error", color: Kirigami.Theme.negativeTextColor }
    ]

    readonly property var limits: usage && usage.limits ? usage.limits : []
    readonly property var days: usage && usage.days ? usage.days : []
    readonly property var models: usage && usage.models ? usage.models : []
    readonly property var session: limits.find(l => l.kind === "session") || null
    readonly property int maxPercent: limits.reduce((m, l) => Math.max(m, l.percent || 0), 0)
    readonly property real dayPeak: Math.max(1, days.reduce((m, d) => Math.max(m, d.total || 0), 0))
    readonly property real modelPeak: Math.max(1, models.reduce((m, d) => Math.max(m, d.total || 0), 0))

    function open() { exec.connectSource(openCmd) }
    function restart() { exec.connectSource(restartCmd + " #" + Date.now()) }
    function setModel(id) { exec.connectSource(modelCmd + id + " #" + Date.now()) }
    function openUsagePage() { exec.connectSource("xdg-open https://claude.ai/settings/usage #" + Date.now()) }
    function refreshSessions() {
        if (sessionsBusySince && Date.now() - sessionsBusySince < 30000) return
        sessionsBusySince = Date.now()
        exec.connectSource(sessionsCmd + " #" + Date.now())
    }
    function takeSessions(stdout) {
        sessionsBusySince = 0
        let d
        try { d = JSON.parse(stdout) } catch (e) { return }
        (d.sessions || []).forEach(s => delete s.ago)   // computed here from `updated`
        const key = JSON.stringify(d)
        if (key === sessionsKey) return
        sessionsKey = key
        if (sessionsHovered) pendingSessions = d
        else { pendingSessions = null; sessionData = d }
    }
    function flushSessions() {
        if (pendingSessions && !sessionsHovered) { sessionData = pendingSessions; pendingSessions = null }
    }
    function takeUsage(stdout) {
        if (stdout === usageKey) return
        try { usage = JSON.parse(stdout); usageKey = stdout } catch (e) {}
    }
    function ago(ms) {
        const s = Math.max(0, (now - ms) / 1000)
        return s < 60 ? "now" : s < 3600 ? Math.floor(s / 60) + "m"
             : s < 86400 ? Math.floor(s / 3600) + "h" : Math.floor(s / 86400) + "d"
    }
    function openSession(id) { exec.connectSource(tool + " --open-session " + id + " #" + Date.now()) }
    function removeSession(id) {
        confirmRemove = ""
        sessionData = Object.assign({}, sessionData, { sessions: sessions.filter(s => s.id !== id) })
        exec.connectSource(tool + " --remove-session " + id + " #" + Date.now())
    }
    function refresh(force) { exec.connectSource((force ? refreshCmd : usageCmd) + " #" + Date.now()) }
    function levelColor(p) {
        return p >= 90 ? Kirigami.Theme.negativeTextColor
             : p >= 70 ? Kirigami.Theme.neutralTextColor
             : Kirigami.Theme.positiveTextColor
    }

    Plasmoid.icon: "claude-code"             // falls back to utilities-terminal below
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: running ? "Claude Code running" : "Claude Code not running"
    toolTipSubText: (needsCount > 0 ? `${needsCount} session${needsCount > 1 ? "s" : ""} need input\n` : "")
        + (session ? `Session ${session.percent}% · weekly ${maxPercent}% max\n` : "")
        + "Left click: usage  ·  Right click: open Claude"
    // No preferredRepresentation here: the system tray only shows a popup for applets
    // that leave it unset (setActiveApplet checks !applet.preferredRepresentation).

    // The tray hands both buttons to our MouseArea: left toggles the popup, right opens Claude.
    onExpandedChanged: () => {
        if (root.expanded) { root.now = Date.now(); root.refresh(false); root.refreshSessions() }
        else { root.confirmRemove = ""; root.showAllDone = false; root.sessionsHovered = false; root.flushSessions() }
    }

    compactRepresentation: Item {
        Kirigami.Icon {
            anchors.fill: parent
            source: Plasmoid.icon
            fallback: "utilities-terminal"
            active: mouse.containsMouse
            opacity: root.running ? 1.0 : 0.4
        }
        Rectangle {
            visible: root.session !== null
            anchors { right: parent.right; bottom: parent.bottom }
            height: Math.round(parent.height * 0.5)
            width: Math.max(height, badgeText.implicitWidth + 4)
            radius: height / 2
            color: root.levelColor(root.maxPercent)
            PC3.Label {
                id: badgeText
                anchors.centerIn: parent
                text: root.session ? root.session.percent : ""
                color: "white"
                font.pixelSize: parent.height * 0.72
                font.bold: true
            }
        }
        Rectangle {
            visible: root.needsCount > 0
            anchors { left: parent.left; top: parent.top }
            height: Math.round(parent.height * 0.45)
            width: Math.max(height, needsText.implicitWidth + 4)
            radius: height / 2
            color: Kirigami.Theme.neutralTextColor
            PC3.Label {
                id: needsText
                anchors.centerIn: parent
                text: root.needsCount
                color: "white"
                font.pixelSize: parent.height * 0.75
                font.bold: true
            }
        }
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: ev => {
                if (ev.button === Qt.RightButton) root.open()
                else root.expanded = !root.expanded
            }
        }
    }

    fullRepresentation: PlasmaExtras.Representation {
        id: panelRep
        Layout.preferredWidth: Kirigami.Units.gridUnit * 46
        // Tall enough for the whole right (usage) column; only the sessions column scrolls.
        // A minimum, because the popup reuses its saved size and only grows to the minimum.
        readonly property real fitHeight: implicitHeaderHeight + implicitFooterHeight
            + usageColumn.implicitHeight + topPadding + bottomPadding + Kirigami.Units.smallSpacing * 2
        Layout.preferredHeight: fitHeight
        Layout.minimumWidth: Kirigami.Units.gridUnit * 36
        Layout.minimumHeight: fitHeight
        collapseMarginsHint: true

        header: PlasmaExtras.PlasmoidHeading {
            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing
                RowLayout {
                    spacing: Kirigami.Units.largeSpacing
                    Kirigami.Icon {
                        source: "claude-code"
                        fallback: "utilities-terminal"
                        Layout.preferredWidth: Kirigami.Units.iconSizes.large
                        Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    }
                    ColumnLayout {
                        spacing: 0
                        Kirigami.Heading { level: 3; text: "Claude Code" }
                        PC3.Label {
                            text: (root.usage && root.usage.plan ? root.usage.plan : "")
                                + (root.running ? "  ·  running" : "  ·  not running")
                            opacity: 0.7
                        }
                    }
                }
                PC3.Label {
                    visible: !!(root.usage && root.usage.error)
                    text: root.usage && root.usage.error ? "⚠ " + root.usage.error : ""
                    color: Kirigami.Theme.neutralTextColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }


            }
        }

        footer: PlasmaExtras.PlasmoidHeading {
            position: PC3.ToolBar.Footer
            RowLayout {
                anchors.fill: parent
                PC3.Button {
                    icon.name: "view-refresh"
                    text: "Refresh"
                    onClicked: root.refresh(true)
                }
                Item { Layout.fillWidth: true }
                PC3.Button {
                    icon.name: "system-reboot"
                    text: "Restart"
                    visible: root.running && !!(root.usage && root.usage.can_switch_model)
                    onClicked: { root.expanded = false; root.restart() }
                }
                PC3.Button {
                    icon.name: "claude-code"
                    text: root.running ? "Open Claude Code" : "Start Claude Code"
                    onClicked: { root.expanded = false; root.open() }
                }
            }

        }

        // Two columns: sessions on the left, usage (limits, tokens, pace, model) on the right.
        contentItem: RowLayout {
          spacing: 0
          PC3.ScrollView {
            id: sessionScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 25
            contentWidth: availableWidth
            PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff
            HoverHandler {
                onHoveredChanged: { root.sessionsHovered = hovered; root.flushSessions() }
            }

            ColumnLayout {
                width: sessionScroll.availableWidth - Kirigami.Units.largeSpacing * 2
                x: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                // SESSIONS: background sessions by state; click opens a window, X removes
                Repeater {
                    model: root.sessionGroups
                    delegate: ColumnLayout {
                        id: group
                        required property var modelData
                        readonly property var all: root.sessions.filter(s => s.group === modelData.key)
                        readonly property bool capped: modelData.key === "done" && !root.showAllDone && all.length > 10
                        Layout.fillWidth: true
                        visible: all.length > 0
                        spacing: 2
                        SectionHeader { text: group.modelData.title + "  ·  " + group.all.length }
                        Repeater {
                            model: group.capped ? group.all.slice(0, 10) : group.all
                            delegate: SessionRow { groupInfo: group.modelData }
                        }
                        PC3.ToolButton {
                            visible: group.modelData.key === "done" && group.all.length > 10
                            text: root.showAllDone ? "Show fewer" : `Show all ${group.all.length}`
                            font: Kirigami.Theme.smallFont
                            onClicked: root.showAllDone = !root.showAllDone
                        }
                    }
                }
                PC3.Label {
                    visible: root.sessions.length === 0
                    Layout.topMargin: Kirigami.Units.largeSpacing
                    text: "No background sessions"
                    opacity: 0.6
                }
                Item { implicitHeight: Kirigami.Units.largeSpacing }
            }
          }

          Kirigami.Separator { Layout.fillHeight: true }

          PC3.ScrollView {
            id: scroll
            Layout.fillHeight: true
            Layout.preferredWidth: Kirigami.Units.gridUnit * 20
            contentWidth: availableWidth
            PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

            ColumnLayout {
                id: usageColumn
                width: scroll.availableWidth - Kirigami.Units.largeSpacing * 2
                x: Kirigami.Units.largeSpacing
                spacing: Kirigami.Units.smallSpacing
                // LIMITS
                SectionHeader { text: "LIMITS"; visible: root.limits.length > 0 }
                Repeater {
                    model: root.limits
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 2
                        RowLayout {
                            Layout.fillWidth: true
                            PC3.Label { text: modelData.label; Layout.fillWidth: true; elide: Text.ElideRight }
                            PC3.Label {
                                text: modelData.reset_in ? "resets in " + modelData.reset_in : ""
                                opacity: 0.6
                                font: Kirigami.Theme.smallFont
                            }
                            PC3.Label {
                                text: modelData.percent + "%"
                                font.bold: true
                                horizontalAlignment: Text.AlignRight
                                Layout.preferredWidth: Kirigami.Units.gridUnit * 2
                                color: modelData.percent >= 90 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                            }
                        }
                        Meter { value: modelData.percent / 100; color: root.levelColor(modelData.percent) }
                    }
                }

                // TOKENS BY DAY
                SectionHeader { text: "TOKENS BY DAY"; visible: root.days.length > 0 }
                Repeater {
                    model: root.days
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        PC3.Label {
                            text: modelData.today ? "Today" : modelData.name
                            font.bold: modelData.today
                            opacity: modelData.today ? 1 : 0.7
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                        }
                        Meter {
                            value: modelData.total / root.dayPeak
                            color: Kirigami.Theme.highlightColor
                            opacity: modelData.today ? 1 : 0.6
                            Layout.alignment: Qt.AlignVCenter
                        }
                        PC3.Label {
                            text: modelData.total_text
                            font.bold: modelData.today
                            horizontalAlignment: Text.AlignRight
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 3
                        }
                    }
                }

                // TOKENS BY MODEL (today)
                SectionHeader { text: "TOKENS BY MODEL · TODAY"; visible: root.models.length > 0 }
                Repeater {
                    model: root.models
                    delegate: ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        spacing: 0
                        RowLayout {
                            Layout.fillWidth: true
                            PC3.Label { text: modelData.name; Layout.fillWidth: true }
                            PC3.Label { text: modelData.total_text; font.bold: true }
                        }
                        Meter { value: modelData.total / root.modelPeak; color: Kirigami.Theme.highlightColor }
                        PC3.Label { text: modelData.split_text; opacity: 0.6; font: Kirigami.Theme.smallFont }
                    }
                }


                // PACE: straight-line projection to each reset
                SectionHeader { text: "PACE"; visible: root.limits.length > 0 }
                Repeater {
                    model: root.limits
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        PC3.Label { text: modelData.label; opacity: 0.7; Layout.fillWidth: true; elide: Text.ElideRight }
                        PC3.Label {
                            text: modelData.pace || ""
                            font: Kirigami.Theme.smallFont
                            color: (modelData.pace || "").indexOf("before reset") >= 0
                                ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
                        }
                    }
                }

                // MODEL: sends /model to the running session (only when tmux_target is configured)
                SectionHeader { text: "MODEL"; visible: modelGrid.visible }
                GridLayout {
                    id: modelGrid
                    visible: !!(root.usage && root.usage.can_switch_model)
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Kirigami.Units.smallSpacing
                    rowSpacing: Kirigami.Units.smallSpacing
                    Repeater {
                        model: root.modelChoices
                        delegate: PC3.Button {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.name
                            checkable: true
                            checked: modelData.current
                            enabled: root.running
                            onClicked: { checked = modelData.current; root.setModel(modelData.id) }
                        }
                    }
                }
                PC3.ToolButton {
                    Layout.fillWidth: true
                    icon.name: "internet-web-browser"
                    text: "Usage on claude.ai"
                    onClicked: { root.expanded = false; root.openUsagePage() }
                }
                Item { implicitHeight: Kirigami.Units.largeSpacing }
            }
          }
        }
    }

    component SectionHeader: PC3.Label {
        Layout.topMargin: Kirigami.Units.largeSpacing
        font.bold: true
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.6
    }

    component SessionRow: Rectangle {
        id: row
        required property var modelData
        property var groupInfo
        readonly property bool confirming: root.confirmRemove === modelData.id
        Layout.fillWidth: true
        implicitHeight: rowLayout.implicitHeight + Kirigami.Units.smallSpacing * 2
        radius: Kirigami.Units.cornerRadius
        color: rowMouse.containsMouse ? Qt.rgba(Kirigami.Theme.highlightColor.r, Kirigami.Theme.highlightColor.g, Kirigami.Theme.highlightColor.b, 0.18) : "transparent"
        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: { root.expanded = false; root.openSession(row.modelData.id) }
        }
        RowLayout {
            id: rowLayout
            anchors { fill: parent; margins: Kirigami.Units.smallSpacing }
            spacing: Kirigami.Units.smallSpacing
            Kirigami.Icon {
                source: row.groupInfo.icon
                color: row.groupInfo.color
                isMask: true
                Layout.preferredWidth: Kirigami.Units.iconSizes.small
                Layout.preferredHeight: Kirigami.Units.iconSizes.small
                Layout.alignment: Qt.AlignTop
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    PC3.Label {
                        text: row.modelData.name
                        font.bold: row.groupInfo.key === "needs"
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    PC3.Label {
                        text: (row.modelData.open ? "open · " : "") + root.ago(row.modelData.updated)
                        opacity: 0.6
                        font: Kirigami.Theme.smallFont
                    }
                }
                PC3.Label {
                    visible: text !== ""
                    text: row.modelData.text || ""
                    opacity: 0.7
                    font: Kirigami.Theme.smallFont
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                }
            }
            PC3.ToolButton {
                icon.name: row.confirming ? "edit-delete" : "window-close"
                text: row.confirming ? "Remove" : ""
                Layout.alignment: Qt.AlignTop
                PC3.ToolTip.text: row.confirming
                    ? (row.groupInfo.key === "working" ? "Click again: stop and remove" : "Click again to remove")
                    : "Remove from list"
                PC3.ToolTip.visible: hovered
                PC3.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    if (row.confirming) root.removeSession(row.modelData.id)
                    else { root.confirmRemove = row.modelData.id; confirmReset.restart() }
                }
            }
        }
    }

    Timer {
        id: confirmReset
        interval: 4000
        onTriggered: root.confirmRemove = ""
    }

    component Meter: Item {
        property real value: 0
        property color color: Kirigami.Theme.highlightColor
        Layout.fillWidth: true
        implicitHeight: 6
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: Kirigami.Theme.textColor
            opacity: 0.15
        }
        Rectangle {
            height: parent.height
            radius: height / 2
            width: parent.width * Math.max(0, Math.min(1, parent.value))
            color: parent.color
        }
    }

    P5Support.DataSource {
        id: exec
        engine: "executable"
        onNewData: (source, data) => {
            if (source === root.pollCmd)
                root.running = data.stdout.trim() === "on"
            else if (source.startsWith(root.sessionsCmd + " #")) {
                root.takeSessions(data.stdout)
            }
            else if (source.startsWith(root.tool + " --remove-session "))
                root.refreshSessions()
            else if (source.startsWith(root.usageCmd) || source.startsWith(root.refreshCmd)) {
                root.takeUsage(data.stdout)
            }
            disconnectSource(source)
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: exec.connectSource(root.pollCmd)
    }
    // Sessions: every 3 s while the popup is open, every 15 s for the badge otherwise.
    Timer {
        interval: root.expanded ? 3000 : 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refreshSessions()
    }
    Timer {
        interval: 30000
        running: root.expanded
        repeat: true
        onTriggered: root.now = Date.now()
    }
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(false)
    }
}
