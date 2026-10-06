import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.kirigami as Kirigami

PlasmaExtras.Representation {
    id: fullRoot

    property real steps: NaN
    property real calories: NaN
    property real distance: NaN
    property real activeMinutes: NaN
    property real restingHeartRate: NaN
    property real sleepMinutes: NaN
    property real oxygenSaturation: NaN
    property real heartRateVariability: NaN
    property real respiratoryRate: NaN
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
    property bool showSleep: true
    property bool showOxygenSaturation: true
    property bool showHeartRateVariability: true
    property bool showRespiratoryRate: true

    readonly property bool anyVitalsVisible: showHeartRate || showSleep || showOxygenSaturation
        || showHeartRateVariability || showRespiratoryRate

    // Bindings don't re-evaluate as time passes, so tick a clock for isStale.
    property real now: Date.now()
    readonly property bool isStale: lastUpdatedTimestamp > 0 && (now - lastUpdatedTimestamp) > 3600000

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: fullRoot.now = Date.now()
    }
    readonly property int contentPadding: Kirigami.Units.gridUnit
    readonly property bool hasSteps: !isNaN(steps)
    readonly property real stepsProgress: stepsGoal > 0 && hasSteps ? Math.min(1, steps / stepsGoal) : 0

    Layout.minimumWidth: Kirigami.Units.gridUnit * 18
    Layout.preferredWidth: Kirigami.Units.gridUnit * 22
    // Pin the popup height to its content so it grows/shrinks as tiles toggle.
    readonly property real fittedHeight: (header ? header.implicitHeight : 0)
        + contentColumn.implicitHeight + topPadding + bottomPadding
    Layout.minimumHeight: fittedHeight
    Layout.preferredHeight: fittedHeight
    Layout.maximumHeight: fittedHeight

    function formatDistance(value, unit) {
        if (isNaN(value)) return "—";
        if (unit === "mi") {
            return i18nc("distance in miles", "%1 mi", (value * 0.621371).toLocaleString(Qt.locale(), "f", 2));
        }
        return i18nc("distance in kilometers", "%1 km", value.toLocaleString(Qt.locale(), "f", 2));
    }

    function formatSleep(minutes) {
        if (isNaN(minutes)) return "—";
        return i18nc("sleep duration in hours and minutes", "%1h %2m", Math.floor(minutes / 60), minutes % 60);
    }

    function visibleMetricCount() {
        var count = 0;
        if (showSteps) count++;
        if (showCalories) count++;
        if (showDistance) count++;
        if (showActiveMinutes) count++;
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
                    text: i18n("Connect Google Health")
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
            visible: fullRoot.hasToken && fullRoot.isLoading && !fullRoot.hasSteps && fullRoot.errorMessage === ""

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
                    text: i18n("Loading Google Health data")
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
            visible: fullRoot.hasToken && (!fullRoot.isLoading || fullRoot.hasSteps)

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
                            text: fullRoot.stepsGoal > 0 && fullRoot.hasSteps
                                ? i18nc("step goal progress", "%1%", Math.round(fullRoot.stepsProgress * 100))
                                : ""
                            visible: text !== ""
                            font.pointSize: Kirigami.Theme.smallFont.pointSize
                        }
                    }

                    PlasmaExtras.Heading {
                        Layout.fillWidth: true
                        level: 1
                        text: fullRoot.hasSteps ? fullRoot.steps.toLocaleString() : "—"
                    }

                    PlasmaComponents.ProgressBar {
                        Layout.fillWidth: true
                        from: 0
                        to: Math.max(fullRoot.stepsGoal, fullRoot.hasSteps ? fullRoot.steps : 0, 1)
                        value: fullRoot.hasSteps ? fullRoot.steps : 0
                        visible: fullRoot.stepsGoal > 0
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        text: !fullRoot.hasSteps ? i18n("No data yet")
                            : fullRoot.stepsGoal > 0
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
                    value: isNaN(fullRoot.calories) ? "—" : fullRoot.calories.toLocaleString()
                    iconName: "speedometer"
                }

                MetricTile {
                    visible: fullRoot.showDistance
                    Layout.fillWidth: true
                    title: i18n("Distance")
                    value: fullRoot.formatDistance(fullRoot.distance, fullRoot.distanceUnit)
                    iconName: Qt.resolvedUrl("../icons/metric-distance.svg")
                }

                MetricTile {
                    visible: fullRoot.showActiveMinutes
                    Layout.fillWidth: true
                    title: i18n("Active")
                    value: isNaN(fullRoot.activeMinutes) ? "—" : i18nc("active minutes", "%1 min", fullRoot.activeMinutes)
                    iconName: "chronometer"
                }
            }

            PlasmaComponents.Label {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.smallSpacing
                text: i18n("Vitals")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.65
                visible: fullRoot.anyVitalsVisible
            }

            GridLayout {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: Kirigami.Units.smallSpacing
                rowSpacing: Kirigami.Units.smallSpacing
                visible: fullRoot.anyVitalsVisible

                MetricTile {
                    visible: fullRoot.showSleep
                    Layout.fillWidth: true
                    title: i18n("Sleep")
                    value: fullRoot.formatSleep(fullRoot.sleepMinutes)
                    iconName: "weather-clear-night"
                }

                MetricTile {
                    visible: fullRoot.showHeartRate
                    Layout.fillWidth: true
                    title: i18n("Resting HR")
                    value: !isNaN(fullRoot.restingHeartRate)
                        ? i18nc("heart rate in beats per minute", "%1 bpm", fullRoot.restingHeartRate)
                        : "—"
                    iconName: Qt.resolvedUrl("../icons/metric-heart.svg")
                }

                MetricTile {
                    visible: fullRoot.showOxygenSaturation
                    Layout.fillWidth: true
                    title: i18n("SpO2")
                    value: !isNaN(fullRoot.oxygenSaturation)
                        ? i18nc("blood oxygen saturation percentage", "%1%", fullRoot.oxygenSaturation.toLocaleString(Qt.locale(), "f", 1))
                        : "—"
                    iconName: Qt.resolvedUrl("../icons/metric-oxygen.svg")
                }

                MetricTile {
                    visible: fullRoot.showHeartRateVariability
                    Layout.fillWidth: true
                    title: i18n("HRV")
                    value: !isNaN(fullRoot.heartRateVariability)
                        ? i18nc("heart rate variability in milliseconds", "%1 ms", Math.round(fullRoot.heartRateVariability))
                        : "—"
                    iconName: "office-chart-line"
                }

                MetricTile {
                    visible: fullRoot.showRespiratoryRate
                    Layout.fillWidth: true
                    title: i18n("Breathing")
                    value: !isNaN(fullRoot.respiratoryRate)
                        ? i18nc("respiratory rate in breaths per minute", "%1 br/min", fullRoot.respiratoryRate.toLocaleString(Qt.locale(), "f", 1))
                        : "—"
                    iconName: Qt.resolvedUrl("../icons/metric-breathing.svg")
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
        property var iconName

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
                // Bundled SVGs are monochrome; tint them with the theme text color.
                isMask: tile.iconName.toString().endsWith(".svg")
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
