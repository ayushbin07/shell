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
    property alias temperature: props.temperature
    property bool ready: false

    readonly property int tempMin: 1000
    readonly property int tempMax: 6500
    readonly property int tempStep: 100

    function enable(): void {
        props.enabled = true;
    }

    function disable(): void {
        props.enabled = false;
    }

    function toggle(): void {
        props.enabled = !props.enabled;
    }

    function setTemperature(temp: int): void {
        props.temperature = Math.max(tempMin, Math.min(tempMax, temp));
        applyTimer.restart();
    }

    Timer {
        id: applyTimer

        interval: 100
        repeat: false
        onTriggered: {
            if (props.enabled) {
                Quickshell.execDetached(["sh", "-c",
                    "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.01; done; hyprsunset -t " + props.temperature.toString()
                ]);
                Toaster.toast(
                    qsTr("Eye protection"),
                    qsTr("Temperature: %1K").arg(props.temperature),
                    "nightlight"
                );
            } else {
                Toaster.toast(
                    qsTr("Eye protection"),
                    qsTr("Temperature: %1K (disabled)").arg(props.temperature),
                    "nightlight"
                );
            }
        }
    }

    onEnabledChanged: {
        if (!ready)
            return;

        applyTimer.stop();
        if (enabled) {
            Quickshell.execDetached(["sh", "-c",
                "pkill -x hyprsunset; while pgrep -x hyprsunset > /dev/null; do sleep 0.01; done; hyprsunset -t " + props.temperature.toString()
            ]);
            Toaster.toast(qsTr("Eye protection enabled"), qsTr("Blue light filter active (%1K)").arg(props.temperature), "nightlight");
        } else {
            Quickshell.execDetached(["pkill", "-x", "hyprsunset"]);
            Toaster.toast(qsTr("Eye protection disabled"), qsTr("Color temperature restored"), "nightlight");
        }
    }

    PersistentProperties {
        id: props

        property bool enabled: false
        property int temperature: 4500

        reloadableId: "nightLight"
    }

    Process {
        id: checkProc

        running: true
        command: ["pgrep", "-x", "hyprsunset"]
        onExited: code => {
            props.enabled = (code === 0);
            root.ready = true;
            running = false; // Only check once at startup; state is managed by toggle/enable/disable after that
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

        function getTemperature(): int {
            return props.temperature;
        }

        function setTemperature(temp: int): void {
            root.setTemperature(temp);
        }

        target: "nightLight"
    }
}
