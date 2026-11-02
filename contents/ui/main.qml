import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    readonly property string baseUrl: (Plasmoid.configuration.lmsUrl || "http://127.0.0.1:1234").replace(/\/+$/, "")
    readonly property string apiKey: Plasmoid.configuration.lmsApiKey || ""
    readonly property int intervalMs: Math.max(5, Plasmoid.configuration.refreshInterval) * 1000

    // [{ name: string, instances: [{ id: string }] }]
    property var models: []
    property bool reachable: false
    property bool checkInFlight: false
    property string errorText: ""

    readonly property var loadedModels: models.filter(function(m) { return m.instances.length > 0 })
    readonly property int loadedCount: loadedModels.length

    Plasmoid.hasConfigurationInterface: true

    toolTipMainText: "LM Studio"
    toolTipSubText: !reachable ? (errorText || i18n("Unreachable"))
                  : loadedCount === 0 ? i18n("No model loaded")
                  : i18np("%1 model loaded", "%1 models loaded", loadedCount)

    // ---- helpers ----
    function sq(s) { return "'" + String(s).replace(/'/g, "'\\''") + "'"; }

    function curlCmd(extraArgs, path) {
        var cmd = "curl -sf -m 10";
        if (root.apiKey !== "")
            cmd += " -H " + sq("Authorization: Bearer " + root.apiKey);
        return cmd + " " + extraArgs + " " + sq(root.baseUrl + path);
    }

    function refresh() {
        if (checkInFlight) return;
        checkInFlight = true;
        executable.connectSource(curlCmd("", "/api/v1/models"));
    }

    function unload(instanceId) {
        var body = JSON.stringify({ instance_id: instanceId });
        executable.connectSource(curlCmd("-X POST -H 'Content-Type: application/json' -d " + sq(body),
                                         "/api/v1/models/unload"));
    }

    function parseModels(text) {
        var data = JSON.parse(text);
        if (data && data.error) throw new Error(data.error.message || String(data.error));
        var list = Array.isArray(data) ? data : (data.models || data.data || []);
        return list.map(function(m) {
            var insts = (m.loaded_instances || []).map(function(i) {
                return { id: i.instance_id || i.id || i.model_id || "" };
            }).filter(function(i) { return i.id !== ""; });
            return { name: m.display_name || m.key || m.model_id || m.id || "?", instances: insts };
        });
    }

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName);
            var exitCode = data["exit code"];
            var stdout = data["stdout"] ? data["stdout"].toString().trim() : "";
            var isUnload = sourceName.indexOf("/api/v1/models/unload") !== -1;

            if (isUnload) {
                var failed = exitCode !== 0;
                if (!failed && stdout !== "") {
                    try { failed = !!JSON.parse(stdout).error; } catch (e) { /* non-JSON ok */ }
                }
                if (failed) root.errorText = i18n("Unload failed");
                root.checkInFlight = false;
                root.refresh();
                return;
            }

            root.checkInFlight = false;
            if (exitCode !== 0 || stdout === "") {
                root.reachable = false;
                root.models = [];
                root.errorText = i18n("Unreachable (curl exit %1)", exitCode);
                return;
            }
            try {
                root.models = root.parseModels(stdout);
                root.reachable = true;
                root.errorText = "";
            } catch (e) {
                root.reachable = false;
                root.models = [];
                root.errorText = i18n("Bad response: %1", e.message);
            }
        }
    }

    Timer {
        interval: root.intervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Connections {
        target: Plasmoid.configuration
        function onLmsUrlChanged() { root.refresh(); }
        function onLmsApiKeyChanged() { root.refresh(); }
    }

    // ---- compact: robot glyph, filled when something is loaded ----
    compactRepresentation: Canvas {
        id: robotCanvas
        // keep the slot square: follow the panel's thickness, never stretch
        readonly property bool vertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical
        Layout.minimumWidth: vertical ? 0 : height
        Layout.minimumHeight: vertical ? width : 0
        Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
        Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium

        readonly property color glyphColor: Kirigami.Theme.textColor
        readonly property bool active: root.reachable && root.loadedCount > 0
        onGlyphColorChanged: requestPaint()
        onActiveChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        function roundedRect(ctx, x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.lineTo(x + w - r, y);
            ctx.arcTo(x + w, y, x + w, y + r, r);
            ctx.lineTo(x + w, y + h - r);
            ctx.arcTo(x + w, y + h, x + w - r, y + h, r);
            ctx.lineTo(x + r, y + h);
            ctx.arcTo(x, y + h, x, y + h - r, r);
            ctx.lineTo(x, y + r);
            ctx.arcTo(x, y, x + r, y, r);
            ctx.closePath();
        }

        onPaint: {
            var ctx = getContext("2d");
            ctx.reset();
            ctx.clearRect(0, 0, width, height);
            // draw in a centered square so the glyph keeps its proportions
            var side = Math.min(width, height);
            ctx.translate((width - side) / 2, (height - side) / 2);
            ctx.globalAlpha = root.reachable ? 1.0 : 0.4;
            ctx.fillStyle = glyphColor;
            ctx.strokeStyle = glyphColor;

            var knobR = Math.max(1.5, side * 0.07), cx = side / 2, knobCy = side * 0.04 + knobR;
            ctx.beginPath();
            ctx.arc(cx, knobCy, knobR, 0, Math.PI * 2);
            ctx.fill();
            ctx.fillRect(cx - 1, knobCy + knobR, 2, side * 0.12);

            var headW = side * 0.8, headH = side * 0.62;
            var headX = (side - headW) / 2, headY = side * 0.3;
            ctx.lineWidth = Math.max(1.5, side * 0.09);
            roundedRect(ctx, headX, headY, headW, headH, headH * 0.45);
            if (active) { ctx.fill(); } else { ctx.stroke(); }

            var eyeR = Math.max(1.5, side * 0.07), eyeY = headY + headH / 2;
            var ex1 = headX + headW * 0.3, ex2 = headX + headW * 0.7;
            ctx.save();
            if (active) ctx.globalCompositeOperation = "destination-out";
            ctx.beginPath(); ctx.arc(ex1, eyeY, eyeR, 0, Math.PI * 2); ctx.fill();
            ctx.beginPath(); ctx.arc(ex2, eyeY, eyeR, 0, Math.PI * 2); ctx.fill();
            ctx.restore();
        }

        Component.onCompleted: requestPaint()

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ---- popup ----
    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 22
        Layout.preferredHeight: Kirigami.Units.gridUnit * 14
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Kirigami.Heading {
                level: 4
                text: "LM Studio"
                Layout.fillWidth: true
            }
            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                enabled: !root.checkInFlight
                onClicked: root.refresh()
                PlasmaComponents.ToolTip { text: i18n("Refresh") }
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.errorText !== ""
            text: root.errorText
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.Wrap
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            visible: root.reachable && root.loadedCount === 0
            text: i18n("No model loaded")
            opacity: 0.7
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.reachable
            model: root.loadedModels
            spacing: Kirigami.Units.smallSpacing

            delegate: ColumnLayout {
                width: list.width
                required property var modelData
                spacing: 0

                PlasmaComponents.Label {
                    text: modelData.name
                    font.bold: true
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
                Repeater {
                    model: modelData.instances
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        PlasmaComponents.Label {
                            text: modelData.id
                            elide: Text.ElideMiddle
                            opacity: 0.7
                            Layout.fillWidth: true
                        }
                        PlasmaComponents.Button {
                            text: i18n("Unload")
                            icon.name: "media-eject"
                            onClicked: root.unload(modelData.id)
                        }
                    }
                }
            }
        }
    }
}
