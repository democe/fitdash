import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configRoot

    property alias cfg_clientId: clientIdField.text
    property alias cfg_refreshInterval: refreshIntervalSpinBox.value
    property string cfg_accessToken
    property string cfg_refreshToken
    property string cfg_userId
    property int cfg_tokenExpiry
    property string cfg_distanceUnit: "km"
    property alias cfg_callbackPort: callbackPortSpinBox.value
    property string cfg_lastRequestStatus
    property alias cfg_showSteps: showStepsCheckBox.checked
    property alias cfg_showCalories: showCaloriesCheckBox.checked
    property alias cfg_showDistance: showDistanceCheckBox.checked
    property alias cfg_showActiveMinutes: showActiveMinutesCheckBox.checked
    property alias cfg_showHeartRate: showHeartRateCheckBox.checked

    // Default value properties expected by Plasma's config loader
    property string cfg_clientIdDefault: ""
    property int cfg_refreshIntervalDefault: 15
    property string cfg_accessTokenDefault: ""
    property string cfg_refreshTokenDefault: ""
    property string cfg_userIdDefault: ""
    property int cfg_tokenExpiryDefault: 0
    property string cfg_distanceUnitDefault: "km"
    property int cfg_callbackPortDefault: 19847
    property string cfg_lastRequestStatusDefault: ""
    property bool cfg_showStepsDefault: true
    property bool cfg_showCaloriesDefault: true
    property bool cfg_showDistanceDefault: true
    property bool cfg_showActiveMinutesDefault: true
    property bool cfg_showHeartRateDefault: true

    property bool authInProgress: false
    property string authStatusMessage: ""
    property bool authStatusIsError: false

    Kirigami.FormLayout {
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

        Item { Kirigami.FormData.isSection: true }

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

        Item { Kirigami.FormData.isSection: true }

        QQC2.CheckBox {
            id: showStepsCheckBox
            Kirigami.FormData.label: i18n("Visible data:")
            text: i18n("Steps")
            checked: true
        }

        QQC2.CheckBox {
            id: showCaloriesCheckBox
            text: i18n("Calories")
            checked: true
        }

        QQC2.CheckBox {
            id: showDistanceCheckBox
            text: i18n("Distance")
            checked: true
        }

        QQC2.CheckBox {
            id: showActiveMinutesCheckBox
            text: i18n("Active Minutes")
            checked: true
        }

        QQC2.CheckBox {
            id: showHeartRateCheckBox
            text: i18n("Resting Heart Rate")
            checked: true
        }

        Item { Kirigami.FormData.isSection: true }

        RowLayout {
            Kirigami.FormData.label: i18n("Fitbit Account:")

            QQC2.Label {
                text: cfg_accessToken !== "" ? i18n("Authorized (User: %1)", cfg_userId || "unknown") : i18n("Not authorized")
                color: cfg_accessToken !== "" ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.negativeTextColor
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Last request:")
            text: cfg_lastRequestStatus || i18n("No requests yet")
            color: cfg_lastRequestStatus.indexOf("OK") === 0 ? Kirigami.Theme.positiveTextColor
                 : cfg_lastRequestStatus === "" ? Kirigami.Theme.textColor
                 : Kirigami.Theme.negativeTextColor
            visible: cfg_accessToken !== ""
        }

        QQC2.Button {
            id: authorizeButton
            text: configRoot.authInProgress
                ? i18n("Authorizing…")
                : (cfg_accessToken !== "" ? i18n("Re-authorize with Fitbit") : i18n("Authorize with Fitbit"))
            icon.name: "network-connect"
            enabled: clientIdField.text !== "" && clientIdField.acceptableInput && !configRoot.authInProgress

            onClicked: {
                configRoot.authInProgress = true;
                configRoot.authStatusMessage = "";
                authHelper.authorize(clientIdField.text);
            }
        }

        QQC2.Label {
            visible: configRoot.authStatusMessage !== ""
            text: configRoot.authStatusMessage
            color: configRoot.authStatusIsError ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.positiveTextColor
            wrapMode: Text.WordWrap
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
