// SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-other"
        source: "configGeneral.qml"
    }
}
