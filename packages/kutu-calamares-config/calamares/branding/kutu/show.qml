import QtQuick 2.0
import calamares.slideshow 1.0

Presentation {
    id: presentation

    Timer {
        interval: 9000
        running: presentation.activatedInCalamares
        repeat: true
        onTriggered: presentation.goToNextSlide()
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#1e1e2e" }
        Image {
            source: "logo.png"
            width: 160
            height: 160
            fillMode: Image.PreserveAspectFit
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 60
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 120
            width: parent.width - 80
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#e2e6f3"
            font.pixelSize: 22
            text: "Installing kutu OS.\nThe memory you save is memory you don't have to buy."
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#1e1e2e" }
        Text {
            anchors.centerIn: parent
            width: parent.width - 100
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#e2e6f3"
            font.pixelSize: 22
            lineHeight: 1.3
            text: "Compressed swap, smarter page eviction and per-app memory ceilings are on from the first boot.\n\nRun kutu-doctor any time to watch it work."
        }
    }

    Slide {
        Rectangle { anchors.fill: parent; color: "#1e1e2e" }
        Text {
            anchors.centerIn: parent
            width: parent.width - 100
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            color: "#e2e6f3"
            font.pixelSize: 22
            lineHeight: 1.3
            text: "Super+Space searches apps and files.\nSuper+Tab switches windows. Super+Q closes one.\n\nThe dock at the bottom appears when you move the mouse there."
        }
    }
}
