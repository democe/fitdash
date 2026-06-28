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

    readonly property bool isStale: lastUpdatedTimestamp > 0 && (Date.now() - lastUpdatedTimestamp) > 3600000
    readonly property int contentPadding: Kirigami.Units.gridUnit
    readonly property real stepsProgress: stepsGoal > 0 ? Math.min(1, steps / stepsGoal) : 0

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.minimumHeight: Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredHeight: Math.max(Kirigami.Units.gridUnit * 14, contentColumn.implicitHeight + topPadding + bottomPadding)

    function formatDistance(value, unit) {
        if (unit === "mi") {
            return i18nc("distance in miles", "%1 mi", (value * 0.621371).toFixed(2));
        }
        return i18nc("distance in kilometers", "%1 km", value.toFixed(2));
    }

    function visibleMetricCount() {
        var count = 0;
        if (showSteps) count++;
        if (showCalories) count++;
        if (showDistance) count++;
        if (showActiveMinutes) count++;
        if (showHeartRate) count++;
        return count;
    }

    header: PlasmaExtras.PlasmoidHeading {
        contentItem: RowLayout {
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/fitdash.svg")
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                isMask: false
            }

            PlasmaExtras.Heading {
                level: 1
                text: i18n("FitDash")
                Layout.fillWidth: true
            }

            PlasmaComponents.Label {
                text: fullRoot.isStale ? i18n("Stale") : i18n("Today")
                visible: fullRoot.hasToken && fullRoot.lastUpdated !== ""
                color: fullRoot.isStale ? Kirigami.Theme.neutralTextColor : Kirigami.Theme.positiveTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            PlasmaComponents.BusyIndicator {
                implicitWidth: Kirigami.Units.iconSizes.smallMedium
                implicitHeight: Kirigami.Units.iconSizes.smallMedium
                running: fullRoot.isLoading
                visible: fullRoot.isLoading
            }
        }
    }

    contentItem: ColumnLayout {
        id: contentColumn

        spacing: Kirigami.Units.largeSpacing

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 10
            visible: !fullRoot.hasToken

            ColumnLayout {
                anchors.centerIn: parent
                width: Math.min(parent.width - fullRoot.contentPadding * 2, Kirigami.Units.gridUnit * 17)
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: Qt.resolvedUrl("../icons/fitdash.svg")
                    Layout.preferredWidth: Kirigami.Units.iconSizes.large
                    Layout.preferredHeight: Kirigami.Units.iconSizes.large
                    Layout.alignment: Qt.AlignHCenter
                    isMask: false
                }

                PlasmaExtras.Heading {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    level: 2
                    text: i18n("Connect Fitbit")
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                    text: i18n("Authorize your account in settings to show today's activity.")
                    wrapMode: Text.WordWrap
                    opacity: 0.72
                }

                PlasmaComponents.Button {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: Kirigami.Units.smallSpacing
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
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Kirigami.Units.gridUnit * 8
            visible: fullRoot.hasToken && fullRoot.isLoading && fullRoot.steps === 0 && fullRoot.errorMessage === ""

            ColumnLayout {
                anchors.centerIn: parent
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.BusyIndicator {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Kirigami.Units.iconSizes.large
                    implicitHeight: Kirigami.Units.iconSizes.large
                    running: true
                }

                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: i18n("Loading Fitbit data")
                    opacity: 0.72
                }
            }
        }

        ColumnLayout {
            id: statsColumn

            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.largeSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.smallSpacing
            visible: fullRoot.hasToken && (!fullRoot.isLoading || fullRoot.steps > 0)

            Kirigami.InlineMessage {
                Layout.fillWidth: true
                type: Kirigami.MessageType.Error
                text: fullRoot.errorMessage
                visible: fullRoot.errorMessage !== ""
                showCloseButton: false
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: stepsSummary.implicitHeight + Kirigami.Units.largeSpacing * 2
                radius: Kirigami.Units.smallSpacing
                color: Kirigami.Theme.alternateBackgroundColor
                border.width: 1
                border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
                visible: fullRoot.showSteps

                ColumnLayout {
                    id: stepsSummary

                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.largeSpacing
                    spacing: Kirigami.Units.smallSpacing

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.smallSpacing

                        Kirigami.Icon {
                            source: Qt.resolvedUrl("../icons/fitdash.svg")
                            Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                            Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                            isMask: false
                        }

                        PlasmaComponents.Label {
                            text: i18n("Steps")
                            opacity: 0.72
                            Layout.fillWidth: true
                        }

                        PlasmaComponents.Label {
                            text: fullRoot.stepsGoal > 0
                                ? i18nc("step goal progress", "%1%", Math.round(fullRoot.stepsProgress * 100))
                                : ""
                            visible: text !== ""
                            color: Kirigami.Theme.positiveTextColor
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    PlasmaExtras.Heading {
                        Layout.fillWidth: true
                        level: 1
                        text: fullRoot.steps.toLocaleString()
                    }

                    PlasmaComponents.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(fullRoot.stepsGoal, fullRoot.steps, 1)
                        value: fullRoot.steps
                        visible: fullRoot.stepsGoal > 0
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: fullRoot.stepsGoal > 0
                            ? i18n("%1 remaining of %2", Math.max(0, fullRoot.stepsGoal - fullRoot.steps).toLocaleString(), fullRoot.stepsGoal.toLocaleString())
                            : i18n("No step goal set")
                        font.pointSize: Kirigami.Theme.smallFont.pointSize
                        opacity: 0.65
                    }
                }
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                visible: fullRoot.visibleMetricCount() > (fullRoot.showSteps ? 1 : 0)

                MetricTile {
                    visible: fullRoot.showCalories
                    Layout.fillWidth: true
                    title: i18n("Calories")
                    value: fullRoot.calories.toLocaleString()
                    iconName: "speedometer"
                }

                MetricTile {
                    visible: fullRoot.showDistance
                    Layout.fillWidth: true
                    title: i18n("Distance")
                    value: fullRoot.formatDistance(fullRoot.distance, fullRoot.distanceUnit)
                    iconName: "map"
                }

                MetricTile {
                    visible: fullRoot.showActiveMinutes
                    Layout.fillWidth: true
                    title: i18n("Active")
                    value: i18nc("active minutes", "%1 min", fullRoot.activeMinutes)
                    iconName: "chronometer"
                }

                MetricTile {
                    visible: fullRoot.showHeartRate
                    Layout.fillWidth: true
                    title: i18n("Resting HR")
                    value: fullRoot.restingHeartRate > 0
                        ? i18nc("heart rate in beats per minute", "%1 bpm", fullRoot.restingHeartRate)
                        : "—"
                    iconName: "heart"
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                visible: fullRoot.lastUpdated !== ""
                spacing: Kirigami.Units.smallSpacing

                Kirigami.Icon {
                    source: "view-history"
                    Layout.preferredWidth: Kirigami.Units.iconSizes.small
                    Layout.preferredHeight: Kirigami.Units.iconSizes.small
                    opacity: fullRoot.isStale ? 0.45 : 0.6
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: i18n("Updated %1", fullRoot.lastUpdated)
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: fullRoot.isStale ? 0.45 : 0.6
                    elide: Text.ElideRight
                }
            }
        }
    }

    component MetricTile: Rectangle {
        id: tile

        property string title
        property string value
        property string iconName

        Layout.preferredHeight: Kirigami.Units.gridUnit * 3.6
        radius: Kirigami.Units.smallSpacing
        color: Kirigami.Theme.backgroundColor
        border.width: 1
        border.color: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.10)

        RowLayout {
            anchors.fill: parent
            anchors.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: tile.iconName
                Layout.preferredWidth: Kirigami.Units.iconSizes.smallMedium
                Layout.preferredHeight: Kirigami.Units.iconSizes.smallMedium
                opacity: 0.75
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: tile.title
                    font.pointSize: Kirigami.Theme.smallFont.pointSize
                    opacity: 0.65
                    elide: Text.ElideRight
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: tile.value
                    font.bold: true
                    elide: Text.ElideRight
                }
            }
        }
    }
}
