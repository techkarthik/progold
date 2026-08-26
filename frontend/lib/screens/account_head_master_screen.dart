import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/location_data.dart';
import '../models/account_head_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class AccountHeadMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const AccountHeadMasterScreen({super.key, this.onBack});

  @override
  State<AccountHeadMasterScreen> createState() => _AccountHeadMasterScreenState();
}

class _AccountHeadMasterScreenState extends State<AccountHeadMasterScreen> {
  final ApiService _api = ApiService();

  List<AccountHead> _accountHeads = [];
  List<AccountHead> _filteredAccountHeads = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // Predefined group names
  final List<String> _groupOptions = [
    'Bank Name',
    'Sundry Debtors',
    'Sundry Creditors',
    'Duties & Taxes',
    'Capital Account',
    'Loans & Liabilities',
    'Current Assets',
    'Sales Account',
    'Purchase Account',
    'Direct Expenses',
    'Indirect Expenses',
  ];

  @override
  void initState() {
    super.initState();
    _loadAccountHeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountHeads() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);
    final heads = await _api.getAccountHeads(token);

    if (mounted) {
      setState(() {
        _accountHeads = heads;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredAccountHeads = List.from(_accountHeads);
    } else {
      _filteredAccountHeads = _accountHeads.where((h) {
        return h.accode.toLowerCase().contains(_searchQuery) ||
            h.accountname.toLowerCase().contains(_searchQuery) ||
            h.groupname.toLowerCase().contains(_searchQuery) ||
            h.state.toLowerCase().contains(_searchQuery) ||
            h.country.toLowerCase().contains(_searchQuery) ||
            h.pincode.toLowerCase().contains(_searchQuery) ||
            h.gstno.toLowerCase().contains(_searchQuery) ||
            h.panno.toLowerCase().contains(_searchQuery);
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
        // Header
        _buildHeaderBar(context, auth, isMobile),
        const SizedBox(height: 16),

        // Search & View toggles
        _buildSearchToolbar(isMobile),
        const SizedBox(height: 16),

        // Body
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: GlassTheme.primaryNeon)),
          )
        else if (_filteredAccountHeads.isEmpty)
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
                  tooltip: "Back to Master Hub",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF43F5E).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Account Head Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Ledgers", color: GlassTheme.accentRose),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Configure accounts, financial groupings, GSTIN & location parameters",
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
                          color: !_isTableView ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                          size: 18,
                        ),
                        tooltip: "Card Grid View",
                        onPressed: () => setState(() => _isTableView = false),
                      ),
                      const SizedBox(
                        height: 20,
                        child: VerticalDivider(width: 1, color: Color(0xFFCBD5E1)),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.table_rows_rounded,
                          color: _isTableView ? GlassTheme.primaryNeon : GlassTheme.textMuted,
                          size: 18,
                        ),
                        tooltip: "Compact Table View",
                        onPressed: () => setState(() => _isTableView = true),
                      ),
                    ],
                  ),
                ),
              if (!isMobile) const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.textSecondary),
                tooltip: "Reload Accounts",
                onPressed: _loadAccountHeads,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Account Head", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showAddEditDialog(),
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
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _applyFilter(val)),
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: GlassTheme.textMuted, size: 20),
                hintText: "Search accounts by name, code, group, state, GSTIN, PAN...",
                hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: GlassTheme.textMuted, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _applyFilter(''));
                        },
                      )
                    : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState(BuildContext context, AuthProvider auth) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0x0EFFFFFF),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0x18FFFFFF)),
              ),
              child: const Icon(Icons.account_balance_wallet_outlined, size: 50, color: GlassTheme.textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching accounts found" : "No Account Heads configured yet",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search filters or clear keywords."
                  : "Get started by adding your first financial ledger/account head.",
              style: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Create Account Head", style: TextStyle(fontWeight: FontWeight.bold)),
                onPressed: () => _showAddEditDialog(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ================= CARD GRID VIEW =================
  Widget _buildCardsGridView(BuildContext context, AuthProvider auth, bool isMobile) {
    final double cardWidth = isMobile ? 320 : 340;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _filteredAccountHeads.map((head) {
            final activeColor = head.active == 1 ? GlassTheme.accentEmerald : GlassTheme.accentRose;
            return SizedBox(
              width: isMobile ? constraints.maxWidth : cardWidth,
              child: GlassContainer(
                borderRadius: 16,
                padding: const EdgeInsets.all(18),
                borderColor: const Color(0x18FFFFFF),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                head.accountname,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.extrabold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                head.groupname,
                                style: const TextStyle(fontSize: 11, color: GlassTheme.accentCyan, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: head.accode, color: const Color(0xFFF43F5E)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0x12FFFFFF)),
                    const SizedBox(height: 10),

                    // Details
                    _buildDetailRow(Icons.location_on_outlined, "${head.state}, ${head.country}"),
                    if (head.pincode.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(Icons.pin_drop_outlined, "Pincode: ${head.pincode}"),
                    ],
                    if (head.gstno.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(Icons.receipt_long_rounded, "GSTIN: ${head.gstno}"),
                    ],
                    if (head.panno.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildDetailRow(Icons.credit_card_rounded, "PAN: ${head.panno}"),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StatusBadge(
                          label: head.active == 1 ? "ACTIVE" : "INACTIVE",
                          color: activeColor,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                              tooltip: "Edit Account",
                              onPressed: () => _showAddEditDialog(head),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                              tooltip: "Delete Account",
                              onPressed: () => _confirmDelete(head),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: GlassTheme.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.white80, fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ================= TABLE VIEW (Desktop) =================
  Widget _buildTableView(BuildContext context, AuthProvider auth) {
    return GlassContainer(
      borderRadius: 16,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0x12FFFFFF)),
            dataRowColor: WidgetStateProperty.all(const Color(0x06FFFFFF)),
            columns: const [
              DataColumn(label: Text("CODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("ACCOUNT NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("GROUP NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("STATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("COUNTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("GSTIN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("PAN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("STATUS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredAccountHeads.map((head) {
              return DataRow(
                cells: [
                  DataCell(Text(head.accode, style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.bold))),
                  DataCell(Text(head.accountname, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(head.groupname, style: const TextStyle(color: GlassTheme.accentCyan))),
                  DataCell(Text(head.state, style: const TextStyle(color: Colors.white80))),
                  DataCell(Text(head.country, style: const TextStyle(color: Colors.white80))),
                  DataCell(Text(head.gstno.isEmpty ? "-" : head.gstno, style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(head.panno.isEmpty ? "-" : head.panno, style: const TextStyle(color: Colors.white70))),
                  DataCell(
                    StatusBadge(
                      label: head.active == 1 ? "ACTIVE" : "INACTIVE",
                      color: head.active == 1 ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                          onPressed: () => _showAddEditDialog(head),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 16),
                          onPressed: () => _confirmDelete(head),
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

  // ================= ADD / EDIT DIALOG =================
  void _showAddEditDialog([AccountHead? existing]) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    final formKey = GlobalKey<FormState>();

    // Input controllers
    final accountNameController = TextEditingController(text: existing?.accountname ?? '');
    final pincodeController = TextEditingController(text: existing?.pincode ?? '');
    final gstController = TextEditingController(text: existing?.gstno ?? '');
    final panController = TextEditingController(text: existing?.panno ?? '');

    String? selectedGroup = existing != null && _groupOptions.contains(existing.groupname)
        ? existing.groupname
        : _groupOptions.first;

    CountryItem? selectedCountry = LocationData.getCountryByNameOrCode(existing?.country ?? 'India') ??
        LocationData.countries.first;

    // Load states for selected country
    List<StateItem> filteredStates = LocationData.getStatesForCountry(selectedCountry.id);

    StateItem? selectedState = (existing != null && filteredStates.any((s) => s.name == existing.state))
        ? filteredStates.firstWhere((s) => s.name == existing.state)
        : (filteredStates.isNotEmpty ? filteredStates.first : null);

    // If state is not in helper list (for custom states / text input fallback)
    final customStateController = TextEditingController(
      text: (selectedState == null && existing != null) ? existing.state : '',
    );

    bool isActive = existing != null ? existing.active == 1 : true;
    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: GlassTheme.bgSurface,
              surfaceTintColor: Colors.transparent,
              shadowColor: Colors.black54,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x1EFFFFFF)),
              ),
              title: Row(
                children: [
                  Icon(
                    existing == null ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                    color: const Color(0xFFF43F5E),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    existing == null ? "Add Account Head" : "Edit Account Head",
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: GlassTheme.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (existing != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0x0EFFFFFF),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0x18FFFFFF)),
                            ),
                            child: Row(
                              children: [
                                const Text("Account Code: ", style: TextStyle(color: GlassTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                                Text(existing.accode, style: const TextStyle(color: Color(0xFFF43F5E), fontSize: 13, fontWeight: FontWeight.extrabold)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Account Name
                        const Text("Account Name *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: accountNameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration("Enter primary account / client name"),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Account name is required";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Group Name (Dropdown)
                        const Text("Account Group *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedGroup,
                              dropdownColor: GlassTheme.bgSurface,
                              isExpanded: true,
                              items: _groupOptions.map((g) {
                                return DropdownMenuItem<String>(
                                  value: g,
                                  child: Text(g, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                );
                              }).toList(),
                              selectedItemBuilder: (context) {
                                return _groupOptions.map((g) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(g, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                  );
                                }).toList();
                              },
                              onChanged: (val) {
                                setDialogState(() => selectedGroup = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Country (Dropdown)
                        const Text("Country *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<CountryItem>(
                              value: selectedCountry,
                              dropdownColor: GlassTheme.bgSurface,
                              isExpanded: true,
                              items: LocationData.countries.map((c) {
                                return DropdownMenuItem<CountryItem>(
                                  value: c,
                                  child: Text("${c.flag}  ${c.name}", style: const TextStyle(fontSize: 13, color: Colors.black)),
                                );
                              }).toList(),
                              selectedItemBuilder: (context) {
                                return LocationData.countries.map((c) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text("${c.flag}  ${c.name}", style: const TextStyle(fontSize: 13, color: Colors.black)),
                                  );
                                }).toList();
                              },
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedCountry = val;
                                    filteredStates = LocationData.getStatesForCountry(val.id);
                                    selectedState = filteredStates.isNotEmpty ? filteredStates.first : null;
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // State (Dropdown or text field)
                        const Text("State / Emirates", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        if (filteredStates.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<StateItem>(
                                value: selectedState,
                                dropdownColor: GlassTheme.bgSurface,
                                isExpanded: true,
                                items: filteredStates.map((s) {
                                  return DropdownMenuItem<StateItem>(
                                    value: s,
                                    child: Text(s.name, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                  );
                                }).toList(),
                                selectedItemBuilder: (context) {
                                  return filteredStates.map((s) {
                                    return Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(s.name, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                    );
                                  }).toList();
                                },
                                onChanged: (val) {
                                  setDialogState(() => selectedState = val);
                                },
                              ),
                            ),
                          ),
                        ] else ...[
                          TextFormField(
                            controller: customStateController,
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            decoration: _inputDecoration("Enter state / province"),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Pincode
                        const Text("Pincode", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: pincodeController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration("Postal / ZIP code"),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        ),
                        const SizedBox(height: 16),

                        // Tax & Pan info
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("GSTIN No.", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: gstController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: _inputDecoration("15-digit GSTIN"),
                                    maxLength: 15,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("PAN Card No.", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: panController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: _inputDecoration("10-digit PAN"),
                                    maxLength: 10,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Active status
                        Row(
                          children: [
                            const Text("Active Status", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                            const Spacer(),
                            Switch(
                              value: isActive,
                              activeColor: GlassTheme.accentEmerald,
                              onChanged: (val) {
                                setDialogState(() => isActive = val);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Color(0x33FFFFFF)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF43F5E),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[700],
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;

                          setDialogState(() => isSaving = true);

                          final finalState = filteredStates.isNotEmpty
                              ? (selectedState?.name ?? '')
                              : customStateController.text.trim();

                          final record = AccountHead(
                            id: existing?.id,
                            accode: existing?.accode ?? '', // Backend autogenerates this for NEW
                            groupname: selectedGroup ?? '',
                            accountname: accountNameController.text.trim(),
                            state: finalState,
                            country: selectedCountry.name,
                            pincode: pincodeController.text.trim(),
                            active: isActive ? 1 : 0,
                            gstno: gstController.text.trim().toUpperCase(),
                            panno: panController.text.trim().toUpperCase(),
                          );

                          bool success = false;
                          String message = '';

                          if (existing == null) {
                            final res = await _api.createAccountHead(token, record);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to create account head';
                          } else {
                            final res = await _api.updateAccountHead(token, existing.id!, record);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to update account head';
                          }

                          if (mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(message),
                                backgroundColor: success ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                              ),
                            );
                            if (success) {
                              _loadAccountHeads();
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existing == null ? "Save Account" : "Update Account"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.primaryNeon, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }

  // ================= CONFIRM DELETE =================
  void _confirmDelete(AccountHead head) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: GlassTheme.bgSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0x1EFFFFFF)),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose),
              const SizedBox(width: 8),
              const Text("Confirm Delete", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(
            "Are you sure you want to permanently delete the Account Head \"${head.accountname}\"? This action cannot be undone.",
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white70,
                side: const BorderSide(color: Color(0x33FFFFFF)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: GlassTheme.accentRose,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                setState(() => _isLoading = true);

                final res = await _api.deleteAccountHead(token, head.id!);
                final success = res['success'] == true;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Failed to delete record'),
                      backgroundColor: success ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                    ),
                  );
                  _loadAccountHeads();
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
