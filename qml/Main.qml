import QtQuick
import QtQuick.Controls
import QtCore
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: window
    width: 1280
    height: 800
    minimumWidth: 720
    minimumHeight: 480
    visible: true
    visibility: slideit.fullscreen ? Window.FullScreen : Window.Windowed
    title: "Slideit"
    color: slideit.background

    property bool playing: true
    property bool controlsVisible: true
    property bool selectorOpen: false
    property string selector: ""
    property point lastPointer: Qt.point(-100, -100)
    property int commandSequence: 0
    property string pendingNavigation: ""
    property bool pagePresented: false

    function command(action, argument) {
        // QQmlPropertyMap only emits valueChanged when the value actually changes.
        // Include a sequence so repeated actions such as next/next are never dropped.
        commandSequence++
        slideit.command = action + "|" + (argument === undefined ? "" : argument) + "|" + commandSequence
    }

    function revealControls() {
        controlsVisible = true
        hideTimer.restart()
    }

    function interact(action, argument) {
        revealControls()
        command(action, argument)
    }

    function navigate(action) {
        revealControls()
        if (pendingNavigation !== "" || !viewport.currentDeckReady)
            return
        pendingNavigation = action
        viewport.exitDirection = action === "previous" ? -1 : 1
        viewport.entryDirection = viewport.exitDirection
        deckExit.restart()
    }

    function toggleFullscreen() {
        const enabled = visibility !== Window.FullScreen
        visibility = enabled ? Window.FullScreen : Window.Windowed
        interact("fullscreen", enabled)
    }

    function toggleSelector(name) {
        revealControls()
        selectorOpen = !(selectorOpen && selector === name)
        selector = name
    }

    function frameColor(style) {
        if (style === "black") return "#111111"
        if (style === "aged") return "#e6d29a"
        return "#f5f3ed"
    }

    onVisibilityChanged: function() {
        const isFullscreen = window.visibility === Window.FullScreen
        if (isFullscreen !== slideit.fullscreen)
            command("fullscreen", isFullscreen)
    }

    Timer {
        id: hideTimer
        interval: 3000
        repeat: false
        running: true
        onTriggered: {
            if (!topControls.hovered && !bottomControls.hovered && !window.selectorOpen)
                window.controlsVisible = false
            else
                restart()
        }
    }

    Timer {
        id: slideshowTimer
        interval: Math.max(2, slideit.interval) * 1000
        repeat: true
        running: window.playing && window.pagePresented && slideit.imageCount > 0
        onTriggered: window.navigate("next")
        onIntervalChanged: if (running) restart()
    }

    FolderDialog {
        id: folderDialog
        title: "Choose a picture folder"
        currentFolder: slideit.folder ? "file://" + slideit.folder : StandardPaths.standardLocations(StandardPaths.PicturesLocation)[0]
        onAccepted: window.interact("folder", selectedFolder)
    }

    Shortcut { sequence: "Space"; onActivated: { window.playing = !window.playing; window.revealControls() } }
    Shortcut { sequences: ["Right", "L", "PgDown"]; onActivated: window.navigate("next") }
    Shortcut { sequences: ["Left", "H", "PgUp"]; onActivated: window.navigate("previous") }
    Shortcut { sequence: "Home"; onActivated: window.interact("first") }
    Shortcut { sequence: "End"; onActivated: window.interact("last") }
    Shortcut { sequences: ["F", "F11"]; onActivated: window.toggleFullscreen() }
    Shortcut { sequence: "O"; onActivated: { window.revealControls(); folderDialog.open() } }
    Shortcut { sequence: "M"; onActivated: window.interact("cycle-layout") }
    Shortcut { sequence: "S"; onActivated: window.interact("cycle-order") }
    Shortcut { sequence: "Shift+S"; onActivated: window.interact("reverse") }
    Shortcut { sequence: "R"; onActivated: window.interact("order", slideit.order === "random" ? "name" : "random") }
    Shortcut { sequence: "["; onActivated: window.interact("count", Math.max(1, slideit.perDeck - 1)) }
    Shortcut { sequence: "]"; onActivated: window.interact("count", Math.min(12, slideit.perDeck + 1)) }
    Shortcut { sequence: "-"; onActivated: window.interact("interval", Math.max(2, slideit.interval - 1)) }
    Shortcut { sequence: "+"; onActivated: window.interact("interval", Math.min(60, slideit.interval + 1)) }
    Shortcut { sequence: "C"; onActivated: window.interact("crop") }
    Shortcut { sequence: "B"; onActivated: window.interact("cycle-frame") }
    Shortcut { sequence: "T"; onActivated: window.interact("cycle-transition") }
    Shortcut { sequence: "F5"; onActivated: window.interact("refresh") }
    Shortcut { sequence: "?"; onActivated: window.toggleSelector("help") }
    Shortcut { sequence: "A"; onActivated: window.toggleSelector("about") }
    Shortcut { sequence: "Q"; onActivated: Qt.quit() }
    Shortcut {
        sequence: "Escape"
        onActivated: {
            if (window.selectorOpen) window.selectorOpen = false
            else if (window.visibility === Window.FullScreen) window.toggleFullscreen()
            else Qt.quit()
        }
    }

    MouseArea {
        id: pointerTracker
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: window.controlsVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: mouse => {
            if (Math.abs(mouse.x - window.lastPointer.x) + Math.abs(mouse.y - window.lastPointer.y) > 8) {
                window.lastPointer = Qt.point(mouse.x, mouse.y)
                window.revealControls()
            }
        }
        onClicked: mouse => {
            window.revealControls()
            if (mouse.button === Qt.RightButton) window.selectorOpen = false
            else if (mouse.x < width * 0.25) window.navigate("previous")
            else if (mouse.x > width * 0.75) window.navigate("next")
            else window.playing = !window.playing
        }
        onWheel: wheel => window.navigate(wheel.angleDelta.y > 0 ? "previous" : "next")
    }

    Item {
        id: viewport
        anchors.fill: parent
        anchors.margins: 24

        // Decode the next deck while the current deck's countdown is running.
        // These invisible Images share Qt's image cache with the visible deck.
        Item {
            id: preloader
            visible: false
            width: viewport.width
            height: viewport.height
            property int photoCount: Math.max(1, (slideit.nextDeck || []).length)
            property int columns: slideit.layout === "single" ? 1 : slideit.layout === "montage"
                ? Math.min(photoCount, Math.max(1, Math.ceil(Math.sqrt(photoCount * width / Math.max(1, height)))))
                : Math.ceil(Math.sqrt(photoCount))
            property int rows: Math.ceil(photoCount / columns)
            property real cellWidth: (width - (columns - 1) * (slideit.layout === "montage" ? 16 : 12)) / columns
            property real cellHeight: (height - (rows - 1) * (slideit.layout === "montage" ? 16 : 12)) / rows
            Repeater {
                model: window.playing && viewport.currentDeckReady ? (slideit.nextDeck || []) : []
                delegate: Image {
                    required property var modelData
                    source: modelData.source
                    asynchronous: true
                    autoTransform: true
                    cache: true
                    sourceSize.width: Math.ceil(preloader.cellWidth * Screen.devicePixelRatio * 1.15)
                    sourceSize.height: Math.ceil(preloader.cellHeight * Screen.devicePixelRatio * 1.15)
                }
            }
        }

        Loader {
            id: deckLoader
            width: parent.width
            height: parent.height
            y: 0
            sourceComponent: slideit.layout === "single" ? singleLayout : slideit.layout === "grid" ? gridLayout : montageLayout
            transformOrigin: Item.Center
            opacity: 0
            antialiasing: true
            // Tilt rotates the complete page. Give that parent transform its own
            // multisampled target; per-photo layers cannot AA the page silhouette.
            layer.enabled: slideit.transition === "tilt" && (deckTransition.running || deckExit.running)
            layer.samples: 4
            layer.smooth: true
        }

        property int readyPhotos: 0
        property int expectedPhotos: (slideit.deck || []).length
        property int observedDeckRevision: slideit.deckRevision || 0
        property bool currentDeckReady: false
        property int exitDirection: 1
        property int entryDirection: 1
        // Include enough overscan for rotated cards, frames, and antialiased
        // edges to clear the viewport completely before the deck is replaced.
        property real slideDistance: viewport.width * 1.18 + 96

        function beginDeck() {
            warmupTimer.stop()
            deckTransition.stop()
            slideshowTimer.stop()
            window.pagePresented = false
            readyPhotos = 0
            currentDeckReady = false
            window.pendingNavigation = ""
            deckLoader.opacity = 0
            deckLoader.x = 0
            deckLoader.scale = 1
            deckLoader.rotation = 0
            if (expectedPhotos === 0) {
                deckLoader.opacity = 1
                currentDeckReady = true
                window.pagePresented = true
            }
        }

        function photoReady() {
            readyPhotos++
            if (readyPhotos >= expectedPhotos && !currentDeckReady) {
                currentDeckReady = true
                // Render the complete deck at effectively zero opacity first.
                // This gives texture uploads and multisampled rotation layers a
                // frame to settle before the visible animation begins.
                deckLoader.opacity = 0.001
                warmupTimer.restart()
            }
        }

        onExpectedPhotosChanged: beginDeck()
        onObservedDeckRevisionChanged: beginDeck()
        Component.onCompleted: beginDeck()

        Timer {
            id: warmupTimer
            interval: 100
            repeat: false
            onTriggered: deckTransition.restart()
        }

        SequentialAnimation {
            id: deckTransition
            ScriptAction {
                script: {
                    deckLoader.opacity = slideit.transition === "fade" || slideit.transition === "tilt" ? 0 : 1
                    deckLoader.x = slideit.transition === "slide" ? viewport.entryDirection * viewport.slideDistance : 0
                    deckLoader.scale = slideit.transition === "zoom" ? 0 : 1
                    deckLoader.rotation = slideit.transition === "tilt" ? -3 : 0
                }
            }
            ParallelAnimation {
                NumberAnimation { target: deckLoader; property: "opacity"; to: 1; duration: slideit.transition === "fade" || slideit.transition === "tilt" ? 750 : 0; easing.type: Easing.InOutCubic }
                SequentialAnimation {
                    NumberAnimation { target: deckLoader; property: "x"; to: viewport.entryDirection * viewport.width; duration: slideit.transition === "slide" ? 100 : 0; easing.type: Easing.OutCubic }
                    NumberAnimation { target: deckLoader; property: "x"; to: 0; duration: slideit.transition === "slide" ? 1100 : 0; easing.type: Easing.InOutCubic }
                }
                NumberAnimation { target: deckLoader; property: "scale"; to: 1; duration: slideit.transition === "zoom" ? 1100 : 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: deckLoader; property: "rotation"; to: 0; duration: slideit.transition === "tilt" ? 900 : 0; easing.type: Easing.OutBack }
            }
            onFinished: {
                window.pagePresented = true
                if (window.playing && slideit.imageCount > 0)
                    slideshowTimer.restart()
            }
        }

        SequentialAnimation {
            id: deckExit
            ParallelAnimation {
                NumberAnimation { target: deckLoader; property: "opacity"; to: slideit.transition === "fade" || slideit.transition === "tilt" ? 0 : 1; duration: slideit.transition === "fade" || slideit.transition === "tilt" ? 600 : 0; easing.type: Easing.InOutCubic }
                SequentialAnimation {
                    NumberAnimation { target: deckLoader; property: "x"; to: slideit.transition === "slide" ? -viewport.exitDirection * viewport.width : 0; duration: slideit.transition === "slide" ? 1100 : 0; easing.type: Easing.InOutCubic }
                    NumberAnimation { target: deckLoader; property: "x"; to: slideit.transition === "slide" ? -viewport.exitDirection * viewport.slideDistance : 0; duration: slideit.transition === "slide" ? 100 : 0; easing.type: Easing.InCubic }
                }
                NumberAnimation { target: deckLoader; property: "scale"; to: slideit.transition === "zoom" ? 0 : 1; duration: slideit.transition === "zoom" ? 1100 : 0; easing.type: Easing.InCubic }
                NumberAnimation { target: deckLoader; property: "rotation"; to: slideit.transition === "tilt" ? viewport.exitDirection * 3 : 0; duration: slideit.transition === "tilt" ? 700 : 0; easing.type: Easing.InBack }
            }
            // Keep the final zoom frame around briefly before replacing its content.
            PauseAnimation { duration: slideit.transition === "zoom" ? 60 : 0 }
            onFinished: {
                const action = window.pendingNavigation
                if (action !== "") window.command(action)
            }
        }

        Component {
            id: photo
            Item {
                id: photoRoot
                signal ready()
                property string source
                property string name
                property real angle
                property real offsetX
                property real offsetY
                property bool montage: false
                property real cardRotation: 0
                property int transitionDelay: 0
                property bool framed: slideit.frameStyle !== "none"
                property bool visualReady: false
                property real frameEdge: slideit.frameSize === "thin" ? 5 : slideit.frameSize === "thick" ? 14 : 9
                property real frameBottom: slideit.frameSize === "thin" ? 9 : slideit.frameSize === "thick" ? 28 : 18
                Item {
                    id: photoVisual
                    anchors.fill: parent
                    rotation: parent.cardRotation
                    scale: parent.montage ? 0.92 : 1
                    antialiasing: true
                    transformOrigin: Item.Center
                    // Render rotated cards into a small multisampled layer so the
                    // outer image/frame silhouette receives proper edge AA.
                    // Keep this active for every rotated card on every page, not
                    // only while an entry/exit transition happens.
                    layer.enabled: parent.montage && Math.abs(parent.cardRotation) > 0.01
                    layer.samples: 4
                    layer.smooth: true
                    Rectangle {
                        visible: parent.parent.framed && parent.parent.visualReady
                        x: photoImage.x + (photoImage.width - photoImage.paintedWidth) / 2 - parent.parent.frameEdge
                        y: photoImage.y + (photoImage.height - photoImage.paintedHeight) / 2 - parent.parent.frameEdge
                        width: photoImage.paintedWidth + parent.parent.frameEdge * 2
                        height: photoImage.paintedHeight + parent.parent.frameEdge + parent.parent.frameBottom
                        color: window.frameColor(slideit.frameStyle)
                        radius: 3
                        antialiasing: true
                    }
                    Image {
                        id: photoImage
                        opacity: parent.parent.visualReady ? 1 : 0
                        anchors.centerIn: parent
                        width: parent.width - (parent.parent.framed ? parent.parent.frameEdge * 2 : 0)
                        height: parent.height - (parent.parent.framed ? parent.parent.frameEdge + parent.parent.frameBottom : 0)
                        source: parent.parent.source
                        asynchronous: true
                        autoTransform: true
                        smooth: true
                        // Images are decoded near their final display size;
                        // mipmaps would add upload time and ~33% texture memory.
                        mipmap: false
                        cache: true
                        sourceSize.width: Math.ceil(width * Screen.devicePixelRatio * 1.15)
                        sourceSize.height: Math.ceil(height * Screen.devicePixelRatio * 1.15)
                        fillMode: slideit.crop ? Image.PreserveAspectCrop : Image.PreserveAspectFit
                        clip: slideit.crop
                        onStatusChanged: {
                            if (status === Image.Ready)
                                decorationReadyTimer.restart()
                            else if (status === Image.Error)
                                parent.parent.ready()
                        }
                    }
                }
                Timer {
                    id: decorationReadyTimer
                    interval: 34
                    repeat: false
                    onTriggered: {
                        photoRoot.visualReady = true
                        photoRoot.ready()
                    }
                }
            }
        }

        Component {
            id: singleLayout
            Item {
                Repeater {
                    model: slideit.deck || []
                    delegate: Loader {
                        anchors.fill: parent
                        sourceComponent: photo
                        onLoaded: {
                            item.ready.connect(viewport.photoReady)
                            item.source = modelData.source; item.name = modelData.name
                            item.angle = modelData.angle; item.offsetX = modelData.offsetX; item.offsetY = modelData.offsetY
                        }
                    }
                }
            }
        }

        Component {
            id: gridLayout
            Grid {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                columns: Math.ceil(Math.sqrt(Math.max(1, (slideit.deck || []).length)))
                spacing: 12
                Repeater {
                    model: slideit.deck || []
                    delegate: Loader {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        height: (parent.height - (Math.ceil((slideit.deck || []).length / parent.columns) - 1) * parent.spacing) / Math.ceil((slideit.deck || []).length / parent.columns)
                        sourceComponent: photo
                        onLoaded: {
                            item.ready.connect(viewport.photoReady)
                            item.source = modelData.source; item.name = modelData.name
                            item.angle = modelData.angle; item.offsetX = modelData.offsetX; item.offsetY = modelData.offsetY
                        }
                    }
                }
            }
        }

        Component {
            id: montageLayout
            Grid {
                anchors.centerIn: parent
                width: parent.width
                height: parent.height
                property int photoCount: Math.max(1, (slideit.deck || []).length)
                property real viewportRatio: width / Math.max(1, height)
                // Bias the grid toward columns on wide displays and toward rows on tall ones.
                // At 16:9, for example, four photos become 3x2 rather than a square 2x2.
                columns: Math.min(photoCount, Math.max(1, Math.ceil(Math.sqrt(photoCount * viewportRatio))))
                property int rows: Math.ceil(photoCount / columns)
                spacing: 16
                Repeater {
                    model: slideit.deck || []
                    delegate: Loader {
                        width: (parent.width - (parent.columns - 1) * parent.spacing) / parent.columns
                        height: (parent.height - (parent.rows - 1) * parent.spacing) / parent.rows
                        sourceComponent: photo
                        onLoaded: {
                            item.ready.connect(viewport.photoReady)
                            item.source = modelData.source; item.name = modelData.name
                            item.angle = modelData.angle; item.offsetX = modelData.offsetX; item.offsetY = modelData.offsetY
                            item.montage = true; item.cardRotation = modelData.angle
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 16
            visible: slideit.imageCount === 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: slideit.loading ? "Loading pictures…" : slideit.folder ? "No supported pictures found" : "Choose a picture folder"
                color: slideit.foreground
                font.family: "monospace"
                font.pixelSize: 20
            }
            BubbleButton {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Open folder  O"
                onClicked: folderDialog.open()
            }
        }
    }

    EdgeBar {
        id: topControls
        anchors.top: parent.top
        x: (parent.width - width) / 2
        shown: window.controlsVisible
        BubbleButton { text: slideit.folderName || "Slideit"; onClicked: folderDialog.open() }
        BubbleLabel { text: slideit.imageCount + " photos  ·  " + (slideit.deckCount ? (slideit.deckIndex + 1) + "/" + slideit.deckCount : "0/0") }
        BubbleLabel { visible: slideit.loading || slideit.message; text: slideit.loading ? "Scanning…" : slideit.message; error: !!slideit.message }
    }

    EdgeBar {
        id: bottomControls
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        shown: window.controlsVisible
        BubbleButton { text: "‹"; onClicked: window.navigate("previous") }
        BubbleButton { text: window.playing ? "Ⅱ  Pause" : "▶  Play"; accented: !window.playing; onClicked: { window.playing = !window.playing; window.revealControls() } }
        BubbleButton { text: "›"; onClicked: window.navigate("next") }
        BubbleButton {
            text: "R"
            accented: slideit.order === "random"
            Accessible.name: slideit.order === "random" ? "Disable random order" : "Enable random order"
            ToolTip.visible: hovered
            ToolTip.text: Accessible.name + "  R"
            onClicked: window.interact("order", slideit.order === "random" ? "name" : "random")
        }
        BubbleButton { text: titleCase(slideit.layout); accented: window.selectorOpen && window.selector === "layout"; onClicked: window.toggleSelector("layout") }
        BubbleButton { visible: slideit.layout !== "single"; text: slideit.perDeck + " photos"; accented: window.selectorOpen && window.selector === "count"; onClicked: window.toggleSelector("count") }
        BubbleButton {
            text: slideit.frameStyle === "none" ? "Frame off" : titleCase(slideit.frameStyle) + " frame"
            accented: window.selectorOpen && window.selector === "frame"
            swatchColor: slideit.frameStyle === "none" ? "" : window.frameColor(slideit.frameStyle)
            darkSwatchText: slideit.frameStyle !== "black"
            onClicked: window.toggleSelector("frame")
        }
        BubbleButton { text: titleCase(slideit.transition); accented: window.selectorOpen && window.selector === "transition"; onClicked: window.toggleSelector("transition") }
        BubbleButton { text: titleCase(slideit.order) + (slideit.order === "random" ? "" : slideit.descending ? " ↓" : " ↑"); accented: window.selectorOpen && window.selector === "order"; onClicked: window.toggleSelector("order") }
        BubbleButton { text: slideit.interval + "s"; accented: window.selectorOpen && window.selector === "timing"; onClicked: window.toggleSelector("timing") }
        BubbleButton { text: "?"; onClicked: window.toggleSelector("help") }
    }

    function titleCase(value) { return value ? value.charAt(0).toUpperCase() + value.slice(1) : "" }

    Popup {
        id: selectorPopup
        visible: window.selectorOpen && window.controlsVisible
        modal: false
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        x: (parent.width - width) / 2
        y: parent.height - bottomControls.height - height - 20
        padding: 10
        background: Rectangle { color: slideit.surface; border.color: slideit.border; radius: 14 }
        contentItem: ColumnLayout {
            spacing: 6
            Label {
                visible: window.selector === "frame"
                text: "COLOR"
                color: slideit.muted
                font.family: "monospace"
                font.pixelSize: 11
                leftPadding: 8
                topPadding: 4
            }
            Repeater {
                model: window.selector === "layout" ? ["single", "grid", "montage"] : window.selector === "count" ? ["1", "2", "3", "4", "5", "6", "8", "9", "12"] : window.selector === "frame" ? ["none", "white", "aged", "black"] : window.selector === "transition" ? ["none", "fade", "slide", "zoom", "tilt"] : window.selector === "order" ? ["name", "created", "modified", "random"] : window.selector === "timing" ? ["3", "5", "8", "12", "20"] : []
                delegate: BubbleButton {
                    required property string modelData
                    text: window.selector === "timing" ? modelData + " seconds" : window.selector === "count" ? modelData + (modelData === "1" ? " photo" : " photos") : window.titleCase(modelData)
                    swatchColor: window.selector === "frame" && modelData !== "none" ? window.frameColor(modelData) : ""
                    darkSwatchText: modelData !== "black"
                    accented: window.selector === "layout" ? slideit.layout === modelData : window.selector === "order" ? slideit.order === modelData : window.selector === "count" ? String(slideit.perDeck) === modelData : window.selector === "frame" ? (slideit.frameStyle === modelData || slideit.frameSize === modelData) : window.selector === "transition" ? slideit.transition === modelData : String(slideit.interval) === modelData
                    onClicked: {
                        const action = window.selector === "timing" ? "interval" : window.selector === "frame" && ["thin", "medium", "thick"].indexOf(modelData) >= 0 ? "frame-size" : window.selector
                        window.interact(action, modelData)
                        if (window.selector !== "frame") window.selectorOpen = false
                    }
                }
            }
            Rectangle {
                visible: window.selector === "frame"
                Layout.fillWidth: true
                height: 1
                color: slideit.border
                opacity: 0.7
                Layout.topMargin: 4
                Layout.bottomMargin: 2
            }
            Label {
                visible: window.selector === "frame"
                text: "THICKNESS"
                color: slideit.muted
                font.family: "monospace"
                font.pixelSize: 11
                leftPadding: 8
            }
            Repeater {
                model: window.selector === "frame" ? ["thin", "medium", "thick"] : []
                delegate: BubbleButton {
                    required property string modelData
                    text: window.titleCase(modelData)
                    accented: slideit.frameSize === modelData
                    enabled: slideit.frameStyle !== "none"
                    opacity: enabled ? 1 : 0.45
                    onClicked: window.interact("frame-size", modelData)
                }
            }
            Label {
                visible: window.selector === "help"
                text: "Space  play/pause    ←/→  navigate    M  layout\nS  order    [/]  photo count    -/+  timing\nC  fit/crop    B  frame    T  transition\nF  fullscreen    O  folder    A  about    Q  quit"
                color: slideit.foreground
                font.family: "monospace"
                padding: 8
            }
            ColumnLayout {
                visible: window.selector === "about"
                spacing: 12
                Layout.minimumWidth: 340
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Slideit"
                    color: slideit.foreground
                    font.family: "monospace"
                    font.pixelSize: 24
                    font.bold: true
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "A quiet place for memories in pictures."
                    color: slideit.muted
                    font.family: "monospace"
                    font.pixelSize: 13
                }
                Rectangle {
                    Layout.fillWidth: true
                    height: 1
                    color: slideit.border
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Dedicated to the memory of my father,\nTrygve."
                    color: slideit.foreground
                    font.family: "monospace"
                    font.pixelSize: 16
                    font.italic: true
                    horizontalAlignment: Text.AlignHCenter
                    lineHeight: 1.35
                }
                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Made with Go, Qt, QML, and MIQT"
                    color: slideit.muted
                    font.family: "monospace"
                    font.pixelSize: 11
                }
            }
        }
        onClosed: window.selectorOpen = false
    }

    component EdgeBar: Pane {
        id: bar
        property bool shown: true
        padding: 12
        opacity: shown ? 1 : 0
        visible: opacity > 0
        background: Item {}
        contentItem: RowLayout { spacing: 8 }
        HoverHandler { id: hover; onHoveredChanged: if (hovered) window.revealControls() }
        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    component BubbleLabel: Label {
        property bool error: false
        color: error ? slideit.error : slideit.foreground
        font.family: "monospace"
        font.pixelSize: 13
        padding: 11
        background: Rectangle { color: slideit.surface; border.color: error ? slideit.error : slideit.border; radius: height / 2 }
    }

    component BubbleButton: Button {
        property bool accented: false
        property string swatchColor: ""
        property bool darkSwatchText: false
        readonly property bool hasSwatch: swatchColor !== ""
        font.family: "monospace"
        font.pixelSize: 13
        leftPadding: 15; rightPadding: 15; topPadding: 10; bottomPadding: 10
        contentItem: Text { text: parent.text; color: parent.hasSwatch ? (parent.darkSwatchText ? "#171717" : "#f5f5f5") : parent.accented ? slideit.background : slideit.foreground; font: parent.font; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
        background: Rectangle {
            color: parent.hasSwatch ? parent.swatchColor : parent.accented ? slideit.accent : slideit.surface
            border.color: parent.hovered || parent.visualFocus ? slideit.accent : slideit.border
            border.width: parent.visualFocus ? 2 : 1
            radius: height / 2
        }
        HoverHandler { onHoveredChanged: if (hovered) window.revealControls() }
    }

}
