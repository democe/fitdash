import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls

// ─────────────────────────────────────────────────────────────────────────────
// FitDashWidget — compact bar item for Noctalia / any Quickshell PanelWindow.
//
// Noctalia integration:
//   1. Drop this directory into your shell config alongside Noctalia.
//   2. Import it:  import "../fitdash-quickshell" as FitDash
//   3. Place in your bar RowLayout:  FitDash.FitDashWidget { scaling: barScale }
//
// The popup (FitDashPopup) and config window (FitDashConfig) are FloatingWindows
// instantiated as children — they require a ShellRoot ancestor, which Noctalia
// and the standalone shell.qml both provide.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    // Noctalia widget identity
    property string key:  "fitdash"
    property string name: "FitDash"

    // Set by Noctalia's ScalingService; default 1.0 for standalone use
    property real scaling: 1.0

    implicitWidth:  row.implicitWidth + 12 * scaling
    implicitHeight: 32 * scaling

    // ── Logic layer ───────────────────────────────────────────────────────────

    Config { id: fitConfig }

    FitbitApi {
        id: fitbitApi
        accessToken: fitConfig.accessToken

        onDataUpdated: {
            fitConfig.lastRequestStatus = lastRequestStatus
            fitConfig.lastRequestState  = lastRequestState
            fitConfig.save()
        }

        onAuthError: {
            fitbitOAuth.refreshToken(fitConfig.clientId, fitConfig.refreshToken)
        }

        onError: function(msg) {
            fitConfig.lastRequestStatus = lastRequestStatus
            fitConfig.lastRequestState  = lastRequestState
            fitConfig.save()
        }
    }

    FitbitOAuth {
        id: fitbitOAuth
        callbackPort: fitConfig.callbackPort

        onAuthorized: function(tokens) {
            fitConfig.accessToken  = tokens.access_token
            fitConfig.refreshToken = tokens.refresh_token
            fitConfig.userId       = tokens.user_id || ""
            fitConfig.tokenExpiry  = Math.floor(Date.now() / 1000) + (tokens.expires_in || 28800)
            fitConfig.save()
            fitbitApi.accessToken = tokens.access_token
            fitbitApi.fetchData()
        }

        onError: function(msg) {
            console.warn("FitDash OAuth:", msg)
        }
    }

    // Refresh the access token ~5 min before expiry
    Timer {
        interval: 60000
        repeat:   true
        running:  fitConfig.refreshToken !== ""

        onTriggered: {
            var now = Math.floor(Date.now() / 1000)
            if (fitConfig.tokenExpiry > 0 && now >= fitConfig.tokenExpiry - 300) {
                fitbitOAuth.refreshToken(fitConfig.clientId, fitConfig.refreshToken)
            }
        }
    }

    // Periodic data refresh
    Timer {
        interval: Math.max(fitConfig.refreshInterval, 5) * 60000
        repeat:   true
        running:  fitConfig.accessToken !== ""
        onTriggered: fitbitApi.fetchData()
    }

    Component.onCompleted: {
        if (fitConfig.accessToken) fitbitApi.fetchData()
    }

    // ── Compact bar UI ────────────────────────────────────────────────────────

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: popup.visible = !popup.visible

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 5 * root.scaling

            Image {
                source:   Qt.resolvedUrl("icons/fitdash.svg")
                width:    16 * root.scaling
                height:   16 * root.scaling
                fillMode: Image.PreserveAspectFit
                smooth:   true
            }

            Controls.Label {
                text:            fitConfig.accessToken !== "" ? fitbitApi.steps.toLocaleString() : "—"
                font.pixelSize:  13 * root.scaling
                verticalAlignment: Text.AlignVCenter
            }

            // Subtle loading dot
            Rectangle {
                width:   6 * root.scaling
                height:  6 * root.scaling
                radius:  3 * root.scaling
                color:   "dodgerblue"
                opacity: fitbitApi.isLoading ? 0.9 : 0
                Behavior on opacity { NumberAnimation { duration: 200 } }
            }
        }
    }

    // ── Popup (full view) ─────────────────────────────────────────────────────

    FitDashPopup {
        id: popup
        visible: false
        fitConfig: fitConfig
        fitbitApi: fitbitApi
        onOpenConfig: {
            popup.visible = false
            configWin.visible = true
        }
    }

    // ── Settings window ───────────────────────────────────────────────────────

    FitDashConfig {
        id: configWin
        visible: false
        fitConfig: fitConfig
        oauth:     fitbitOAuth
    }
}
