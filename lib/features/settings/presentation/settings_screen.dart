import 'package:flutter/material.dart';
import 'package:harikyu_lab/core/widgets/app_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AppPage(
    title: '設定',
    child: ListView(children: const [
      Card(child: Column(children: [ListTile(leading: Icon(Icons.person_outline), title: Text('アカウント'), trailing: Icon(Icons.chevron_right)), Divider(height: 1, indent: 56), ListTile(leading: Icon(Icons.notifications_outlined), title: Text('通知設定'), trailing: Icon(Icons.chevron_right))])),
      SizedBox(height: 16),
      Card(child: Column(children: [ListTile(leading: Icon(Icons.help_outline), title: Text('ヘルプ・お問い合わせ'), trailing: Icon(Icons.chevron_right)), Divider(height: 1, indent: 56), ListTile(leading: Icon(Icons.info_outline), title: Text('アプリについて'), trailing: Text('1.0.0'))])),
    ]),
  );
}
