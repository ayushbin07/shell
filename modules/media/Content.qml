pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import M3Shapes
import Caelestia
import Caelestia.Components
import Caelestia.Config
import qs.components
import qs.components.controls
import qs.components.images
import qs.services
import qs.modules.dashboard.media as DashboardMedia

Item {
    id: root

    required property ScreenState screenState

    readonly property bool shouldBeOpen: screenState?.fullscreenMedia ?? false
    property real offsetScale: shouldBeOpen ? 0 : 1

    anchors.fill: parent
    visible: offsetScale < 1
    opacity: 1 - offsetScale
    scale: 0.96 + 0.04 * (1 - offsetScale)
    focus: shouldBeOpen

    Keys.onEscapePressed: {
        root.screenState.fullscreenMedia = false;
    }

    Behavior on offsetScale {
        Anim {
            duration: Tokens.anim.durations.expressiveDefaultSpatial
            easing: Tokens.anim.expressiveDefaultSpatial
        }
    }

    // 1. Dark translucent backdrop
    StyledRect {
        anchors.fill: parent
        color: Colours.palette.m3surface
        opacity: 0.88

        Behavior on color {
            CAnim {}
        }
    }

    // 2. Blurred cover art background
    FadeImage {
        anchors.fill: parent
        source: Players.getArtUrl(Players.active)
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blurMax: 64
            blur: 1.0
        }
        opacity: (status === Image.Ready && Players.active) ? 0.35 : 0

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    // 3. Subtle dark vignette gradient
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Vertical

            GradientStop {
                position: 0.0
                color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.45)
            }
            GradientStop {
                position: 0.5
                color: Qt.alpha(Colours.palette.m3surface, 0.2)
            }
            GradientStop {
                position: 1.0
                color: Qt.alpha(Colours.palette.m3surfaceContainerLowest, 0.65)
            }
        }
    }

    // 4. Drifting Material shapes in the background
    DashboardMedia.BackgroundShapes {
        anchors.fill: parent
        count: 22
        maxSize: 180
    }

    // Header Bar
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.extraExtraLarge
        implicitHeight: Math.max(badgeRow.implicitHeight, closeBtn.implicitHeight)
        z: 10

        RowLayout {
            id: badgeRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.medium

            StyledRect {
                implicitHeight: tagLayout.implicitHeight + Tokens.padding.small * 2
                implicitWidth: tagLayout.implicitWidth + Tokens.padding.large * 2
                radius: Tokens.rounding.full
                color: Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

                RowLayout {
                    id: tagLayout

                    anchors.centerIn: parent
                    spacing: Tokens.spacing.small

                    MaterialIcon {
                        text: "queue_music"
                        fontStyle: Tokens.font.icon.small
                        color: Colours.palette.m3primary
                    }

                    StyledText {
                        text: qsTr("Now Playing")
                        font: Tokens.font.label.large
                        color: Colours.palette.m3primary
                    }
                }
            }

            StyledText {
                text: Players.active ? `•  ${Players.getIdentity(Players.active)}` : ""
                font: Tokens.font.title.small
                color: Colours.palette.m3onSurfaceVariant
                visible: text.length > 0
                animate: true
            }
        }

        IconButton {
            id: closeBtn

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            type: IconButton.Tonal
            icon: "close"
            isRound: true
            shapeMorph: true
            font: Tokens.font.icon.medium
            onClicked: root.screenState.fullscreenMedia = false
        }
    }

    // Main Content
    Item {
        id: mainContent

        anchors.top: header.bottom
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Tokens.padding.extraExtraLarge
        clip: true

        // Media Playing Layout
        RowLayout {
            id: mediaLayout

            anchors.fill: parent
            anchors.topMargin: Tokens.padding.large
            anchors.bottomMargin: Tokens.padding.large
            anchors.leftMargin: Tokens.padding.extraExtraLarge
            anchors.rightMargin: Tokens.padding.extraExtraLarge
            spacing: Tokens.spacing.extraExtraLarge * 2
            visible: Players.active !== null

            // Left Column: Big Cover Visualiser & Details
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.alignment: Qt.AlignHCenter
                spacing: Tokens.spacing.large

                DashboardMedia.CoverVisualiser {
                    id: bigVisualiser

                    Layout.alignment: Qt.AlignHCenter
                    readonly property real coverSizeVal: Math.min(mediaLayout.width * 0.34, mediaLayout.height * 0.44, 400)
                    implicitWidth: coverSizeVal * 1.35
                    implicitHeight: coverSizeVal * 1.35
                    coverSize: coverSizeVal
                }

                DashboardMedia.Details {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: Math.min(parent.width, 540)
                    titleFont: Tokens.font.headline.large
                    artistFont: Tokens.font.title.large
                    albumFont: Tokens.font.title.medium
                    buttonScale: 1.3
                }
            }

            // Right Column: Synchronized Lyrics & Player Selector
            DashboardMedia.LyricsAndSelector {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                Layout.maximumWidth: Math.min(mediaLayout.width * 0.52, 700)
                Layout.alignment: Qt.AlignVCenter
                lyricFont: Tokens.font.title.medium
                currentLyricFont: Tokens.font.headline.small
            }
        }

        // No Media Fallback
        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.spacing.large
            visible: Players.active === null

            MaterialShape {
                Layout.alignment: Qt.AlignHCenter
                color: Colours.palette.m3primaryContainer
                implicitSize: emptyIcon.implicitHeight + Tokens.padding.extraLargeIncreased * 2
                shape: MaterialShape.ClamShell

                Behavior on color {
                    CAnim {}
                }

                MaterialIcon {
                    id: emptyIcon

                    anchors.centerIn: parent
                    text: "queue_music"
                    fontStyle: Tokens.font.icon.builders.large.scale(2.5).build()
                    color: Colours.palette.m3onPrimaryContainer
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Nothing playing")
                font: Tokens.font.headline.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("Play something on your media player to see it here!")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.medium
            }

            SplitButton {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Tokens.spacing.large
                type: SplitButton.Tonal
                disabled: !Players.list.length
                active: menuItems.find(m => m.modelData === Players.active) ?? menuItems[0] ?? null
                menu.onItemSelected: item => Players.manualActive = (item as MenuItem).modelData
                menuItems: emptyPlayerList.instances
                fallbackIcon: "music_off"
                fallbackText: qsTr("No players")

                Variants {
                    id: emptyPlayerList

                    model: Players.list

                    MenuItem {
                        required property var modelData

                        icon: modelData === Players.active ? "check" : ""
                        text: Players.getIdentity(modelData)
                        activeIcon: "animated_images"
                    }
                }
            }
        }
    }
}
