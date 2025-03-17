import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/rss_service.dart';
import '../services/notification_service.dart';
import '../services/log_service.dart';
import '../services/discord_service.dart';
import '../services/version_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = false;
  String _checkInterval = '60';

  @override
  void initState() {
    super.initState();
    LogService.log('Settings page opened', category: 'settings');
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    LogService.log('Loading settings', category: 'settings');
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? false;
      _checkInterval = prefs.getString('check_interval') ?? '60';
    });
  }

  Future<void> _saveSettings() async {
    LogService.log('Saving settings - Notifications: $_notificationsEnabled, Interval: $_checkInterval', 
        category: 'settings');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setString('check_interval', _checkInterval);

    if (_notificationsEnabled) {
      await Workmanager().registerPeriodicTask(
        'samen1-rss-check',
        'checkRSSFeed',
        frequency: Duration(minutes: int.parse(_checkInterval)),
      );
    } else {
      await Workmanager().cancelByUniqueName('samen1-rss-check');
    }
  }

  Future<void> _launchEmail() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'floris.vandenbroek@samen1.nl',
      query: 'subject=Feedback Samen1 App',
    );

    if (!await launchUrl(emailLaunchUri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kon email app niet openen')),
        );
      }
    }
  }

  Future<void> _openBatterySettings() async {
    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Batterij optimalisatie'),
          content: const Text(
            '1. Houd de Samen1 app ingedrukt\n'
            '2. Selecteer "App-info"\n'
            '3. Tik op "Batterij"\n'
            '4. Selecteer "Onbeperkt" of "Niet optimaliseren"\n'
            '5. Bevestig je keuze',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _showBugReportDialog() async {
    final TextEditingController descriptionController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bug rapporteren'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Beschrijf het probleem zo duidelijk mogelijk:'),
            const SizedBox(height: 8),
            TextField(
              controller: descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Beschrijf het probleem...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                hintText: 'E-mail (optioneel)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (descriptionController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Geef een beschrijving van het probleem')),
                );
                return;
              }
              
              // Sluit eerst de bug report dialog
              Navigator.pop(context);
              
              // Voeg email toe aan de beschrijving als deze is ingevuld
              String description = descriptionController.text;
              if (emailController.text.isNotEmpty) {
                description = 'Email: ${emailController.text}\n\n$description';
              }
              
              // Toon loading indicator
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Bug report versturen...'),
                    duration: Duration(milliseconds: 1500),
                  ),
                );
              }
              
              final report = await LogService.generateReport(description);
              final success = await DiscordService.sendBugReport(report);
              
              // Toon resultaat snackbar
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success 
                        ? 'Bedankt voor je melding! We gaan er mee aan de slag.' 
                        : 'Er ging iets mis bij het versturen. Probeer het later opnieuw.'
                    ),
                    duration: const Duration(seconds: 4),
                    action: success ? null : SnackBarAction(
                      label: 'Opnieuw',
                      onPressed: () => _showBugReportDialog(),
                    ),
                  ),
                );
              }
            },
            child: const Text('Versturen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instellingen'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ExpansionTile(
                  title: Text(
                    'Meldingen',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  initiallyExpanded: true,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  children: [
                    SwitchListTile(
                      title: const Text('Meldingen inschakelen'),
                      subtitle: const Text('Ontvang meldingen bij nieuwe artikelen'),
                      value: _notificationsEnabled,
                      onChanged: (value) {
                        setState(() => _notificationsEnabled = value);
                        _saveSettings();
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Controle interval'),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: '10', label: Text('10m')),
                                ButtonSegment(value: '30', label: Text('30m')),
                                ButtonSegment(value: '60', label: Text('1u')),
                                ButtonSegment(value: '240', label: Text('4u')),
                              ],
                              selected: {_checkInterval},
                              onSelectionChanged: _notificationsEnabled
                                  ? (Set<String> newSelection) {
                                      setState(() => _checkInterval = newSelection.first);
                                      _saveSettings();
                                    }
                                  : null,
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    ListTile(
                      title: const Text('Test melding'),
                      subtitle: const Text('Stuur een test melding om te controleren'),
                      trailing: IconButton(
                        icon: const Icon(Icons.notifications_active),
                        onPressed: () async {
                          await NotificationService.initialize();
                          final result = await RSSService.sendTestNotification();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result)),
                            );
                          }
                        },
                      ),
                    ),
                    if (Theme.of(context).platform == TargetPlatform.android)
                      ListTile(
                        title: const Text('Batterij optimalisatie'),
                        subtitle: const Text('Schakel batterij optimalisatie uit voor betrouwbare meldingen'),
                        trailing: IconButton(
                          icon: const Icon(Icons.battery_saver),
                          onPressed: _openBatterySettings,
                        ),
                      ),
                  ],
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.bug_report),
                  title: const Text('Bug rapporteren'),
                  subtitle: const Text('Stuur een probleem rapport'),
                  onTap: _showBugReportDialog,
                ),
                const SizedBox(height: 32),
                Center(
                  child: Text(
                    VersionService.copyright,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
