import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasma5support as Plasma5Support

PlasmoidItem {
    id: root

    readonly property bool constrained: [PlasmaCore.Types.Vertical, PlasmaCore.Types.Horizontal]
        .includes(Plasmoid.formFactor)

    Plasmoid.backgroundHints: PlasmaCore.Types.DefaultBackground | PlasmaCore.Types.ConfigurableBackground

    preferredRepresentation: compactRepresentation

    compactRepresentation: MouseArea {
        id: compactRoot

        property bool wasExpanded: false

        Layout.preferredWidth: compactRow.implicitWidth + Kirigami.Units.smallSpacing * 2
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
                text: healthApi.accessToken !== "" ? healthApi.steps.toLocaleString() : "—"
                font.bold: false
                font.pixelSize: root.constrained ? Kirigami.Units.gridUnit * 0.75 : compactRoot.height * 0.3
            }
        }
    }

    fullRepresentation: FullRepresentation {
        steps: healthApi.steps
        calories: healthApi.calories
        distance: healthApi.distance
        activeMinutes: healthApi.activeMinutes
        restingHeartRate: healthApi.restingHeartRate
        stepsGoal: Plasmoid.configuration.stepsGoal || 0
        lastUpdated: healthApi.lastUpdated
        lastUpdatedTimestamp: healthApi.lastUpdatedTimestamp
        hasToken: healthApi.accessToken !== ""
        isLoading: healthApi.isLoading
        errorMessage: healthApi.errorMessage
        distanceUnit: Plasmoid.configuration.distanceUnit || "km"
        showSteps: Plasmoid.configuration.showSteps
        showCalories: Plasmoid.configuration.showCalories
        showDistance: Plasmoid.configuration.showDistance
        showActiveMinutes: Plasmoid.configuration.showActiveMinutes
        showHeartRate: Plasmoid.configuration.showHeartRate
    }

    toolTipMainText: i18n("FitDash")
    toolTipSubText: {
        if (healthApi.accessToken === "") return i18n("Not connected");
        var unit = Plasmoid.configuration.distanceUnit || "km";
        var dist = unit === "mi" ? i18nc("distance in miles", "%1 mi", (healthApi.distance * 0.621371).toLocaleString(Qt.locale(), "f", 2))
                                 : i18nc("distance in kilometers", "%1 km", healthApi.distance.toLocaleString(Qt.locale(), "f", 2));
        return i18n("Steps: %1 | Cal: %2 | Dist: %3\nUpdated: %4",
            healthApi.steps.toLocaleString(),
            healthApi.calories.toLocaleString(),
            dist,
            healthApi.lastUpdated || "—");
    }

    Plasmoid.icon: "fitdash"


    function setLastRequest(status, state) {
        Plasmoid.configuration.lastRequestStatus = status;
        Plasmoid.configuration.lastRequestState = state;
    }

    function clearExpiredAuthorization(message) {
        var time = new Date().toLocaleTimeString();
        Plasmoid.configuration.accessToken = "";
        Plasmoid.configuration.refreshToken = "";
        Plasmoid.configuration.tokenExpiry = 0;
        healthApi.accessToken = "";
        healthApi.errorMessage = message;
        healthApi.lastRequestStatus = i18n("Authorization expired at %1 — please re-authorize", time);
        healthApi.lastRequestState = "error";
        setLastRequest(healthApi.lastRequestStatus, healthApi.lastRequestState);
    }

    function recordRefreshError(message, requiresAuthorization) {
        if (requiresAuthorization) {
            clearExpiredAuthorization(message);
            return;
        }

        var time = new Date().toLocaleTimeString();
        healthApi.errorMessage = message;
        healthApi.lastRequestStatus = i18n("Token refresh failed at %1 — %2", time, message);
        healthApi.lastRequestState = "error";
        setLastRequest(healthApi.lastRequestStatus, healthApi.lastRequestState);
    }

    Plasma5Support.DataSource {
        id: desktopFileInstaller
        engine: "executable"
        connectedSources: []
    }

    GoogleHealthApi {
        id: healthApi
        accessToken: Plasmoid.configuration.accessToken || ""

        onDataUpdated: {
            console.log("FitDash: data updated");
            Plasmoid.configuration.lastRequestStatus = healthApi.lastRequestStatus;
            Plasmoid.configuration.lastRequestState = healthApi.lastRequestState;
        }

        onAuthError: {
            console.log("FitDash: auth error, refreshing token");
            if (!Plasmoid.configuration.refreshToken) {
                clearExpiredAuthorization(i18n("No refresh token available — please re-authorize"));
                return;
            }
            healthOAuth.refreshToken(
                Plasmoid.configuration.clientId,
                Plasmoid.configuration.clientSecret,
                Plasmoid.configuration.refreshToken
            );
        }

        onError: function(message) {
            console.warn("FitDash API error:", message);
            healthApi.errorMessage = message;
            Plasmoid.configuration.lastRequestStatus = healthApi.lastRequestStatus;
            Plasmoid.configuration.lastRequestState = healthApi.lastRequestState;
        }
    }

    GoogleHealthOAuth {
        id: healthOAuth
        callbackPort: Plasmoid.configuration.callbackPort || 19847

        onAuthorized: function(tokens) {
            Plasmoid.configuration.accessToken = tokens.access_token;
            if (tokens.refresh_token) {
                Plasmoid.configuration.refreshToken = tokens.refresh_token;
            }
            if (tokens.user_id) {
                Plasmoid.configuration.userId = tokens.user_id;
            }
            Plasmoid.configuration.tokenExpiry = Math.floor(Date.now() / 1000) + (tokens.expires_in || 3600);
            healthApi.accessToken = tokens.access_token;
            setLastRequest(i18n("Token refreshed at %1", new Date().toLocaleTimeString()), "ok");
            healthApi.fetchData();
        }

        onError: function(message) {
            console.warn("FitDash OAuth error:", message);
            recordRefreshError(message, healthOAuth.lastErrorRequiresAuthorization);
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
            if (expiry > 0 && now >= expiry - 300 && Plasmoid.configuration.refreshToken !== "") {
                healthOAuth.refreshToken(
                    Plasmoid.configuration.clientId,
                    Plasmoid.configuration.clientSecret,
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
        onTriggered: healthApi.fetchData()
    }

    Connections {
        target: Plasmoid.configuration
        function onAccessTokenChanged() {
            if (Plasmoid.configuration.accessToken) {
                healthApi.accessToken = Plasmoid.configuration.accessToken;
                healthApi.fetchData();
            } else {
                healthApi.accessToken = "";
            }
        }
    }

    Component.onCompleted: {
        desktopFileInstaller.connectSource(
            "test -f \"$HOME/.local/share/applications/com.democe.fitdash.desktop\" || " +
            "(mkdir -p \"$HOME/.local/share/applications\" && " +
            "printf '[Desktop Entry]\\nName=FitDash\\nName[fr]=FitDash\\nName[es]=FitDash\\nName[nl]=FitDash\\nName[de]=FitDash\\nComment=Step counter and fitness data widget for KDE Plasma (Google Health)\\nComment[fr]=Widget de compteur de pas et de données fitness pour KDE Plasma (Google Health)\\nComment[es]=Widget de contador de pasos y datos de fitness para KDE Plasma (Google Health)\\nComment[nl]=Widget voor stappenteller en fitnessgegevens voor KDE Plasma (Google Health)\\nComment[de]=Widget für Schrittzähler und Fitnessdaten für KDE Plasma (Google Health)\\nExec=plasmawindowed com.democe.fitdash\\nIcon=fitdash\\nType=Application\\nCategories=Qt;KDE;System;\\n' " +
            "> \"$HOME/.local/share/applications/com.democe.fitdash.desktop\")"
        );

        if (Plasmoid.configuration.accessToken) {
            healthApi.fetchData();
        }
    }

    Component.onDestruction: {
        tokenRefreshTimer.stop();
        dataRefreshTimer.stop();
        healthApi.cleanup();
    }
}
