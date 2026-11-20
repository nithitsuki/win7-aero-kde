/*
    SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
    SPDX-License-Identifier: GPL-3.0-or-later

    Clean-room QML reimplementation of the Windows 7 Calendar gadget.
    The artwork in contents/images/ is Microsoft's and is copied from the
    user's Windows 7 installation by the installer; it is not part of this
    repository.
*/

import QtQuick
import org.kde.plasma.configuration

ConfigModel {
    ConfigCategory {
        name: i18n("General")
        icon: "preferences-desktop"
        source: "configGeneral.qml"
    }
}
