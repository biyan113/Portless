import 'package:flutter/material.dart';

import 'app/home_page.dart';
import 'services/agent_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PortlessApp());
}

class PortlessApp extends StatelessWidget {
  const PortlessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Portless',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: HomePage(agent: AgentService()),
    );
  }
}
