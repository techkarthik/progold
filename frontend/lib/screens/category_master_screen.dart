import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../models/account_head_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class CategoryMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const CategoryMasterScreen({super.key, this.onBack});

  @override
  State<CategoryMasterScreen> createState() => _CategoryMasterScreenState();
}

class _CategoryMasterScreenState extends State<CategoryMasterScreen> {
  final ApiService _api = ApiService();

  List<CategoryRecord> _categories = [];
  List<CategoryRecord> _filteredCategories = [];
  List<Metal> _metals = [];
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

    final results = await Future.wait([
      _api.getCategories(token),
      _api.getMetals(token),
      _api.getAccountHeads(token),
    ]);

    if (mounted) {
      setState(() {
        _categories = results[0] as List<CategoryRecord>;
        _metals = results[1] as List<Metal>;
        _accountHeads = results[2] as List<AccountHead>;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredCategories = List.from(_categories);
    } else {
      _filteredCategories = _categories.where((c) {
        return c.catcode.toLowerCase().contains(_searchQuery) ||
            c.catname.toLowerCase().contains(_searchQuery) ||
            c.categorytype.toLowerCase().contains(_searchQuery) ||
            (c.metalname ?? '').toLowerCase().contains(_searchQuery) ||
            c.sgstacname.toLowerCase().contains(_searchQuery) ||
            c.cgstacname.toLowerCase().contains(_searchQuery) ||
            c.igstacname.toLowerCase().contains(_searchQuery);
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
        else if (_filteredCategories.isEmpty)
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
                  tooltip: "Back to Inventory Submenu",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.shopping_bag_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Category Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Classifications", color: GlassTheme.accentRose),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Define product categories (Ornaments, Bulloins), tax percentages, and mapping accounts",
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
                tooltip: "Reload Categories",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Add Category", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                hintText: "Search categories by code, name, metal, mapping accounts...",
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
              child: const Icon(Icons.shopping_bag_outlined, size: 50, color: GlassTheme.textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching categories found" : "No Category classifications configured yet",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search filters or clear keywords."
                  : "Get started by adding your first ornament/metal category (e.g. Gold Ornaments GST).",
              style: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isEmpty) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text("Create Category", style: TextStyle(fontWeight: FontWeight.bold)),
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
          children: _filteredCategories.map((c) {
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
                                c.catname,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.extrabold, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "${c.metalname ?? c.metalid} — ${c.categorytype}",
                                style: const TextStyle(fontSize: 11, color: GlassTheme.accentCyan, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: c.catcode, color: const Color(0xFF3B82F6)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0x12FFFFFF)),
                    const SizedBox(height: 10),

                    // Tax Specs
                    _buildTaxSpecRow("SGST", c.sgstPer, c.sgstacname),
                    const SizedBox(height: 6),
                    _buildTaxSpecRow("CGST", c.cgstPer, c.cgstacname),
                    const SizedBox(height: 6),
                    _buildTaxSpecRow("IGST", c.igstPer, c.igstacname),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                          tooltip: "Edit Category",
                          onPressed: () => _showAddEditDialog(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete Category",
                          onPressed: () => _confirmDelete(c),
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

  Widget _buildTaxSpecRow(String label, double rate, String account) {
    return Row(
      children: [
        Container(
          width: 50,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0x0EFFFFFF),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "${rate.toStringAsFixed(2)}%",
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            account.isNotEmpty ? "Posting: $account" : "No account linked",
            style: TextStyle(
              fontSize: 11,
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
              DataColumn(label: Text("CATCODE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("CATEGORY NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("METAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("TYPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("SGST %", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("CGST %", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("IGST %", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredCategories.map((c) {
              return DataRow(
                cells: [
                  DataCell(Text(c.catcode, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold))),
                  DataCell(Text(c.catname, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(c.metalname ?? c.metalid, style: const TextStyle(color: Colors.white70))),
                  DataCell(Text(c.categorytype, style: const TextStyle(color: GlassTheme.accentCyan))),
                  DataCell(Text("${c.sgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${c.cgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(Text("${c.igstPer.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                          onPressed: () => _showAddEditDialog(c),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 16),
                          onPressed: () => _confirmDelete(c),
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
  void _showAddEditDialog([CategoryRecord? existing]) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    if (_metals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No metals configured. Please create at least one metal first under Metal Master."),
          backgroundColor: GlassTheme.accentRose,
        ),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();

    // Input controllers
    final nameController = TextEditingController(text: existing?.catname ?? '');
    final sgstPerController = TextEditingController(text: existing != null ? existing.sgstPer.toString() : '1.5');
    final cgstPerController = TextEditingController(text: existing != null ? existing.cgstPer.toString() : '1.5');
    final igstPerController = TextEditingController(text: existing != null ? existing.igstPer.toString() : '3.0');

    String? selectedMetalId = existing != null && _metals.any((m) => m.metalid == existing.metalid)
        ? existing.metalid
        : _metals.first.metalid;

    // Segmented / option selection category type
    String selectedType = existing?.categorytype ?? 'ORNAMENTS/STONE'; // 'METAL' or 'ORNAMENTS/STONE'

    // Posting ledgers
    String? selectedSgstAc = existing != null && existing.sgstacname.isNotEmpty ? existing.sgstacname : null;
    String? selectedCgstAc = existing != null && existing.cgstacname.isNotEmpty ? existing.cgstacname : null;
    String? selectedIgstAc = existing != null && existing.igstacname.isNotEmpty ? existing.igstacname : null;

    final List<String> ledgerNames = _accountHeads.map((h) => h.accountname).toList();

    // Verify mapping targets exist in loaded database
    if (selectedSgstAc != null && !ledgerNames.contains(selectedSgstAc)) selectedSgstAc = null;
    if (selectedCgstAc != null && !ledgerNames.contains(selectedCgstAc)) selectedCgstAc = null;
    if (selectedIgstAc != null && !ledgerNames.contains(selectedIgstAc)) selectedIgstAc = null;

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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0x1EFFFFFF)),
              ),
              title: Row(
                children: [
                  Icon(
                    existing == null ? Icons.add_circle_outline_rounded : Icons.edit_note_rounded,
                    color: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    existing == null ? "Add Category" : "Edit Category",
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
                        // Auto-generated counter badge
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
                              const Text("Category Code: ", style: TextStyle(color: GlassTheme.textMuted, fontSize: 13, fontWeight: FontWeight.bold)),
                              Text(
                                existing == null ? "(Auto-generated on Save)" : existing.catcode,
                                style: const TextStyle(color: Color(0xFF3B82F6), fontSize: 13, fontWeight: FontWeight.extrabold),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Metal selector (Dropdown)
                        const Text("Select Metal *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                              value: selectedMetalId,
                              dropdownColor: GlassTheme.bgSurface,
                              isExpanded: true,
                              items: _metals.map((m) {
                                return DropdownMenuItem<String>(
                                  value: m.metalid,
                                  child: Text(m.metalname, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                );
                              }).toList(),
                              selectedItemBuilder: (context) {
                                return _metals.map((m) {
                                  return Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(m.metalname, style: const TextStyle(fontSize: 13, color: Colors.black)),
                                  );
                                }).toList();
                              },
                              onChanged: (val) {
                                setDialogState(() => selectedMetalId = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Category Name
                        const Text("Category Name *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration("e.g. GOLD ORNAMENTS GST, GOLD BAR"),
                          maxLength: 30,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Category name is required";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category Type: Segmented Option Buttons (METAL, ORNAMENTS/STONE)
                        const Text("Category Type *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildSegmentOption("ORNAMENTS/STONE", selectedType == 'ORNAMENTS/STONE', () {
                              setDialogState(() => selectedType = 'ORNAMENTS/STONE');
                            }),
                            const SizedBox(width: 12),
                            _buildSegmentOption("METAL", selectedType == 'METAL', () {
                              setDialogState(() => selectedType = 'METAL');
                            }),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Color(0x12FFFFFF)),
                        const SizedBox(height: 12),

                        // SGST Input Block
                        _buildCategoryTaxRow(
                          label: "SGST Rate %",
                          controller: sgstPerController,
                          ledgerVal: selectedSgstAc,
                          ledgerList: ledgerNames,
                          onLedgerChanged: (val) => setDialogState(() => selectedSgstAc = val),
                        ),
                        const SizedBox(height: 14),

                        // CGST Input Block
                        _buildCategoryTaxRow(
                          label: "CGST Rate %",
                          controller: cgstPerController,
                          ledgerVal: selectedCgstAc,
                          ledgerList: ledgerNames,
                          onLedgerChanged: (val) => setDialogState(() => selectedCgstAc = val),
                        ),
                        const SizedBox(height: 14),

                        // IGST Input Block
                        _buildCategoryTaxRow(
                          label: "IGST Rate %",
                          controller: igstPerController,
                          ledgerVal: selectedIgstAc,
                          ledgerList: ledgerNames,
                          onLedgerChanged: (val) => setDialogState(() => selectedIgstAc = val),
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
                    backgroundColor: const Color(0xFF3B82F6),
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

                          final record = CategoryRecord(
                            id: existing?.id,
                            metalid: selectedMetalId!,
                            catcode: existing?.catcode ?? '', // Autogenerated on create
                            catname: nameController.text.trim(),
                            categorytype: selectedType,
                            sgstPer: double.tryParse(sgstPerController.text.trim()) ?? 0.0,
                            cgstPer: double.tryParse(cgstPerController.text.trim()) ?? 0.0,
                            igstPer: double.tryParse(igstPerController.text.trim()) ?? 0.0,
                            sgstacname: selectedSgstAc ?? '',
                            cgstacname: selectedCgstAc ?? '',
                            igstacname: selectedIgstAc ?? '',
                          );

                          bool success = false;
                          String message = '';

                          if (existing == null) {
                            final res = await _api.createCategory(token, record);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to create category';
                          } else {
                            final res = await _api.updateCategory(token, existing.id!, record);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to update category';
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
                      : Text(existing == null ? "Save Category" : "Update Category"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSegmentOption(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          foregroundColor: isSelected ? Colors.white : Colors.white70,
          side: BorderSide(color: isSelected ? const Color(0xFF3B82F6) : const Color(0x33FFFFFF)),
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }

  Widget _buildCategoryTaxRow({
    required String label,
    required TextEditingController controller,
    required String? ledgerVal,
    required List<String> ledgerList,
    required ValueChanged<String?> onLedgerChanged,
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
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              TextFormField(
                controller: controller,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: _inputDecoration("Rate %"),
                keyboardType: const TextInputType.withOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return "Required";
                  if (double.tryParse(val.trim()) == null) return "Invalid";
                  return null;
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),

        // Posting Ledger Dropdown
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Posting Ledger Account", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
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
                    value: ledgerVal,
                    dropdownColor: GlassTheme.bgSurface,
                    hint: const Text("Select Ledger Account", style: TextStyle(fontSize: 11, color: GlassTheme.textMuted)),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text("None (No mapping)", style: TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                      ),
                      ...ledgerList.map((name) {
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
                        ...ledgerList.map((name) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(name, style: const TextStyle(fontSize: 12, color: Colors.black)),
                          );
                        }),
                      ];
                    },
                    onChanged: onLedgerChanged,
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
  void _confirmDelete(CategoryRecord c) {
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
            "Are you sure you want to permanently delete the Category \"${c.catname} (${c.catcode})\"? This action cannot be undone.",
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

                final res = await _api.deleteCategory(token, c.id!);
                final success = res['success'] == true;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Failed to delete category'),
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
