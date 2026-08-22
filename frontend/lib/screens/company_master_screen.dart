import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/location_data.dart';
import '../models/company_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class CompanyMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CompanyMasterScreen({super.key, this.onBack});

  @override
  State<CompanyMasterScreen> createState() => _CompanyMasterScreenState();
}

class _CompanyMasterScreenState extends State<CompanyMasterScreen> {
  final ApiService _api = ApiService();

  List<Company> _companies = [];
  List<Company> _filteredCompanies = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // Pre-configured standard branch options for multi-selection
  final List<String> _availableBranches = [
    'BR-01 Main Showroom',
    'BR-02 City Counter',
    'BR-03 Wholesale Depot',
    'BR-04 Bullion Vault',
    'BR-05 Karigar Workshop',
  ];

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanies() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    final list = await _api.getCompanies(token);

    if (mounted) {
      setState(() {
        _companies = list;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredCompanies = List.from(_companies);
    } else {
      _filteredCompanies = _companies.where((c) {
        return c.companyId.toLowerCase().contains(_searchQuery) ||
            c.companyName.toLowerCase().contains(_searchQuery) ||
            c.gstNo.toLowerCase().contains(_searchQuery) ||
            c.mobileNumber.toLowerCase().contains(_searchQuery) ||
            c.city.toLowerCase().contains(_searchQuery) ||
            c.state.toLowerCase().contains(_searchQuery) ||
            c.country.toLowerCase().contains(_searchQuery) ||
            c.accountName.toLowerCase().contains(_searchQuery) ||
            c.branchId.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  // ================= MAIN BUILD =================
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Breadcrumb & Actions Bar
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // Search & Filter Toolbar
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Main Content Area
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: GlassTheme.primaryNeon)),
          )
        else if (_filteredCompanies.isEmpty)
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
                  tooltip: "Back to Organization Menu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: GlassTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: GlassTheme.primaryNeon.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Company Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Master DB", color: GlassTheme.accentEmerald),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Manage corporate entities, GST, branches & banking details",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ),

          // Actions: New Company + Refresh + View Toggle
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
                onPressed: _loadCompanies,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.primaryNeon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 2,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("New Company", style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                onPressed: () => _showCompanyFormDialog(context, auth),
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
                hintText: "Search company by ID, name, GSTIN, mobile, city, state, country, branch...",
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
                  borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
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
              "${_filteredCompanies.length} of ${_companies.length} Records",
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
          itemCount: _filteredCompanies.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            mainAxisExtent: 325,
          ),
          itemBuilder: (context, index) {
            final company = _filteredCompanies[index];
            return _buildCompanyCard(context, auth, company);
          },
        );
      },
    );
  }

  // Single Company Card
  Widget _buildCompanyCard(BuildContext context, AuthProvider auth, Company company) {
    final branches = company.branchList;
    final countryItem = LocationData.getCountryById(company.countryId ?? 1) ??
        LocationData.getCountryByNameOrCode(company.country);
    final stateItem = (company.stateId != null && company.stateId! > 0)
        ? LocationData.getStateById(company.stateId!)
        : LocationData.getStateByNameOrCode(company.state, company.countryId);

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
          // Top Header: Logo Avatar + Name + ID + Flag
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: GlassTheme.primaryNeon.withValues(alpha: 0.12),
                  child: Text(
                    company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                    style: const TextStyle(
                      color: GlassTheme.primaryNeon,
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
                      Text(
                        company.companyName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: GlassTheme.primaryNeon.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              company.companyId,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.primaryNeon),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "${countryItem?.flag ?? '🌍'} ${stateItem?.name ?? company.state}${company.city.isNotEmpty ? ' • ${company.city}' : ''}",
                              style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w500),
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

          // Body Details (GST, Mobile, Account, Location Details)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GSTIN
                  if (company.gstNo.isNotEmpty)
                    _buildInfoRow(
                      Icons.receipt_long_rounded,
                      "GSTIN",
                      company.gstNo,
                      isCopyable: true,
                      color: GlassTheme.accentEmerald,
                    )
                  else
                    _buildInfoRow(Icons.receipt_long_rounded, "GSTIN", "Not Registered", color: GlassTheme.textMuted),
                  const SizedBox(height: 8),

                  // Mobile
                  if (company.mobileNumber.isNotEmpty)
                    _buildInfoRow(Icons.phone_rounded, "Mobile", company.mobileNumber, color: GlassTheme.accentCyan)
                  else
                    _buildInfoRow(Icons.phone_rounded, "Mobile", "Not Provided", color: GlassTheme.textMuted),
                  const SizedBox(height: 8),

                  // State with GST State Code & Country
                  _buildInfoRow(
                    Icons.public_rounded,
                    "Region",
                    "${stateItem != null ? '${stateItem.name} [ID: ${stateItem.id}]' : (company.state.isNotEmpty ? company.state : 'Not Selected')} • ${countryItem?.name ?? company.country}",
                    color: GlassTheme.secondaryNeon,
                  ),
                  const SizedBox(height: 8),

                  // Account / Bank
                  if (company.accountName.isNotEmpty)
                    _buildInfoRow(Icons.account_balance_rounded, "Account", company.accountName, color: GlassTheme.accentAmber)
                  else
                    _buildInfoRow(Icons.account_balance_rounded, "Account", "Default Account", color: GlassTheme.textMuted),
                  const SizedBox(height: 10),

                  // Branch Chips Multi-Selection View
                  const Text(
                    "Assigned Branches:",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: GlassTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  if (branches.isEmpty)
                    const Text("All Branches (Global)", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted, fontStyle: FontStyle.italic))
                  else
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: branches.take(3).map((branch) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: GlassTheme.primaryNeon.withValues(alpha: 0.25)),
                          ),
                          child: Text(
                            branch,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: GlassTheme.primaryNeon),
                          ),
                        );
                      }).toList()
                        ..addAll(
                          branches.length > 3
                              ? [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      "+${branches.length - 3} more",
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

          // Bottom Actions Footer (View, Edit, Delete)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // View Details Button
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: GlassTheme.primaryNeon,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  icon: const Icon(Icons.visibility_outlined, size: 15),
                  label: const Text("View", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  onPressed: () => _showCompanyDetailsDialog(context, company),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Edit
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18, color: GlassTheme.accentCyan),
                      tooltip: "Edit Company",
                      onPressed: () => _showCompanyFormDialog(context, auth, existingCompany: company),
                    ),
                    // Delete
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: GlassTheme.accentRose),
                      tooltip: "Delete Company",
                      onPressed: () => _showDeleteConfirmation(context, auth, company),
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

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isCopyable = false, required Color color}) {
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
              DataColumn(label: Text("Company ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Company Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("GSTIN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Mobile", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("State [ID]", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Country [ID]", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Account Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Branches", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
              DataColumn(label: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
            ],
            rows: _filteredCompanies.map((c) {
              final countryItem = LocationData.getCountryById(c.countryId ?? 1) ??
                  LocationData.getCountryByNameOrCode(c.country);
              final stateItem = (c.stateId != null && c.stateId! > 0)
                  ? LocationData.getStateById(c.stateId!)
                  : LocationData.getStateByNameOrCode(c.state, c.countryId);

              return DataRow(
                cells: [
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: GlassTheme.primaryNeon.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        c.companyId,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: GlassTheme.primaryNeon),
                      ),
                    ),
                  ),
                  DataCell(
                    Text(c.companyName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GlassTheme.primaryNeon)),
                  ),
                  DataCell(Text(c.gstNo.isNotEmpty ? c.gstNo : '-', style: const TextStyle(fontSize: 12))),
                  DataCell(Text(c.mobileNumber.isNotEmpty ? c.mobileNumber : '-', style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(
                      stateItem != null ? "${stateItem.name} [${stateItem.id}]" : (c.state.isNotEmpty ? c.state : '-'),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(
                    Text(
                      "${countryItem?.flag ?? '🌍'} ${countryItem?.name ?? c.country} [${c.countryId ?? 1}]",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  DataCell(Text(c.accountName.isNotEmpty ? c.accountName : '-', style: const TextStyle(fontSize: 12))),
                  DataCell(
                    Text(c.branchId.isNotEmpty ? c.branchId : 'All Branches', style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary)),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility_outlined, size: 16, color: GlassTheme.primaryNeon),
                          tooltip: "View Details",
                          onPressed: () => _showCompanyDetailsDialog(context, c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 16, color: GlassTheme.accentCyan),
                          tooltip: "Edit",
                          onPressed: () => _showCompanyFormDialog(context, auth, existingCompany: c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 16, color: GlassTheme.accentRose),
                          tooltip: "Delete",
                          onPressed: () => _showDeleteConfirmation(context, auth, c),
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
                color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.apartment_rounded, size: 48, color: GlassTheme.primaryNeon),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty ? "No matching companies found" : "No Companies Registered Yet",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try searching with a different term or clear the filter."
                  : "Add your first corporate entity with manual VARCHAR(5) Company ID.",
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
                  backgroundColor: GlassTheme.primaryNeon,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Create First Company", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showCompanyFormDialog(context, auth),
              ),
          ],
        ),
      ),
    );
  }

  // ================= INSERT / EDIT COMPANY FORM DIALOG =================
  void _showCompanyFormDialog(BuildContext context, AuthProvider auth, {Company? existingCompany}) {
    final isEditing = existingCompany != null;
    final formKey = GlobalKey<FormState>();

    final idController = TextEditingController(text: existingCompany?.companyId ?? '');
    final nameController = TextEditingController(text: existingCompany?.companyName ?? '');
    final gstController = TextEditingController(text: existingCompany?.gstNo ?? '');
    final mobileController = TextEditingController(text: existingCompany?.mobileNumber ?? '');
    final addressController = TextEditingController(text: existingCompany?.address ?? '');
    final cityController = TextEditingController(text: existingCompany?.city ?? '');
    final accountController = TextEditingController(text: existingCompany?.accountName ?? '');
    final customBranchController = TextEditingController();

    // Initial country ID: default to 1 (India) or existing
    int selectedCountryId = existingCompany?.countryId ?? 1;
    if (LocationData.getCountryById(selectedCountryId) == null) {
      final countryMatch = LocationData.getCountryByNameOrCode(existingCompany?.country ?? '');
      selectedCountryId = countryMatch?.id ?? 1;
    }

    // Initial state ID: find matching state
    int? selectedStateId;
    if (existingCompany?.stateId != null && existingCompany!.stateId! > 0) {
      selectedStateId = existingCompany.stateId;
    } else if (existingCompany?.state != null && existingCompany!.state.isNotEmpty) {
      final stateMatch = LocationData.getStateByNameOrCode(existingCompany.state, selectedCountryId);
      selectedStateId = stateMatch?.id;
    }

    // Default to Tamil Nadu (ID 33) if India and no state is chosen
    if (selectedStateId == null && selectedCountryId == 1) {
      selectedStateId = 33;
    }

    // Selected branches set
    final List<String> selectedBranches = List.from(existingCompany?.branchList ?? []);
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentStates = LocationData.getStatesForCountry(selectedCountryId);

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
                              gradient: GlassTheme.primaryGradient,
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
                                  isEditing ? "Edit Company Details" : "Create New Company",
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                                ),
                                Text(
                                  isEditing
                                      ? "Updating Company ID: ${existingCompany.companyId}"
                                      : "Manual VARCHAR(5) Company ID & standard Region Dropdowns",
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
                              // 1. Company ID (VARCHAR 5, Manual) & Company Name Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "Company ID * (VARCHAR 5)",
                                      controller: idController,
                                      icon: Icons.tag_rounded,
                                      hintText: "e.g. CMP01",
                                      maxLength: 5,
                                      enabled: !isEditing,
                                      textCapitalization: TextCapitalization.characters,
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return "ID is required";
                                        }
                                        if (val.trim().length > 5) {
                                          return "Max 5 chars";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 4,
                                    child: _buildFormField(
                                      label: "Company Name *",
                                      controller: nameController,
                                      icon: Icons.business_rounded,
                                      hintText: "e.g. ProGold Jewels & Bullion Pvt Ltd",
                                      validator: (val) {
                                        if (val == null || val.trim().isEmpty) {
                                          return "Company Name is required";
                                        }
                                        if (val.trim().length > 200) {
                                          return "Maximum 200 characters allowed";
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 2. GST Number & Mobile Number Row
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: _buildFormField(
                                      label: "GST Number (GSTIN)",
                                      controller: gstController,
                                      icon: Icons.receipt_long_rounded,
                                      hintText: "e.g. 33AAAAA0000A1Z5",
                                      textCapitalization: TextCapitalization.characters,
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: _buildFormField(
                                      label: "Mobile Number",
                                      controller: mobileController,
                                      icon: Icons.phone_rounded,
                                      hintText: "e.g. +91 9876543210",
                                      keyboardType: TextInputType.phone,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 3. Address & City
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: _buildFormField(
                                      label: "Registered Address",
                                      controller: addressController,
                                      icon: Icons.location_on_rounded,
                                      hintText: "Shop No, Street, Landmark...",
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    flex: 2,
                                    child: _buildFormField(
                                      label: "City",
                                      controller: cityController,
                                      icon: Icons.location_city_rounded,
                                      hintText: "e.g. Chennai / Mumbai",
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // 4. Country Dropdown & State Dropdown Row (Store IDs)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Country Dropdown
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          "Country * (Select Dropdown)",
                                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
                                        ),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<int>(
                                          value: selectedCountryId,
                                          dropdownColor: Colors.white,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.primaryNeon),
                                          style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.public_rounded, size: 18, color: GlassTheme.primaryNeon),
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
                                              borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
                                            ),
                                          ),
                                          items: LocationData.countries.map((c) {
                                            return DropdownMenuItem<int>(
                                              value: c.id,
                                              child: Text("${c.flag} ${c.name} (ID: ${c.id})"),
                                            );
                                          }).toList(),
                                          onChanged: (newCountryId) {
                                            if (newCountryId != null) {
                                              setDialogState(() {
                                                selectedCountryId = newCountryId;
                                                final newStates = LocationData.getStatesForCountry(selectedCountryId);
                                                if (newStates.isNotEmpty) {
                                                  selectedStateId = newStates.first.id;
                                                } else {
                                                  selectedStateId = null;
                                                }
                                              });
                                            }
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
                                          value: currentStates.any((s) => s.id == selectedStateId) ? selectedStateId : (currentStates.isNotEmpty ? currentStates.first.id : null),
                                          dropdownColor: Colors.white,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: GlassTheme.primaryNeon),
                                          style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w600),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            prefixIcon: const Icon(Icons.map_rounded, size: 18, color: GlassTheme.primaryNeon),
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
                                              borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
                                            ),
                                          ),
                                          items: currentStates.map((s) {
                                            return DropdownMenuItem<int>(
                                              value: s.id,
                                              child: Text(
                                                s.gstCode.isNotEmpty
                                                    ? "${s.name} [GST/ID: ${s.gstCode}]"
                                                    : "${s.name} [ID: ${s.id}]",
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

                              // 5. Account Name / Bank Account
                              _buildFormField(
                                label: "Account Name / Bank Details",
                                controller: accountController,
                                icon: Icons.account_balance_rounded,
                                hintText: "e.g. HDFC Current Acc - 50200012345678",
                              ),
                              const SizedBox(height: 20),

                              // 6. Branch ID with Multi-Selection
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.storefront_rounded, size: 16, color: GlassTheme.primaryNeon),
                                        SizedBox(width: 8),
                                        Text(
                                          "Assign Branches (Multi-Selection)",
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: GlassTheme.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      "Select multiple branches where this company entity operates:",
                                      style: TextStyle(fontSize: 11, color: GlassTheme.textSecondary),
                                    ),
                                    const SizedBox(height: 12),

                                    // Interactive Multi-Selection Chips
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _availableBranches.map((branch) {
                                        final isSelected = selectedBranches.contains(branch);
                                        return FilterChip(
                                          label: Text(branch),
                                          selected: isSelected,
                                          selectedColor: GlassTheme.primaryNeon.withValues(alpha: 0.15),
                                          checkmarkColor: GlassTheme.primaryNeon,
                                          labelStyle: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                            color: isSelected ? GlassTheme.primaryNeon : GlassTheme.textPrimary,
                                          ),
                                          backgroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(
                                              color: isSelected ? GlassTheme.primaryNeon : const Color(0xFFCBD5E1),
                                            ),
                                          ),
                                          onSelected: (selected) {
                                            setDialogState(() {
                                              if (selected) {
                                                selectedBranches.add(branch);
                                              } else {
                                                selectedBranches.remove(branch);
                                              }
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),

                                    const SizedBox(height: 12),

                                    // Add Custom Branch Input
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: customBranchController,
                                            style: const TextStyle(fontSize: 12),
                                            decoration: InputDecoration(
                                              hintText: "Add custom branch (e.g. BR-06 Airport Outlet)",
                                              hintStyle: const TextStyle(fontSize: 11, color: GlassTheme.textMuted),
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              filled: true,
                                              fillColor: Colors.white,
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                          ),
                                          icon: const Icon(Icons.add_rounded, size: 14),
                                          label: const Text("Add", style: TextStyle(fontSize: 12)),
                                          onPressed: () {
                                            final custom = customBranchController.text.trim();
                                            if (custom.isNotEmpty && !selectedBranches.contains(custom)) {
                                              setDialogState(() {
                                                if (!_availableBranches.contains(custom)) {
                                                  _availableBranches.add(custom);
                                                }
                                                selectedBranches.add(custom);
                                                customBranchController.clear();
                                              });
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
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
                              backgroundColor: GlassTheme.primaryNeon,
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
                                      ? "Update Company"
                                      : "Save Company",
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                            ),
                            onPressed: isSaving
                                ? null
                                : () async {
                                    if (!formKey.currentState!.validate()) return;

                                    setDialogState(() => isSaving = true);
                                    final token = auth.authToken;
                                    if (token == null) return;

                                    final countryObj = LocationData.getCountryById(selectedCountryId);
                                    final stateObj = selectedStateId != null
                                        ? LocationData.getStateById(selectedStateId!)
                                        : null;

                                    final finalCompanyId = isEditing
                                        ? existingCompany.companyId
                                        : idController.text.trim().toUpperCase();

                                    final companyPayload = Company(
                                      companyId: finalCompanyId,
                                      companyName: nameController.text.trim(),
                                      gstNo: gstController.text.trim(),
                                      mobileNumber: mobileController.text.trim(),
                                      address: addressController.text.trim(),
                                      city: cityController.text.trim(),
                                      state: stateObj?.name ?? '',
                                      stateId: selectedStateId ?? 0,
                                      country: countryObj?.name ?? 'India',
                                      countryId: selectedCountryId,
                                      accountName: accountController.text.trim(),
                                      branchId: selectedBranches.join(', '),
                                    );

                                    Map<String, dynamic> res;
                                    if (isEditing) {
                                      res = await _api.updateCompany(token, existingCompany.companyId, companyPayload);
                                    } else {
                                      res = await _api.createCompany(token, companyPayload);
                                    }

                                    setDialogState(() => isSaving = false);

                                    if (res['success'] == true) {
                                      Navigator.pop(dialogCtx);
                                      _loadCompanies();
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isEditing
                                                  ? "Company updated successfully!"
                                                  : "Company created successfully!",
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GlassTheme.textPrimary),
        ),
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
            prefixIcon: Icon(icon, size: 18, color: enabled ? GlassTheme.primaryNeon : GlassTheme.textMuted),
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
              borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
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

  // ================= VIEW COMPANY DETAILS DIALOG =================
  void _showCompanyDetailsDialog(BuildContext context, Company company) {
    final countryItem = LocationData.getCountryById(company.countryId ?? 1) ??
        LocationData.getCountryByNameOrCode(company.country);
    final stateItem = (company.stateId != null && company.stateId! > 0)
        ? LocationData.getStateById(company.stateId!)
        : LocationData.getStateByNameOrCode(company.state, company.countryId);

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
                      backgroundColor: GlassTheme.primaryNeon.withValues(alpha: 0.15),
                      child: Text(
                        company.companyName.isNotEmpty ? company.companyName[0].toUpperCase() : 'C',
                        style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.bold, fontSize: 20),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            company.companyName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: GlassTheme.primaryNeon.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: GlassTheme.primaryNeon.withValues(alpha: 0.3)),
                                ),
                                child: Text(
                                  "ID: ${company.companyId}",
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.primaryNeon),
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
                _buildDetailTile("Company ID", company.companyId, Icons.tag_rounded),
                _buildDetailTile("GST Number", company.gstNo.isNotEmpty ? company.gstNo : "Not Registered", Icons.receipt_long_rounded),
                _buildDetailTile("Mobile Number", company.mobileNumber.isNotEmpty ? company.mobileNumber : "Not Provided", Icons.phone_rounded),
                _buildDetailTile("Registered Address", company.address.isNotEmpty ? company.address : "Not Provided", Icons.home_rounded),
                _buildDetailTile(
                  "Country",
                  "${countryItem?.flag ?? '🌍'} ${countryItem?.name ?? company.country} (ID: ${company.countryId ?? 1})",
                  Icons.public_rounded,
                ),
                _buildDetailTile(
                  "State / Province",
                  "${stateItem?.name ?? company.state}${stateItem?.gstCode.isNotEmpty == true ? ' [GST: ${stateItem!.gstCode}]' : ''} (ID: ${company.stateId ?? '-'})",
                  Icons.map_rounded,
                ),
                _buildDetailTile("City", company.city.isNotEmpty ? company.city : "-", Icons.location_city_rounded),
                _buildDetailTile("Account Name / Bank", company.accountName.isNotEmpty ? company.accountName : "Default", Icons.account_balance_rounded),

                const SizedBox(height: 12),
                const Text("Assigned Branches:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GlassTheme.textSecondary)),
                const SizedBox(height: 6),
                if (company.branchList.isEmpty)
                  const Text("All Branches (Global access)", style: TextStyle(fontSize: 12, color: GlassTheme.textMuted))
                else
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: company.branchList.map((b) {
                      return Chip(
                        label: Text(b, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GlassTheme.primaryNeon)),
                        backgroundColor: GlassTheme.primaryNeon.withValues(alpha: 0.08),
                        side: BorderSide(color: GlassTheme.primaryNeon.withValues(alpha: 0.3)),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                      );
                    }).toList(),
                  ),

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
          Icon(icon, size: 16, color: GlassTheme.primaryNeon),
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
  void _showDeleteConfirmation(BuildContext context, AuthProvider auth, Company company) {
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
                  Text("Delete Company", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Are you sure you want to delete \"${company.companyName}\" (ID: ${company.companyId})?",
                    style: const TextStyle(fontSize: 14, color: GlassTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "This action is permanent and will remove the record from your database.",
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

                          final res = await _api.deleteCompany(token, company.companyId);
                          setDialogState(() => isDeleting = false);

                          if (res['success'] == true) {
                            Navigator.pop(ctx);
                            _loadCompanies();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Company deleted successfully!"),
                                  backgroundColor: GlassTheme.accentEmerald,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message'] ?? "Failed to delete company."),
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
