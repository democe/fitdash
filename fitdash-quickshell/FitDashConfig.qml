import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as Controls
import Quickshell

// Settings window. Shares the FitbitOAuth instance from FitDashWidget so
// there is only ever one auth process running at a time.
FloatingWindow {
    id: configWin

    required property var fitConfig
    required property var oauth

    property bool   authInProgress: false
    property string authStatus: ""
    property bool   authStatusIsError: false

    width:  420
    height: 560
    title:  "FitDash — Settings"
    color:  "#1e1e2e"

    // Keep local SpinBox / ComboBox in sync when config loads asynchronously
    Connections {
        target: fitConfig
        function onRefreshIntervalChanged() { refreshIntervalBox.value = fitConfig.refreshInterval }
        function onCallbackPortChanged()    { callbackPortBox.value    = fitConfig.callbackPort }
        function onDistanceUnitChanged()    {
            distanceUnitBox.currentIndex = fitConfig.distanceUnit === "mi" ? 1 : 0
        }
    }

    // Listen for auth results from the shared OAuth object
    Connections {
        target: oauth

        function onAuthorized(tokens) {
            configWin.authInProgress  = false
            configWin.authStatusIsError = false
            configWin.authStatus      = "Authorization successful!"
        }

        function onError(message) {
            configWin.authInProgress  = false
            configWin.authStatusIsError = true
            configWin.authStatus      = message
        }
    }

    // ── Content ───────────────────────────────────────────────────────────────

    Controls.ScrollView {
        anchors.fill:    parent
        anchors.margins: 16
        contentWidth:    availableWidth

        ColumnLayout {
            width:   parent.width
            spacing: 10

            // ── Client ID ─────────────────────────────────────────────────────
            Controls.Label { text: "Fitbit Client ID"; font.bold: true }

            Controls.TextField {
                id: clientIdField
                Layout.fillWidth: true
                placeholderText:  "From dev.fitbit.com/apps"
                text:             fitConfig.clientId
                validator: RegularExpressionValidator { regularExpression: /^[A-Za-z0-9]*$/ }
                onTextEdited: fitConfig.clientId = text
            }

            Controls.Label {
                text:           "OAuth 2.0 Client ID from your Fitbit app registration"
                font.pixelSize: 11
                opacity:        0.65
            }

            // ── Callback URL ──────────────────────────────────────────────────
            Controls.Label { text: "Callback URL"; font.bold: true }

            RowLayout {
                Layout.fillWidth: true

                Controls.TextField {
                    id:           callbackUrlDisplay
                    Layout.fillWidth: true
                    readOnly:     true
                    text:         "http://localhost:" + fitConfig.callbackPort + "/callback"
                }

                Controls.Button {
                    text: "Copy"
                    onClicked: {
                        callbackUrlDisplay.selectAll()
                        callbackUrlDisplay.copy()
                        callbackUrlDisplay.deselect()
                    }
                }
            }

            Controls.Label {
                text:           "Paste this URL into your Fitbit app settings at dev.fitbit.com"
                font.pixelSize: 11
                opacity:        0.65
            }

            // ── Callback port ─────────────────────────────────────────────────
            Controls.Label { text: "Callback Port"; font.bold: true }

            Controls.SpinBox {
                id:    callbackPortBox
                from:  1024
                to:    65535
                value: fitConfig.callbackPort
                onValueModified: fitConfig.callbackPort = value
            }

            // ── Refresh interval ──────────────────────────────────────────────
            Controls.Label { text: "Refresh Interval (minutes)"; font.bold: true }

            Controls.SpinBox {
                id:    refreshIntervalBox
                from:  5
                to:    60
                value: fitConfig.refreshInterval
                onValueModified: fitConfig.refreshInterval = value
            }

            Controls.Label {
                text:           "Recommended: 15–30 min to stay within Fitbit rate limits"
                font.pixelSize: 11
                opacity:        0.65
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: "#44ffffff" }

            // ── Distance unit ─────────────────────────────────────────────────
            Controls.Label { text: "Distance Unit"; font.bold: true }

            Controls.ComboBox {
                id:           distanceUnitBox
                model:        ["Kilometers (km)", "Miles (mi)"]
                currentIndex: fitConfig.distanceUnit === "mi" ? 1 : 0
                onActivated: fitConfig.distanceUnit = currentIndex === 1 ? "mi" : "km"
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: "#44ffffff" }

            // ── Visible data ──────────────────────────────────────────────────
            Controls.Label { text: "Visible Data"; font.bold: true }

            Controls.CheckBox {
                text:    "Steps"
                checked: fitConfig.showSteps
                onCheckedChanged: fitConfig.showSteps = checked
            }
            Controls.CheckBox {
                text:    "Calories"
                checked: fitConfig.showCalories
                onCheckedChanged: fitConfig.showCalories = checked
            }
            Controls.CheckBox {
                text:    "Distance"
                checked: fitConfig.showDistance
                onCheckedChanged: fitConfig.showDistance = checked
            }
            Controls.CheckBox {
                text:    "Active Minutes"
                checked: fitConfig.showActiveMinutes
                onCheckedChanged: fitConfig.showActiveMinutes = checked
            }
            Controls.CheckBox {
                text:    "Resting Heart Rate"
                checked: fitConfig.showHeartRate
                onCheckedChanged: fitConfig.showHeartRate = checked
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: "#44ffffff" }

            // ── Account status ────────────────────────────────────────────────
            Controls.Label { text: "Fitbit Account"; font.bold: true }

            Controls.Label {
                text:  fitConfig.accessToken !== ""
                    ? "Authorized — User: " + (fitConfig.userId || "unknown")
                    : "Not authorized"
                color: fitConfig.accessToken !== "" ? "#a6e3a1" : "#f38ba8"
            }

            Controls.Label {
                text:           fitConfig.lastRequestStatus || "No requests yet"
                font.pixelSize: 11
                opacity:        0.65
                wrapMode:       Text.WordWrap
                Layout.fillWidth: true
                visible:        fitConfig.accessToken !== ""
            }

            Controls.Button {
                Layout.fillWidth: true
                text: configWin.authInProgress
                    ? "Cancel Authorization"
                    : (fitConfig.accessToken !== "" ? "Re-authorize with Fitbit" : "Authorize with Fitbit")
                enabled: configWin.authInProgress
                    || (clientIdField.text !== "" && clientIdField.acceptableInput)

                onClicked: {
                    if (configWin.authInProgress) {
                        oauth.cancelAuthorization()
                        return
                    }
                    configWin.authInProgress = true
                    configWin.authStatus     = ""
                    oauth.authorize(clientIdField.text)
                }
            }

            Controls.Label {
                visible:   configWin.authStatus !== ""
                text:      configWin.authStatus
                color:     configWin.authStatusIsError ? "#f38ba8" : "#a6e3a1"
                wrapMode:  Text.WordWrap
                Layout.fillWidth: true
            }

            Rectangle { height: 1; Layout.fillWidth: true; color: "#44ffffff" }

            // ── Footer buttons ────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true

                Controls.Button {
                    text:    "Save & Close"
                    Layout.fillWidth: true
                    onClicked: { fitConfig.save(); configWin.visible = false }
                }

                Controls.Button {
                    text:     "Cancel"
                    onClicked: configWin.visible = false
                }
            }

            Item { implicitHeight: 4 }
        }
    }
}
