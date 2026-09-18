pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia
import Caelestia.Config
import qs.services

Singleton {
    id: root

    property alias enabled: props.enabled
    property bool ready: false

    function enable(): void {
        props.enabled = true;
    }

    function disable(): void {
        props.enabled = false;
    }

    function toggle(): void {
        props.enabled = !props.enabled;
    }

    onEnabledChanged: {
        if (!ready)
            return;

        if (enabled) {
            Quickshell.execDetached(["hyprsunset", "-t", "4500"]);
            Toaster.toast(qsTr("Eye protection enabled"), qsTr("Blue light filter active (4500K)"), "nightlight");
        } else {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
            Toaster.toast(qsTr("Eye protection disabled"), qsTr("Color temperature restored"), "nightlight");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: false

        reloadableId: "nightLight"
    }

    Process {
        id: checkProc

        running: true
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => {
            props.enabled = (code === 0);
            root.ready = true;
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            root.toggle();
        }

        function enable(): void {
            root.enable();
        }

        function disable(): void {
            root.disable();
        }

        target: "nightLight"
    }
}
