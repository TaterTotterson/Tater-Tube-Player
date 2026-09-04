pragma Singleton

import QtQml
import QtMultimedia

QtObject {
    id: root

    property double suppressNavigationUntil: 0

    readonly property SoundEffect stepEffect: SoundEffect {
        source: Qt.resolvedUrl("../../assets/sounds/tater-step.wav")
        volume: 0.32
    }

    readonly property SoundEffect selectEffect: SoundEffect {
        source: Qt.resolvedUrl("../../assets/sounds/tater-select.wav")
        volume: 0.38
    }

    readonly property SoundEffect backEffect: SoundEffect {
        source: Qt.resolvedUrl("../../assets/sounds/tater-back.wav")
        volume: 0.34
    }

    readonly property SoundEffect alertEffect: SoundEffect {
        source: Qt.resolvedUrl("../../assets/sounds/tater-alert.wav")
        volume: 0.36
    }

    function restart(effect) {
        effect.stop()
        effect.play()
    }

    function navigate() {
        if (Date.now() < suppressNavigationUntil)
            return
        restart(stepEffect)
    }

    function select() {
        suppressNavigationUntil = Date.now() + 160
        restart(selectEffect)
    }

    function back() {
        suppressNavigationUntil = Date.now() + 150
        restart(backEffect)
    }

    function alert() {
        suppressNavigationUntil = Date.now() + 180
        restart(alertEffect)
    }

    function playRole(role) {
        if (role === "none")
            return
        if (role === "back")
            back()
        else if (role === "alert")
            alert()
        else
            select()
    }
}
