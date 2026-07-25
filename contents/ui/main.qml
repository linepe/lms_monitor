import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    readonly property string lmsExecutable: "~/.lmstudio/bin/lms"
    readonly property int pollIntervalMs: 5000

    property bool modelLoaded: false
    property string statusText: "Checking..."
    property bool checkInFlight: false
    property bool unloadInProgress: false
    property string currentCommand: ""
    property string rawOutput: ""

    Plasma5Support.DataSource {
        id: executable
        engine: "executable"
        connectedSources: []

        onNewData: function(sourceName, data) {
            disconnectSource(sourceName); // one-shot per run

            var exitCode = data["exit code"];
            var stdout = data["stdout"] ? data["stdout"].toString() : "";

            if (root.currentCommand === "unload") {
                root.unloadInProgress = false;
                if (exitCode !== 0) {
                    console.log("[LMS Unload] ERROR: exit=" + exitCode);
                    root.statusText = "Unload Failed";
                } else {
                    console.log("[LMS Unload] OK");
                    root.modelLoaded = false;
                    root.statusText = "Model Unloaded";
                }
                root.currentCommand = "";
                return;
            }

            // status check (default path)
            root.checkInFlight = false;
            root.currentCommand = "";

            if (exitCode !== 0 || !stdout || stdout.trim() === "") {
                console.log("[LMS Status] ERROR: exit=" + exitCode + " stdout empty=" + (!stdout));
                root.modelLoaded = false;
                root.statusText = "Error";
                root.rawOutput = "";
                return;
            }

            root.rawOutput = stdout;

            if (stdout.indexOf("Loaded Models") !== -1) {
                root.modelLoaded = true;
                root.statusText = "Model Loaded";
            } else {
                root.modelLoaded = false;
                root.statusText = "No Model";
            }
        }
    }

    function runStatusCheck() {
        if (root.checkInFlight) return;
        root.checkInFlight = true;
        root.currentCommand = "status";
        executable.connectSource(root.lmsExecutable + " status");
    }

    function runUnload() {
        if (root.unloadInProgress) return;
        root.unloadInProgress = true;
        root.currentCommand = "unload";
        executable.connectSource(root.lmsExecutable + " unload");
    }

    Timer {
        interval: root.pollIntervalMs
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.runStatusCheck()
    }

    toolTipMainText: "LM Studio"
    toolTipSubText: root.statusText

    // ---- Compact panel representation: minimalist robot glyph ----
    compactRepresentation: Canvas {
        id: robotCanvas
        Layout.preferredWidth: PlasmaCore.Units.iconSizes.smallMedium
        Layout.preferredHeight: PlasmaCore.Units.iconSizes.smallMedium

        readonly property color glyphColor: "#FFFFFF"

        function drawRoundedRectPath(ctx, x, y, w, h, r) {
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

            // antenna knob
            var knobR = 2;
            var knobCx = width / 2;
            var knobCy = height * 0.05 + knobR;
            ctx.fillStyle = glyphColor;
            ctx.beginPath();
            ctx.arc(knobCx, knobCy, knobR, 0, Math.PI * 2);
            ctx.fill();

            // antenna stalk
            var stalkY = knobCy + knobR;
            var stalkH = height * 0.18;
            ctx.fillRect(width / 2 - 1, stalkY, 2, stalkH);

            // head
            var headW = width * 0.72;
            var headH = height * 0.6;
            var headX = (width - headW) / 2;
            var headY = height * 0.32;
            var headR = headW * 0.2;

            drawRoundedRectPath(ctx, headX, headY, headW, headH, headR);
            if (root.modelLoaded) {
                ctx.fillStyle = glyphColor;
                ctx.fill();
            } else {
                ctx.strokeStyle = glyphColor;
                ctx.lineWidth = 2;
                ctx.stroke();
            }

            // eyes
            var eyeR = 1.5;
            var eyeY = headY + headH / 2;
            var eyeLeftX = headX + headW * 0.22 + eyeR;
            var eyeRightX = headX + headW * 0.78 - eyeR;

            if (root.modelLoaded) {
                // real cutout — erases pixels rather than painting over them
                ctx.save();
                ctx.globalCompositeOperation = "destination-out";
                ctx.beginPath();
                ctx.arc(eyeLeftX, eyeY, eyeR, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(eyeRightX, eyeY, eyeR, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();
            } else {
                ctx.fillStyle = glyphColor;
                ctx.beginPath();
                ctx.arc(eyeLeftX, eyeY, eyeR, 0, Math.PI * 2);
                ctx.fill();
                ctx.beginPath();
                ctx.arc(eyeRightX, eyeY, eyeR, 0, Math.PI * 2);
                ctx.fill();
            }
        }

        Connections {
            target: root
            function onModelLoadedChanged() { robotCanvas.requestPaint(); }
        }

        Component.onCompleted: requestPaint()

        MouseArea {
            anchors.fill: parent
            onClicked: root.expanded = !root.expanded
        }
    }

    // ---- Expanded popup representation ----
    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: PlasmaCore.Units.gridUnit * 22
        Layout.preferredHeight: PlasmaCore.Units.gridUnit * 14
        spacing: PlasmaCore.Units.smallSpacing

        PlasmaComponents.Label {
            text: "LM Studio Status"
            font.bold: true
        }

        RowLayout {
            Rectangle {
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                radius: 4
                color: root.modelLoaded ? "#4CAF50" : "#F44336"
            }
            PlasmaComponents.Label {
                text: root.statusText
            }
        }

        PlasmaComponents.Label {
            text: "Details:"
            font.bold: true
            Layout.topMargin: PlasmaCore.Units.smallSpacing
            visible: root.rawOutput !== ""
        }

        PlasmaComponents.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.rawOutput !== ""

            PlasmaComponents.Label {
                width: parent.width
                text: root.rawOutput
                wrapMode: Text.Wrap
                font.family: "monospace"
                font.pixelSize: 11
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: PlasmaCore.Units.smallSpacing

            PlasmaComponents.Button {
                Layout.fillWidth: true
                text: "Check Now"
                enabled: !root.checkInFlight && !root.unloadInProgress
                onClicked: root.runStatusCheck()
            }

            PlasmaComponents.Button {
                Layout.fillWidth: true
                text: "Unload"
                enabled: !root.unloadInProgress && !root.checkInFlight
                onClicked: root.runUnload()
            }
        }
    }
}
