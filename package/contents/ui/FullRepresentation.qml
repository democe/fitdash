import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
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

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 6
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: {
        var contentH = statsColumn.visible ? statsColumn.implicitHeight : Kirigami.Units.gridUnit * 8;
        var headerH = header.implicitHeight;
        return contentH + headerH + topPadding + bottomPadding;
    }

    function formatDistance(value, unit) {
        if (unit === "mi") {
            return i18nc("distance in miles", "%1 mi", (value * 0.621371).toFixed(2));
        }
        return i18nc("distance in kilometers", "%1 km", value.toFixed(2));
    }

    readonly property bool isStale: lastUpdatedTimestamp > 0 && (Date.now() - lastUpdatedTimestamp) > 3600000

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                level: 1
                text: i18n("FitDash")
                Layout.fillWidth: true
            }

            PlasmaComponents.BusyIndicator {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                running: fullRoot.isLoading
                visible: fullRoot.isLoading
            }
        }
    }

    contentItem: Item {
        implicitHeight: statsColumn.visible ? statsColumn.implicitHeight : Kirigami.Units.gridUnit * 8

        // Not connected
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: !fullRoot.hasToken
            spacing: Kirigami.Units.largeSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/fitdash.svg")
                Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                Layout.alignment: Qt.AlignHCenter
                isMask: false
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: i18n("Not connected to Fitbit")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: i18n("Authorize your Fitbit account in Settings to see your fitness data.")
                wrapMode: Text.WordWrap
                opacity: 0.7
            }

            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                icon.name: "configure"
                text: i18n("Open Settings")
                onClicked: {
                    Plasmoid.expanded = false;
                    Qt.callLater(function() {
                        var action = Plasmoid.internalAction("configure");
                        if (action) action.trigger();
                    });
                }
            }
        }

        // Loading with no data yet
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - Kirigami.Units.gridUnit * 4
            visible: fullRoot.hasToken && fullRoot.isLoading && fullRoot.steps === 0 && fullRoot.errorMessage === ""
            spacing: Kirigami.Units.largeSpacing

            PlasmaComponents.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: Kirigami.Units.iconSizes.huge
                implicitHeight: Kirigami.Units.iconSizes.huge
                running: true
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: i18n("Loading…")
                font.pointSize: Kirigami.Theme.defaultFont.pointSize + 2
            }
        }

        // Stats
        ColumnLayout {
            id: statsColumn
            anchors.left: parent.left
            anchors.right: parent.right
            visible: fullRoot.hasToken && (!fullRoot.isLoading || fullRoot.steps > 0)
            spacing: Kirigami.Units.smallSpacing

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                text: fullRoot.errorMessage
                visible: fullRoot.errorMessage !== ""
                showCloseButton: false
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.largeSpacing
                rowSpacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: i18n("Steps")
                    opacity: 0.7
                    visible: fullRoot.showSteps
                }
                PlasmaComponents.Label {
                    text: fullRoot.steps.toLocaleString()
                         + (fullRoot.stepsGoal > 0 ? " / " + fullRoot.stepsGoal.toLocaleString() : "")
                    visible: fullRoot.showSteps
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: i18n("Calories")
                    opacity: 0.7
                    visible: fullRoot.showCalories
                }
                PlasmaComponents.Label {
                    text: fullRoot.calories.toLocaleString()
                    visible: fullRoot.showCalories
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: i18n("Distance")
                    opacity: 0.7
                    visible: fullRoot.showDistance
                }
                PlasmaComponents.Label {
                    text: fullRoot.formatDistance(fullRoot.distance, fullRoot.distanceUnit)
                    visible: fullRoot.showDistance
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: i18n("Active minutes")
                    opacity: 0.7
                    visible: fullRoot.showActiveMinutes
                }
                PlasmaComponents.Label {
                    text: i18nc("active minutes", "%1 min", fullRoot.activeMinutes)
                    visible: fullRoot.showActiveMinutes
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: i18n("Resting HR")
                    opacity: 0.7
                    visible: fullRoot.showHeartRate
                }
                PlasmaComponents.Label {
                    text: fullRoot.restingHeartRate > 0
                        ? i18nc("heart rate in beats per minute", "%1 bpm", fullRoot.restingHeartRate)
                        : "—"
                    visible: fullRoot.showHeartRate
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    Layout.columnSpan: 2
                    Layout.alignment: Qt.AlignHCenter
                    text: fullRoot.lastUpdated ? i18n("Updated: %1", fullRoot.lastUpdated) : ""
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: fullRoot.isStale ? 0.4 : 0.6
                    visible: text !== ""
                }
            }
        }
    }
}
