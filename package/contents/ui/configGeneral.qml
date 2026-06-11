import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: configRoot
    title: i18n("General")

    property alias cfg_clientId: clientIdField.text
    property alias cfg_refreshInterval: refreshIntervalSpinBox.value
    property string cfg_accessToken
    property string cfg_refreshToken
    property string cfg_userId
    property int cfg_tokenExpiry
    property string cfg_distanceUnit: "km"
    property alias cfg_callbackPort: callbackPortSpinBox.value
    property string cfg_lastRequestStatus
    property string cfg_lastRequestState
    property alias cfg_showSteps: showStepsCheckBox.checked
    property alias cfg_showCalories: showCaloriesCheckBox.checked
    property alias cfg_showDistance: showDistanceCheckBox.checked
    property alias cfg_showActiveMinutes: showActiveMinutesCheckBox.checked
    property alias cfg_showHeartRate: showHeartRateCheckBox.checked

    property string cfg_clientIdDefault: ""
    property int cfg_refreshIntervalDefault: 15
    property string cfg_accessTokenDefault: ""
    property string cfg_refreshTokenDefault: ""
    property string cfg_userIdDefault: ""
    property int cfg_tokenExpiryDefault: 0
    property string cfg_distanceUnitDefault: "km"
    property int cfg_callbackPortDefault: 19847
    property string cfg_lastRequestStatusDefault: ""
    property string cfg_lastRequestStateDefault: "unknown"
    property bool cfg_showStepsDefault: true
    property bool cfg_showCaloriesDefault: true
    property bool cfg_showDistanceDefault: true
    property bool cfg_showActiveMinutesDefault: true
    property bool cfg_showHeartRateDefault: true

    property bool authInProgress: false
    property string authStatusMessage: ""
    property bool authStatusIsError: false

    // Manual copy+paste fallback flow.
    property bool manualAuthActive: false
    property string manualAuthUrl: ""

    function accountStatusText() {
        if (cfg_accessToken === "" && cfg_refreshToken === "") {
            return i18n("Not authorized");
        }
        if (cfg_lastRequestState === "error") {
            return i18n("Authorization problem — re-authorize");
        }
        if (cfg_tokenExpiry > 0 && Math.floor(Date.now() / 1000) >= cfg_tokenExpiry) {
            return i18n("Token expired — refresh needed");
        }
        return i18n("Authorized (User: %1)", cfg_userId || i18n("unknown"));
    }

    function accountStatusColor() {
        if (cfg_accessToken === "" && cfg_refreshToken === "") {
            return Kirigami.Theme.negativeTextColor;
        }
        if (cfg_lastRequestState === "error" || (cfg_tokenExpiry > 0 && Math.floor(Date.now() / 1000) >= cfg_tokenExpiry)) {
            return Kirigami.Theme.negativeTextColor;
        }
        if (cfg_lastRequestState === "warn") {
            return Kirigami.Theme.neutralTextColor;
        }
        return Kirigami.Theme.positiveTextColor;
    }

    ColumnLayout {
        width: parent.width
        spacing: 0

        Kirigami.FormLayout {
            Layout.fillWidth: true

            QQC2.TextField {
                id: clientIdField
                Kirigami.FormData.label: i18n("Client ID:")
                placeholderText: i18n("From dev.fitbit.com/apps")
                validator: RegularExpressionValidator { regularExpression: /^[A-Za-z0-9]+$/ }
            }

            QQC2.Label {
                text: i18n("OAuth 2.0 Client ID from your Fitbit app registration")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }

            RowLayout {
                Kirigami.FormData.label: i18n("Callback URL:")

                QQC2.TextField {
                    id: callbackUrlField
                    text: "http://localhost:" + callbackPortSpinBox.value + "/callback"
                    readOnly: true
                    Layout.fillWidth: true
                }

                QQC2.Button {
                    icon.name: "edit-copy"
                    QQC2.ToolTip.text: i18n("Copy to clipboard")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        callbackUrlField.selectAll();
                        callbackUrlField.copy();
                        callbackUrlField.deselect();
                    }
                }
            }

            QQC2.SpinBox {
                id: callbackPortSpinBox
                Kirigami.FormData.label: i18n("Callback port:")
                from: 1024
                to: 65535
                value: 19847
            }

            QQC2.Label {
                text: i18n("Paste the callback URL into your Fitbit app settings at dev.fitbit.com")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }

            QQC2.SpinBox {
                id: refreshIntervalSpinBox
                Kirigami.FormData.label: i18n("Refresh interval (minutes):")
                from: 5
                to: 60
                value: 15
            }

            QQC2.Label {
                text: i18n("Recommended: 15–30 minutes to stay within Fitbit rate limits")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Display")
            }

            QQC2.ComboBox {
                id: distanceUnitComboBox
                Kirigami.FormData.label: i18n("Distance unit:")
                model: [
                    { text: i18n("Kilometers (km)"), value: "km" },
                    { text: i18n("Miles (mi)"), value: "mi" }
                ]
                textRole: "text"
                currentIndex: cfg_distanceUnit === "mi" ? 1 : 0
                onActivated: function(index) {
                    cfg_distanceUnit = model[index].value;
                }
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Visible Metrics")
            }

            QQC2.CheckBox {
                id: showStepsCheckBox
                Kirigami.FormData.label: i18n("Steps:")
                checked: true
            }

            QQC2.CheckBox {
                id: showCaloriesCheckBox
                Kirigami.FormData.label: i18n("Calories:")
                checked: true
            }

            QQC2.CheckBox {
                id: showDistanceCheckBox
                Kirigami.FormData.label: i18n("Distance:")
                checked: true
            }

            QQC2.CheckBox {
                id: showActiveMinutesCheckBox
                Kirigami.FormData.label: i18n("Active minutes:")
                checked: true
            }

            QQC2.CheckBox {
                id: showHeartRateCheckBox
                Kirigami.FormData.label: i18n("Resting heart rate:")
                checked: true
            }

            Kirigami.Separator {
                Kirigami.FormData.isSection: true
                Kirigami.FormData.label: i18n("Fitbit Account")
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Status:")
                text: configRoot.accountStatusText()
                color: configRoot.accountStatusColor()
            }

            QQC2.Label {
                Kirigami.FormData.label: i18n("Last request:")
                text: cfg_lastRequestStatus || i18n("No requests yet")
                color: cfg_lastRequestState === "ok" ? Kirigami.Theme.positiveTextColor
                     : cfg_lastRequestState === "warn" ? Kirigami.Theme.neutralTextColor
                     : cfg_lastRequestState === "error" ? Kirigami.Theme.negativeTextColor
                     : Kirigami.Theme.textColor
                visible: cfg_accessToken !== "" || cfg_refreshToken !== "" || cfg_lastRequestStatus !== ""
            }

            QQC2.Button {
                Kirigami.FormData.label: i18n("Authorization:")
                text: configRoot.authInProgress
                    ? i18n("Cancel")
                    : (cfg_accessToken !== "" ? i18n("Re-authorize with Fitbit") : i18n("Authorize with Fitbit"))
                icon.name: configRoot.authInProgress ? "dialog-cancel" : "network-connect"
                enabled: configRoot.authInProgress || (clientIdField.text !== "" && clientIdField.acceptableInput)

                onClicked: {
                    if (configRoot.authInProgress) {
                        authHelper.cancelAuthorization();
                        return;
                    }
                    configRoot.authInProgress = true;
                    configRoot.authStatusMessage = "";
                    authHelper.authorize(clientIdField.text);
                }
            }

            QQC2.Button {
                text: i18n("Authorize manually (copy & paste)")
                icon.name: "edit-paste"
                visible: !configRoot.manualAuthActive
                enabled: clientIdField.text !== "" && clientIdField.acceptableInput
                QQC2.ToolTip.text: i18n("Use this if the browser can't reach localhost (sandboxed browser, remote session, or no Python)")
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                onClicked: {
                    configRoot.authStatusMessage = "";
                    var url = authHelper.beginManualAuthorization(clientIdField.text);
                    if (url !== "") {
                        configRoot.manualAuthUrl = url;
                        configRoot.manualAuthActive = true;
                        Qt.openUrlExternally(url);
                    }
                }
            }

            QQC2.Label {
                visible: configRoot.manualAuthActive
                Kirigami.FormData.label: i18n("Step 1:")
                text: i18n("Open this URL in a browser and approve access:")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }

            RowLayout {
                visible: configRoot.manualAuthActive
                Kirigami.FormData.label: i18n("Authorization URL:")

                QQC2.TextField {
                    id: manualUrlField
                    text: configRoot.manualAuthUrl
                    readOnly: true
                    Layout.fillWidth: true
                }

                QQC2.Button {
                    icon.name: "edit-copy"
                    QQC2.ToolTip.text: i18n("Copy to clipboard")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        manualUrlField.selectAll();
                        manualUrlField.copy();
                        manualUrlField.deselect();
                    }
                }

                QQC2.Button {
                    icon.name: "globe"
                    QQC2.ToolTip.text: i18n("Open in browser")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: Qt.openUrlExternally(configRoot.manualAuthUrl)
                }
            }

            QQC2.Label {
                visible: configRoot.manualAuthActive
                Kirigami.FormData.label: i18n("Step 2:")
                text: i18n("After approving, copy the address bar URL and paste it below:")
                font.pointSize: Kirigami.Theme.smallFont.pointSize
                opacity: 0.7
            }

            RowLayout {
                visible: configRoot.manualAuthActive
                Kirigami.FormData.label: i18n("Redirect URL or code:")

                QQC2.TextField {
                    id: manualCodeField
                    placeholderText: i18n("http://localhost:…/callback?code=…")
                    Layout.fillWidth: true
                    onAccepted: completeManualButton.clicked()
                }

                QQC2.Button {
                    id: completeManualButton
                    text: i18n("Complete")
                    icon.name: "dialog-ok-apply"
                    enabled: manualCodeField.text !== ""
                    onClicked: authHelper.completeManualAuthorization(clientIdField.text, manualCodeField.text)
                }

                QQC2.Button {
                    icon.name: "dialog-cancel"
                    QQC2.ToolTip.text: i18n("Cancel manual authorization")
                    QQC2.ToolTip.visible: hovered
                    QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay
                    onClicked: {
                        configRoot.manualAuthActive = false;
                        manualCodeField.text = "";
                    }
                }
            }
        }

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            Layout.leftMargin: Kirigami.Units.largeSpacing
            Layout.rightMargin: Kirigami.Units.largeSpacing
            Layout.topMargin: Kirigami.Units.smallSpacing
            Layout.bottomMargin: Kirigami.Units.largeSpacing
            visible: configRoot.authStatusMessage !== ""
            text: configRoot.authStatusMessage
            type: configRoot.authStatusIsError ? Kirigami.MessageType.Error : Kirigami.MessageType.Positive
            showCloseButton: true
            onVisibleChanged: {
                if (!visible) configRoot.authStatusMessage = "";
            }
        }
    }

    FitbitOAuth {
        id: authHelper
        callbackPort: callbackPortSpinBox.value

        onAuthorized: function(tokens) {
            cfg_accessToken = tokens.access_token;
            cfg_refreshToken = tokens.refresh_token;
            cfg_userId = tokens.user_id || "";
            cfg_tokenExpiry = Math.floor(Date.now() / 1000) + (tokens.expires_in || 28800);
            configRoot.authInProgress = false;
            configRoot.manualAuthActive = false;
            configRoot.authStatusIsError = false;
            configRoot.authStatusMessage = i18n("Authorization successful!");
        }

        onError: function(message) {
            configRoot.authInProgress = false;
            configRoot.authStatusIsError = true;
            configRoot.authStatusMessage = message;
        }
    }
}
