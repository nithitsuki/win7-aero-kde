/*
    SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
    SPDX-License-Identifier: GPL-3.0-or-later

    Clean-room QML reimplementation of the Windows 7 Calendar gadget.

    The look follows the original gadget: a spiral-bound desktop page with a
    month grid on the upper page and a large day page on the lower page, or a
    single day page when only the docked layout is wanted. The artwork in
    contents/images/ is Microsoft's and is copied from the user's Windows 7
    installation by the installer; it is not part of this repository.
*/

import QtQuick
import QtQuick.Layouts

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: root

    // The two layouts have different native sizes.
    readonly property int designWidth: viewMode === "double" ? 129 : 130
    readonly property int designHeight: viewMode === "double" ? 264 : 141

    // "double" is the desktop page with a month grid above and a day page
    // below; "day" is the docked-style page with one large day number.
    readonly property string viewMode: Plasmoid.configuration.view === "day" ? "day" : "double"
    // "month" shows the month grid, "year" shows the 12-month picker.
    readonly property string zoomMode: Plasmoid.configuration.zoom === "year" ? "year" : "month"

    // Rolled forward by the midnight timer.
    property date today: new Date()

    // The upper page is anchored to shownDate. An empty stored value means
    // "follow today", which is what the original gadget does until the user
    // navigates away.
    readonly property date shownDate: {
        var stored = isoToDate(Plasmoid.configuration.shownDate)
        return stored !== null ? stored : today
    }

    // The lower page is the tear-off day sheet. It starts on the upper page's
    // date and then moves independently, as in the original.
    property date dayDate: new Date()
    readonly property bool dayDateToday: sameDay(dayDate, today)
    readonly property bool shownToday: sameDay(shownDate, today)

    Component.onCompleted: dayDate = shownDate
    onViewModeChanged: {
        if (viewMode === "double") {
            dayDate = shownDate
        }
    }
    // "Show today" in the settings clears shownDate; bring the tear-off page
    // along and let it follow the midnight rollover too.
    onShownDateChanged: {
        if (Plasmoid.configuration.shownDate === "") {
            dayDate = today
        }
    }

    readonly property int firstDay: Qt.locale().firstDayOfWeek

    // Some locales write the year before the month. The original decided this
    // by formatting a test date; do the same with the system long date.
    readonly property bool yearFirst: {
        var sample = Qt.formatDate(new Date(1999, 0, 25), Qt.SystemLocaleLongDate)
        var dayPos = sample.indexOf("25")
        var yearPos = sample.indexOf("99")
        return dayPos >= 0 && yearPos >= 0 && yearPos < dayPos
    }

    implicitWidth: designWidth
    implicitHeight: designHeight

    Plasmoid.title: i18n("Calendar")
    Plasmoid.icon: "x-office-calendar"
    Plasmoid.status: PlasmaCore.Types.PassiveStatus
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Accessible.name: i18n("Calendar")
    Accessible.description: i18n("A calendar with a month grid and a tear-off day page")
    toolTipMainText: i18n("Calendar")
    toolTipSubText: i18n("Click the title for the year view. The arrows change the month.")
    preferredRepresentation: fullRepresentation

    Layout.preferredWidth: implicitWidth
    Layout.preferredHeight: implicitHeight

    // ------------------------------------------------------------------
    // Date helpers
    // ------------------------------------------------------------------

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
            && a.getDate() === b.getDate()
    }

    function sameMonth(a, b) {
        return a.getFullYear() === b.getFullYear()
            && a.getMonth() === b.getMonth()
    }

    function makeDate(year, month, day) {
        var lastDay = new Date(year, month + 1, 0).getDate()
        return new Date(year, month, Math.min(day, lastDay))
    }

    function addMonths(date, count) {
        return makeDate(date.getFullYear(), date.getMonth() + count, date.getDate())
    }

    function addYears(date, count) {
        return makeDate(date.getFullYear() + count, date.getMonth(), date.getDate())
    }

    function isoDate(date) {
        return Qt.formatDate(date, "yyyy-MM-dd")
    }

    function isoToDate(value) {
        if (typeof value !== "string" || value.length === 0) {
            return null
        }
        var parts = value.split("-")
        if (parts.length !== 3) {
            return null
        }
        var year = parseInt(parts[0], 10)
        var month = parseInt(parts[1], 10)
        var day = parseInt(parts[2], 10)
        if (isNaN(year) || isNaN(month) || isNaN(day)) {
            return null
        }
        var result = new Date(year, month - 1, day)
        if (result.getFullYear() !== year
                || result.getMonth() !== month - 1
                || result.getDate() !== day) {
            return null
        }
        return result
    }

    function leadingDays(year, month) {
        // Number of cells before the first of the month, honouring the
        // locale's first day of week.
        var first = new Date(year, month, 1)
        return (first.getDay() - firstDay + 7) % 7
    }

    function cellDate(year, month, index) {
        return new Date(year, month, 1 - leadingDays(year, month) + index)
    }

    // ------------------------------------------------------------------
    // Locale labels
    // ------------------------------------------------------------------

    function monthShort(month) {
        return Qt.locale().monthName(month, Locale.ShortFormat)
    }

    function monthLong(month) {
        return Qt.locale().monthName(month, Locale.LongFormat)
    }

    function monthTitle(date) {
        var month = monthShort(date.getMonth())
        var year = String(date.getFullYear()).slice(-2)
        return yearFirst ? (year + " " + month) : (month + " " + year)
    }

    function monthYearLabel(date) {
        var month = monthLong(date.getMonth())
        var year = date.getFullYear()
        return yearFirst ? (year + " " + month) : (month + " " + year)
    }

    function weekdayLong(date) {
        return Qt.locale().dayName(date.getDay(), Locale.LongFormat)
    }

    function weekdayInitial(dayOfWeek) {
        var narrow = Qt.locale().dayName(dayOfWeek, Locale.NarrowFormat)
        // Some locales (including C) return a bare weekday number in the
        // narrow format. Use a letter from the short name instead.
        if (narrow.length === 1 && !/^\d+$/.test(narrow)) {
            return narrow
        }
        var shortName = Qt.locale().dayName(dayOfWeek, Locale.ShortFormat)
        return shortName.length > 0 ? shortName.charAt(0) : ""
    }

    // ------------------------------------------------------------------
    // Navigation
    // ------------------------------------------------------------------

    property real flipAngle: 0
    property bool flipRunning: false
    property int flipDirection: 1
    property string flipScope: "top"
    property var pendingAction: null

    readonly property real topFlipAngle: flipScope === "top" || flipScope === "both" ? flipAngle : 0
    readonly property real dayFlipAngle: flipScope === "day" || flipScope === "both" ? flipAngle : 0

    function runFlip(direction, scope, action) {
        if (flipRunning) {
            return
        }
        flipDirection = direction
        flipScope = scope
        pendingAction = action
        flipAngle = 0
        flipRunning = true
        flipAnimation.restart()
    }

    function goToToday(animated) {
        if (viewMode === "day") {
            if (shownToday) {
                return
            }
            var dayDirection = shownDate.getTime() <= today.getTime() ? 1 : -1
            var dayAction = function() {
                Plasmoid.configuration.shownDate = ""
                Plasmoid.configuration.zoom = "month"
            }
            if (animated) {
                runFlip(dayDirection, "day", dayAction)
            } else {
                dayAction()
            }
            return
        }

        var topChanges = !sameMonth(shownDate, today)
        if (dayDateToday && !topChanges) {
            return
        }
        var direction = (topChanges && today.getTime() >= shownDate.getTime())
            || (!topChanges && today.getTime() >= dayDate.getTime()) ? 1 : -1
        var scope = dayDateToday ? "top" : (topChanges ? "both" : "day")
        var action = function() {
            root.dayDate = root.today
            Plasmoid.configuration.shownDate = ""
            Plasmoid.configuration.zoom = "month"
        }
        if (animated) {
            runFlip(direction, scope, action)
        } else {
            action()
        }
    }

    // Clicking a day in the upper grid changes the lower day page only.
    function selectDay(date) {
        if (sameDay(date, dayDate)) {
            return
        }
        var direction = date.getTime() > dayDate.getTime() ? 1 : -1
        runFlip(direction, "day", function() {
            root.dayDate = date
        })
    }

    // Clicking the lower day page makes the upper page follow it.
    function selectDayPage() {
        var nextShown = sameDay(dayDate, today) ? "" : isoDate(dayDate)
        var action = function() {
            Plasmoid.configuration.shownDate = nextShown
            Plasmoid.configuration.zoom = "month"
        }
        if (sameMonth(dayDate, shownDate)) {
            action()
            return
        }
        var direction = dayDate.getTime() > shownDate.getTime() ? 1 : -1
        runFlip(direction, "top", action)
    }

    // Prev/next only turns the upper page; the tear-off page stays put.
    function navigate(direction) {
        var yearZoom = zoomMode === "year"
        var action = function() {
            var base = root.shownDate
            var next = yearZoom ? addYears(base, direction) : addMonths(base, direction)
            Plasmoid.configuration.shownDate = isoDate(next)
        }
        runFlip(direction, "top", action)
    }

    function toggleZoom() {
        if (viewMode !== "double") {
            return
        }
        Plasmoid.configuration.zoom = zoomMode === "year" ? "month" : "year"
    }

    function selectMonth(month) {
        var date = makeDate(shownDate.getFullYear(), month, shownDate.getDate())
        var nextShown = sameDay(date, today) ? "" : isoDate(date)
        var action = function() {
            Plasmoid.configuration.shownDate = nextShown
            Plasmoid.configuration.zoom = "month"
        }
        if (sameMonth(date, shownDate)) {
            action()
            return
        }
        runFlip(date.getTime() > shownDate.getTime() ? 1 : -1, "top", action)
    }

    // ------------------------------------------------------------------
    // Animation
    // ------------------------------------------------------------------

    SequentialAnimation {
        id: flipAnimation

        NumberAnimation {
            target: root
            property: "flipAngle"
            to: root.flipDirection > 0 ? -88 : 88
            duration: 110
            easing.type: Easing.InQuad
        }
        ScriptAction {
            script: {
                if (root.pendingAction !== null) {
                    var action = root.pendingAction
                    root.pendingAction = null
                    action()
                }
                root.flipAngle = root.flipDirection > 0 ? 88 : -88
            }
        }
        NumberAnimation {
            target: root
            property: "flipAngle"
            to: 0
            duration: 150
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.flipRunning = false
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true

        onTriggered: {
            var now = new Date()
            if (!root.sameDay(now, root.today)) {
                var dayPageWasToday = root.sameDay(root.dayDate, root.today)
                root.today = now
                if (dayPageWasToday) {
                    root.dayDate = now
                }
            }
        }
    }

    // ------------------------------------------------------------------
    // Presentation
    // ------------------------------------------------------------------

    fullRepresentation: Item {
        id: holder

        implicitWidth: root.designWidth
        implicitHeight: root.designHeight

        Layout.preferredWidth: implicitWidth
        Layout.preferredHeight: implicitHeight
        Layout.minimumWidth: implicitWidth
        Layout.minimumHeight: implicitHeight
        Layout.maximumWidth: implicitWidth
        Layout.maximumHeight: implicitHeight

        Item {
            id: frame

            width: root.designWidth
            height: root.designHeight
            anchors.centerIn: parent
            clip: true

            Image {
                id: pageBackground

                anchors.fill: parent
                asynchronous: false
                smooth: true
                fillMode: Image.Stretch
                source: {
                    if (root.viewMode === "double") {
                        return root.dayDateToday
                            ? "../images/calendar_double_orange.png"
                            : "../images/calendar_double.png"
                    }
                    return root.shownToday
                        ? "../images/calendar_single_orange.png"
                        : "../images/calendar_single.png"
                }
            }

            // ----------------------------------------------------------
            // Desktop page: month grid above, day page below
            // ----------------------------------------------------------

            Item {
                id: doubleView

                anchors.fill: parent
                visible: root.viewMode === "double"

                // Upper page: month grid or year picker.
                Item {
                    id: topPageLayer

                    anchors.fill: parent
                    enabled: !root.flipRunning
                    antialiasing: true

                    transform: Rotation {
                        origin.x: topPageLayer.width / 2
                        origin.y: topPageLayer.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: root.topFlipAngle
                    }

                    Item {
                        id: monthBlock

                        readonly property date anchorDate: root.shownDate
                        readonly property int year: anchorDate.getFullYear()
                        readonly property int month: anchorDate.getMonth()

                        x: 3
                        y: 7
                        width: 123
                        height: 112
                        visible: root.zoomMode === "month"

                        Image {
                            x: 1
                            y: -3
                            width: 120
                            height: 118
                            source: "../images/calendar_double_bkg.png"
                            fillMode: Image.Stretch
                            smooth: true
                            asynchronous: false
                        }

                        Text {
                            x: 0
                            y: 0
                            width: parent.width
                            height: 20
                            text: root.monthTitle(monthBlock.anchorDate)
                            color: "#1a1a1a"
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Repeater {
                            model: 7

                            delegate: Item {
                                id: weekdayHeader

                                required property int index

                                readonly property int dayOfWeek: (root.firstDay + index) % 7
                                readonly property bool todayColumn: dayOfWeek === root.today.getDay()
                                    && monthBlock.year === root.today.getFullYear()
                                    && monthBlock.month === root.today.getMonth()

                                x: 2 + index * 17
                                y: 20
                                width: 16
                                height: 14

                                Rectangle {
                                    x: 0
                                    y: 0
                                    width: 1
                                    height: parent.height
                                    visible: weekdayHeader.index > 0
                                    color: "#dedfde"
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.rightMargin: 2
                                    text: root.weekdayInitial(weekdayHeader.dayOfWeek)
                                    color: weekdayHeader.todayColumn ? "#ff6400" : "#808080"
                                    font.pixelSize: 10
                                    font.bold: true
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                }
                            }
                        }

                        Repeater {
                            model: 42

                            delegate: Item {
                                id: dayCell

                                required property int index

                                readonly property int row: Math.floor(index / 7)
                                readonly property int column: index % 7
                                readonly property date cellDate: root.cellDate(monthBlock.year, monthBlock.month, index)
                                readonly property bool inMonth: cellDate.getMonth() === monthBlock.month
                                readonly property bool isToday: inMonth && root.sameDay(cellDate, root.today)
                                property bool hovered: false

                                x: 2 + column * 17
                                y: 34 + row * 13
                                width: 16
                                height: 13

                                Image {
                                    anchors.fill: parent
                                    visible: dayCell.isToday
                                    source: "../images/bg-today.png"
                                    // The source has a dark page edge; the
                                    // centre is the flat orange cell fill.
                                    sourceClipRect: Qt.rect(6, 6, 111, 115)
                                    fillMode: Image.Stretch
                                    smooth: true
                                    asynchronous: false
                                }

                                Rectangle {
                                    x: 0
                                    y: 0
                                    width: 1
                                    height: parent.height
                                    visible: dayCell.column > 0
                                    color: "#dedfde"
                                }

                                Text {
                                    anchors.fill: parent
                                    anchors.rightMargin: 2
                                    text: dayCell.cellDate.getDate()
                                    color: {
                                        if (dayCell.isToday) {
                                            return "white"
                                        }
                                        if (dayCell.hovered) {
                                            return "#ff6400"
                                        }
                                        if (!dayCell.inMonth) {
                                            return "#c0c0c0"
                                        }
                                        return "#1a1a1a"
                                    }
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: dayCell.hovered = true
                                    onExited: dayCell.hovered = false
                                    onClicked: root.selectDay(dayCell.cellDate)
                                }
                            }
                        }
                    }

                    // The year picker replaces the month grid on the upper
                    // page; the day page below stays visible.
                    Item {
                        id: yearPage

                        x: 3
                        y: 4
                        width: 123
                        height: 118
                        visible: root.zoomMode === "year"

                        Image {
                            x: 1
                            y: 0
                            width: 120
                            height: 118
                            source: "../images/calendar_double_bkg.png"
                            fillMode: Image.Stretch
                            smooth: true
                            asynchronous: false
                        }

                        Text {
                            x: 0
                            y: 3
                            width: parent.width
                            height: 18
                            text: String(root.shownDate.getFullYear())
                            color: "#1a1a1a"
                            font.pixelSize: 11
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Repeater {
                            model: 12

                            delegate: Item {
                                id: yearMonth

                                required property int index

                                readonly property int column: index % 4
                                readonly property int row: Math.floor(index / 4)
                                property bool hovered: false

                                x: 5 + column * 28
                                y: 24 + row * 28
                                width: 28
                                height: 27

                                Image {
                                    x: (parent.width - width) / 2
                                    y: 0
                                    width: 13
                                    height: 9
                                    source: "../images/month.png"
                                    smooth: false
                                    asynchronous: false
                                }

                                Text {
                                    x: 0
                                    y: 9
                                    width: parent.width
                                    height: 15
                                    text: root.monthShort(yearMonth.index)
                                    color: yearMonth.hovered ? "#ff6400" : "#1a1a1a"
                                    font.pixelSize: 10
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: yearMonth.hovered = true
                                    onExited: yearMonth.hovered = false
                                    onClicked: root.selectMonth(yearMonth.index)
                                }
                            }
                        }
                    }
                }

                // Lower page: the tear-off day sheet.
                Item {
                    id: lowerPageLayer

                    x: 3
                    y: 133
                    width: 123
                    height: 127
                    antialiasing: true

                    transform: Rotation {
                        origin.x: lowerPageLayer.width / 2
                        origin.y: lowerPageLayer.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: root.dayFlipAngle
                    }

                    Image {
                        anchors.fill: parent
                        source: root.dayDateToday
                            ? "../images/calendar_single_bkg_orange.png"
                            : "../images/calendar_single_bkg.png"
                        fillMode: Image.Stretch
                        smooth: true
                        asynchronous: false
                    }

                    Item {
                        id: lowerDayContent

                        x: 2
                        y: 10
                        width: 120
                        height: 112

                        readonly property color ink: root.dayDateToday ? "white" : "black"

                        Text {
                            x: 0
                            y: 2
                            width: parent.width
                            height: 18
                            text: root.weekdayLong(root.dayDate)
                            color: lowerDayContent.ink
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }

                        Text {
                            x: 0
                            y: 18
                            width: parent.width
                            height: 64
                            text: root.dayDate.getDate()
                            color: lowerDayContent.ink
                            font.pixelSize: 75
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        Text {
                            x: 0
                            y: 84
                            width: parent.width
                            height: 18
                            text: root.monthYearLabel(root.dayDate)
                            color: lowerDayContent.ink
                            font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }
                }

                // Clicking the tear-off page makes the upper page follow it.
                MouseArea {
                    x: 3
                    y: 133
                    width: 123
                    height: 127
                    enabled: !root.flipRunning
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.selectDayPage()
                }

                // Navigation buttons stay on the page while its text flips.
                Item {
                    id: previousButton

                    x: 6
                    y: 9
                    width: 16
                    height: 16

                    Image {
                        anchors.fill: parent
                        smooth: false
                        asynchronous: false
                        source: previousButtonMouse.pressed
                            ? "../images/bPrev-down.png"
                            : (previousButtonMouse.containsMouse
                                ? "../images/bPrev-hot.png"
                                : "../images/bPrev.png")
                    }

                    MouseArea {
                        id: previousButtonMouse

                        anchors.fill: parent
                        enabled: !root.flipRunning
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigate(-1)
                    }
                }

                Item {
                    id: nextButton

                    x: 107
                    y: 9
                    width: 16
                    height: 16

                    Image {
                        anchors.fill: parent
                        smooth: false
                        asynchronous: false
                        source: nextButtonMouse.pressed
                            ? "../images/bNext-down.png"
                            : (nextButtonMouse.containsMouse
                                ? "../images/bNext-hot.png"
                                : "../images/bNext.png")
                    }

                    MouseArea {
                        id: nextButtonMouse

                        anchors.fill: parent
                        enabled: !root.flipRunning
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.navigate(1)
                    }
                }

                // The month/year title toggles the year picker.
                MouseArea {
                    x: 24
                    y: 7
                    width: 81
                    height: 20
                    enabled: !root.flipRunning
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleZoom()
                }

                // Page curl on the lower page.
                Item {
                    id: doubleCurl

                    x: 2
                    y: 234
                    width: 27
                    height: 27
                    visible: !root.dayDateToday

                    Image {
                        anchors.fill: parent
                        smooth: true
                        asynchronous: false
                        source: doubleCurlMouse.containsMouse
                            ? "../images/curl-hot.png"
                            : "../images/curl.png"
                    }

                    MouseArea {
                        id: doubleCurlMouse

                        anchors.fill: parent
                        enabled: !root.flipRunning
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToToday(true)
                    }
                }
            }

            // ----------------------------------------------------------
            // Day-only page
            // ----------------------------------------------------------

            Item {
                id: dayView

                anchors.fill: parent
                visible: root.viewMode === "day"

                readonly property color ink: root.shownToday ? "white" : "black"

                MouseArea {
                    anchors.fill: parent
                    enabled: !root.flipRunning && !root.shownToday
                    cursorShape: root.shownToday ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onClicked: root.goToToday(true)
                }

                Item {
                    id: dayTextLayer

                    x: 4
                    y: 18
                    width: 122
                    height: 112
                    antialiasing: true

                    transform: Rotation {
                        origin.x: dayTextLayer.width / 2
                        origin.y: dayTextLayer.height / 2
                        axis { x: 0; y: 1; z: 0 }
                        angle: root.dayFlipAngle
                    }

                    Text {
                        x: 0
                        y: 2
                        width: parent.width
                        height: 18
                        text: root.weekdayLong(root.shownDate)
                        color: dayView.ink
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    Text {
                        x: 0
                        y: 18
                        width: parent.width
                        height: 64
                        text: root.shownDate.getDate()
                        color: dayView.ink
                        font.pixelSize: 75
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        x: 0
                        y: 84
                        width: parent.width
                        height: 18
                        text: root.monthYearLabel(root.shownDate)
                        color: dayView.ink
                        font.pixelSize: 13
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }
                }

                Item {
                    id: dayCurl

                    x: 4
                    y: 109
                    width: 27
                    height: 27
                    visible: !root.shownToday

                    Image {
                        anchors.fill: parent
                        smooth: true
                        asynchronous: false
                        source: dayCurlMouse.containsMouse
                            ? "../images/curl-hot.png"
                            : "../images/curl.png"
                    }

                    MouseArea {
                        id: dayCurlMouse

                        anchors.fill: parent
                        enabled: !root.flipRunning
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.goToToday(true)
                    }
                }
            }
        }
    }
}
