import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root

    readonly property bool constrained: [PlasmaCore.Types.Vertical, PlasmaCore.Types.Horizontal]
        .includes(Plasmoid.formFactor)

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    preferredRepresentation: compactRepresentation

    compactRepresentation: MouseArea {
        id: compactRoot

        property bool wasExpanded: false

        Layout.preferredWidth: root.constrained
            ? compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
            : -1
        Layout.fillHeight: true
        Layout.fillWidth: !root.constrained

        hoverEnabled: true

        onPressed: wasExpanded = root.expanded
        onClicked: root.expanded = !wasExpanded

        RowLayout {
            id: compactRow
            anchors.centerIn: parent
            spacing: Kirigami.Units.smallSpacing

            Kirigami.Icon {
                source: Qt.resolvedUrl("../icons/fitdash.svg")
                Layout.preferredWidth: root.constrained
                    ? Kirigami.Units.iconSizes.smallMedium
                    : compactRoot.height * 0.6
                Layout.preferredHeight: root.constrained
                    ? Kirigami.Units.iconSizes.smallMedium
                    : compactRoot.height * 0.6
            }

            PlasmaComponents.Label {
                id: stepLabel
                text: fitbitApi.accessToken !== "" ? fitbitApi.steps.toLocaleString() : "—"
                font.bold: false
                font.pixelSize: root.constrained ? -1 : compactRoot.height * 0.3
            }
        }
    }

    fullRepresentation: FullRepresentation {
        steps: fitbitApi.steps
        calories: fitbitApi.calories
        distance: fitbitApi.distance
        activeMinutes: fitbitApi.activeMinutes
        restingHeartRate: fitbitApi.restingHeartRate
        stepsGoal: fitbitApi.stepsGoal
        lastUpdated: fitbitApi.lastUpdated
        lastUpdatedTimestamp: fitbitApi.lastUpdatedTimestamp
        hasToken: fitbitApi.accessToken !== ""
        isLoading: fitbitApi.isLoading
        errorMessage: fitbitApi.errorMessage
        distanceUnit: Plasmoid.configuration.distanceUnit || "km"
        showSteps: Plasmoid.configuration.showSteps
        showCalories: Plasmoid.configuration.showCalories
        showDistance: Plasmoid.configuration.showDistance
        showActiveMinutes: Plasmoid.configuration.showActiveMinutes
        showHeartRate: Plasmoid.configuration.showHeartRate
    }

    toolTipMainText: i18n("FitDash")
    toolTipSubText: {
        if (fitbitApi.accessToken === "") return i18n("Not connected");
        var unit = Plasmoid.configuration.distanceUnit || "km";
        var dist = unit === "mi" ? (fitbitApi.distance * 0.621371).toFixed(2) + " mi"
                                 : fitbitApi.distance.toFixed(2) + " km";
        return i18n("Steps: %1 | Cal: %2 | Dist: %3\nUpdated: %4",
            fitbitApi.steps.toLocaleString(),
            fitbitApi.calories.toLocaleString(),
            dist,
            fitbitApi.lastUpdated || "—");
    }

    Plasmoid.icon: Qt.resolvedUrl("../icons/fitdash.svg")

    FitbitApi {
        id: fitbitApi
        accessToken: Plasmoid.configuration.accessToken || ""

        onDataUpdated: {
            console.log("FitDash: data updated");
            Plasmoid.configuration.lastRequestStatus = fitbitApi.lastRequestStatus;
        }

        onAuthError: {
            console.log("FitDash: auth error, refreshing token");
            fitbitOAuth.refreshToken(
                Plasmoid.configuration.clientId,
                Plasmoid.configuration.refreshToken
            );
        }

        onError: function(message) {
            console.warn("FitDash API error:", message);
            fitbitApi.errorMessage = message;
            Plasmoid.configuration.lastRequestStatus = fitbitApi.lastRequestStatus;
        }
    }

    FitbitOAuth {
        id: fitbitOAuth
        callbackPort: Plasmoid.configuration.callbackPort || 19847

        onAuthorized: function(tokens) {
            Plasmoid.configuration.accessToken = tokens.access_token;
            Plasmoid.configuration.refreshToken = tokens.refresh_token;
            Plasmoid.configuration.userId = tokens.user_id || "";
            Plasmoid.configuration.tokenExpiry = Math.floor(Date.now() / 1000) + (tokens.expires_in || 28800);
            fitbitApi.accessToken = tokens.access_token;
            fitbitApi.fetchData();
        }

        onError: function(message) {
            console.warn("FitDash OAuth error:", message);
        }
    }

    Timer {
        id: tokenRefreshTimer
        interval: 60000
        repeat: true
        running: Plasmoid.configuration.refreshToken !== ""

        onTriggered: {
            var now = Math.floor(Date.now() / 1000);
            var expiry = Plasmoid.configuration.tokenExpiry;
            if (expiry > 0 && now >= expiry - 300) {
                fitbitOAuth.refreshToken(
                    Plasmoid.configuration.clientId,
                    Plasmoid.configuration.refreshToken
                );
            }
        }
    }

    Timer {
        id: dataRefreshTimer
        interval: (Plasmoid.configuration.refreshInterval || 15) * 60000
        repeat: true
        running: Plasmoid.configuration.accessToken !== ""
        onTriggered: fitbitApi.fetchData()
    }

    Connections {
        target: Plasmoid.configuration
        function onAccessTokenChanged() {
            if (Plasmoid.configuration.accessToken) {
                fitbitApi.accessToken = Plasmoid.configuration.accessToken;
                fitbitApi.fetchData();
            }
        }
    }

    Component.onCompleted: {
        if (Plasmoid.configuration.accessToken) {
            fitbitApi.fetchData();
        }
    }

    Component.onDestruction: {
        tokenRefreshTimer.stop();
        dataRefreshTimer.stop();
    }
}
