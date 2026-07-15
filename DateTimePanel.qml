// Level 2 - combined date/weather panel, opened by clicking the date in the bar. Just stacks the
// two self-contained panels (weather on top for an at-a-glance summary, the calendar below) so each
// keeps its own theming, morph and (for weather) incubation guard. Order is a one-line swap.
import QtQuick

Column {
    id: dt
    property var skin
    property var appcfg
    width: 320; spacing: 12

    WeatherPanel { width: dt.width; skin: dt.skin; appcfg: dt.appcfg }

    Rectangle {
        width: parent.width; height: 1
        color: dt.skin ? Qt.rgba(dt.skin.text.r, dt.skin.text.g, dt.skin.text.b, 0.12) : "#333333"
    }

    CalendarPanel { width: dt.width; skin: dt.skin; appcfg: dt.appcfg }
}
