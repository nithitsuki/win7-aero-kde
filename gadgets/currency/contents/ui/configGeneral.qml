// SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    property alias cfg_docked: dockedCheck.checked
    property alias cfg_rowCount: rowsBox.value

    Kirigami.FormLayout {
        QQC.CheckBox {
            id: dockedCheck
            text: i18n("Use the docked layout (130 x 83)")
        }

        QQC.SpinBox {
            id: rowsBox
            from: 2
            to: 4
            Kirigami.FormData.label: i18n("Rows (undocked):")
            enabled: !dockedCheck.checked
        }

        QQC.Label {
            text: i18n("The docked layout always shows two rows.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            visible: dockedCheck.checked
        }

        QQC.Label {
            text: i18n("Rates come from the European Central Bank reference rates, published once per working day through Frankfurter.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
            wrapMode: Text.WordWrap
        }
    }
}
