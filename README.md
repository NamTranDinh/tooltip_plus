# Tooltip Plus

A Flutter tooltip widget that offers rich customization and smart positioning to enhance user experience.


[![Pub Version](https://img.shields.io/pub/v/tooltip_plus?color=blue&logo=dart)](https://pub.dev/packages/tooltip_plus)
[![likes](https://img.shields.io/pub/likes/tooltip_plus)](https://pub.dev/packages/tooltip_plus/score)
[![popularity](https://img.shields.io/pub/popularity/tooltip_plus)](https://pub.dev/packages/tooltip_plus/score)
[![pub points](https://img.shields.io/pub/points/tooltip_plus)](https://pub.dev/packages/tooltip_plus/score)

## Features

- 🎯 **Multiple Trigger Modes**
    - Tap
    - Long Press
    - Manual Control

- 🎨 **Customizable Appearance**
    - Flexible build tooltip by widget
    - Flexible Styling

- 📍 **Smart Positioning**
    - Automatic Edge Detection
    - Multiple Directions (Top, Bottom, Left, Right)
    - Customizable Offset


## Installation

Add Widget TooltipPlus to your `pubspec.yaml`:

```bash
flutter pub add tooltip_plus
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:tooltip_plus/screens/tooltip_plus.dart';

void main() => runApp(const Main());

class Main extends StatelessWidget {
  const Main({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Material(child: TooltipScreen()),
    );
  }
}

class TooltipScreen extends StatefulWidget {
  const TooltipScreen({super.key});

  @override
  State<TooltipScreen> createState() => _TooltipScreenState();
}

class _TooltipScreenState extends State<TooltipScreen> {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: TooltipPlus(
        messageWidget: const ColoredBox(color: Colors.red, child: Text('TooltipPlus')),
        buildTooltipOffset: (currentOffset, parentSize, tooltipSize) {
          return Offset(
            currentOffset.dx + parentSize.width / 2,
            currentOffset.dy - parentSize.width / 2,
          );
        },
        child: Container(width: 100, height: 100, color: Colors.green),
      ),
    );
  }
}

```

## Platform Support

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux


## Why Widget Tooltip?

Flutter's built-in Tooltip widget is great for simple use cases, but when you need more control over the appearance and behavior of your tooltips, Widget Tooltip provides:

## Features

- **Rich Customization**: Full control over the tooltip's appearance, allowing the use of custom widgets for the tooltip message via the `messageWidget` property.

- **Smart Positioning**: Automatically adjusts the tooltip's position, with options to customize offsets using the `buildTooltipOffset` function, ensuring that the tooltip stays within screen bounds.

- **Multiple Triggers**: Support for various trigger modes through the `triggerMode` property to choose how the tooltip is displayed, or implement manual control for flexible display logic.

- **Flexible Dismiss Behavior**: Configure dismissal behaviors with various durations (`waitDuration`, `showDuration`, `exitDuration`) to control how long the tooltip remains visible or when it should be hidden.

- **Controller Support**: Option to programmatically control tooltip visibility, allowing integration with other components and dynamic interactions.

- **Callback Support**: React to tooltip events with `onTriggered` callbacks, enabling custom behavior when the tooltip is displayed or hidden.

- **Feedback Mechanism**: Option to provide user feedback on activation via the `enableFeedback` property, enhancing the user experience.

- **Open Tooltip Management**: Maintains a list of currently opened tooltips (`_openedTooltips`) for central management of multiple tooltips within the application.


## Documentation

For detailed documentation and examples, visit our [documentation site](https://github.com/NamTranDinh/tooltip_plus).

## License

This project is licensed under the MIT License - see the [LICENSE](https://github.com/NamTranDinh/tooltip_plus/blob/main/LICENSE) file for details.