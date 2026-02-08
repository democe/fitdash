import QtQuick
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami

ColumnLayout {
    id: fullRoot

    property int steps: 0
    property int calories: 0
    property real distance: 0.0
    property int activeMinutes: 0
    property int restingHeartRate: 0
    property int stepsGoal: 0
    property string lastUpdated: ""
    property real lastUpdatedTimestamp: 0
    property bool hasToken: false
    property bool isLoading: false
    property string errorMessage: ""
    property string distanceUnit: "km"
    property bool showSteps: true
    property bool showCalories: true
    property bool showDistance: true
    property bool showActiveMinutes: true
    property bool showHeartRate: true

    function formatDistance(value, unit) {
        if (unit === "mi") {
            return (value * 0.621371).toFixed(2) + " mi";
        }
        return value.toFixed(2) + " km";
    }

    readonly property bool isStale: {
        if (lastUpdatedTimestamp <= 0) return false;
        return (Date.now() - lastUpdatedTimestamp) > 3600000;
    }

    Layout.preferredWidth: Kirigami.Units.gridUnit * 18
    Layout.preferredHeight: Kirigami.Units.gridUnit * 16
    spacing: Kirigami.Units.largeSpacing

    PlasmaComponents.Label {
        text: "FitDash"
        font.bold: true
        font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.4
        Layout.alignment: Qt.AlignHCenter
    }

    // Error message
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: Kirigami.Units.largeSpacing
        Layout.rightMargin: Kirigami.Units.largeSpacing
        visible: fullRoot.errorMessage !== ""

        Kirigami.Icon {
            source: "dialog-warning-symbolic"
            Layout.preferredWidth: Kirigami.Units.iconSizes.small
            Layout.preferredHeight: Kirigami.Units.iconSizes.small
            color: Kirigami.Theme.negativeTextColor
        }

        PlasmaComponents.Label {
            text: fullRoot.errorMessage
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    // Loading indicator
    PlasmaComponents.BusyIndicator {
        Layout.alignment: Qt.AlignHCenter
        running: fullRoot.isLoading
        visible: fullRoot.isLoading
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: Kirigami.Units.smallSpacing
        visible: fullRoot.hasToken

        GridLayout {
            columns: 2
            columnSpacing: Kirigami.Units.largeSpacing
            rowSpacing: Kirigami.Units.smallSpacing
            Layout.fillWidth: true

            PlasmaComponents.Label { text: i18n("Steps"); font.bold: true; visible: fullRoot.showSteps }
            PlasmaComponents.Label {
                text: fullRoot.steps.toLocaleString() + (fullRoot.stepsGoal > 0 ? " / " + fullRoot.stepsGoal.toLocaleString() : "")
                visible: fullRoot.showSteps
            }

            PlasmaComponents.Label { text: i18n("Calories"); font.bold: true; visible: fullRoot.showCalories }
            PlasmaComponents.Label {
                text: fullRoot.calories.toLocaleString()
                visible: fullRoot.showCalories
            }

            PlasmaComponents.Label { text: i18n("Distance"); font.bold: true; visible: fullRoot.showDistance }
            PlasmaComponents.Label {
                text: fullRoot.formatDistance(fullRoot.distance, fullRoot.distanceUnit)
                visible: fullRoot.showDistance
            }

            PlasmaComponents.Label { text: i18n("Active Min"); font.bold: true; visible: fullRoot.showActiveMinutes }
            PlasmaComponents.Label {
                text: fullRoot.activeMinutes + " min"
                visible: fullRoot.showActiveMinutes
            }

            PlasmaComponents.Label { text: i18n("Resting HR"); font.bold: true; visible: fullRoot.showHeartRate }
            PlasmaComponents.Label {
                text: fullRoot.restingHeartRate > 0 ? fullRoot.restingHeartRate + " bpm" : "—"
                visible: fullRoot.showHeartRate
            }
        }

        PlasmaComponents.Label {
            text: fullRoot.lastUpdated ? i18n("Updated: %1", fullRoot.lastUpdated) : ""
            font.pointSize: Kirigami.Theme.smallFont.pointSize
            opacity: 0.7
            Layout.alignment: Qt.AlignHCenter
            visible: text !== ""
        }
    }

    PlasmaComponents.Label {
        text: i18n("Configure your Fitbit account in settings to get started.")
        wrapMode: Text.WordWrap
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignHCenter
        horizontalAlignment: Text.AlignHCenter
        visible: !fullRoot.hasToken
    }
}
