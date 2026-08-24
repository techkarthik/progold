import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/menu_tree_view.dart';

class UserMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const UserMasterScreen({super.key, this.onBack});

  @override
  State<UserMasterScreen> createState() => _UserMasterScreenState();
}

class _UserMasterScreenState extends State<UserMasterScreen> {
  final ApiService _api = ApiService();

  List<AppUser> _users = [];
  List<AppUser> _filteredUsers = [];
  List<Branch> _dbBranches = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  // Filter States
  String _statusFilter = 'ALL'; // ALL, ACTIVE, INACTIVE
  String _centLoginFilter = 'ALL'; // ALL, YES, NO
  String _branchFilter = 'ALL'; // ALL or branchId

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    final results = await Future.wait([
      _api.getUsers(token),
      _api.getBranches(token),
    ]);

    if (mounted) {
      setState(() {
        _users = results[0] as List<AppUser>;
        _dbBranches = results[1] as List<Branch>;
        _applyFilter();
        _isLoading = false;
      });
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredUsers = _users.where((u) {
      // 1. Search Query Filter
      final matchesSearch = query.isEmpty ||
          u.userId.toLowerCase().contains(query) ||
          u.username.toLowerCase().contains(query) ||
          u.email.toLowerCase().contains(query) ||
          u.branchId.toLowerCase().contains(query);

      if (!matchesSearch) return false;

      // 2. Status Filter
      if (_statusFilter == 'ACTIVE' && !u.isActive) return false;
      if (_statusFilter == 'INACTIVE' && u.isActive) return false;

      // 3. Central Login Filter
      if (_centLoginFilter == 'YES' && !u.isCentralLogin) return false;
      if (_centLoginFilter == 'NO' && u.isCentralLogin) return false;

      // 4. Branch Filter
      if (_branchFilter != 'ALL' && u.branchId.toUpperCase() != _branchFilter.toUpperCase()) {
        return false;
      }

      return true;
    }).toList();
  }

