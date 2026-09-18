pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.services
import qs.utils

Item {
    id: root

    required property var content
    required property ScreenState screenState
    required property var panels
    required property real maxHeight
    required property SearchBar search
    required property int padding
    required property int rounding

    readonly property bool showWallpapers: search.text.startsWith(`${GlobalConfig.launcher.actionPrefix}wallpaper `)
    readonly property var currentList: showWallpapers ? wallpaperList.item : appList.item // Can be either ListView or PathView, so can't type properly
    property string animState: showWallpapers ? "wallpapers" : "apps"
    readonly property bool isWebSearch: root.state === "apps" && root.search.text.trim().length > 0 && !root.search.text.startsWith(GlobalConfig.launcher.actionPrefix)

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom

    clip: true
    state: animState

    states: [
        State {
            name: "apps"

            PropertyChanges {
                root.implicitWidth: root.Tokens.sizes.launcher.itemWidth
                root.implicitHeight: Math.min(root.maxHeight, appList.implicitHeight > 0 ? appList.implicitHeight : empty.implicitHeight)
                appList.active: true
            }

            AnchorChanges {
                anchors.left: root.parent.left
                anchors.right: root.parent.right
            }
        },
        State {
            name: "wallpapers"

            PropertyChanges {
                root.implicitWidth: Math.max(root.Tokens.sizes.launcher.itemWidth * 1.2, wallpaperList.implicitWidth)
                root.implicitHeight: root.Tokens.sizes.launcher.wallpaperHeight
                wallpaperList.active: true
            }
        }
    ]

    Behavior on animState {
        SequentialAnimation {
            Anim {
                target: root
                property: "opacity"
                from: 1
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: root
                property: "opacity"
                from: 0
                to: 1
                type: Anim.DefaultEffects
            }
        }
    }

    Loader {
        id: appList

        active: false

        anchors.fill: parent

        sourceComponent: AppList {
            objectName: "launcherAppList"

            search: root.search
            screenState: root.screenState
        }
    }

    Loader {
        id: wallpaperList

        asynchronous: true
        active: false

        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter

        sourceComponent: WallpaperList {
            objectName: "launcherWallpaperList"

            search: root.search
            screenState: root.screenState
            panels: root.panels
            content: root.content
        }
    }

    Item {
        id: empty

        opacity: root.currentList?.count === 0 ? 1 : 0
        scale: root.currentList?.count === 0 ? 1 : 0.5

        implicitWidth: emptyRow.implicitWidth + (root.isWebSearch ? Tokens.padding.large * 2 : 0)
        implicitHeight: emptyRow.implicitHeight + (root.isWebSearch ? Tokens.padding.medium * 2 : 0)

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter

        StateLayer {
            id: stateLayer

            visible: root.isWebSearch
            radius: Tokens.rounding.large
            onClicked: {
                Quickshell.execDetached(["xdg-open", `https://www.google.com/search?q=${encodeURIComponent(root.search.text.trim())}`]);
                root.screenState.launcher = false;
            }
        }

        Row {
            id: emptyRow

            anchors.centerIn: parent
            spacing: Tokens.spacing.medium
            padding: root.isWebSearch ? 0 : Tokens.padding.large

            MaterialIcon {
                text: root.state === "wallpapers" ? "wallpaper_slideshow" : (root.isWebSearch ? "travel_explore" : "manage_search")
                color: root.isWebSearch ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant
                fontStyle: Tokens.font.icon.extraLarge

                anchors.verticalCenter: parent.verticalCenter
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    text: {
                        if (root.state === "wallpapers")
                            return qsTr("No wallpapers found");
                        if (root.isWebSearch)
                            return qsTr("Search Google for \"%1\"").arg(root.search.text.trim());
                        return qsTr("No results");
                    }
                    color: root.isWebSearch ? Colours.palette.m3onSurface : Colours.palette.m3onSurfaceVariant
                    font: Tokens.font.body.builders.large.weight(Font.Medium).build()
                }

                StyledText {
                    text: {
                        if (root.state === "wallpapers")
                            return Wallpapers.list.length === 0 ? qsTr("Try putting some wallpapers in %1").arg(Paths.shortenHome(Paths.wallsdir)) : qsTr("Try searching for something else");
                        if (root.isWebSearch)
                            return qsTr("Press Enter or click to open in browser");
                        return qsTr("Try searching for something else");
                    }
                    color: Colours.palette.m3outline
                    font: Tokens.font.body.medium
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        Behavior on scale {
            Anim {}
        }
    }

    Behavior on implicitWidth {
        enabled: root.screenState.launcher

        Anim {}
    }

    Behavior on implicitHeight {
        enabled: root.screenState.launcher

        Anim {}
    }
}
