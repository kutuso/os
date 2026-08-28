import calamares.slideshow 1.0

Presentation {
    id: presentation

    Slide {
        Image {
            source: "logo.png"
            anchors.centerIn: parent
            width: 256
            height: 256
            fillMode: Image.PreserveAspectFit
        }
    }
}
