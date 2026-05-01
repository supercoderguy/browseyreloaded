# BrowseyReloaded - The extra-private AI-powered web browser.
A complete rewrite of Browsey written in Swift instead of Python (see https://github.com/jacobStuff/browsey)

**Version 0.1 - Open Beta**

## Beta Notice

This is the first open beta release of BrowseyReloaded. While the browser is fully functional with all planned features, please be aware that:

- This is beta software and may contain bugs
- Features may change based on user feedback
- Data loss is possible (please backup important bookmarks/settings)
- Report any issues to help improve the final release

## Features

- **Tabbed Browsing**: Multiple tabs with customizable UI and positioning
- **Bookmarks**: Built-in bookmark management with sidebar
- **AI Integration**: Groq AI chat integration for enhanced browsing
- **Custom Web Engine**: Support for both WebKit and custom rendering engines
- **Content Blocking**: Built-in ad and tracker blocking
- **User Scripts**: Support for custom JavaScript and CSS injection
- **Extensions**: Browser extension support with native messaging
- **Downloads**: Integrated download management
- **Privacy**: Enhanced privacy features and settings
- **Themes**: Customizable appearance with dark/light mode support

## Requirements

- macOS 26.0 or later (will release a legacy version at some time that supports macOS 11.0, as well as a Linux version (because I use CachyOS on my gaming PC), possibly not a Windows version soon due to a lack of a Windows device)
- Xcode 26.0 or later

## Installation

1. Clone the repository
2. Open `BrowseyReloaded.xcodeproj` in Xcode
3. Build and run the project

## Usage

### Basic Browsing
- Enter URLs in the address bar or search terms
- Use keyboard shortcuts for navigation:
  - `Cmd+T`: New tab
  - `Cmd+W`: Close tab
  - `Cmd+R`: Reload page
  - `Cmd+L`: Focus address bar
  - `Cmd+Shift+H`: Go home
  - `Cmd+Ctrl+→/←`: Next/previous tab

### Bookmarks
- Click the star icon to bookmark the current page
- Use the bookmarks sidebar to organize and access bookmarks

### Settings
- Access comprehensive settings through the gear icon
- Customize appearance, behavior, and features

### AI Chat
- Click the sparkles icon to open Groq AI chat
- Ask questions and get AI-powered assistance
- Requires a Groq account and API key (free, go to [https://console.groq.com/docs/api-reference](https://console.groq.com/docs/quickstart) for more info)

## Architecture

The app is built with a modular architecture:

- `ContentView`: Main UI and tab management
- `WebView`: WebKit-based web view wrapper
- `CustomWebEngine`: Alternative rendering engine using JavaScriptCore
- `BrowserSettings`: Centralized settings management
- `BookmarkStore`: Bookmark persistence
- `DownloadManager`: Download handling
- `GroqService`: AI chat integration

## Contributing

Contributions are welcome! Please feel free to submit pull requests or open issues.

## License

GNU GPL (go to [LICENSE](LICENSE) for the full license)

## Support

For support, email me at [jffbk@outlook.com](mailto:jffbk@outlook.com) or [join the Discord](https://discord.gg/xhYAf4d9hh).
