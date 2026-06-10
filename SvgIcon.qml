// Simple SVG icon wrapper (config-driven path). Qt's image provider rasterizes SVG
// crisply at sourceSize. Empty path -> invisible + 0 width, so the layout is unaffected.

import QtQuick

Image {
    id: ico
    property string path: ""
    property real size: 16
    visible: path.length > 0
    source: path.length > 0 ? ("file://" + path) : ""
    sourceSize.width: size
    sourceSize.height: size
    width: visible ? size : 0
    height: size
    fillMode: Image.PreserveAspectFit
    asynchronous: true
    smooth: true
    mipmap: true
}
