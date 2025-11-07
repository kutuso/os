// kutu OS - KDE Plasma Desktop Configuration
// Dark theme with pastel rainbow accents
// Applied during first boot

const config = {
    theme: {
        // Global theme
        plasma: "breeze-dark",
        colorScheme: "KutuDark",
        icon: "breeze-dark",
        cursor: "breeze_cursors",

        // Window decorations
        windowDecoration: "Breeze",

        // Fonts
        font: {
            general: "Noto Sans, 10",
            fixed: "Hack, 10",
            small: "Noto Sans, 9",
            toolbar: "Noto Sans, 10",
            menu: "Noto Sans, 10",
            windowTitle: "Noto Sans, 10"
        }
    },

    // Color palette - Pastel Rainbow
    colors: {
        background: "#181825",      // Deep dark background
        backgroundAlt: "#1e1e2e",   // Slightly lighter
        foreground: "#cdd6f4",      // Light text

        // Pastel rainbow accents
        accent1: "#FFB3BA",  // Pink
        accent2: "#FFDFBA",  // Peach
        accent3: "#FFFFBA",  // Yellow
        accent4: "#BAFFC9",  // Green
        accent5: "#BAE1FF",  // Blue (primary)
        accent6: "#D4BAFF",  // Purple
        accent7: "#FFB3E6",  // Magenta

        // Functional colors using pastels
        primary: "#BAE1FF",    // Blue
        positive: "#BAFFC9",   // Green
        negative: "#FFB3BA",   // Pink
        neutral: "#FFFFBA",    // Yellow
        link: "#BAE1FF",       // Blue
        visited: "#D4BAFF"     // Purple
    },

    panels: {
        bottom: {
            height: 48,
            background: "translucent",
            widgets: [
                {
                    type: "org.kde.plasma.kickoff",
                    config: {
                        icon: "kutu-logo"
                    }
                },
                {
                    type: "org.kde.plasma.pager"
                },
                {
                    type: "org.kde.plasma.icontasks",
                    config: {
                        showOnlyCurrentDesktop: false,
                        groupPopups: true
                    }
                },
                {
                    type: "org.kde.plasma.marginsseparator"
                },
                {
                    type: "org.kde.plasma.systemmonitor.cpu",
                    config: {
                        chartColor: "#BAE1FF",  // Blue
                        showLegend: true
                    }
                },
                {
                    type: "org.kde.plasma.systemmonitor.gpu",
                    config: {
                        chartColor: "#BAFFC9",  // Green
                        showLegend: true
                    }
                },
                {
                    type: "org.kde.plasma.systemmonitor.memory",
                    config: {
                        chartColor: "#FFB3BA",  // Pink
                        showLegend: true
                    }
                },
                {
                    type: "org.kde.plasma.systemtray",
                    config: {
                        scaleIconsToFit: true
                    }
                },
                {
                    type: "org.kde.plasma.digitalclock",
                    config: {
                        showDate: true,
                        use24hFormat: true
                    }
                }
            ]
        }
    },

    desktop: {
        wallpaper: "/usr/share/wallpapers/kutu-minimal.svg",

        // Desktop effects
        effects: {
            blur: true,
            translucency: true,
            wobblyWindows: false,
            desktopCube: false
        }
    },

    shortcuts: {
        "Konsole": "Ctrl+Alt+T",
        "System Monitor": "Ctrl+Shift+Esc",
        "Run Command": "Alt+Space",
        "Show Desktop": "Meta+D"
    },

    systemMonitor: {
        updateInterval: 2000,
        showCPU: true,
        showGPU: true,
        showMemory: true,
        showNetwork: true,
        showDisk: true,

        // Use pastel colors for graphs
        cpuColor: "#BAE1FF",     // Blue
        gpuColor: "#BAFFC9",     // Green
        memoryColor: "#FFB3BA",  // Pink
        networkUpColor: "#D4BAFF",   // Purple
        networkDownColor: "#FFDFBA", // Peach
        diskColor: "#FFFFBA"     // Yellow
    },

    terminal: {
        theme: "KutuDark",
        font: "Hack 10",
        opacity: 0.95,
        blurBackground: true
    }
};

module.exports = config;
