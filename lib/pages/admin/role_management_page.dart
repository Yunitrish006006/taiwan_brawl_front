import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/locale_provider.dart';

class RoleManagementPage extends StatefulWidget {
  const RoleManagementPage({super.key});

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage> {
  static const Map<String, String> _roleLabels = {
    'admin': 'Admin',
    'card_manager': 'Card Manager',
    'player': 'Player',
  };

  late final AdminService _adminService;
  final TextEditingController _searchController = TextEditingController();

  List<ManageUser> _users = const [];
  bool _isLoading = true;
  String? _busyKey;

  @override
  void initState() {
    super.initState();
    _adminService = AdminService(ApiClient());
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final users = await _adminService.searchUsers(
        _searchController.text.trim(),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateRole(ManageUser user, String role) async {
    setState(() {
      _busyKey = 'role-${user.id}';
    });

    try {
      final updated = await _adminService.updateUserRole(user.id, role);
      if (!mounted) {
        return;
      }
      setState(() {
        _users = _users
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<LocaleProvider>().translation.text(
              'Role updated successfully',
            ),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) {
        setState(() {
          _busyKey = null;
        });
      }
    }
  }

  String _formatLastActive(String? value) {
    final t = context.read<LocaleProvider>().translation;
    if (value == null || value.isEmpty) {
      return t.text('No activity yet');
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final viewer = context.watch<AuthService>().user;
    final t = context.watch<LocaleProvider>().translation;
    if (viewer == null) {
      return Scaffold(body: Center(child: Text(t.text('Please log in first'))));
    }
    if (viewer.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: Text(t.text('Role Management'))),
        body: Center(child: Text(t.text('Only admins can view this page'))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(t.text('Role Management')),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: t.text('Refresh'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                t.text('Manage player roles'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                t.text(
                  'Available roles are Admin, Card Manager, and Player. This version only changes role assignments and does not attach role-specific features yet.',
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        labelText: t.text('Search players'),
                        hintText: t.text('Search by name, email, or player ID'),
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _loadUsers(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.search),
                    label: Text(t.text('Search')),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _users.isEmpty
                      ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(
                            child: Text(t.text('No matching players found')),
                          ),
                        )
                      : Column(
                          children: _users
                              .map(
                                (user) =>
                                    _buildUserTile(context, viewer.id, user),
                              )
                              .toList(),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserTile(BuildContext context, int viewerId, ManageUser user) {
    final t = context.watch<LocaleProvider>().translation;
    final isSelf = viewerId == user.id;
    final busy = _busyKey == 'role-${user.id}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x14000000))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: const Color(0xFF16324F),
            child: Text(user.name.isEmpty ? '?' : user.name.characters.first),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text('${t.text('Player ID')} ${user.id} · ${user.email}'),
                const SizedBox(height: 4),
                Text(
                  '${t.text('Last online')}: ${_formatLastActive(user.lastActiveAt)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSelf) ...[
                  const SizedBox(height: 6),
                  Text(
                    t.text('You cannot change your own role'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: DropdownButtonFormField<String>(
              initialValue: user.role,
              isExpanded: true,
              decoration: InputDecoration(labelText: t.text('Role')),
              items: _roleLabels.entries
                  .map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: isSelf || busy
                  ? null
                  : (value) {
                      if (value == null || value == user.role) {
                        return;
                      }
                      _updateRole(user, value);
                    },
            ),
          ),
        ],
      ),
    );
  }
}
