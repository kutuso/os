# kutu OS Dark Theme

Beautiful dark theme with pastel rainbow accents matching the kutu logo.

## Color Palette

### Base Colors
- **Background**: `#181825` - Deep dark blue/black
- **Background Alt**: `#1e1e2e` - Slightly lighter
- **Foreground**: `#cdd6f4` - Light blue-gray text

### Pastel Rainbow Accents
- **Pink**: `#FFB3BA` - Used for warnings, negative actions
- **Peach**: `#FFDFBA` - Used for network upload indicators
- **Yellow**: `#FFFFBA` - Used for neutral notifications
- **Green**: `#BAFFC9` - Used for success, positive actions
- **Blue**: `#BAE1FF` - Primary accent, links, selections
- **Purple**: `#D4BAFF` - Used for visited links, secondary
- **Magenta**: `#FFB3E6` - Used for special highlights

### Functional Colors
- **Success**: Green `#BAFFC9`
- **Warning**: Yellow `#FFFFBA`
- **Error**: Pink `#FFB3BA`
- **Info**: Blue `#BAE1FF`
- **Link**: Blue `#BAE1FF`
- **Visited Link**: Purple `#D4BAFF`

## Files Included

### KDE Plasma
- `KutuDark.colors` - KDE color scheme file
- Apply via: System Settings → Appearance → Colors

### Terminal (Konsole)
- `konsole-kutu-dark.colorscheme` - Konsole color scheme
- Install to: `~/.local/share/konsole/`
- Select in Konsole: Settings → Edit Current Profile → Appearance

### GTK Applications
- `gtk-3.0/gtk.css` - GTK3 theme
- `gtk-4.0/gtk.css` - GTK4 theme
- Install to: `~/.config/gtk-3.0/` and `~/.config/gtk-4.0/`

## Installation

Themes are automatically installed during kutu OS setup. For manual installation:

```bash
# KDE Color Scheme
mkdir -p ~/.local/share/color-schemes
cp KutuDark.colors ~/.local/share/color-schemes/

# Konsole
mkdir -p ~/.local/share/konsole
cp konsole-kutu-dark.colorscheme ~/.local/share/konsole/

# GTK
mkdir -p ~/.config/gtk-3.0
mkdir -p ~/.config/gtk-4.0
cp gtk-3.0/gtk.css ~/.config/gtk-3.0/
cp gtk-4.0/gtk.css ~/.config/gtk-4.0/
```

## Usage

### System-wide
The theme is applied by default on kutu OS.

### Per-Application

**KDE Applications:**
- System Settings → Appearance → Colors → Kutu Dark

**Konsole:**
- Settings → Edit Current Profile → Appearance → Color Scheme → Kutu Dark

**GTK Applications:**
- Automatically themed via `~/.config/gtk-3.0/gtk.css` and `gtk-4.0/gtk.css`

## Customization

### Changing Accent Color

Edit the color scheme files and replace the accent colors:

**For KDE** (`KutuDark.colors`):
```ini
[Colors:Selection]
BackgroundNormal=186,225,255  # Change to your RGB values
```

**For GTK** (`gtk.css`):
```css
@define-color accent_blue #BAE1FF;  /* Change hex value */
```

### System Monitor Colors

In `plasma-config.js`:
```javascript
systemMonitor: {
    cpuColor: "#BAE1FF",     // Change to your preferred color
    gpuColor: "#BAFFC9",
    memoryColor: "#FFB3BA",
    // ... etc
}
```

## Matching Components

The theme is designed to match:
- kutu logo colors
- kutu wallpapers (minimal, stripes, gradient, default)
- System monitoring widgets
- Boot splash (when implemented)

## Technical Details

### Color Format Conversions

RGB to Hex:
- Pink: RGB(255, 179, 186) = #FFB3BA

Hex to RGB:
- #BAE1FF = RGB(186, 225, 255)

### Opacity Values
- Window backgrounds: 100% (solid)
- Terminal: 95% (slight transparency)
- Panel: Translucent (blur effect)
- Tooltips: 95%

## Contributing

When modifying the theme:
1. Maintain the pastel rainbow palette
2. Keep sufficient contrast for readability (WCAG AA minimum)
3. Test on both light and dark backgrounds
4. Update all format files (KDE, GTK3, GTK4, Konsole)

## License

MIT License - See repository root LICENSE file
