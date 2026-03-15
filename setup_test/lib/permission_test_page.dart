import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionTestPage extends StatefulWidget {
  const PermissionTestPage({super.key});

  @override
  State<PermissionTestPage> createState() => _PermissionTestPageState();
}

class _PermissionTestPageState extends State<PermissionTestPage> {
  final List<_PermissionItem> _permissions = [
    _PermissionItem(
      permission: Permission.camera,
      title: 'Camera',
      icon: Icons.camera_alt,
    ),
    _PermissionItem(
      permission: Permission.photos,
      title: 'Photo Library',
      icon: Icons.photo_library,
    ),
    _PermissionItem(
      permission: Permission.microphone,
      title: 'Microphone',
      icon: Icons.mic,
    ),
    _PermissionItem(
      permission: Permission.location,
      title: 'Location',
      icon: Icons.location_on,
    ),
    _PermissionItem(
      permission: Permission.notification,
      title: 'Notification',
      icon: Icons.notifications,
    ),
    _PermissionItem(
      permission: Permission.contacts,
      title: 'Contacts',
      icon: Icons.contacts,
    ),
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
