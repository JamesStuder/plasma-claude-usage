import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PC3
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

// Claude Code usage in the system tray.
// Left click = usage panel (limits, pace, tokens by day, tokens by model, model switch);
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
    readonly property var modelChoices: usage && usage.model_choices ? usage.model_choices : []
    property bool running: false
    property var usage: null

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
    function refresh(force) { exec.connectSource((force ? refreshCmd : usageCmd) + " #" + Date.now()) }
    function levelColor(p) {
        return p >= 90 ? Kirigami.Theme.negativeTextColor
             : p >= 70 ? Kirigami.Theme.neutralTextColor
             : Kirigami.Theme.positiveTextColor
    }

    Plasmoid.icon: "claude-code"             // falls back to utilities-terminal below
    Plasmoid.status: PlasmaCore.Types.ActiveStatus
    toolTipMainText: running ? "Claude Code running" : "Claude Code not running"
    toolTipSubText: (session ? `Session ${session.percent}% · weekly ${maxPercent}% max\n` : "")
        + "Left click: usage  ·  Right click: open Claude"
    // No preferredRepresentation here: the system tray only shows a popup for applets
    // that leave it unset (setActiveApplet checks !applet.preferredRepresentation).

    // The tray hands both buttons to our MouseArea: left toggles the popup, right opens Claude.
    onExpandedChanged: () => { if (root.expanded) root.refresh(false) }

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
        Layout.preferredWidth: Kirigami.Units.gridUnit * 20
        Layout.preferredHeight: Kirigami.Units.gridUnit * 30
        Layout.minimumWidth: Kirigami.Units.gridUnit * 16
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

        contentItem: PC3.ScrollView {
            id: scroll
            contentWidth: availableWidth
            PC3.ScrollBar.horizontal.policy: PC3.ScrollBar.AlwaysOff

            ColumnLayout {
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

    component SectionHeader: PC3.Label {
        Layout.topMargin: Kirigami.Units.largeSpacing
        font.bold: true
        font.pixelSize: Kirigami.Theme.smallFont.pixelSize
        opacity: 0.6
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
            else if (source.startsWith(root.usageCmd) || source.startsWith(root.refreshCmd)) {
                try { root.usage = JSON.parse(data.stdout) } catch (e) {}
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
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh(false)
    }
}
