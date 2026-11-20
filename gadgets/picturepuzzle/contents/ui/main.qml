/*
    SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
    SPDX-License-Identifier: GPL-3.0-or-later

    A clean-room Plasma 6 port of the Windows 7 Picture Puzzle sidebar gadget.

    The artwork (background, picture, bezel, toolbar icons) is not part of this
    package. The installer copies it from the Windows 7 ISO into
    contents/images/ before the plasmoid is used.
*/

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // Geometry of the original gadget.
    readonly property int gridSize: 4
    readonly property int tileSize: 27
    readonly property int boardSize: gridSize * tileSize
    readonly property int boardLeft: 11
    readonly property int boardTop: 21
    readonly property int imageCount: 11

    implicitWidth: 130
    implicitHeight: 138
    Layout.minimumWidth: 130
    Layout.maximumWidth: 130
    Layout.minimumHeight: 138
    Layout.maximumHeight: 138
    Layout.preferredWidth: 130
    Layout.preferredHeight: 138

    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Plasmoid.title: i18n("Picture Puzzle")
    Plasmoid.icon: "io.github.win7aero.picturepuzzle"
    Plasmoid.status: PlasmaCore.Types.PassiveStatus
    preferredRepresentation: fullRepresentation

    toolTipMainText: i18n("Picture Puzzle")
    toolTipSubText: i18n("Click a tile next to the gap, or use the arrow keys.")

    focus: true

    // Board contents: one entry per cell, holding the picture piece shown
    // there. Pieces 1..15 are picture tiles, 16 is the empty cell.
    property var board: []
    property int gapIndex: 15
    property int imageId: 1
    property int elapsedSeconds: 0

    property bool timerRunning: false
    property bool won: false
    property bool hintVisible: false
    property bool pictureShown: false
    property bool winMessageShown: false
    property bool inputLocked: false
    property bool animateMoves: false

    // Toolbar action: false shows "Solve" (board is scrambled), true shows
    // "Shuffle" (board is solved, or the player just won).
    property bool actionIsShuffle: false

    Accessible.name: i18n("Picture Puzzle")
    Accessible.description: i18n("Move the pieces of the puzzle and try to put them in order.")

    // ---------------------------------------------------------------------
    // Game logic
    // ---------------------------------------------------------------------

    function validImageId(value) {
        const id = Number(value)
        if (!Number.isInteger(id) || id < 1 || id > imageCount) {
            return 1;
        }
        return id;
    }

    function solvedBoard() {
        const result = [];
        for (let i = 0; i < gridSize * gridSize; ++i) {
            result.push(i + 1);
        }
        return result;
    }

    function isSolved() {
        if (board.length !== gridSize * gridSize) {
            return false;
        }
        for (let i = 0; i < board.length; ++i) {
            if (board[i] !== i + 1) {
                return false;
            }
        }
        return true;
    }

    // Parse "1,2,...,16" from the config. Returns null for anything that is
    // not a permutation of 1..16.
    function parseBoard(text) {
        if (typeof text !== "string" || text.length === 0) {
            return null;
        }
        const parts = text.split(",");
        if (parts.length !== gridSize * gridSize) {
            return null;
        }
        const result = [];
        const seen = {};
        for (let i = 0; i < parts.length; ++i) {
            const value = Number(parts[i].trim());
            if (!Number.isInteger(value) || value < 1 || value > 16 || seen[value]) {
                return null;
            }
            seen[value] = true;
            result.push(value);
        }
        return result;
    }

    // A 4x4 sliding puzzle is solvable when the number of inversions and the
    // blank row (counted from the bottom) have the parity of the solved state.
    function isSolvable(candidate) {
        const tiles = candidate.filter(value => value !== 16);
        let inversions = 0;
        for (let i = 0; i < tiles.length; ++i) {
            for (let j = i + 1; j < tiles.length; ++j) {
                if (tiles[i] > tiles[j]) {
                    ++inversions;
                }
            }
        }
        const blankRowFromBottom = gridSize - Math.floor(candidate.indexOf(16) / gridSize);
        return blankRowFromBottom % 2 === 1
            ? inversions % 2 === 0
            : inversions % 2 === 1;
    }

    // 1000 random legal gap moves starting from the solved board, never
    // immediately undoing the previous move. The result is always solvable.
    function scrambledBoard() {
        for (let attempt = 0; attempt < 8; ++attempt) {
            const result = solvedBoard();
            let gap = gridSize * gridSize - 1;
            let previousStep = 0;

            for (let move = 0; move < 1000; ++move) {
                const row = Math.floor(gap / gridSize);
                const column = gap % gridSize;
                const steps = [];
                if (row > 0) {
                    steps.push(-gridSize);
                }
                if (row < gridSize - 1) {
                    steps.push(gridSize);
                }
                if (column > 0) {
                    steps.push(-1);
                }
                if (column < gridSize - 1) {
                    steps.push(1);
                }

                const options = steps.filter(step => step !== -previousStep);
                if (options.length === 0) {
                    break;
                }
                const step = options[Math.floor(Math.random() * options.length)];
                const next = gap + step;
                const moved = result[gap];
                result[gap] = result[next];
                result[next] = moved;
                gap = next;
                previousStep = step;
            }

            // A random walk almost never ends solved. If it does, try again.
            let solved = true;
            for (let i = 0; i < result.length; ++i) {
                if (result[i] !== i + 1) {
                    solved = false;
                    break;
                }
            }
            if (!solved) {
                return result;
            }
        }
        return solvedBoard();
    }

    function setBoard(candidate) {
        animateMoves = false;
        board = candidate;
        gapIndex = candidate.indexOf(16);
        animateMoves = true;
    }

    function saveBoard() {
        Plasmoid.configuration.board = board.join(",");
        Plasmoid.configuration.started = true;
    }

    function saveElapsed() {
        Plasmoid.configuration.elapsed = elapsedSeconds;
    }

    function stopWinMessage() {
        winFade.stop();
        winMessageShown = false;
        winOverlay.opacity = 0;
    }

    function restartState() {
        stopWinMessage();
        won = false;
        hintVisible = false;
        pictureShown = false;
        inputLocked = false;
        timerRunning = false;
        elapsedSeconds = 0;
        moveUnlock.stop();
    }

    function shuffle() {
        restartState();
        setBoard(scrambledBoard());
        actionIsShuffle = false;
        saveBoard();
        saveElapsed();
        forceActiveFocus();
    }

    // "Solve" snaps the board to the solved layout. It is not an auto-solver.
    function solve() {
        restartState();
        setBoard(solvedBoard());
        actionIsShuffle = true;
        saveBoard();
        saveElapsed();
        forceActiveFocus();
    }

    function pauseTimer() {
        timerRunning = false;
        saveElapsed();
    }

    function restoreBoard(candidate, savedElapsed) {
        restartState();
        setBoard(candidate);
        elapsedSeconds = savedElapsed;
        actionIsShuffle = isSolved();
        timerRunning = false;
    }

    function formattedTime() {
        const total = Math.max(0, elapsedSeconds);
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total / 60) % 60;
        const seconds = total % 60;
        return (hours < 10 ? "0" : "") + hours + ":"
            + (minutes < 10 ? "0" : "") + minutes + ":"
            + (seconds < 10 ? "0" : "") + seconds;
    }

    function winGame() {
        timerRunning = false;
        inputLocked = false;
        moveUnlock.stop();
        won = true;
        pictureShown = true;
        hintVisible = false;
        actionIsShuffle = true;
        saveElapsed();

        stopWinMessage();
        winMessageShown = true;
        winOverlay.opacity = 0;
        winFade.restart();
    }

    // Slide the run between the gap and the clicked cell one step towards the
    // gap. Only cells in the gap's row or column are accepted.
    function moveToCell(cell) {
        if (won || inputLocked || hintVisible) {
            return;
        }
        if (!Number.isInteger(cell) || cell < 0 || cell >= gridSize * gridSize
                || cell === gapIndex) {
            return;
        }

        const gapRow = Math.floor(gapIndex / gridSize);
        const gapColumn = gapIndex % gridSize;
        const row = Math.floor(cell / gridSize);
        const column = cell % gridSize;

        let step = 0;
        if (row === gapRow) {
            step = cell > gapIndex ? 1 : -1;
        } else if (column === gapColumn) {
            step = cell > gapIndex ? gridSize : -gridSize;
        } else {
            return;
        }

        const next = board.slice();
        let current = gapIndex;
        while (current !== cell) {
            const following = current + step;
            next[current] = next[following];
            current = following;
        }
        next[cell] = 16;

        gapIndex = cell;
        board = next;
        moveUnlock.restart();
        inputLocked = true;
        saveBoard();

        if (isSolved()) {
            winGame();
        } else if (!timerRunning) {
            timerRunning = true;
            if (elapsedSeconds === 0) {
                saveElapsed();
            }
        }
    }

    // The arrow selects the tile on the opposite side of the gap (the official
    // gadget: Right picks the left tile, Left picks the right tile, and so on).
    // The bounds guard belongs to the selected cell, so it swaps with the key.
    function moveFromKey(key) {
        if (won || inputLocked || hintVisible) {
            return;
        }
        const row = Math.floor(gapIndex / gridSize);
        const column = gapIndex % gridSize;
        let target = -1;
        if (key === Qt.Key_Left && column < gridSize - 1) {
            target = gapIndex + 1;
        } else if (key === Qt.Key_Right && column > 0) {
            target = gapIndex - 1;
        } else if (key === Qt.Key_Up && row < gridSize - 1) {
            target = gapIndex + gridSize;
        } else if (key === Qt.Key_Down && row > 0) {
            target = gapIndex - gridSize;
        }
        if (target >= 0) {
            moveToCell(target);
        }
    }

    function applyImageId() {
        const id = validImageId(Plasmoid.configuration.imageId);
        if (id !== Plasmoid.configuration.imageId) {
            Plasmoid.configuration.imageId = id;
            return;
        }
        if (id === imageId) {
            return;
        }
        imageId = id;
        shuffle();
    }

    Component.onCompleted: {
        imageId = validImageId(Plasmoid.configuration.imageId);
        if (imageId !== Plasmoid.configuration.imageId) {
            Plasmoid.configuration.imageId = imageId;
        }
        const savedElapsed = Math.max(0, Number(Plasmoid.configuration.elapsed) || 0);

        const saved = parseBoard(String(Plasmoid.configuration.board));
        if (Plasmoid.configuration.started && saved !== null && isSolvable(saved)) {
            restoreBoard(saved, savedElapsed);
        } else {
            shuffle();
        }
        forceActiveFocus();
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Left || event.key === Qt.Key_Right
                || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
            moveFromKey(event.key);
            event.accepted = true;
        }
    }

    Timer {
        id: gameTimer

        interval: 1000
        repeat: true
        running: root.timerRunning

        onTriggered: {
            root.elapsedSeconds += 1;
            root.saveElapsed();
        }
    }

    Timer {
        id: moveUnlock

        interval: 90
        repeat: false

        onTriggered: root.inputLocked = false
    }

    Connections {
        target: Plasmoid.configuration

        function onImageIdChanged() {
            root.applyImageId();
        }
    }

    // ---------------------------------------------------------------------
    // Artwork
    // ---------------------------------------------------------------------

    // The ATP desktop snaps applet cells to a 16 px grid, so this fixed
    // 130x138 design can land in a larger cell. Keep the art and the board at
    // their native size instead of stretching background.png.
    Item {
        id: gadget

        width: 130
        height: 138
        anchors.centerIn: parent

        Image {
            anchors.fill: parent
            source: "../images/background.png"
            fillMode: Image.Pad
        }

        // The original gadget runs in IE quirks mode: the 110x110 pad includes
        // its 1 px border. The background art has a 110x110 recess at (10,19), so
        // the pad sits at (10,20) and the 108x108 tiles fill its content box.
        Rectangle {
            x: 10
            y: 20
            width: root.boardSize + 2
            height: root.boardSize + 2
            color: "transparent"
            border.width: 1
            border.color: "#462300"
        }

        Item {
            id: boardArea

            x: root.boardLeft
            y: root.boardTop
            width: root.boardSize
            height: root.boardSize
            clip: true

            Repeater {
                model: 16

                delegate: Item {
                    id: piece

                    required property int index

                    readonly property int pieceId: index + 1
                    readonly property int cell: root.board.indexOf(pieceId)

                    x: (cell % root.gridSize) * root.tileSize
                    y: Math.floor(cell / root.gridSize) * root.tileSize
                    width: root.tileSize
                    height: root.tileSize
                    z: pieceId === 16 ? 0 : 1
                    visible: cell >= 0

                    Behavior on x {
                        enabled: root.animateMoves
                        NumberAnimation {
                            duration: 90
                            easing.type: Easing.Linear
                        }
                    }
                    Behavior on y {
                        enabled: root.animateMoves
                        NumberAnimation {
                            duration: 90
                            easing.type: Easing.Linear
                        }
                    }

                    Image {
                        anchors.fill: parent
                        visible: piece.pieceId !== 16
                        source: Qt.resolvedUrl("../images/" + root.imageId + ".png")
                        sourceClipRect: Qt.rect(((piece.pieceId - 1) % root.gridSize) * root.tileSize,
                                                Math.floor((piece.pieceId - 1) / root.gridSize) * root.tileSize,
                                                root.tileSize, root.tileSize)
                    }

                    Image {
                        anchors.fill: parent
                        visible: piece.pieceId === 16
                        source: "../images/tile_drop_shadow.png"
                    }

                    Image {
                        anchors.fill: parent
                        visible: piece.pieceId !== 16
                        source: "../images/tile_bezel.png"
                    }
                }
            }
        }

        // Transparent in the original gadget; kept because it is the click target.
        Image {
            x: root.boardLeft
            y: root.boardTop
            width: root.boardSize
            height: root.boardSize
            source: "../images/glow.png"
            z: 8
        }

        MouseArea {
            id: boardMouse

            x: root.boardLeft
            y: root.boardTop
            width: root.boardSize
            height: root.boardSize
            z: 9
            acceptedButtons: Qt.LeftButton
            cursorShape: Qt.ArrowCursor

            onPressed: (mouse) => {
                root.forceActiveFocus();
                const column = Math.floor(mouse.x / root.tileSize);
                const row = Math.floor(mouse.y / root.tileSize);
                root.moveToCell(row * root.gridSize + column);
            }
        }

        // Full picture shown while the hint button is held, and after a win.
        Image {
            id: pictureOverlay

            x: root.boardLeft
            y: root.boardTop
            width: root.boardSize
            height: root.boardSize
            source: Qt.resolvedUrl("../images/" + root.imageId + ".png")
            visible: root.hintVisible || root.pictureShown
            z: 20

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                onPressed: (mouse) => mouse.accepted = true
            }
        }

        Rectangle {
            id: winOverlay

            x: 10
            y: 19
            width: root.boardSize + 2
            height: root.boardSize + 2
            color: "#333333"
            border.width: 1
            border.color: "#462300"
            opacity: 0
            visible: root.winMessageShown
            z: 30

            Column {
                y: 30
                width: parent.width
                spacing: 2

                Text {
                    width: parent.width
                    text: i18n("Congratulations!")
                    color: "#ffffff"
                    font.family: "Segoe UI"
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    width: parent.width
                    text: i18n("You win !!")
                    color: "#ffffff"
                    font.family: "Segoe UI"
                    font.pixelSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton

                onPressed: (mouse) => mouse.accepted = true
            }
        }

        SequentialAnimation {
            id: winFade

            NumberAnimation {
                target: winOverlay
                property: "opacity"
                from: 0
                to: 1
                duration: 200
            }
            PauseAnimation {
                duration: 800
            }
            NumberAnimation {
                target: winOverlay
                property: "opacity"
                from: 1
                to: 0
                duration: 900
            }
            ScriptAction {
                script: {
                    root.winMessageShown = false;
                    winOverlay.opacity = 0;
                }
            }
        }

        // ---------------------------------------------------------------------
        // Toolbar
        // ---------------------------------------------------------------------

        component ToolbarButton: Item {
            id: button

            property string iconName: ""
            property string tooltipText: ""

            signal clicked()
            signal pressed()
            signal released()

            width: 14
            height: 14

            readonly property string imageState: !button.enabled
                ? "up"
                : (mouse.pressed ? "down" : (mouse.containsMouse ? "over" : "up"))

            Image {
                anchors.fill: parent
                source: Qt.resolvedUrl("../images/" + button.iconName + "_" + button.imageState + ".png")
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton
                cursorShape: Qt.ArrowCursor

                onPressed: button.pressed()
                onReleased: button.released()
                onCanceled: button.released()
                onClicked: button.clicked()
            }

            QQC2.ToolTip.visible: button.enabled && mouse.containsMouse && button.tooltipText.length > 0
            QQC2.ToolTip.text: button.tooltipText
        }

        ToolbarButton {
            x: 9
            y: 4
            iconName: "timer"
            tooltipText: i18n("Pause timer")
            enabled: root.timerRunning && !root.won

            onClicked: root.pauseTimer()
        }

        Text {
            id: timerText

            x: 24
            y: 4
            text: root.formattedTime()
            color: "#462300"
            font.family: "Segoe UI"
            font.pixelSize: 11
            font.bold: true
        }

        ToolbarButton {
            id: hintButton

            x: 92
            y: 4
            iconName: "hint"
            tooltipText: i18n("Show picture")
            enabled: !root.won

            onPressed: root.hintVisible = true
            onReleased: root.hintVisible = false
        }

        ToolbarButton {
            x: 107
            y: 4
            iconName: "shuffle"
            tooltipText: root.actionIsShuffle ? i18n("Shuffle") : i18n("Solve")
            enabled: !root.winMessageShown

            onClicked: {
                if (root.actionIsShuffle) {
                    root.shuffle();
                } else {
                    root.solve();
                }
            }
        }
    }
}