  String _getBranchName(String branchId) {
    if (branchId.isEmpty) return 'Global / All Branches';
    final match = _dbBranches.firstWhere(
      (b) => b.branchId.toUpperCase() == branchId.toUpperCase(),
      orElse: () => Branch(branchId: branchId, branchName: branchId, companyId: ''),
    );
    return "${match.branchId} - ${match.branchName}";
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Header Bar & Quick Metrics
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // 2. Quick Metrics Row
        _buildMetricsRow(isMobile),
        const SizedBox(height: 16),

        // 3. Search & Filter Toolbar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // 4. Main Content Area (Loading / Empty / Cards / Table)
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: GlassTheme.primaryNeon)),
          )
        else if (_filteredUsers.isEmpty)
          _buildEmptyState(context, auth)
        else if (_isTableView && !isMobile)
          _buildTableView(context, auth)
        else
          _buildCardsGridView(context, auth, isMobile),
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeaderBar(BuildContext context, AuthProvider auth, bool isMobile) {
    return GlassContainer(
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.onBack != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Back to Master Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: GlassTheme.cyanGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.accentCyan.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "User Master & Security",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Access Control", color: GlassTheme.accentCyan),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage login accounts, central login & .NET tree view menu permissions",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          // Actions: New User + Refresh + View Toggle
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isMobile)
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.grid_view_rounded,
                          size: 18,
                          color: !_isTableView ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                        ),
                        tooltip: "Card View",
                        onPressed: () => setState(() => _isTableView = false),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.table_rows_rounded,
                          size: 18,
                          color: _isTableView ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                        ),
                        tooltip: "Table View",
                        onPressed: () => setState(() => _isTableView = true),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: "Refresh List",
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.primaryNeon),
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text("New User Account", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                onPressed: () => _showUserFormDialog(context, auth),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= METRICS ROW =================
  Widget _buildMetricsRow(bool isMobile) {
    final total = _users.length;
    final active = _users.where((u) => u.isActive).length;
    final centLogin = _users.where((u) => u.isCentralLogin).length;
    final branchesCovered = _users.map((u) => u.branchId).where((b) => b.isNotEmpty).toSet().length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 500 ? 2 : 1);

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isMobile ? 3.0 : 2.6,
          children: [
            _buildMetricCard("Total Users", "$total", Icons.group_rounded, GlassTheme.primaryNeon),
            _buildMetricCard("Active Accounts", "$active", Icons.verified_user_rounded, GlassTheme.accentEmerald),
            _buildMetricCard("Central Login (YES)", "$centLogin", Icons.vpn_lock_rounded, GlassTheme.accentCyan),
            _buildMetricCard("Assigned Branches", "$branchesCovered", Icons.storefront_rounded, GlassTheme.accentAmber),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                Text(title, style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= SEARCH & FILTER TOOLBAR =================
  Widget _buildSearchToolbar(bool isMobile) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          // Search Input Field
          SizedBox(
            width: isMobile ? double.infinity : 320,
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                _searchQuery = val;
                setState(() => _applyFilter());
              },
              style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary),
              decoration: InputDecoration(
                hintText: "Search user ID, name, email, branch...",
                hintStyle: const TextStyle(fontSize: 12, color: GlassTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: GlassTheme.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: GlassTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          _searchQuery = '';
                          setState(() => _applyFilter());
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
          ),

          // Filters Row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Status Filter
              _buildFilterDropdown<String>(
                label: "Status",
                value: _statusFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text("All Status")),
                  DropdownMenuItem(value: 'ACTIVE', child: Text("Active")),
                  DropdownMenuItem(value: 'INACTIVE', child: Text("Inactive")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _statusFilter = val;
                      _applyFilter();
                    });
                  }
                },
              ),

              // CentLogin Filter
              _buildFilterDropdown<String>(
                label: "Central Login",
                value: _centLoginFilter,
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text("All CentLogin")),
                  DropdownMenuItem(value: 'YES', child: Text("CentLogin: YES")),
                  DropdownMenuItem(value: 'NO', child: Text("CentLogin: NO")),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _centLoginFilter = val;
                      _applyFilter();
                    });
                  }
                },
              ),

              // Branch Filter
              _buildFilterDropdown<String>(
                label: "Branch",
                value: _branchFilter,
                items: [
                  const DropdownMenuItem(value: 'ALL', child: Text("All Branches")),
                  ..._dbBranches.map((b) => DropdownMenuItem(
                        value: b.branchId,
                        child: Text("${b.branchId} - ${b.branchName}"),
                      )),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _branchFilter = val;
                      _applyFilter();
                    });
                  }
                },
              ),

              // Record Count Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  "${_filteredUsers.length} of ${_users.length} Users",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textSecondary),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 12, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: GlassTheme.textMuted, size: 20),
          isDense: true,
        ),
      ),
    );
  }

  // ================= CARDS GRID VIEW =================
  Widget _buildCardsGridView(BuildContext context, AuthProvider auth, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 950
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredUsers.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 310,
          ),
          itemBuilder: (context, index) {
            final user = _filteredUsers[index];
            return _buildUserCard(context, auth, user);
          },
        );
      },
    );
  }

  // Single User Card
  Widget _buildUserCard(BuildContext context, AuthProvider auth, AppUser user) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: user.isActive ? const Color(0xFFE2E8F0) : const Color(0xFFFCA5A5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header: Avatar + User ID + Name + Status Indicator
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: GlassTheme.accentCyan.withValues(alpha: 0.15),
                      child: Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: GlassTheme.accentCyan,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: user.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.username,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: GlassTheme.accentCyan.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: GlassTheme.accentCyan.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              user.userId,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.accentCyan),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: user.isCentralLogin
                                  ? GlassTheme.primaryNeon.withValues(alpha: 0.1)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              user.isCentralLogin ? "CentLogin: YES" : "CentLogin: NO",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: user.isCentralLogin ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Card Body: Branch, Email, Allowed Menu Count
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Branch
                  _buildCardRow(
                    Icons.storefront_rounded,
                    "Branch",
                    _getBranchName(user.branchId),
                    color: GlassTheme.accentEmerald,
                  ),
                  const SizedBox(height: 8),

                  // Email
                  if (user.email.isNotEmpty)
                    _buildCardRow(
                      Icons.email_outlined,
                      "Email",
                      user.email,
                      isCopyable: true,
                      color: GlassTheme.secondaryNeon,
                    )
                  else
                    _buildCardRow(Icons.email_outlined, "Email", "No email linked (Recovery unavailable)", color: GlassTheme.textMuted),
                  const SizedBox(height: 10),

                  // Menu Access Counter & Tree Preview Pill
                  Row(
                    children: [
                      const Icon(Icons.account_tree_rounded, size: 14, color: GlassTheme.accentCyan),
                      const SizedBox(width: 6),
                      const Text("Allowed Menus: ", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
                      Text(
                        "${user.allowedMenus.length} / ${MenuTreeRegistry.totalMenuItemsCount}",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Allowed Menu Chips preview
                  if (user.allowedMenus.isEmpty)
                    const Text("No menus permitted", style: TextStyle(fontSize: 11, color: GlassTheme.accentRose, fontStyle: FontStyle.italic))
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: user.allowedMenus.take(3).map((code) {
                        final node = _findNodeByCode(code);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (node?.color ?? GlassTheme.primaryNeon).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: (node?.color ?? GlassTheme.primaryNeon).withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            node?.title ?? code,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: node?.color ?? GlassTheme.primaryNeon),
                          ),
                        );
                      }).toList()
                        ..addAll(
                          user.allowedMenus.length > 3
                              ? [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "+${user.allowedMenus.length - 3} more",
                                      style: const TextStyle(fontSize: 10, color: GlassTheme.textMuted),
                                    ),
                                  )
                                ]
                              : [],
                        ),
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Card Footer Actions: View Details, Change Password, Edit, Delete
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // View Permissions Button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: GlassTheme.accentCyan,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text("Permissions", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _showUserDetailsDialog(context, user),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Change Password
                    IconButton(
                      icon: const Icon(Icons.key_rounded, size: 17, color: GlassTheme.accentAmber),
                      tooltip: "Change Password",
                      onPressed: () => _showChangePasswordDialog(context, auth, user),
                    ),
                    // Edit
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 17, color: GlassTheme.primaryNeon),
                      tooltip: "Edit User & Menus",
                      onPressed: () => _showUserFormDialog(context, auth, existingUser: user),
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 17, color: GlassTheme.accentRose),
                      tooltip: "Delete User",
                      onPressed: () => _showDeleteConfirmation(context, auth, user),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardRow(IconData icon, String label, String value, {bool isCopyable = false, required Color color}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text("$label: ", style: const TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (isCopyable)
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("Copied $label: $value"),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Icon(Icons.copy_rounded, size: 12, color: GlassTheme.textMuted),
            ),
          ),
      ],
    );
  }

  MenuTreeNode? _findNodeByCode(String code) {
    for (final root in MenuTreeRegistry.fullTree) {
      if (root.code == code) return root;
      for (final child in root.children) {
        if (child.code == code) return child;
      }
    }
    return null;
  }

  // ================= TABLE VIEW =================
  Widget _buildTableView(BuildContext context, AuthProvider auth) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
            columns: const [
              DataColumn(label: Text("User ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Username", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Email", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Branch", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("CentLogin", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Allowed Menus", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _filteredUsers.map((u) {
              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GlassTheme.accentCyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GlassTheme.accentCyan.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        u.userId,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.accentCyan),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(u.username, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GlassTheme.textPrimary)),
                  ),
                  DataCell(Text(u.email.isNotEmpty ? u.email : '-', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(_getBranchName(u.branchId), style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: u.isActive
                            ? GlassTheme.accentEmerald.withValues(alpha: 0.1)
                            : GlassTheme.accentRose.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        u.isActive ? "Active" : "Inactive",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: u.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      u.centlogin,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: u.isCentralLogin ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                      ),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${u.allowedMenus.length} Menus",
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.primaryNeon),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16, color: GlassTheme.accentCyan),
                          tooltip: "View Details & Permissions",
                          onPressed: () => _showUserDetailsDialog(context, u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.key_rounded, size: 16, color: GlassTheme.accentAmber),
                          tooltip: "Change Password",
                          onPressed: () => _showChangePasswordDialog(context, auth, u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: GlassTheme.primaryNeon),
                          tooltip: "Edit User",
                          onPressed: () => _showUserFormDialog(context, auth, existingUser: u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: GlassTheme.accentRose),
                          tooltip: "Delete User",
                          onPressed: () => _showDeleteConfirmation(context, auth, u),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState(BuildContext context, AuthProvider auth) {
    return GlassContainer(
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: GlassTheme.accentCyan.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, size: 48, color: GlassTheme.accentCyan),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty || _statusFilter != 'ALL' || _centLoginFilter != 'ALL'
                  ? "No matching user accounts found"
                  : "No User Accounts Created Yet",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query or reset filter dropdowns."
                  : "Create login accounts for cashiers, billing operators & managers with .NET Tree View permissions.",
              style: const TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isNotEmpty || _statusFilter != 'ALL' || _centLoginFilter != 'ALL')
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text("Reset Filters"),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchQuery = '';
                    _statusFilter = 'ALL';
                    _centLoginFilter = 'ALL';
                    _branchFilter = 'ALL';
                    _applyFilter();
                  });
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18),
                label: const Text("Create First User", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showUserFormDialog(context, auth),
              ),
          ],
        ),
      ),
    );
  }

  // ================= CREATE / EDIT USER FORM MODAL =================
  void _showUserFormDialog(BuildContext context, AuthProvider auth, {AppUser? existingUser}) {
    final isEditing = existingUser != null;
    final formKey = GlobalKey<FormState>();

    final idController = TextEditingController(text: existingUser?.userId ?? '');
    final nameController = TextEditingController(text: existingUser?.username ?? '');
    final emailController = TextEditingController(text: existingUser?.email ?? '');
    final passwordController = TextEditingController();

    String selectedBranchId = existingUser?.branchId ?? (_dbBranches.isNotEmpty ? _dbBranches.first.branchId : '');
    bool isActive = existingUser?.isActive ?? true;
    bool isCentLogin = existingUser?.isCentralLogin ?? false;

    // Selected menus from Tree View
    List<String> currentSelectedMenus = List.from(existingUser?.allowedMenus ?? MenuTreeRegistry.allLeafCodes);
    bool isSaving = false;
    bool obscurePassword = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Container(
                width: 780,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Modal Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFF8FAFC), Colors.white],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: GlassTheme.cyanGradient,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.manage_accounts_rounded : Icons.person_add_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEditing ? "Edit User Account & Permissions" : "Create New User Account",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                                ),
                                Text(
                                  isEditing
                                      ? "Updating User ID: ${existingUser.userId}"
                                      : "Assign branch, central login & fine-grained .NET Tree View permissions",
                                  style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: GlassTheme.textMuted),
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                    ),

                    // Scrollable Form Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 1. User ID & Username Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "User ID * (Login ID)",
                                      controller: idController,
                                      icon: Icons.badge_rounded,
                                      hintText: "e.g. USR01",
                                      maxLength: 10,
                                      enabled: !isEditing,
                                      textCapitalization: TextCapitalization.characters,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return "User ID is required";
                                        if (val.trim().length > 10) return "Max 10 chars";
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 4,
                                    child: _buildFormField(
                                      label: "User Full Name *",
                                      controller: nameController,
                                      icon: Icons.person_rounded,
                                      hintText: "e.g. Rajesh Kumar (Cashier)",
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) return "Full Name is required";
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2. Email & Password Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildFormField(
                                      label: "Email Address (For Password Recovery)",
                                      controller: emailController,
                                      icon: Icons.email_rounded,
                                      hintText: "e.g. rajesh@progold.com",
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  if (!isEditing)
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            "Password *",
                                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                          ),
                                          const SizedBox(height: 6),
                                          TextFormField(
                                            controller: passwordController,
                                            obscureText: obscurePassword,
                                            validator: (val) {
                                              if (val == null || val.length < 4) return "Min 4 characters";
                                              return null;
                                            },
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                            decoration: InputDecoration(
                                              hintText: "Enter login password",
                                              hintStyle: const TextStyle(fontSize: 12, color: GlassTheme.textMuted),
                                              prefixIcon: const Icon(Icons.lock_rounded, size: 18, color: GlassTheme.accentCyan),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                                  size: 18,
                                                  color: GlassTheme.textMuted,
                                                ),
                                                onPressed: () => setDialogState(() => obscurePassword = !obscurePassword),
                                              ),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                              filled: true,
                                              fillColor: const Color(0xFFF8FAFC),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(10),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Branch Dropdown, Active Switch, Central Login Switch
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Branch Dropdown
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Assigned Branch (from Branch Master)",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          value: _dbBranches.any((b) => b.branchId.toUpperCase() == selectedBranchId.toUpperCase())
                                              ? selectedBranchId
                                              : (_dbBranches.isNotEmpty ? _dbBranches.first.branchId : ''),
                                          dropdownColor: Colors.white,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.accentCyan),
                                          style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.storefront_rounded, size: 18, color: GlassTheme.accentEmerald),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                          ),
                                          items: [
                                            const DropdownMenuItem(value: '', child: Text("Global / No Specific Branch")),
                                            ..._dbBranches.map((b) {
                                              return DropdownMenuItem(
                                                value: b.branchId,
                                                child: Text("${b.branchId} - ${b.branchName}", overflow: TextOverflow.ellipsis),
                                              );
                                            }),
                                          ],
                                          onChanged: (newBranchId) {
                                            if (newBranchId != null) {
                                              setDialogState(() => selectedBranchId = newBranchId);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Central Login Toggle (YES / NO)
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Central Login",
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                              ),
                                              Switch(
                                                value: isCentLogin,
                                                activeThumbColor: GlassTheme.primaryNeon,
                                                onChanged: (val) => setDialogState(() => isCentLogin = val),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            isCentLogin ? "YES (Can login across all branches)" : "NO (Restricted to branch)",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isCentLogin ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Account Active Switch
                                  Expanded(
                                    flex: 2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFCBD5E1)),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text(
                                                "Status",
                                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                              ),
                                              Switch(
                                                value: isActive,
                                                activeThumbColor: GlassTheme.accentEmerald,
                                                onChanged: (val) => setDialogState(() => isActive = val),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            isActive ? "ACTIVE (Can login)" : "INACTIVE (Disabled)",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),

                              // 4. .NET Style Tree View for Menu Permissions
                              MenuPermissionsTreeView(
                                initialSelectedMenus: currentSelectedMenus,
                                onPermissionsChanged: (newMenus) {
                                  currentSelectedMenus = newMenus;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Modal Action Buttons Footer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
                        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                            child: const Text("Cancel", style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GlassTheme.accentCyan,
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : Icon(isEditing ? Icons.save_rounded : Icons.check_circle_rounded, size: 18),
                            label: Text(
                              isSaving
                                  ? "Saving..."
                                  : isEditing
                                      ? "Update User Account"
                                      : "Save User Account",
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;

                                    setDialogState(() => isSaving = true);
                                    final token = auth.authToken;
                                    if (token == null) return;

                                    final userPayload = AppUser(
                                      userId: isEditing ? existingUser.userId : idController.text.trim().toUpperCase(),
                                      username: nameController.text.trim(),
                                      email: emailController.text.trim(),
                                      branchId: selectedBranchId.trim().toUpperCase(),
                                      isActive: isActive,
                                      centlogin: isCentLogin ? 'YES' : 'NO',
                                      allowedMenus: currentSelectedMenus,
                                    );

                                    Map<String, dynamic> res;
                                    if (isEditing) {
                                      res = await _api.updateUser(token, existingUser.userId, userPayload);
                                    } else {
                                      res = await _api.createUser(token, userPayload, passwordController.text.trim());
                                    }

                                    setDialogState(() => isSaving = false);

                                    if (res['success'] == true) {
                                      Navigator.pop(dialogCtx);
                                      _loadData();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing
                                                  ? "User account updated successfully!"
                                                  : "User account created successfully!",
                                            ),
                                            backgroundColor: GlassTheme.accentEmerald,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    } else {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(res['message'] ?? "Operation failed"),
                                            backgroundColor: GlassTheme.accentRose,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ================= CHANGE PASSWORD DIALOG =================
  void _showChangePasswordDialog(BuildContext context, AuthProvider auth, AppUser user) {
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final passFormKey = GlobalKey<FormState>();
    bool isSaving = false;
    bool obscure = true;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setPassState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentAmber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.key_rounded, color: GlassTheme.accentAmber, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text("Change Password: ${user.userId}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Form(
                key: passFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Enter a new password for user \"${user.username}\":", style: const TextStyle(fontSize: 13, color: GlassTheme.textSecondary)),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscure,
                      validator: (val) {
                        if (val == null || val.length < 4) return "Password must be at least 4 chars";
                        return null;
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "New Password",
                        prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18, color: GlassTheme.accentAmber),
                        suffixIcon: IconButton(
                          icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                          onPressed: () => setPassState(() => obscure = !obscure),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscure,
                      validator: (val) {
                        if (val != newPassController.text) return "Passwords do not match";
                        return null;
                      },
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        labelText: "Confirm New Password",
                        prefixIcon: const Icon(Icons.lock_reset_rounded, size: 18, color: GlassTheme.accentAmber),
                        isDense: true,
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                OutlinedButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.accentAmber,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!passFormKey.currentState!.validate()) return;
                          setPassState(() => isSaving = true);
                          final token = auth.authToken;
                          if (token == null) return;

                          final res = await _api.changeUserPassword(token, user.userId, newPassController.text.trim());
                          setPassState(() => isSaving = false);

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Password changed successfully!"),
                                  backgroundColor: GlassTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? "Failed to change password"),
                                  backgroundColor: GlassTheme.accentRose,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text("Update Password", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= VIEW USER DETAILS & PERMISSIONS MODAL =================
  void _showUserDetailsDialog(BuildContext context, AppUser user) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 650,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: GlassTheme.accentCyan.withValues(alpha: 0.15),
                      child: Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: const TextStyle(color: GlassTheme.accentCyan, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.username, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary)),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: GlassTheme.accentCyan.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text("ID: ${user.userId}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.accentCyan)),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: user.isActive ? GlassTheme.accentEmerald.withValues(alpha: 0.1) : GlassTheme.accentRose.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  user.isActive ? "Active" : "Inactive",
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: user.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: GlassTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),

                const SizedBox(height: 14),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 10),

                // Details List
                _buildDetailTile("Assigned Branch", _getBranchName(user.branchId), Icons.storefront_rounded),
                _buildDetailTile("Central Login", user.isCentralLogin ? "YES (Can login across all branches)" : "NO (Branch locked)", Icons.vpn_lock_rounded),
                _buildDetailTile("Registered Email", user.email.isNotEmpty ? user.email : "Not Provided", Icons.email_outlined),

                const SizedBox(height: 14),
                const Text(
                  "Assigned Menu Permissions Hierarchy:",
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                ),
                const SizedBox(height: 8),

                // Readonly Tree View
                Expanded(
                  child: MenuPermissionsTreeView(
                    initialSelectedMenus: user.allowedMenus,
                    readOnly: true,
                    onPermissionsChanged: (_) {},
                  ),
                ),

                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: GlassTheme.textPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Close"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailTile(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: GlassTheme.accentCyan),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ================= DELETE CONFIRMATION DIALOG =================
  void _showDeleteConfirmation(BuildContext context, AuthProvider auth, AppUser user) {
    bool isDeleting = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose, size: 24),
                  SizedBox(width: 10),
                  Text("Delete User Account", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Are you sure you want to delete user \"${user.username}\" (ID: ${user.userId})?", style: const TextStyle(fontSize: 14, color: GlassTheme.textPrimary)),
                  const SizedBox(height: 8),
                  const Text("This user will no longer be able to log in to the software.", style: TextStyle(fontSize: 12, color: GlassTheme.textMuted)),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.accentRose, foregroundColor: Colors.white),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final token = auth.authToken;
                          if (token == null) return;

                          final res = await _api.deleteUser(token, user.userId);
                          setDialogState(() => isDeleting = false);

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("User account deleted successfully!"),
                                  backgroundColor: GlassTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? "Failed to delete user."),
                                  backgroundColor: GlassTheme.accentRose,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text("Delete Permanently"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Helper form input field
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
    int? maxLength,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          maxLength: maxLength,
          enabled: enabled,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontSize: 13,
            color: enabled ? GlassTheme.textPrimary : GlassTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 12, color: GlassTheme.textMuted, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, size: 18, color: enabled ? GlassTheme.accentCyan : GlassTheme.textMuted),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GlassTheme.accentCyan, width: 1.5)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: GlassTheme.accentRose)),
          ),
        ),
      ],
    );
  }
}
