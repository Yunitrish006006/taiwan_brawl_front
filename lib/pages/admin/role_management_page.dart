import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/admin_models.dart';
import '../../services/admin_service.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${updated.name} 的身份組已更新')));
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
    if (value == null || value.isEmpty) {
      return '尚無紀錄';
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final viewer = context.watch<AuthService>().user;
    if (viewer == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }
    if (viewer.role != 'admin') {
      return Scaffold(
        appBar: AppBar(title: const Text('身份組管理')),
        body: const Center(child: Text('只有 Admin 可以查看這個頁面')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('身份組管理'),
        actions: [
          IconButton(
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: '重新整理',
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('管理玩家身份組', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              Text(
                '目前可分配的身份組有 Admin、Card Manager、Player。這一版先只做角色切換，不綁實際功能。',
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
                      decoration: const InputDecoration(
                        labelText: '搜尋玩家',
                        hintText: '輸入名稱、Email 或玩家 ID',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onSubmitted: (_) => _loadUsers(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: _loadUsers,
                    icon: const Icon(Icons.search),
                    label: const Text('搜尋'),
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
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 28),
                          child: Center(child: Text('找不到符合條件的玩家')),
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
                Text('ID ${user.id} · ${user.email}'),
                const SizedBox(height: 4),
                Text(
                  '最後上線: ${_formatLastActive(user.lastActiveAt)}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isSelf) ...[
                  const SizedBox(height: 6),
                  Text(
                    '不能修改自己的身份組',
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
              decoration: const InputDecoration(labelText: '身份組'),
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
