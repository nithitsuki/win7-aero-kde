// SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
// SPDX-License-Identifier: GPL-3.0-or-later
//
// Windows 7 "Currency" sidebar gadget, reimplemented for Plasma 6.
//
// Box sizes, row pitch, fonts and hover states follow the original gadget:
// 254 x 171/226/281 px undocked (2/3/4 rows) and 130 x 83 px docked.
// The artwork (backgrounds, buttons, spinner strip) is not part of the source
// tree; the installer copies it from the Windows 7 ISO into ../images/.
//
// The only real difference from the original is the data source: the Windows
// Live COM service it polled is dead, so RateService.qml talks to Frankfurter
// (daily ECB reference rates) instead. See RateService.qml for the details and
// the limits of that feed.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC

import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid

PlasmoidItem {
    id: applet

    readonly property int minimumRows: 2
    readonly property int maximumRows: 4

    // The original was drawn with Segoe UI on Windows. Where the font is not
    // installed Qt falls back to the system UI font.
    readonly property string uiFont: "Segoe UI"

    // Configuration mirror. The applet's configuration map is read once the
    // item is complete and kept in local properties: bindings that read it
    // during construction (implicitWidth and friends) do not always keep
    // their dependency on the map, and the mirror also survives a map being
    // replaced by the config dialog.
    property int rowsFromConfig: 2
    property bool dockedFromConfig: false
    property string baseFromConfig: "USD"
    property var symbolsFromConfig: ["EUR", "GBP", "JPY"]

    readonly property int visibleRows: Math.max(minimumRows, Math.min(maximumRows, rowsFromConfig))
    readonly property bool docked: dockedFromConfig
    readonly property string baseCode: baseFromConfig

    // Currencies of rows 1..3. Always three entries so adding a row never has
    // to invent a currency; rows beyond visibleRows are simply not shown.
    readonly property var symbolList: symbolsFromConfig

    function readConfig() {
        var n = Number(Plasmoid.configuration.rowCount);
        rowsFromConfig = isFinite(n) ? Math.round(n) : 2;

        dockedFromConfig = Plasmoid.configuration.docked === true;
        baseFromConfig = String(Plasmoid.configuration.base || "USD");

        var stored = Plasmoid.configuration.symbols;
        var defaults = ["EUR", "GBP", "JPY"];
        var list = [];
        if (stored && stored.length !== undefined) {
            for (var i = 0; i < stored.length && i < 3; i++)
                list.push(String(stored[i]));
        }
        while (list.length < 3)
            list.push(defaults[list.length]);
        if (list.join(",") !== symbolsFromConfig.join(","))
            symbolsFromConfig = list;
    }

    // Text exactly as typed; the base row is the only editable one.
    property string amountRaw: "1"
    // Converted text for rows 1..3, recomputed whenever an input changes.
    property var rowValues: ["", "", ""]
    property string ageLabel: ""
    property int spinnerFrame: 0

    // 254 x 171 (2 rows), 254 x 226 (3 rows), 254 x 281 (4 rows), or the
    // 130 x 83 docked box. The size is fixed, the gadget is not resizable.
    readonly property int widgetWidth: docked ? 130 : 254
    readonly property int widgetHeight: docked ? 83 : (171 + 55 * (visibleRows - 2))

    implicitWidth: widgetWidth
    implicitHeight: widgetHeight
    Layout.preferredWidth: widgetWidth
    Layout.preferredHeight: widgetHeight
    Layout.minimumWidth: widgetWidth
    Layout.minimumHeight: widgetHeight
    Layout.maximumWidth: widgetWidth
    Layout.maximumHeight: widgetHeight

    // The gadget art already contains the Aero frame: no Plasma background.
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    Plasmoid.title: i18n("Currency")
    Plasmoid.icon: "accessories-calculator"
    Plasmoid.status: PlasmaCore.Types.PassiveStatus

    Accessible.name: i18n("Currency")
    Accessible.description: i18n("Convert an amount between currencies")

    preferredRepresentation: fullRepresentation
    toolTipMainText: i18n("Currency")
    toolTipSubText: ageLabel

    RateService {
        id: rateService
    }

    // ------------------------------------------------------------------
    // Rows
    // ------------------------------------------------------------------

    function currencyForRow(index) {
        if (index <= 0)
            return baseCode;
        return symbolList[index - 1] || "EUR";
    }

    function setRowCurrency(index, code) {
        if (index <= 0) {
            Plasmoid.configuration.base = code;
        } else {
            var list = symbolList.slice();
            list[index - 1] = code;
            Plasmoid.configuration.symbols = list;
        }
        readConfig();
    }

    function addRow() {
        if (visibleRows >= maximumRows)
            return;
        Plasmoid.configuration.rowCount = visibleRows + 1;
        readConfig();
    }

    // Removes the row and renumbers the ones below it, like the original.
    // The removed currency moves to the end of the hidden slots, so adding a
    // row again brings it back instead of duplicating a visible one.
    function deleteRow(index) {
        if (index <= 0 || visibleRows <= minimumRows)
            return;
        var list = symbolList.slice();
        var removed = list.splice(index - 1, 1)[0];
        list.push(removed);
        Plasmoid.configuration.symbols = list;
        Plasmoid.configuration.rowCount = visibleRows - 1;
        readConfig();
    }

    // ------------------------------------------------------------------
    // Values
    // ------------------------------------------------------------------

    // Accepts "1", "1.5", "1,5", "1,234.56" and "1 234,56"; anything else is
    // not a number (the original printed "Bad Number!" for those).
    function parseAmount(text) {
        var raw = String(text === undefined || text === null ? "" : text);
        var cleaned = raw.replace(/[\s\u00a0\u202f]/g, "");
        if (cleaned === "")
            return 0;
        if (/^-?\d{1,3}(,\d{3})+(\.\d+)?$/.test(cleaned))
            cleaned = cleaned.replace(/,/g, "");
        else
            cleaned = cleaned.replace(/,/g, ".");
        var value = Number(cleaned);
        return isNaN(value) ? NaN : value;
    }

    function recompute() {
        if (!rateService.hasData) {
            rowValues = ["", "", ""];
            return;
        }
        var amount = parseAmount(amountRaw);
        // Original: 3 decimals docked, 5 decimals undocked.
        var decimals = docked ? 3 : 5;
        var values = [];
        for (var i = 1; i < maximumRows; i++) {
            if (isNaN(amount))
                values.push(i18n("Bad Number!"));
            else
                values.push(rateService.format(amount, baseCode, currencyForRow(i), decimals));
        }
        rowValues = values;
    }

    function updateAge() {
        if (!rateService.hasData || rateService.lastUpdate === null) {
            ageLabel = "";
            return;
        }
        var diff = Math.max(0, Date.now() - rateService.lastUpdate.getTime());
        var minutes = Math.floor(diff / 60000);
        var hours = Math.floor(minutes / 60);
        var days = Math.floor(hours / 24);
        if (days > 0)
            ageLabel = i18n("%1 %2 ago", String(days), days > 1 ? i18n("days") : i18n("day"));
        else if (hours > 0)
            ageLabel = i18n("%1 %2 ago", String(hours), hours > 1 ? i18n("hrs") : i18n("hr"));
        else if (minutes > 0)
            ageLabel = i18n("%1 %2 ago", String(minutes), i18n("min"));
        else
            ageLabel = "";
    }

    function refreshRates() {
        rateService.refresh();
    }

    // ------------------------------------------------------------------
    // Startup / cache
    // ------------------------------------------------------------------

    Component.onCompleted: {
        readConfig();
        amountRaw = String(Plasmoid.configuration.amount || "1");

        var hadCache = rateService.restoreCache(String(Plasmoid.configuration.ratesCache || ""));
        if (hadCache) {
            var stamp = String(Plasmoid.configuration.lastUpdate || "");
            rateService.lastUpdate = stamp !== "" ? new Date(stamp) : null;
        }
        updateAge();
        recompute();

        // At most one request per day: a cache from today is good enough.
        if (!rateService.isFresh())
            rateService.refresh();
    }

    Connections {
        target: Plasmoid.configuration
        function onValueChanged(key, value) {
            applet.readConfig();
        }
    }

    Connections {
        target: rateService
        function onRefreshed() {
            Plasmoid.configuration.ratesCache = rateService.cacheJson();
            Plasmoid.configuration.lastUpdate = rateService.lastUpdate !== null
                ? rateService.lastUpdate.toISOString() : "";
            updateAge();
            recompute();
        }
        function onFailed() {
            updateAge();
            recompute();
        }
    }

    onBaseCodeChanged: recompute()
    onSymbolListChanged: recompute()
    onDockedChanged: recompute()
    onAmountRawChanged: recompute()

    // Keeps "12 min ago" honest.
    Timer {
        interval: 60 * 1000
        repeat: true
        running: true
        onTriggered: applet.updateAge()
    }

    // Picks up the next daily ECB fix while the gadget stays open. Without
    // data (offline, or a failed first fetch) retry every minute, like the
    // original gadget did; once data is fresh, a half-hourly check is enough.
    Timer {
        interval: rateService.hasData ? 30 * 60 * 1000 : 60 * 1000
        repeat: true
        running: true
        onTriggered: {
            if (rateService.loading)
                return;
            if (rateService.hasData && rateService.isFresh())
                return;
            rateService.refresh();
        }
    }

    // Animated 16x288 strip from the original gadget (18 frames of 16 px).
    Timer {
        interval: 30
        repeat: true
        running: rateService.loading
        onTriggered: applet.spinnerFrame = (applet.spinnerFrame + 1) % 18
    }

    // ------------------------------------------------------------------
    // UI
    // ------------------------------------------------------------------

    fullRepresentation: Item {
        id: widget

        readonly property bool dockedMode: applet.docked
        readonly property bool busy: rateService.loading
        readonly property bool showData: rateService.hasData

        // Size of the original art; the box it sits in can be taller in some
        // containments, so bottom-anchored items follow the art, not the item.
        readonly property int artWidth: dockedMode ? 130 : 254
        readonly property int artHeight: dockedMode ? 83 : (171 + 55 * (applet.visibleRows - 2))

        // 254 x 171 (2 rows), 254 x 226 (3 rows), 254 x 281 (4 rows).
        implicitWidth: applet.widgetWidth
        implicitHeight: applet.widgetHeight
        Layout.preferredWidth: applet.widgetWidth
        Layout.preferredHeight: applet.widgetHeight
        Layout.minimumWidth: applet.widgetWidth
        Layout.minimumHeight: applet.widgetHeight
        Layout.maximumWidth: applet.widgetWidth
        Layout.maximumHeight: applet.widgetHeight

        clip: true

        Image {
            id: background
            x: 0
            y: 0
            width: widget.artWidth
            height: widget.artHeight
            source: widget.dockedMode ? "../images/base-docked.png"
                                      : "../images/base-undocked-" + applet.visibleRows + ".png"
            fillMode: Image.Pad
        }

        // ------------------------------------------------------------
        // Status / error pane (covers the rows while there is no data)
        // ------------------------------------------------------------
        Item {
            id: messagePane
            visible: !widget.showData
            x: widget.dockedMode ? 0 : 13
            y: 0
            width: widget.dockedMode ? 130 : 220
            height: widget.dockedMode ? 81 : 162

            // The original gadget retried on its own every minute; let a click
            // on the status text do it immediately as well.
            MouseArea {
                anchors.fill: parent
                cursorShape: widget.busy ? Qt.ArrowCursor : Qt.PointingHandCursor
                onClicked: applet.refreshRates()
                QQC.ToolTip.text: i18n("Click to retry")
                QQC.ToolTip.visible: containsMouse && !widget.busy
                QQC.ToolTip.delay: 500
            }

            Row {
                anchors.centerIn: parent
                spacing: 4

                Item {
                    width: 16
                    height: 16
                    anchors.verticalCenter: parent.verticalCenter

                    Image {
                        anchors.fill: parent
                        visible: widget.busy
                        source: "../images/activity16v.png"
                        sourceClipRect: Qt.rect(0, (applet.spinnerFrame % 18) * 16, 16, 16)
                    }

                    Image {
                        anchors.fill: parent
                        visible: !widget.busy
                        source: "../images/info.png"
                    }
                }

                // Undocked: one short line next to the icon.
                Text {
                    visible: !widget.dockedMode
                    anchors.verticalCenter: parent.verticalCenter
                    text: widget.busy ? i18n("Getting data...") : i18n("Cannot connect to service")
                    color: "white"
                    font.family: applet.uiFont
                    font.pixelSize: 12
                }

                // Docked: the same text, wrapped in the narrow box.
                Text {
                    visible: widget.dockedMode
                    width: 104
                    anchors.verticalCenter: parent.verticalCenter
                    text: widget.busy ? i18n("Getting data...") : i18n("Cannot connect to service")
                    color: "white"
                    font.family: applet.uiFont
                    font.pixelSize: 12
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        // ------------------------------------------------------------
        // Currency rows
        // ------------------------------------------------------------
        Item {
            id: rowsPane
            visible: widget.showData
            x: widget.dockedMode ? 0 : 13
            y: widget.dockedMode ? 0 : 15
            width: widget.dockedMode ? 130 : 220
            height: widget.dockedMode ? 83 : 54 * applet.visibleRows

            Repeater {
                model: widget.dockedMode ? 2 : applet.visibleRows

                delegate: Item {
                    id: row
                    x: 0
                    y: widget.dockedMode ? (index === 0 ? 0 : 27) : index * 54
                    width: rowsPane.width
                    height: 54

                    readonly property int rowIndex: index
                    readonly property bool isBaseRow: index === 0
                    readonly property string currency: applet.currencyForRow(index)
                    readonly property bool hovered: rowHover.hovered

                    HoverHandler {
                        id: rowHover
                    }

                    // Row highlight, 218x49 inside the 1 px row border.
                    Image {
                        visible: !widget.dockedMode && row.hovered
                        x: 1
                        y: 2
                        width: 218
                        height: 49
                        source: "../images/row_over.png"
                        fillMode: Image.Pad
                    }

                    // ---- currency picker (caption + triangle) ----
                    Item {
                        id: captionArea
                        x: widget.dockedMode ? 9 : 19
                        y: widget.dockedMode ? 9 : 2
                        width: widget.dockedMode ? 42 : 180
                        height: 21

                        Image {
                            visible: captionHover.hovered && !widget.dockedMode
                            x: 0
                            y: 0
                            width: 3
                            height: parent.height
                            source: "../images/combo-hover-left.png"
                        }
                        Image {
                            visible: captionHover.hovered && !widget.dockedMode
                            x: 3
                            y: 0
                            width: parent.width - 6
                            height: parent.height
                            source: "../images/combo-hover-middle.png"
                            fillMode: Image.Tile
                        }
                        Image {
                            visible: captionHover.hovered && !widget.dockedMode
                            x: parent.width - 3
                            y: 0
                            width: 3
                            height: parent.height
                            source: "../images/combo-hover-right.png"
                        }

                        Text {
                            id: captionText
                            x: 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.min(implicitWidth, captionArea.width - 16)
                            text: widget.dockedMode ? row.currency
                                                    : rateService.currencyName(row.currency).toUpperCase()
                            color: "white"
                            font.family: applet.uiFont
                            font.pixelSize: widget.dockedMode ? 11 : 12
                            font.bold: widget.dockedMode
                            elide: Text.ElideRight
                        }

                        Image {
                            x: captionText.x + captionText.width + 3
                            anchors.verticalCenter: parent.verticalCenter
                            width: 7
                            height: 4
                            source: "../images/triangle.png"
                        }

                        HoverHandler {
                            id: captionHover
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: widget.openPicker(row.rowIndex)
                            QQC.ToolTip.text: rateService.currencyName(row.currency)
                            QQC.ToolTip.visible: containsMouse
                            QQC.ToolTip.delay: 900
                        }
                    }

                    // ---- graph button (target rows only) ----
                    Item {
                        id: graphButton
                        visible: !widget.dockedMode && !row.isBaseRow
                        x: 3
                        y: 2
                        width: 16
                        height: 16

                        Image {
                            anchors.fill: parent
                            source: graphMouse.pressed ? "../images/graph_down.png"
                                                       : (graphMouse.containsMouse ? "../images/graph_over.png"
                                                                                   : "../images/graph_up.png")
                        }

                        MouseArea {
                            id: graphMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Qt.openUrlExternally(widget.graphUrl(row.currency))
                            QQC.ToolTip.text: i18n("Go to ECB reference rates")
                            QQC.ToolTip.visible: containsMouse
                            QQC.ToolTip.delay: 900
                        }
                    }

                    // ---- delete button (target rows only) ----
                    Item {
                        id: deleteButton
                        visible: !widget.dockedMode && !row.isBaseRow && row.hovered
                        x: 199
                        y: 2
                        width: 16
                        height: 16

                        Image {
                            anchors.fill: parent
                            source: deleteMouse.pressed ? "../images/delete_down.png"
                                                        : (deleteMouse.containsMouse ? "../images/delete_over.png"
                                                                                     : "../images/delete_up.png")
                        }

                        MouseArea {
                            id: deleteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: applet.deleteRow(row.rowIndex)
                            QQC.ToolTip.text: i18n("Remove")
                            QQC.ToolTip.visible: containsMouse
                            QQC.ToolTip.delay: 900
                        }
                    }

                    // ---- value field ----
                    Rectangle {
                        x: widget.dockedMode ? 51 : 19
                        y: widget.dockedMode ? 9 : 25
                        width: widget.dockedMode ? 72 : 180
                        height: 21
                        color: "#80ffffff"
                        border.width: 1
                        border.color: "black"
                    }

                    TextInput {
                        id: amountInput
                        visible: row.isBaseRow
                        x: widget.dockedMode ? 51 : 19
                        y: widget.dockedMode ? 9 : 25
                        width: widget.dockedMode ? 72 : 180
                        height: 21
                        leftPadding: widget.dockedMode ? 1 : 3
                        rightPadding: widget.dockedMode ? 5 : 3
                        verticalAlignment: TextInput.AlignVCenter
                        horizontalAlignment: TextInput.AlignRight
                        color: "black"
                        selectionColor: "#3399ff"
                        selectedTextColor: "white"
                        font.family: applet.uiFont
                        font.pixelSize: 12
                        font.bold: true
                        maximumLength: 20
                        selectByMouse: true
                        clip: true
                        text: applet.amountRaw
                        onTextEdited: {
                            applet.amountRaw = text;
                            Plasmoid.configuration.amount = text;
                        }
                    }

                    Text {
                        visible: !row.isBaseRow
                        x: widget.dockedMode ? 51 : 19
                        y: widget.dockedMode ? 9 : 25
                        width: widget.dockedMode ? 72 : 180
                        height: 21
                        leftPadding: widget.dockedMode ? 1 : 3
                        rightPadding: widget.dockedMode ? 5 : 3
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignRight
                        color: "black"
                        font.family: applet.uiFont
                        font.pixelSize: 12
                        font.bold: true
                        elide: Text.ElideRight
                        text: applet.rowValues[row.rowIndex - 1] || ""
                    }
                }
            }
        }

        // ------------------------------------------------------------
        // Bottom bar: data source, age, refresh, add (undocked only)
        // ------------------------------------------------------------
        Item {
            id: bottomBar
            visible: !widget.dockedMode && widget.showData
            x: 20
            y: widget.artHeight - 38
            width: 211
            height: 16

            Text {
                id: dataLink
                x: 0
                y: 0
                width: 100
                height: 16
                text: i18n("DATA PROVIDERS")
                color: "white"
                font.family: applet.uiFont
                font.pixelSize: 10
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight

                MouseArea {
                    anchors.fill: parent
                    onClicked: Qt.openUrlExternally("https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/index.en.html")
                    QQC.ToolTip.text: i18n("European Central Bank reference rates (via Frankfurter)")
                    QQC.ToolTip.visible: containsMouse
                    QQC.ToolTip.delay: 900
                }
            }

            Text {
                id: ageText
                x: 103
                y: 0
                width: 64
                height: 16
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: applet.ageLabel
                color: "white"
                font.family: applet.uiFont
                font.pixelSize: 11
                elide: Text.ElideRight
            }

            // Refresh: the original had no button, it polled on a timer. The
            // new feed only changes once per working day, so a manual pull is
            // the useful addition.
            Item {
                id: refreshButton
                x: 171
                y: 0
                width: 16
                height: 16
                visible: !widget.busy

                Text {
                    anchors.centerIn: parent
                    text: "\u21bb"
                    color: "white"
                    opacity: refreshMouse.containsMouse ? 1.0 : 0.75
                    font.family: applet.uiFont
                    font.pixelSize: 14
                }

                MouseArea {
                    id: refreshMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: applet.refreshRates()
                    QQC.ToolTip.text: i18n("Refresh rates")
                    QQC.ToolTip.visible: containsMouse
                    QQC.ToolTip.delay: 900
                }
            }

            Image {
                visible: widget.busy
                x: 171
                y: 0
                width: 16
                height: 16
                source: "../images/activity16v.png"
                sourceClipRect: Qt.rect(0, (applet.spinnerFrame % 18) * 16, 16, 16)
            }

            Item {
                id: addButton
                visible: applet.visibleRows < applet.maximumRows
                x: 195
                y: 0
                width: 16
                height: 16

                Image {
                    anchors.fill: parent
                    source: addMouse.pressed ? "../images/add_down.png"
                                             : (addMouse.containsMouse ? "../images/add_over.png"
                                                                       : "../images/add_up.png")
                }

                MouseArea {
                    id: addMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: applet.addRow()
                    QQC.ToolTip.text: i18n("Add")
                    QQC.ToolTip.visible: containsMouse
                    QQC.ToolTip.delay: 900
                }
            }
        }

        // ------------------------------------------------------------
        // Age stamp in the docked box (only shown when rates are stale,
        // as in the original)
        // ------------------------------------------------------------
        Text {
            visible: widget.dockedMode && widget.showData && applet.ageLabel !== ""
                     && !rateService.isFresh()
            anchors.right: parent.right
            anchors.rightMargin: 7
            y: widget.artHeight - 5 - height
            text: applet.ageLabel
            color: "white"
            font.family: applet.uiFont
            font.pixelSize: 11
        }

        // ------------------------------------------------------------
        // Currency dropdown, drawn in place like the original <select>
        // ------------------------------------------------------------
        Item {
            id: picker
            visible: false
            x: widget.dockedMode ? 5 : 18
            y: widget.dockedMode ? 5 : 18
            width: widget.dockedMode ? 119 : 210
            height: (widget.dockedMode ? 4 : 8) * 18 + 2
            z: 500

            // Keyboard control: the widget's text input has focus when the
            // list opens, so the picker has to take active focus explicitly.
            focus: visible
            onVisibleChanged: if (visible) forceActiveFocus()
            Keys.onEscapePressed: picker.visible = false
            Keys.onUpPressed: picker.moveSelection(-1)
            Keys.onDownPressed: picker.moveSelection(1)
            Keys.onReturnPressed: picker.activate()
            Keys.onEnterPressed: picker.activate()

            property int targetRow: 0
            property var model: []
            property int selectedIndex: 0

            function ensureVisible(index) {
                if (index < 0)
                    return;
                var top = index * 18;
                var viewHeight = pickerFlick.height;
                if (top < pickerFlick.contentY)
                    pickerFlick.contentY = top;
                else if (top + 18 > pickerFlick.contentY + viewHeight)
                    pickerFlick.contentY = top + 18 - viewHeight;
            }

            function moveSelection(delta) {
                if (picker.model.length === 0)
                    return;
                picker.selectedIndex = Math.max(0, Math.min(picker.model.length - 1,
                                                            picker.selectedIndex + delta));
                ensureVisible(picker.selectedIndex);
            }

            function activate() {
                if (picker.selectedIndex >= 0 && picker.selectedIndex < picker.model.length)
                    widget.chooseCurrency(picker.targetRow, picker.model[picker.selectedIndex].code);
            }

            Rectangle {
                anchors.fill: parent
                color: "white"
                border.width: 1
                border.color: "#7f9db9"
            }

            Flickable {
                id: pickerFlick
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                contentWidth: width
                contentHeight: pickerColumn.height
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: pickerColumn
                    width: pickerFlick.width

                    Repeater {
                        model: picker.model

                        delegate: Rectangle {
                            width: pickerColumn.width
                            height: 18
                            color: index === picker.selectedIndex ? "#3399ff"
                                 : (entryHover.hovered ? "#e5f3ff" : "transparent")

                            Text {
                                anchors.left: parent.left
                                anchors.leftMargin: 3
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 6
                                text: modelData.name
                                color: index === picker.selectedIndex ? "white" : "black"
                                font.family: applet.uiFont
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }

                            HoverHandler {
                                id: entryHover
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: widget.chooseCurrency(picker.targetRow, modelData.code)
                            }
                        }
                    }
                }
            }
        }

        // Click anywhere else to dismiss the dropdown, Escape does the same.
        // Click anywhere outside the list to dismiss it. Keyboard handling
        // lives on the picker itself (it owns the active focus while open).
        Item {
            id: pickerDismiss
            visible: picker.visible
            anchors.fill: parent
            z: picker.z - 1

            MouseArea {
                anchors.fill: parent
                onClicked: picker.visible = false
            }
        }

        // ------------------------------------------------------------
        // Helpers that need the row/UI ids
        // ------------------------------------------------------------

        function openPicker(index) {
            var list = rateService.currencyList();
            if (list.length === 0)
                return;
            var current = applet.currencyForRow(index);
            var selected = 0;
            for (var i = 0; i < list.length; i++) {
                if (list[i].code === current) {
                    selected = i;
                    break;
                }
            }
            picker.model = list;
            picker.targetRow = index;
            picker.selectedIndex = selected;
            picker.visible = true;
            Qt.callLater(function () {
                picker.ensureVisible(selected);
            });
        }

        function chooseCurrency(index, code) {
            picker.visible = false;
            applet.setRowCurrency(index, code);
        }

        function graphUrl(code) {
            return "https://www.ecb.europa.eu/stats/policy_and_exchange_rates/euro_reference_exchange_rates/html/eurofxref-graph-"
                    + String(code).toLowerCase() + ".en.html";
        }
    }
}
