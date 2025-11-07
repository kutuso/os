// kutu OS - KDE Plasma Desktop Configuration
// Applied during first boot

// Plasma theme and appearance
const config = {
    theme: {
        plasma: "breeze-dark",
        colorScheme: "KutuDark",
        icon: "breeze-dark",
        cursor: "breeze_cursors",
        font: {
            general: "Noto Sans, 10",
            fixed: "Hack, 10",
            menu: "Noto Sans, 10",
            toolbar: "Noto Sans, 9"
        }
    },

    panels: {
        bottom: {
            height: 48,
            widgets: [
                "org.kde.plasma.kickoff",
                "org.kde.plasma.pager",
                "org.kde.plasma.icontasks",
                "org.kde.plasma.systemmonitor.cpu",
                "org.kde.plasma.systemmonitor.gpu",
                "org.kde.plasma.systemmonitor.memory",
                "org.kde.plasma.systemtray",
                "org.kde.plasma.digitalclock"
            ]
        }
    },

    wallpaper: "/usr/share/wallpapers/kutu-default.jpg",

    shortcuts: {
        "Konsole": "Ctrl+Alt+T",
        "System Monitor": "Ctrl+Shift+Esc"
    },

    systemMonitor: {
        updateInterval: 2000,
        showCPU: true,
        showGPU: true,
        showMemory: true,
        showNetwork: true,
        showDisk: true
    }
};

module.exports = config;
