import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/location_data.dart';
import '../models/branch_model.dart';
import '../models/company_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class BranchMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const BranchMasterScreen({super.key, this.onBack});

  @override
  State<BranchMasterScreen> createState() => _BranchMasterScreenState();
}

class _BranchMasterScreenState extends State<BranchMasterScreen> {
  final ApiService _api = ApiService();

  List<Branch> _branches = [];
  List<Branch> _filteredBranches = [];
  List<Company> _companies = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // Standard Account Name options
  final List<String> _accountOptions = [
    'Primary Operating Account',
    'HDFC Bank - Current Account',
    'SBI - Cash Credit Account',
    'ICICI Bank - Bullion Account',
    'Axis Bank - Retail Settlement',
    'Petty Cash / Store Counter',
  ];

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

    // Fetch both branches and companies concurrently
    final results = await Future.wait([
      _api.getBranches(token),
      _api.getCompanies(token),
    ]);

    if (mounted) {
      setState(() {
        _branches = results[0] as List<Branch>;
        _companies = results[1] as List<Company>;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredBranches = List.from(_branches);
    } else {
      _filteredBranches = _branches.where((b) {
        return b.branchId.toLowerCase().contains(_searchQuery) ||
            b.branchName.toLowerCase().contains(_searchQuery) ||
            b.companyId.toLowerCase().contains(_searchQuery) ||
            (b.companyName ?? '').toLowerCase().contains(_searchQuery) ||
            b.state.toLowerCase().contains(_searchQuery) ||
            b.mobile.toLowerCase().contains(_searchQuery) ||
            b.email.toLowerCase().contains(_searchQuery) ||
            b.accountName.toLowerCase().contains(_searchQuery) ||
            b.address.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // Helper to find company name for a company ID
  String _getCompanyName(String companyId) {
    final match = _companies.firstWhere(
      (c) => c.companyId.toUpperCase() == companyId.toUpperCase(),
      orElse: () => Company(companyId: companyId, companyName: companyId),
    );
    return match.companyName;
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Header Bar
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // Search & View Toolbar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Content Area
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: GlassTheme.primaryNeon)),
          )
        else if (_filteredBranches.isEmpty)
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
                  tooltip: "Back to Organization",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [GlassTheme.accentEmerald, GlassTheme.accentEmerald.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.accentEmerald.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Branch Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Organization Master", color: GlassTheme.accentEmerald),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage retail outlets, billing counters, linked companies, states & accounts",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          // Actions
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
                          color: !_isTableView ? GlassTheme.accentEmerald : GlassTheme.textMuted,
                        ),
                        tooltip: "Card View",
                        onPressed: () => setState(() => _isTableView = false),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.table_rows_rounded,
                          size: 18,
                          color: _isTableView ? GlassTheme.accentEmerald : GlassTheme.textMuted,
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
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.accentEmerald),
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text("New Branch", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _showBranchFormDialog(context, auth),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= SEARCH TOOLBAR =================
  Widget _buildSearchToolbar(bool isMobile) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _applyFilter(val)),
              style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary),
              decoration: InputDecoration(
                hintText: "Search branch by ID, name, company, state, mobile, email, account, address...",
                hintStyle: const TextStyle(fontSize: 13, color: GlassTheme.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: GlassTheme.textMuted),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16, color: GlassTheme.textMuted),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFilter(''));
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
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: GlassTheme.accentEmerald, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              "${_filteredBranches.length} of ${_branches.length} Branches",
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ================= CARDS GRID VIEW =================
  Widget _buildCardsGridView(BuildContext context, AuthProvider auth, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 600
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _filteredBranches.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 310,
          ),
          itemBuilder: (context, index) {
            final branch = _filteredBranches[index];
            return _buildBranchCard(context, auth, branch);
          },
        );
      },
    );
  }

  // Single Branch Card
  Widget _buildBranchCard(BuildContext context, AuthProvider auth, Branch branch) {
    final companyName = branch.companyName?.isNotEmpty == true
        ? branch.companyName!
        : _getCompanyName(branch.companyId);

    final stateItem = (branch.stateId != null && branch.stateId! > 0)
        ? LocationData.getStateById(branch.stateId!)
        : LocationData.getStateByNameOrCode(branch.state, branch.countryId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          // Top Header
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: GlassTheme.accentEmerald.withValues(alpha: 0.12),
                  child: Text(
                    branch.branchName.isNotEmpty ? branch.branchName[0].toUpperCase() : 'B',
                    style: const TextStyle(
                      color: GlassTheme.accentEmerald,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              branch.branchName,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: GlassTheme.textPrimary,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Active / Inactive Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: branch.isActive
                                  ? GlassTheme.accentEmerald.withValues(alpha: 0.12)
                                  : GlassTheme.accentRose.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: branch.isActive
                                    ? GlassTheme.accentEmerald.withValues(alpha: 0.4)
                                    : GlassTheme.accentRose.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              branch.isActive ? "Active: Yes" : "Active: No",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: branch.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: GlassTheme.accentEmerald.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: GlassTheme.accentEmerald.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              branch.branchId,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.accentEmerald),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Under: $companyName (${branch.companyId})",
                              style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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

          // Body Details
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // State / Region with GST Code
                  _buildInfoRow(
                    Icons.map_rounded,
                    "State",
                    "${stateItem != null ? '${stateItem.name} [ID: ${stateItem.id}]' : (branch.state.isNotEmpty ? branch.state : 'Not Selected')}",
                    color: GlassTheme.secondaryNeon,
                  ),
                  const SizedBox(height: 8),

                  // Account Name
                  if (branch.accountName.isNotEmpty)
                    _buildInfoRow(
                      Icons.account_balance_rounded,
                      "Account",
                      branch.accountName,
                      color: GlassTheme.accentAmber,
                    )
                  else
                    _buildInfoRow(Icons.account_balance_rounded, "Account", "Default Account", color: GlassTheme.textMuted),
                  const SizedBox(height: 8),

                  // Mobile
                  if (branch.mobile.isNotEmpty)
                    _buildInfoRow(Icons.phone_rounded, "Mobile", branch.mobile, color: GlassTheme.accentCyan)
                  else
                    _buildInfoRow(Icons.phone_rounded, "Mobile", "Not Provided", color: GlassTheme.textMuted),
                  const SizedBox(height: 8),

                  // Email
                  if (branch.email.isNotEmpty)
                    _buildInfoRow(Icons.email_rounded, "Email", branch.email, color: GlassTheme.primaryNeon)
                  else
                    _buildInfoRow(Icons.email_rounded, "Email", "Not Provided", color: GlassTheme.textMuted),
                  const SizedBox(height: 8),

                  // Address
                  if (branch.address.isNotEmpty)
                    _buildInfoRow(Icons.location_on_rounded, "Address", branch.address, color: GlassTheme.textSecondary)
                  else
                    _buildInfoRow(Icons.location_on_rounded, "Address", "Not Provided", color: GlassTheme.textMuted),
                ],
              ),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Bottom Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // View Details
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: GlassTheme.accentEmerald,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () => _showBranchDetailsDialog(context, branch),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: GlassTheme.accentCyan),
                      tooltip: "Edit Branch",
                      onPressed: () => _showBranchFormDialog(context, auth, existingBranch: branch),
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GlassTheme.accentRose),
                      tooltip: "Delete Branch",
                      onPressed: () => _showDeleteConfirmation(context, auth, branch),
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

  Widget _buildInfoRow(IconData icon, String label, String value, {required Color color}) {
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
      ],
    );
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
              DataColumn(label: Text("Branch ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Branch Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Company", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("State [ID]", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Account", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Mobile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _filteredBranches.map((b) {
              final companyName = b.companyName?.isNotEmpty == true
                  ? b.companyName!
                  : _getCompanyName(b.companyId);

              final stateItem = (b.stateId != null && b.stateId! > 0)
                  ? LocationData.getStateById(b.stateId!)
                  : LocationData.getStateByNameOrCode(b.state, b.countryId);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GlassTheme.accentEmerald.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GlassTheme.accentEmerald.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        b.branchId,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.accentEmerald),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(b.branchName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GlassTheme.textPrimary)),
                  ),
                  DataCell(
                    Text("$companyName (${b.companyId})", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: GlassTheme.primaryNeon)),
                  ),
                  DataCell(
                    Text(stateItem != null ? "${stateItem.name} [${stateItem.id}]" : (b.state.isNotEmpty ? b.state : '-'), style: const TextStyle(fontSize: 12)),
                  ),
                  DataCell(Text(b.accountName.isNotEmpty ? b.accountName : '-', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(b.mobile.isNotEmpty ? b.mobile : '-', style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: b.isActive
                            ? GlassTheme.accentEmerald.withValues(alpha: 0.12)
                            : GlassTheme.accentRose.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        b.isActive ? "Yes" : "No",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: b.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16, color: GlassTheme.accentEmerald),
                          tooltip: "View Details",
                          onPressed: () => _showBranchDetailsDialog(context, b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: GlassTheme.accentCyan),
                          tooltip: "Edit",
                          onPressed: () => _showBranchFormDialog(context, auth, existingBranch: b),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: GlassTheme.accentRose),
                          tooltip: "Delete",
                          onPressed: () => _showDeleteConfirmation(context, auth, b),
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
                color: GlassTheme.accentEmerald.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.storefront_rounded, size: 48, color: GlassTheme.accentEmerald),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? "No matching branches found" : "No Branches Registered Yet",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try searching with a different keyword or clear the search filter."
                  : "Add your retail outlets, showrooms, or depots and link them to your companies.",
              style: const TextStyle(fontSize: 13, color: GlassTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_searchQuery.isNotEmpty)
              OutlinedButton.icon(
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text("Clear Search"),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _applyFilter(''));
                },
              )
            else
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentEmerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_business_rounded, size: 18),
                label: const Text("Add First Branch", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showBranchFormDialog(context, auth),
              ),
          ],
        ),
      ),
    );
  }

  // ================= INSERT / EDIT BRANCH FORM DIALOG =================
  void _showBranchFormDialog(BuildContext context, AuthProvider auth, {Branch? existingBranch}) {
    final isEditing = existingBranch != null;
    final formKey = GlobalKey<FormState>();

    final idController = TextEditingController(text: existingBranch?.branchId ?? '');
    final nameController = TextEditingController(text: existingBranch?.branchName ?? '');
    final addressController = TextEditingController(text: existingBranch?.address ?? '');
    final mobileController = TextEditingController(text: existingBranch?.mobile ?? '');
    final emailController = TextEditingController(text: existingBranch?.email ?? '');

    // Company Selection: default to existing or first available company
    String? selectedCompanyId = existingBranch?.companyId;
    if (selectedCompanyId == null || selectedCompanyId.isEmpty) {
      if (_companies.isNotEmpty) {
        selectedCompanyId = _companies.first.companyId;
      }
    }

    // Account Name Dropdown selection / custom
    String selectedAccount = existingBranch?.accountName ?? (_accountOptions.isNotEmpty ? _accountOptions.first : '');
    if (selectedAccount.isNotEmpty && !_accountOptions.contains(selectedAccount)) {
      _accountOptions.add(selectedAccount);
    }

    // State ID: find matching state
    int? selectedStateId;
    if (existingBranch?.stateId != null && existingBranch!.stateId! > 0) {
      selectedStateId = existingBranch.stateId;
    } else if (existingBranch?.state != null && existingBranch!.state.isNotEmpty) {
      final stateMatch = LocationData.getStateByNameOrCode(existingBranch.state, 1);
      selectedStateId = stateMatch?.id;
    }

    // Default to Tamil Nadu (ID 33) if no state is chosen
    if (selectedStateId == null) {
      selectedStateId = 33;
    }

    // Active Status (Yes / No)
    bool isActive = existingBranch?.isActive ?? true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final indianStates = LocationData.indianStates;

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 680,
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
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
                              color: GlassTheme.accentEmerald,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isEditing ? Icons.edit_note_rounded : Icons.add_business_rounded,
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
                                  isEditing ? "Edit Branch Details" : "Create New Branch",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                                ),
                                Text(
                                  isEditing
                                      ? "Updating Branch ID: ${existingBranch.branchId}"
                                      : "Link branch under corporate company with state & account details",
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
                              // 1. Branch ID & Branch Name
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "Branch ID *",
                                      controller: idController,
                                      icon: Icons.tag_rounded,
                                      hintText: "e.g. BR01",
                                      enabled: !isEditing,
                                      textCapitalization: TextCapitalization.characters,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return "Branch ID is required";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 4,
                                    child: _buildFormField(
                                      label: "Branch Name *",
                                      controller: nameController,
                                      icon: Icons.storefront_rounded,
                                      hintText: "e.g. Main Showroom - T.Nagar",
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return "Branch Name is required";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2. Select Under Which Company (Company Dropdown) & State Dropdown
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Company Dropdown
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Company * (Select Under Which Company)",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          value: _companies.any((c) => c.companyId == selectedCompanyId)
                                              ? selectedCompanyId
                                              : (_companies.isNotEmpty ? _companies.first.companyId : null),
                                          dropdownColor: Colors.white,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.accentEmerald),
                                          style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.apartment_rounded, size: 18, color: GlassTheme.accentEmerald),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: GlassTheme.accentEmerald, width: 1.5),
                                            ),
                                          ),
                                          items: _companies.map((c) {
                                            return DropdownMenuItem<String>(
                                              value: c.companyId,
                                              child: Text(
                                                "${c.companyName} (${c.companyId})",
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (newCompanyId) {
                                            setDialogState(() {
                                              selectedCompanyId = newCompanyId;
                                            });
                                          },
                                          validator: (val) {
                                            if (val == null || val.isEmpty) {
                                              return "Please select a company";
                                            }
                                            return null;
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // State Dropdown
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "State / Province * (Select Dropdown)",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<int>(
                                          value: indianStates.any((s) => s.id == selectedStateId)
                                              ? selectedStateId
                                              : (indianStates.isNotEmpty ? indianStates.first.id : null),
                                          dropdownColor: Colors.white,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.accentEmerald),
                                          style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.map_rounded, size: 18, color: GlassTheme.accentEmerald),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: GlassTheme.accentEmerald, width: 1.5),
                                            ),
                                          ),
                                          items: indianStates.map((s) {
                                            return DropdownMenuItem<int>(
                                              value: s.id,
                                              child: Text(
                                                "${s.name} [GST/ID: ${s.gstCode}]",
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (newStateId) {
                                            setDialogState(() {
                                              selectedStateId = newStateId;
                                            });
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Account Name Dropdown & Active (Yes / No)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Account Name Dropdown
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Account Name (Select Dropdown)",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          value: _accountOptions.contains(selectedAccount) ? selectedAccount : _accountOptions.first,
                                          dropdownColor: Colors.white,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.accentEmerald),
                                          style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.account_balance_rounded, size: 18, color: GlassTheme.accentEmerald),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              borderSide: const BorderSide(color: GlassTheme.accentEmerald, width: 1.5),
                                            ),
                                          ),
                                          items: _accountOptions.map((acc) {
                                            return DropdownMenuItem<String>(
                                              value: acc,
                                              child: Text(acc, overflow: TextOverflow.ellipsis),
                                            );
                                          }).toList(),
                                          onChanged: (newAcc) {
                                            if (newAcc != null) {
                                              setDialogState(() {
                                                selectedAccount = newAcc;
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Active Yes / No Toggle Box
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Active Status * (Yes / No)",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(color: const Color(0xFFCBD5E1)),
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    isActive ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                                    size: 18,
                                                    color: isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    isActive ? "Yes (Active)" : "No (Inactive)",
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Switch(
                                                value: isActive,
                                                activeColor: GlassTheme.accentEmerald,
                                                onChanged: (val) {
                                                  setDialogState(() {
                                                    isActive = val;
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 4. Mobile & Email
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildFormField(
                                      label: "Mobile Number",
                                      controller: mobileController,
                                      icon: Icons.phone_rounded,
                                      hintText: "e.g. +91 9876543210",
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildFormField(
                                      label: "Email Address",
                                      controller: emailController,
                                      icon: Icons.email_rounded,
                                      hintText: "e.g. branch@jewellers.com",
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 5. Address
                              _buildFormField(
                                label: "Branch Address",
                                controller: addressController,
                                icon: Icons.location_on_rounded,
                                hintText: "Shop No, Street, Commercial Complex, Landmark...",
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Actions Footer
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
                              backgroundColor: GlassTheme.accentEmerald,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              elevation: 2,
                            ),
                            icon: isSaving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Icon(isEditing ? Icons.save_rounded : Icons.check_circle_rounded, size: 18),
                            label: Text(
                              isSaving
                                  ? "Saving..."
                                  : isEditing
                                      ? "Update Branch"
                                      : "Save Branch",
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;

                                    setDialogState(() => isSaving = true);
                                    final token = auth.authToken;
                                    if (token == null) return;

                                    final stateObj = selectedStateId != null
                                        ? LocationData.getStateById(selectedStateId!)
                                        : null;

                                    final finalBranchId = isEditing
                                        ? existingBranch.branchId
                                        : idController.text.trim().toUpperCase();

                                    final branchPayload = Branch(
                                      branchId: finalBranchId,
                                      branchName: nameController.text.trim(),
                                      companyId: selectedCompanyId?.trim().toUpperCase() ?? '',
                                      accountName: selectedAccount.trim(),
                                      state: stateObj?.name ?? '',
                                      stateId: selectedStateId ?? 0,
                                      country: 'India',
                                      countryId: 1,
                                      address: addressController.text.trim(),
                                      mobile: mobileController.text.trim(),
                                      email: emailController.text.trim(),
                                      isActive: isActive,
                                    );

                                    Map<String, dynamic> res;
                                    if (isEditing) {
                                      res = await _api.updateBranch(token, existingBranch.branchId, branchPayload);
                                    } else {
                                      res = await _api.createBranch(token, branchPayload);
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
                                                  ? "Branch updated successfully!"
                                                  : "Branch created successfully!",
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

  // Helper form field
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hintText,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool enabled = true,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          enabled: enabled,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: TextStyle(
            fontSize: 13,
            color: enabled ? GlassTheme.textPrimary : GlassTheme.textMuted,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 12, color: GlassTheme.textMuted, fontWeight: FontWeight.normal),
            prefixIcon: Icon(icon, size: 18, color: enabled ? GlassTheme.accentEmerald : GlassTheme.textMuted),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            filled: true,
            fillColor: enabled ? const Color(0xFFF8FAFC) : const Color(0xFFF1F5F9),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GlassTheme.accentEmerald, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: GlassTheme.accentRose),
            ),
          ),
        ),
      ],
    );
  }

  // ================= VIEW BRANCH DETAILS DIALOG =================
  void _showBranchDetailsDialog(BuildContext context, Branch branch) {
    final companyName = branch.companyName?.isNotEmpty == true
        ? branch.companyName!
        : _getCompanyName(branch.companyId);

    final stateItem = (branch.stateId != null && branch.stateId! > 0)
        ? LocationData.getStateById(branch.stateId!)
        : LocationData.getStateByNameOrCode(branch.state, branch.countryId);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            width: 540,
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
                      backgroundColor: GlassTheme.accentEmerald.withValues(alpha: 0.15),
                      child: Text(
                        branch.branchName.isNotEmpty ? branch.branchName[0].toUpperCase() : 'B',
                        style: const TextStyle(color: GlassTheme.accentEmerald, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            branch.branchName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: GlassTheme.accentEmerald.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: GlassTheme.accentEmerald.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  "Branch ID: ${branch.branchId}",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.accentEmerald),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: branch.isActive
                                      ? GlassTheme.accentEmerald.withValues(alpha: 0.12)
                                      : GlassTheme.accentRose.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  branch.isActive ? "Active: Yes" : "Active: No",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: branch.isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                                  ),
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

                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 12),

                // Details List
                _buildDetailTile("Branch ID", branch.branchId, Icons.tag_rounded),
                _buildDetailTile("Branch Name", branch.branchName, Icons.storefront_rounded),
                _buildDetailTile("Parent Company", "$companyName (${branch.companyId})", Icons.apartment_rounded),
                _buildDetailTile(
                  "State / Province",
                  "${stateItem?.name ?? branch.state}${stateItem?.gstCode.isNotEmpty == true ? ' [GST: ${stateItem!.gstCode}]' : ''} (ID: ${branch.stateId ?? '-'})",
                  Icons.map_rounded,
                ),
                _buildDetailTile("Account Name", branch.accountName.isNotEmpty ? branch.accountName : "Default Account", Icons.account_balance_rounded),
                _buildDetailTile("Mobile Number", branch.mobile.isNotEmpty ? branch.mobile : "Not Provided", Icons.phone_rounded),
                _buildDetailTile("Email Address", branch.email.isNotEmpty ? branch.email : "Not Provided", Icons.email_rounded),
                _buildDetailTile("Registered Address", branch.address.isNotEmpty ? branch.address : "Not Provided", Icons.location_on_rounded),
                _buildDetailTile("Active Status", branch.isActive ? "Yes (Active)" : "No (Inactive)", Icons.toggle_on_rounded),

                const SizedBox(height: 20),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: GlassTheme.accentEmerald),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary)),
          ),
        ],
      ),
    );
  }

  // ================= DELETE CONFIRMATION DIALOG =================
  void _showDeleteConfirmation(BuildContext context, AuthProvider auth, Branch branch) {
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
                  Text("Delete Branch", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Are you sure you want to delete \"${branch.branchName}\" (ID: ${branch.branchId})?",
                    style: const TextStyle(fontSize: 14, color: GlassTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This action is permanent and will remove the branch record from your database.",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textMuted),
                  ),
                ],
              ),
              actions: [
                OutlinedButton(
                  onPressed: isDeleting ? null : () => Navigator.pop(ctx),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.accentRose,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);
                          final token = auth.authToken;
                          if (token == null) return;

                          final res = await _api.deleteBranch(token, branch.branchId);
                          setDialogState(() => isDeleting = false);

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            _loadData();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Branch deleted successfully!"),
                                  backgroundColor: GlassTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? "Failed to delete branch."),
                                  backgroundColor: GlassTheme.accentRose,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                  child: isDeleting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text("Delete Permanently"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
