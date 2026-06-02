import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell

// Full fitness data view. Floats independently; position is compositor-managed.
// Triggered by clicking FitDashWidget in the bar.
FloatingWindow {
    id: popup

    required property var fitConfig
    required property var fitbitApi

    signal openConfig()

    width:  300
    height: implicitContent.implicitHeight + 32
    title:  "FitDash"
    color:  "#1e1e2e"

    // ── Helpers ───────────────────────────────────────────────────────────────

    function formatDistance(value, unit) {
        if (unit === "mi") return (value * 0.621371).toFixed(2) + " mi"
        return value.toFixed(2) + " km"
    }

    readonly property bool isStale: {
        if (fitbitApi.lastUpdatedTimestamp <= 0) return false
        return (Date.now() - fitbitApi.lastUpdatedTimestamp) > 3600000
    }

    // ── Content ───────────────────────────────────────────────────────────────

    ColumnLayout {
        id: implicitContent
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.margins: 16
        spacing: 10

        // Title
        Controls.Label {
            text:            "FitDash"
            font.bold:       true
            font.pixelSize:  18
            Layout.alignment: Qt.AlignHCenter
        }

        // Error banner
        RowLayout {
            Layout.fillWidth: true
            visible: fitbitApi.errorMessage !== ""

            Controls.Label {
                text:      "⚠  " + fitbitApi.errorMessage
                color:     "#f38ba8"
                wrapMode:  Text.WordWrap
                Layout.fillWidth: true
            }
        }

        // Stale data warning
        Controls.Label {
            visible:        popup.isStale
            text:           "Data may be outdated"
            color:          "#fab387"
            font.pixelSize: 11
            opacity:        0.8
            Layout.alignment: Qt.AlignHCenter
        }

        // Loading indicator
        Controls.BusyIndicator {
            Layout.alignment: Qt.AlignHCenter
            running: fitbitApi.isLoading
            visible: fitbitApi.isLoading
        }

        // ── Stats grid ────────────────────────────────────────────────────────
        GridLayout {
            columns:       2
            columnSpacing: 16
            rowSpacing:    6
            Layout.fillWidth: true
            visible: fitConfig.accessToken !== "" && !fitbitApi.isLoading

            Controls.Label { text: "Steps";      font.bold: true; visible: fitConfig.showSteps }
            Controls.Label {
                text: fitbitApi.steps.toLocaleString()
                    + (fitbitApi.stepsGoal > 0 ? "  /  " + fitbitApi.stepsGoal.toLocaleString() : "")
                visible: fitConfig.showSteps
            }

            Controls.Label { text: "Calories";   font.bold: true; visible: fitConfig.showCalories }
            Controls.Label { text: fitbitApi.calories.toLocaleString(); visible: fitConfig.showCalories }

            Controls.Label { text: "Distance";   font.bold: true; visible: fitConfig.showDistance }
            Controls.Label {
                text:    popup.formatDistance(fitbitApi.distance, fitConfig.distanceUnit)
                visible: fitConfig.showDistance
            }

            Controls.Label { text: "Active Min"; font.bold: true; visible: fitConfig.showActiveMinutes }
            Controls.Label { text: fitbitApi.activeMinutes + " min"; visible: fitConfig.showActiveMinutes }

            Controls.Label { text: "Resting HR"; font.bold: true; visible: fitConfig.showHeartRate }
            Controls.Label {
                text:    fitbitApi.restingHeartRate > 0 ? fitbitApi.restingHeartRate + " bpm" : "—"
                visible: fitConfig.showHeartRate
            }
        }

        // Last updated
        Controls.Label {
            text:           fitbitApi.lastUpdated ? "Updated " + fitbitApi.lastUpdated : ""
            font.pixelSize: 11
            opacity:        0.55
            Layout.alignment: Qt.AlignHCenter
            visible:        text !== ""
        }

        // Not-connected prompt
        Controls.Label {
            text:       "Connect your Fitbit account in Settings."
            wrapMode:   Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            visible:    fitConfig.accessToken === ""
        }

        // ── Action buttons ────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true

            Controls.Button {
                text:    "Settings"
                onClicked: popup.openConfig()
                Layout.fillWidth: true
            }

            Controls.Button {
                text:    "Refresh"
                enabled: fitConfig.accessToken !== "" && !fitbitApi.isLoading
                onClicked: fitbitApi.fetchData()
            }

            Controls.Button {
                text:    "Close"
                onClicked: popup.visible = false
            }
        }

        Item { implicitHeight: 4 }
    }
}
