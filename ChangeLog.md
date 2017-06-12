## Version 0.16.1
 - The Xcode toolchain is now supported for building the `swift-langsrv` project.
 - Better support for the Xcode toolchain for the plugin.
 - Better error information when the toolchain has issues.

## Version 0.15.0

 - Full support for SwiftPM projects layouts.
 - General performance enhancements with SourceKit interaction.
 - The following commands were enabled:
    - Hover over information for code.
    - Go to definition support (only within your project for now, no module file generation).

*Known Issues*: When new files are added, or if completions stop, rebuild your project.