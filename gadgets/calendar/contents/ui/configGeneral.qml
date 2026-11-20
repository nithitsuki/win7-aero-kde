/*
    SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
    SPDX-License-Identifier: GPL-3.0-or-later

    Clean-room QML reimplementation of the Windows 7 Calendar gadget.
    The artwork in contents/images/ is Microsoft's and is copied from the
    user's Windows 7 installation by the installer; it is not part of this
    repository.
*/

import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kirigami as Kirigami

Kirigami.ScrollablePage {
    id: page

    Kirigami.FormLayout {
        QQC2.RadioButton {
            Kirigami.FormData.label: i18n("View:")

            text: i18n("Month and day page")
            checked: plasmoid.configuration.view !== "day"
            onToggled: {
                if (checked) {
                    plasmoid.configuration.view = "double"
                }
            }
        }

        QQC2.RadioButton {
            text: i18n("Single day")
            checked: plasmoid.configuration.view === "day"
            onToggled: {
                if (checked) {
                    plasmoid.configuration.view = "day"
                }
            }
        }

        QQC2.Button {
            Kirigami.FormData.label: i18n("Date:")

            text: i18n("Show today")
            onClicked: {
                plasmoid.configuration.shownDate = ""
                plasmoid.configuration.zoom = "month"
            }
        }
    }
}
