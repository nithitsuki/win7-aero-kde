/*
    SPDX-FileCopyrightText: 2026 win7-aero-kde contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

KCM.SimpleKCM {
    id: page

    // Bound to the "imageId" key in main.xml by the configuration system.
    property int cfg_imageId: 1

    readonly property int imageCount: 11
    readonly property int currentImage: Math.min(Math.max(cfg_imageId, 1), imageCount)

    function previousImage() {
        cfg_imageId = currentImage > 1 ? currentImage - 1 : imageCount;
    }

    function nextImage() {
        cfg_imageId = currentImage < imageCount ? currentImage + 1 : 1;
    }

    component ArrowButton: Item {
        id: arrow

        property string direction: "left"

        signal clicked()

        width: 19
        height: 19

        Accessible.name: arrow.direction === "left" ? i18n("Previous") : i18n("Next")
        Accessible.role: Accessible.Button

        Image {
            anchors.fill: parent
            source: Qt.resolvedUrl("../images/settings_" + arrow.direction + "_"
                + (mouse.pressed ? "pressed" : (mouse.containsMouse ? "hover" : "rest")) + ".png")
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onClicked: arrow.clicked()
        }

        QQC2.ToolTip.visible: mouse.containsMouse
        QQC2.ToolTip.text: arrow.direction === "left" ? i18n("Previous") : i18n("Next")
    }

    ColumnLayout {
        width: parent ? parent.width : implicitWidth
        spacing: Kirigami.Units.largeSpacing

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.largeSpacing

            ArrowButton {
                direction: "left"
                Layout.alignment: Qt.AlignVCenter

                onClicked: page.previousImage()
            }

            ColumnLayout {
                spacing: Kirigami.Units.smallSpacing

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredWidth: 116
                    Layout.preferredHeight: 116
                    color: "#ffffff"
                    border.width: 1
                    border.color: "#c8c8c8"

                    Image {
                        anchors.centerIn: parent
                        width: 108
                        height: 108
                        source: Qt.resolvedUrl("../images/" + page.currentImage + ".png")
                        smooth: true
                    }
                }

                QQC2.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: page.currentImage + " " + i18n("of") + " " + page.imageCount
                }
            }

            ArrowButton {
                direction: "right"
                Layout.alignment: Qt.AlignVCenter

                onClicked: page.nextImage()
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: 280
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: i18n("Choose a picture with Previous and Next. Changing the picture shuffles the puzzle again and restarts the timer.")
        }
    }
}
