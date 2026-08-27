import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/tax_model.dart';
import '../models/account_head_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class TaxMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const TaxMasterScreen({super.key, this.onBack});

  @override
  State<TaxMasterScreen> createState() => _TaxMasterScreenState();
}

class _TaxMasterScreenState extends State<TaxMasterScreen> {
  final ApiService _api = ApiService();

  List<TaxRecord> _taxRecords = [];
  List<TaxRecord> _filteredTaxRecords = [];
  List<AccountHead> _accountHeads = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

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

    // Load tax records and account heads concurrently
    final results = await Future.wait([
      _api.getTaxRecords(token),
      _api.getAccountHeads(token),
    ]);

    if (mounted) {
      setState(() {
        _taxRecords = results[0] as List<TaxRecord>;
        _accountHeads = results[1] as List<AccountHead>;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredTaxRecords = List.from(_taxRecords);
    } else {
      _filteredTaxRecords = _taxRecords.where((t) {
        return t.taxcode.toLowerCase().contains(_searchQuery) ||
            t.taxname.toLowerCase().contains(_searchQuery) ||
            t.sgstacname.toLowerCase().contains(_searchQuery) ||
            t.cgstacname.toLowerCase().contains(_searchQuery) ||
            t.igstacname.toLowerCase().contains(_searchQuery);
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
        else if (_filteredTaxRecords.isEmpty)
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
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.percent_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Tax Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Rates & Accounts", color: GlassTheme.accentEmerald),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Configure SGST, CGST & IGST tax configurations and ledger mappings",
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
                tooltip: "Reload Taxes",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Tax Config", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                hintText: "Search tax configs by name, code, posting accounts...",
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
              child: const Icon(Icons.percent_rounded, size: 50, color: GlassTheme.textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching tax rates found" : "No Tax Configs created yet",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search filters or clear keywords."
                  : "Get started by adding your first tax configuration rate (e.g. GST, VAT).",
              style: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Create Tax Config", style: TextStyle(fontWeight: FontWeight.bold)),
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
    final double cardWidth = isMobile ? 320 : 360;
    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: _filteredTaxRecords.map((tax) {
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
                                tax.taxname,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: tax.taxcode, color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0x12FFFFFF)),
                    const SizedBox(height: 10),

                    // Tax Rates & Mappings
                    _buildTaxParamRow("SGST", tax.sgstPer, tax.sgstacname),
                    const SizedBox(height: 8),
                    _buildTaxParamRow("CGST", tax.cgstPer, tax.cgstacname),
                    const SizedBox(height: 8),
                    _buildTaxParamRow("IGST", tax.igstPer, tax.igstacname),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                          tooltip: "Edit Tax Config",
                          onPressed: () => _showAddEditDialog(tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete Tax Config",
                          onPressed: () => _confirmDelete(tax),
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

  Widget _buildTaxParamRow(String label, double percentage, String account) {
    return Row(
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0x0EFFFFFF),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "${percentage.toStringAsFixed(2)}%",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            account.isNotEmpty ? "Posting A/C: $account" : "No account mapped",
            style: TextStyle(
              fontSize: 12,
              color: account.isNotEmpty ? GlassTheme.accentCyan : GlassTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ================= TABLE VIEW =================
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
              DataColumn(label: Text("TAX NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("SGST %", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("SGST ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("CGST %", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("CGST ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("IGST %", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("IGST ACCOUNT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredTaxRecords.map((tax) {
              return DataRow(
                cells: [
                  DataCell(Text(tax.taxcode, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
                  DataCell(Text(tax.taxname, style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${tax.sgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(Text(tax.sgstacname.isEmpty ? "-" : tax.sgstacname, style: const TextStyle(color: GlassTheme.accentCyan))),
                  DataCell(Text("${tax.cgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(Text(tax.cgstacname.isEmpty ? "-" : tax.cgstacname, style: const TextStyle(color: GlassTheme.accentCyan))),
                  DataCell(Text("${tax.igstPer.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(Text(tax.igstacname.isEmpty ? "-" : tax.igstacname, style: const TextStyle(color: GlassTheme.accentCyan))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                          onPressed: () => _showAddEditDialog(tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 16),
                          onPressed: () => _confirmDelete(tax),
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
  void _showAddEditDialog([TaxRecord? existing]) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    final formKey = GlobalKey<FormState>();

    // Input controllers
    final codeController = TextEditingController(text: existing?.taxcode ?? '');
    final nameController = TextEditingController(text: existing?.taxname ?? '');
    final sgstPerController = TextEditingController(text: existing != null ? existing.sgstPer.toString() : '0.0');
    final cgstPerController = TextEditingController(text: existing != null ? existing.cgstPer.toString() : '0.0');
    final igstPerController = TextEditingController(text: existing != null ? existing.igstPer.toString() : '0.0');

    // Mapped Posting Accounts (dropdown values)
    String? selectedSgstAc = existing != null && existing.sgstacname.isNotEmpty ? existing.sgstacname : null;
    String? selectedCgstAc = existing != null && existing.cgstacname.isNotEmpty ? existing.cgstacname : null;
    String? selectedIgstAc = existing != null && existing.igstacname.isNotEmpty ? existing.igstacname : null;

    bool isSaving = false;

    // Filtered list of account names
    final List<String> accountNames = _accountHeads.map((h) => h.accountname).toList();

    // Verify existing mapping falls in actual database account names
    if (selectedSgstAc != null && !accountNames.contains(selectedSgstAc)) selectedSgstAc = null;
    if (selectedCgstAc != null && !accountNames.contains(selectedCgstAc)) selectedCgstAc = null;
    if (selectedIgstAc != null && !accountNames.contains(selectedIgstAc)) selectedIgstAc = null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: GlassTheme.bgSurface,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x1EFFFFFF)),
              ),
              title: Row(
                children: [
                  Icon(
                    existing == null ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    existing == null ? "Add Tax Config" : "Edit Tax Config",
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
                width: 520,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Tax Code & Tax Name
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tax Code (max 3 chars) *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: codeController,
                                    enabled: existing == null, // Unique code key cannot be altered after creation
                                    style: TextStyle(
                                      color: existing == null ? Colors.white : GlassTheme.textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    decoration: _inputDecoration("e.g. GST"),
                                    maxLength: 3,
                                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                                    inputFormatters: [
                                      LengthLimitingTextInputFormatter(3),
                                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                                    ],
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return "Code is required";
                                      if (val.trim().length > 3) return "Max 3 chars";
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Tax Name *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 6),
                                  TextFormField(
                                    controller: nameController,
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                    decoration: _inputDecoration("e.g. GST 18 Percent"),
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) return "Name is required";
                                      return null;
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Divider(color: Color(0x12FFFFFF)),
                        const SizedBox(height: 12),

                        // SGST Configurations
                        _buildTaxInputBlock(
                          percentageTitle: "SGST Rate (%)",
                          percentageController: sgstPerController,
                          accountTitle: "SGST Posting Ledger Account",
                          accountValue: selectedSgstAc,
                          accountList: accountNames,
                          onAccountChanged: (val) => setDialogState(() => selectedSgstAc = val),
                        ),
                        const SizedBox(height: 16),

                        // CGST Configurations
                        _buildTaxInputBlock(
                          percentageTitle: "CGST Rate (%)",
                          percentageController: cgstPerController,
                          accountTitle: "CGST Posting Ledger Account",
                          accountValue: selectedCgstAc,
                          accountList: accountNames,
                          onAccountChanged: (val) => setDialogState(() => selectedCgstAc = val),
                        ),
                        const SizedBox(height: 16),

                        // IGST Configurations
                        _buildTaxInputBlock(
                          percentageTitle: "IGST Rate (%)",
                          percentageController: igstPerController,
                          accountTitle: "IGST Posting Ledger Account",
                          accountValue: selectedIgstAc,
                          accountList: accountNames,
                          onAccountChanged: (val) => setDialogState(() => selectedIgstAc = val),
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
                    backgroundColor: const Color(0xFF10B981),
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

                          final record = TaxRecord(
                            taxid: existing?.taxid,
                            taxcode: codeController.text.trim().toUpperCase(),
                            taxname: nameController.text.trim(),
                            sgstPer: double.tryParse(sgstPerController.text.trim()) ?? 0.0,
                            sgstacname: selectedSgstAc ?? '',
                            cgstPer: double.tryParse(cgstPerController.text.trim()) ?? 0.0,
                            cgstacname: selectedCgstAc ?? '',
                            igstPer: double.tryParse(igstPerController.text.trim()) ?? 0.0,
                            igstacname: selectedIgstAc ?? '',
                          );

                          bool success = false;
                          String message = '';

                          if (existing == null) {
                            final res = await _api.createTaxRecord(token, record);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to create tax configuration';
                          } else {
                            final res = await _api.updateTaxRecord(token, existing.taxid!, record);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to update tax configuration';
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
                              _loadData();
                            }
                          }
                        },
                  child: isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(existing == null ? "Save Tax Master" : "Update Tax Master"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTaxInputBlock({
    required String percentageTitle,
    required TextEditingController percentageController,
    required String accountTitle,
    required String? accountValue,
    required List<String> accountList,
    required ValueChanged<String?> onAccountChanged,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Percentage Rate
        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(percentageTitle, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              TextFormField(
                controller: percentageController,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration("Rate %"),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Required";
                  if (double.tryParse(val.trim()) == null) return "Invalid rate";
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Mapped Posting Account
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(accountTitle, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: accountValue,
                    dropdownColor: GlassTheme.bgSurface,
                    hint: const Text("Select Ledger Account", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("None (No mapping)", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                      ...accountList.map((name) {
                        return DropdownMenuItem<String>(
                          value: name,
                          child: Text(name, style: const TextStyle(fontSize: 12, color: Colors.black)),
                        );
                      }),
                    ],
                    selectedItemBuilder: (context) {
                      return [
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text("None", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                        ),
                        ...accountList.map((name) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(name, style: const TextStyle(fontSize: 12, color: Colors.black)),
                          );
                        }),
                      ];
                    },
                    onChanged: onAccountChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      errorStyle: const TextStyle(fontSize: 10),
    );
  }

  // ================= CONFIRM DELETE =================
  void _confirmDelete(TaxRecord tax) {
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
            "Are you sure you want to permanently delete the Tax Configuration \"${tax.taxname} (${tax.taxcode})\"? This action cannot be undone.",
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

                final res = await _api.deleteTaxRecord(token, tax.taxid!);
                final success = res['success'] == true;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Failed to delete record'),
                      backgroundColor: success ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                    ),
                  );
                  _loadData();
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
