pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Caelestia
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.services

Variants {
    id: root

    model: Screens.screens

    Scope {
        id: scope

        required property ShellScreen modelData

        readonly property ScreenState screenState: ShellState.forScreen(scope.modelData)

        StyledWindow {
            id: win

            screen: scope.modelData
            name: "fullscreen-media"
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (scope.screenState?.fullscreenMedia ?? false) ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            mask: (scope.screenState?.fullscreenMedia ?? false) ? null : emptyRegion

            anchors.top: true
            anchors.bottom: true
            anchors.left: true
            anchors.right: true

            Region {
                id: emptyRegion
            }

            Content {
                screenState: scope.screenState
            }
        }
    }
}
