import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionTestPage extends StatefulWidget {
  const PermissionTestPage({super.key});

  @override
  State<PermissionTestPage> createState() => _PermissionTestPageState();
}

class _PermissionTestPageState extends State<PermissionTestPage> {
  final List<_PermissionItem> _permissions = [
    // Device
    _PermissionItem(permission: Permission.camera, title: 'Camera', icon: Icons.camera_alt),
    _PermissionItem(permission: Permission.microphone, title: 'Microphone', icon: Icons.mic),
    _PermissionItem(permission: Permission.speech, title: 'Speech Recognition', icon: Icons.record_voice_over),
    _PermissionItem(permission: Permission.sensors, title: 'Sensors (Motion)', icon: Icons.sensors),
    _PermissionItem(permission: Permission.bluetooth, title: 'Bluetooth', icon: Icons.bluetooth),
    // Photos & Media
    _PermissionItem(permission: Permission.photos, title: 'Photo Library', icon: Icons.photo_library),
    _PermissionItem(permission: Permission.photosAddOnly, title: 'Photos (Add Only)', icon: Icons.add_photo_alternate),
    _PermissionItem(permission: Permission.videos, title: 'Videos', icon: Icons.video_library),
    _PermissionItem(permission: Permission.audio, title: 'Audio (Media Library)', icon: Icons.library_music),
    _PermissionItem(permission: Permission.storage, title: 'Storage', icon: Icons.sd_storage),
    _PermissionItem(permission: Permission.manageExternalStorage, title: 'Manage External Storage', icon: Icons.folder_open),
    // Location
    _PermissionItem(permission: Permission.location, title: 'Location', icon: Icons.location_on),
    _PermissionItem(permission: Permission.locationAlways, title: 'Location Always', icon: Icons.location_searching),
    _PermissionItem(permission: Permission.locationWhenInUse, title: 'Location When In Use', icon: Icons.my_location),
    // Contacts & Calendar
    _PermissionItem(permission: Permission.contacts, title: 'Contacts', icon: Icons.contacts),
    // ignore: deprecated_member_use
    _PermissionItem(permission: Permission.calendar, title: 'Calendar (deprecated)', icon: Icons.calendar_today),
    _PermissionItem(permission: Permission.calendarFullAccess, title: 'Calendar Full Access', icon: Icons.edit_calendar),
    _PermissionItem(permission: Permission.calendarWriteOnly, title: 'Calendar Write Only', icon: Icons.calendar_month),
    _PermissionItem(permission: Permission.reminders, title: 'Reminders', icon: Icons.alarm),
    // Notifications
    _PermissionItem(permission: Permission.notification, title: 'Notification', icon: Icons.notifications),
    _PermissionItem(permission: Permission.criticalAlerts, title: 'Critical Alerts', icon: Icons.warning_amber),
    // Communication
    _PermissionItem(permission: Permission.phone, title: 'Phone', icon: Icons.phone),
    _PermissionItem(permission: Permission.sms, title: 'SMS', icon: Icons.sms),
    // Health & Activity
    _PermissionItem(permission: Permission.activityRecognition, title: 'Activity Recognition', icon: Icons.directions_walk),
    // Tracking & App
    _PermissionItem(permission: Permission.appTrackingTransparency, title: 'App Tracking Transparency', icon: Icons.track_changes),
    _PermissionItem(permission: Permission.accessMediaLocation, title: 'Access Media Location', icon: Icons.image_search),
    _PermissionItem(permission: Permission.mediaLibrary, title: 'Media Library (Apple Music)', icon: Icons.music_note),
  ];

  @override
  void initState() {
    super.initState();
    _checkStatuses();
  }

  Future<void> _checkStatuses() async {
    for (final item in _permissions) {
      final status = await item.permission.status;
      if (mounted) {
        setState(() => item.status = status);
      }
    }
  }

  Future<void> _requestPermission(_PermissionItem item) async {
    final status = await item.permission.request();
    if (mounted) {
      setState(() => item.status = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permission Test'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _permissions.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final item = _permissions[index];
          return ListTile(
            leading: Icon(item.icon, size: 28),
            title: Text(item.title),
            subtitle: Text(
              item.status?.toString().split('.').last ?? 'unknown',
              style: TextStyle(
                color: _statusColor(item.status),
                fontWeight: FontWeight.w500,
              ),
            ),
            trailing: FilledButton(
              onPressed: () => _requestPermission(item),
              child: const Text('Request'),
            ),
          );
        },
      ),
    );
  }

  Color _statusColor(PermissionStatus? status) {
    return switch (status) {
      PermissionStatus.granted => Colors.green,
      PermissionStatus.denied => Colors.orange,
      PermissionStatus.permanentlyDenied => Colors.red,
      PermissionStatus.restricted => Colors.red,
      PermissionStatus.limited => Colors.blue,
      PermissionStatus.provisional => Colors.blue,
      _ => Colors.grey,
    };
  }
}

class _PermissionItem {
  final Permission permission;
  final String title;
  final IconData icon;
  PermissionStatus? status;

  _PermissionItem({
    required this.permission,
    required this.title,
    required this.icon,
  });
}
