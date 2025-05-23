// show.qml
import QtQuick 2.0

Rectangle {
    anchors.fill: parent
    color: "transparent"

    Image {
        id: splash
        source: "sudosplash.webp"    // make sure this file lives in the same folder
        anchors.centerIn: parent
        fillMode: Image.PreserveAspectFit
    }
}
