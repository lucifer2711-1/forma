import 'package:flutter/material.dart';

import 'package:forma/design_system/theme.dart';
import 'package:forma/features/library/library_screen.dart';

/// Root widget: dark-first theming driven by the Forma design tokens.
class FormaApp extends StatelessWidget {
  const FormaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Forma',
      debugShowCheckedModeBanner: false,
      theme: buildFormaTheme(Brightness.light),
      darkTheme: buildFormaTheme(Brightness.dark),
      home: const LibraryScreen(),
    );
  }
}
