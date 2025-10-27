
# Editt - Photo Editor & Viewer

A photo editing and viewing application for Linux desktop that looks CLEAN!

<h4>Download</h4>  

<a href="https://github.com/mirarr-app/editt/releases"><img src="https://raw.githubusercontent.com/NeoApplications/Neo-Backup/034b226cea5c1b30eb4f6a6f313e4dadcbb0ece4/badge_github.png" width="200"></a> 

## Install from AUR

```bash
yay -S editt-bin
```

## Screenshots

|                     Image Selection                      |                     Editing                      |
| :--------------------------------------------------: | :------------------------------------------------------: |
| ![editt image selection](https://github.com/user-attachments/assets/1bfc71df-2eea-4d3a-ae65-6f10bfba50aa) | ![editt editing](https://github.com/user-attachments/assets/26b3f2c9-87bd-4d15-937e-0862f545f5f9) |
|                     Filters                      |                     Saving                      |
| ![edit filters](https://github.com/user-attachments/assets/b93042d4-d60d-4cfb-9669-1e3e661e3a6e) | ![editt saving](https://github.com/user-attachments/assets/cd67c733-88d4-4ecf-8b05-8c680ef083fc) |




## Features

### Image Viewing
- Fast image loading with zoom and pan capabilities
- Support for multiple image formats (JPG, PNG, WebP, GIF, BMP)
- Responsive layout optimized for desktop window resizing
- Interactive viewer with pinch-to-zoom and pan gestures

### Omarchy Linux Integration
- **Dynamic Theme Support**: Automatically adapts the app's color scheme to match your current Omarchy Linux theme
- Falls back to default blue theme on non-Omarchy systems

<table>
  <tr>
    <td align="center" width="300">
      <video 
        src="https://github.com/user-attachments/assets/749d36fc-3a61-4462-ad6f-0cdd327ca73f" 
        controls 
        style="max-width:100%;">
      </video>
    </td>
  </tr>
  <tr>
    <td align="center">
      <em>Video may be compressed by GitHub</em>
    </td>
  </tr>
</table>






### Image Editing
- **Crop**: Crop images with various aspect ratio options
- **Rotate**: Rotate images at any angle
- **Flip**: Flip images horizontally or vertically
- **Filters**: Apply various filters and adjustments
- **Paint/Draw**: Draw and paint on images
- **Text**: Add text overlays
- **Stickers & Emojis**: Add stickers and emojis


### Keyboard shortcuts

- Text Editor = 'ctrl+t'
- Paint Editor = 'ctrl+b'
- Crop Editor = 'ctrl+c'
- Filter Editor = 'ctrl+f'
- Emoji Editor = 'ctrl+e'
- Tune Editor = 'ctrl+u'
- Blur Editor = 'ctrl+l'
- Cutout Tool = 'ctrl+k'
- Undo = 'ctrl+z'
- Redo = 'ctrl+y'
- Save = 'ctrl+s'
- Close = 'ctrl+w'
- Done = 'ctrl+d'

### Advanced Options
- **Format Conversion**: Convert between JPG, PNG, and WebP formats
- **Resolution Reduction**: Scale down image dimensions
- **Quality Adjustment**: Lower image quality to reduce file size
- **Save Options**: Choose to save as a new file or overwrite the original

## Building

### Prerequisites
- Flutter SDK (3.5.3 or higher)

### Setup
1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Build and run:
   ```bash
   flutter run -d linux
   ```

## Usage

### Opening Images

#### Method 1: File Picker (GUI)
1. Launch the application
2. Click the "Open Image" button
3. Select an image from the file picker dialog

#### Method 2: Command Line
You can open an image directly from the command line:
```bash
editt imagename.jpg
```


### Editing Images

1. Once an image is loaded in the viewer, click the "Edit Image" button
2. Use the built-in tools to edit your image:
   - Crop, rotate, flip
   - Apply filters
   - Draw or add text
   - Add stickers/emojis
3. Click the settings icon (top-right) for advanced options:
   - Change output format
   - Adjust image quality
   - Reduce resolution
4. When finished, click the save/done button
5. Choose whether to save as a new file or overwrite the original

## Project Structure

```
lib/
├── main.dart                    # App entry point with command-line args
├── screens/
│   ├── viewer_screen.dart       # Image viewing screen
│   └── editor_screen.dart       # Image editing screen
├── services/
│   ├── image_service.dart       # Image processing utilities
│   ├── file_service.dart        # File operations
│   └── theme_service.dart       # Omarchy theme detection
└── widgets/
    ├── image_viewer.dart        # Image display widget
    └── save_dialog.dart         # Save options dialog
```

## Dependencies

- `pro_image_editor` - Comprehensive image editing features
- `file_picker` - File selection dialog
- `image` - Image format conversion and manipulation
- `path_provider` - File path handling
- `path` - Path utilities


## License

This project is licensed under the MIT License.
