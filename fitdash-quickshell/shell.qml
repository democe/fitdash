// Standalone Quickshell entry point.
// Run with:  quickshell -p /path/to/fitdash-quickshell/
//
// Creates a minimal top panel showing the FitDash bar widget.
// Click the widget to open the full popup; use Settings inside the popup
// to connect your Fitbit account.
//
// ── Noctalia integration (instead of running this standalone) ────────────────
// In your Noctalia bar file, import this directory and add FitDashWidget to
// your bar's RowLayout:
//
//   import "../fitdash-quickshell" as FitDash
//
//   RowLayout {
//       // ... other widgets ...
//       FitDash.FitDashWidget {
//           scaling: barScale  // optional, defaults to 1.0
//       }
//   }
// ─────────────────────────────────────────────────────────────────────────────

import QtQuick
import QtQuick.Layouts
import Quickshell

ShellRoot {
    PanelWindow {
        id: panel
        anchors.top:   true
        anchors.left:  true
        anchors.right: true
        implicitHeight: 40

        Rectangle {
            anchors.fill: parent
            color: "#CC1a1a2e"

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin:  8
                anchors.rightMargin: 8

                Item { Layout.fillWidth: true }

                FitDashWidget {
                    scaling: 1.0
                }

                Item { Layout.fillWidth: true }
            }
        }
    }
}
