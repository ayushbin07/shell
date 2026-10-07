pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.Services
import qs.components
import qs.components.containers
import qs.components.controls
import qs.components.effects
import qs.services

Item {
    id: root

    // Funny binding hack to make lyrics update
    readonly property var _: {
        const p = Players.active;
        if (p)
            Lyrics.setTrack(p.trackArtist, p.trackTitle, p.trackAlbum, p.length);
        else
            Lyrics.clearTrack();
    }

    readonly property real fadeAmount: 0.1
    property list<string> lyricList: Lyrics.lyrics
    property font lyricFont: Tokens.font.body.medium
    property font currentLyricFont: Tokens.font.body.medium

    property bool hasLyrics: Lyrics.hasLyrics && lyricList.length > 0
    readonly property bool isLoading: !hasLyrics && Lyrics.loading
    readonly property bool showNoLyrics: !hasLyrics && !isLoading

    // Current active lyric index according to player position
    readonly property int activeLyricIndex: {
        root.lyricList;
        Lyrics.offset;
        const p = Players.active;
        if (!p || !root.hasLyrics)
            return -1;
        return Lyrics.indexForTime(p.position);
    }

    onActiveLyricIndexChanged: {
        if (!lyrics.moving && !lyrics.flicking && !resumeAutoScrollTimer.running) {
            syncToActiveLyric(true);
        }
    }

    onHeightChanged: {
        if (root.hasLyrics && lyrics.count > 0 && !lyrics.moving && !lyrics.flicking) {
            syncToActiveLyric(false);
        }
    }

    function syncToActiveLyric(smooth: bool): void {
        if (!root.hasLyrics || lyrics.count <= 0)
            return;

        const target = Math.max(0, Math.min(root.activeLyricIndex, lyrics.count - 1));
        if (lyrics.currentIndex !== target) {
            lyrics.currentIndex = target;
        }
        if (!smooth) {
            lyrics.positionViewAtIndex(target, ListView.Center);
        }
    }

    // Timer to poll player position changes so lyrics continuously update
    Timer {
        id: positionTimer
        running: root.hasLyrics && (Players.active?.isPlaying ?? false)
        interval: Math.min(250, GlobalConfig.dashboard.mediaUpdateInterval)
        triggeredOnStart: true
        repeat: true
        onTriggered: Players.active?.positionChanged()
    }

    // Auto-scroll resume timer: after user finishes manual scrolling, resume auto-centering
    Timer {
        id: resumeAutoScrollTimer
        interval: 2500
        repeat: false
        onTriggered: root.syncToActiveLyric(true)
    }

    Connections {
        target: lyrics

        function onMovingChanged(): void {
            if (lyrics.moving) {
                resumeAutoScrollTimer.stop();
            } else if (!lyrics.flicking) {
                resumeAutoScrollTimer.restart();
            }
        }

        function onFlickingChanged(): void {
            if (lyrics.flicking) {
                resumeAutoScrollTimer.stop();
            } else if (!lyrics.moving) {
                resumeAutoScrollTimer.restart();
            }
        }
    }

    onLyricListChanged: {
        hasLyrics = Lyrics.hasLyrics && lyricList.length > 0;
        Qt.callLater(() => {
            syncToActiveLyric(false);
        });
    }

    Component.onCompleted: {
        syncToActiveLyric(false);
    }

    Connections {
        target: Lyrics

        function onHasLyricsChanged(): void {
            root.hasLyrics = Lyrics.hasLyrics && root.lyricList.length > 0;
        }

        function onLyricsChanged(): void {
            Qt.callLater(() => {
                root.hasLyrics = Lyrics.hasLyrics && root.lyricList.length > 0;
                root.syncToActiveLyric(false);
            });
        }
    }

    layer.enabled: true
    layer.effect: Mask {
        maskSource: mask

        Rectangle {
            id: mask

            layer.enabled: true
            visible: false
            implicitWidth: root.width
            implicitHeight: root.height

            gradient: Gradient {
                orientation: Gradient.Vertical

                GradientStop {
                    color: Qt.alpha("black", 0)
                    position: 0
                }
                GradientStop {
                    color: Qt.alpha("black", 1)
                    position: root.fadeAmount
                }
                GradientStop {
                    color: Qt.alpha("black", 1)
                    position: 1 - root.fadeAmount
                }
                GradientStop {
                    color: Qt.alpha("black", 0)
                    position: 1
                }
            }
        }
    }

    Loader {
        id: loadingIndicator

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        visible: opacity > 0
        opacity: root.isLoading ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.large

            StyledRect {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: shape.implicitSize + Tokens.padding.medium * 2
                implicitHeight: shape.implicitSize + Tokens.padding.medium * 2
                color: Colours.palette.m3primaryContainer
                radius: Tokens.rounding.full

                LoadingIndicator {
                    id: shape

                    anchors.centerIn: parent
                    implicitSize: Math.round(Tokens.sizes.dashboard.mediaSectionWidth / 5)
                    containsIcon: true // This removes the pentagon, which is not centered
                }
            }

            StyledText {
                text: qsTr("Loading lyrics...")
                color: Colours.palette.m3onSurfaceVariant
                font: Tokens.font.title.medium
            }
        }



    }

    Loader {
        id: noLyrics

        anchors.centerIn: parent
        asynchronous: true
        active: opacity > 0
        visible: opacity > 0
        opacity: root.showNoLyrics ? 1 : 0

        Behavior on opacity {
            Anim {
                type: Anim.DefaultEffects
            }
        }

        sourceComponent: ColumnLayout {
            spacing: Tokens.spacing.medium

            AnimatedImage {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: Math.min(root.width * 0.8, 260)
                Layout.preferredHeight: Math.min(root.height * 0.5, 260)
                source: Quickshell.shellPath("assets/no-lyrics.gif")
                playing: Players.active?.isPlaying ?? true
                fillMode: AnimatedImage.PreserveAspectFit
                asynchronous: true
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: qsTr("No lyrics found")
                color: Colours.palette.m3outline
                font: Tokens.font.title.medium
            }
        }
    }

    StyledListView {
        id: lyrics

        anchors.fill: parent
        anchors.topMargin: parent.height * root.fadeAmount / 2
        anchors.bottomMargin: parent.height * root.fadeAmount / 2

        displayMarginBeginning: lyrics.height
        displayMarginEnd: lyrics.height

        model: root.lyricList

        highlightFollowsCurrentItem: true
        highlightRangeMode: ListView.StrictlyEnforceRange
        highlightMoveDuration: Tokens.anim.durations.large
        highlightMoveVelocity: -1
        preferredHighlightBegin: height > 0 ? Math.round((height - (currentItem?.implicitHeight ?? currentItem?.height ?? 32)) / 2) : 0
        preferredHighlightEnd: height > 0 ? Math.round((height + (currentItem?.implicitHeight ?? currentItem?.height ?? 32)) / 2) : 0

        spacing: Tokens.spacing.small
        visible: opacity > 0
        opacity: root.hasLyrics ? 1 : 0

        header: Item {
            width: lyrics.width
            height: Math.max(0, Math.round(lyrics.height / 2))
        }

        footer: Item {
            width: lyrics.width
            height: Math.max(0, Math.round(lyrics.height / 2))
        }

        delegate: StyledText {
            id: lyric

            required property string modelData
            required property int index
            readonly property bool isActive: index === root.activeLyricIndex
            property real effectScale: isActive ? 1 : 0

            anchors.left: lyrics.contentItem.left
            anchors.right: lyrics.contentItem.right

            text: modelData || ". . ."
            color: isActive ? Colours.palette.m3primary : mouse.containsMouse ? Colours.palette.m3onSurface : Colours.palette.m3outline
            font: isActive ? root.currentLyricFont : root.lyricFont
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere

            Behavior on color {
                CAnim {}
            }

            layer.enabled: effectScale > 0
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Colours.palette.m3primary
                shadowOpacity: 0.5 * lyric.effectScale
                shadowBlur: 0.6 * lyric.effectScale
                blur: 0.4 * lyric.effectScale
            }

            Behavior on effectScale {
                Anim {
                    type: Anim.SlowEffects
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    const p = Players.active;
                    if (p) {
                        resumeAutoScrollTimer.stop();
                        p.position = Lyrics.timeForIndex(lyric.index);
                        lyrics.currentIndex = lyric.index;
                        lyrics.positionViewAtIndex(lyric.index, ListView.Center);
                    }
                }
            }
        }

        Behavior on opacity {
            Anim {
                type: Anim.SlowEffects
            }
        }
    }

    Behavior on lyricList {
        SequentialAnimation {
            Anim {
                target: lyrics
                property: "opacity"
                to: 0
                type: Anim.DefaultEffects
            }
            PropertyAction {}
            Anim {
                target: lyrics
                property: "opacity"
                to: 1
                type: Anim.SlowEffects
            }
        }
    }
}
