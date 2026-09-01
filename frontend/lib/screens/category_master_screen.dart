import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../models/account_head_model.dart';
import '../models/tax_model.dart';
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
  List<TaxRecord> _taxRecords = [];
  bool _isLoading = false;
  String _searchQuery = '';
  bool _isTableView = false;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  CategoryRecord? _editingCategory;
  final _formKey = GlobalKey<FormState>();

  String? _selectedMetalId;
  final _nameController = TextEditingController();
  String _selectedType = 'ORNAMENTS/STONE';

  // Tax Master linkage & calculation
  TaxRecord? _selectedTaxRecord;
  final _sgstPerController = TextEditingController(text: '1.50');
  final _cgstPerController = TextEditingController(text: '1.50');
  final _igstPerController = TextEditingController(text: '3.00');

  // Sales & Purchase Account Heads (Where sales and purchases post)
  String? _selectedSalesAc;
  String? _selectedPurchaseAc;

  // Tax Posting Ledgers (Optional)
  String? _selectedSgstAc;
  String? _selectedCgstAc;
  String? _selectedIgstAc;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _sgstPerController.dispose();
    _cgstPerController.dispose();
    _igstPerController.dispose();
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
      _api.getTaxRecords(token),
    ]);

    if (mounted) {
      setState(() {
        _categories = results[0] as List<CategoryRecord>;
        _metals = results[1] as List<Metal>;
        _accountHeads = results[2] as List<AccountHead>;
        _taxRecords = results[3] as List<TaxRecord>;
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
            c.salesacname.toLowerCase().contains(_searchQuery) ||
            c.purchaseacname.toLowerCase().contains(_searchQuery) ||
            c.sgstacname.toLowerCase().contains(_searchQuery) ||
            c.cgstacname.toLowerCase().contains(_searchQuery) ||
            c.igstacname.toLowerCase().contains(_searchQuery);
      }).toList();
    }
  }

  void _onTaxRecordSelected(TaxRecord? tax) {
    setState(() {
      _selectedTaxRecord = tax;
      if (tax != null) {
        // Automatically populate and calculate tax percentages
        _sgstPerController.text = tax.sgstPer.toStringAsFixed(2);
        _cgstPerController.text = tax.cgstPer.toStringAsFixed(2);
        _igstPerController.text = tax.igstPer.toStringAsFixed(2);

        // Auto-assign posting ledgers if configured in Tax Master
        final ledgerNames = _accountHeads.map((h) => h.accountname).toList();
        if (tax.sgstacname.isNotEmpty && ledgerNames.contains(tax.sgstacname)) {
          _selectedSgstAc = tax.sgstacname;
        }
        if (tax.cgstacname.isNotEmpty && ledgerNames.contains(tax.cgstacname)) {
          _selectedCgstAc = tax.cgstacname;
        }
        if (tax.igstacname.isNotEmpty && ledgerNames.contains(tax.igstacname)) {
          _selectedIgstAc = tax.igstacname;
        }
      }
    });
  }

  void _openForm([CategoryRecord? existing]) {
    setState(() {
      _editingCategory = existing;
      _showForm = true;
      if (existing != null) {
        _selectedMetalId = existing.metalid;
        _nameController.text = existing.catname;
        _selectedType = existing.categorytype.isNotEmpty ? existing.categorytype : 'ORNAMENTS/STONE';
        _sgstPerController.text = existing.sgstPer.toStringAsFixed(2);
        _cgstPerController.text = existing.cgstPer.toStringAsFixed(2);
        _igstPerController.text = existing.igstPer.toStringAsFixed(2);

        final ledgerNames = _accountHeads.map((h) => h.accountname).toList();
        _selectedSalesAc = ledgerNames.contains(existing.salesacname) ? existing.salesacname : (existing.salesacname.isNotEmpty ? existing.salesacname : null);
        _selectedPurchaseAc = ledgerNames.contains(existing.purchaseacname) ? existing.purchaseacname : (existing.purchaseacname.isNotEmpty ? existing.purchaseacname : null);
        _selectedSgstAc = ledgerNames.contains(existing.sgstacname) ? existing.sgstacname : null;
        _selectedCgstAc = ledgerNames.contains(existing.cgstacname) ? existing.cgstacname : null;
        _selectedIgstAc = ledgerNames.contains(existing.igstacname) ? existing.igstacname : null;

        // Try matching with existing Tax Master record
        _selectedTaxRecord = _taxRecords.where((t) {
          return (t.sgstPer == existing.sgstPer && t.cgstPer == existing.cgstPer) ||
              (t.igstPer == existing.igstPer && existing.igstPer > 0);
        }).firstOrNull;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _selectedMetalId = _metals.isNotEmpty ? _metals.first.metalid : null;
    _nameController.clear();
    _selectedType = 'ORNAMENTS/STONE';
    _selectedSalesAc = null;
    _selectedPurchaseAc = null;

    // Default to first tax record if available (e.g. 3% GST), otherwise 1.5% SGST + 1.5% CGST
    if (_taxRecords.isNotEmpty) {
      _selectedTaxRecord = _taxRecords.first;
      _sgstPerController.text = _taxRecords.first.sgstPer.toStringAsFixed(2);
      _cgstPerController.text = _taxRecords.first.cgstPer.toStringAsFixed(2);
      _igstPerController.text = _taxRecords.first.igstPer.toStringAsFixed(2);

      final ledgerNames = _accountHeads.map((h) => h.accountname).toList();
      _selectedSgstAc = ledgerNames.contains(_taxRecords.first.sgstacname) ? _taxRecords.first.sgstacname : null;
      _selectedCgstAc = ledgerNames.contains(_taxRecords.first.cgstacname) ? _taxRecords.first.cgstacname : null;
      _selectedIgstAc = ledgerNames.contains(_taxRecords.first.igstacname) ? _taxRecords.first.igstacname : null;
    } else {
      _selectedTaxRecord = null;
      _sgstPerController.text = '1.50';
      _cgstPerController.text = '1.50';
      _igstPerController.text = '3.00';
      _selectedSgstAc = null;
      _selectedCgstAc = null;
      _selectedIgstAc = null;
    }
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingCategory = null;
      _resetFormFields();
    });
  }

  Future<void> _saveCategoryForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    if (_selectedMetalId == null || _selectedMetalId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a base metal"), backgroundColor: GlassTheme.accentRose),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final sgst = double.tryParse(_sgstPerController.text.trim()) ?? 0.0;
      final cgst = double.tryParse(_cgstPerController.text.trim()) ?? 0.0;
      final igst = double.tryParse(_igstPerController.text.trim()) ?? (sgst + cgst);

      final record = CategoryRecord(
        id: _editingCategory?.id,
        catcode: _editingCategory?.catcode ?? '',
        metalid: _selectedMetalId!,
        catname: name,
        categorytype: _selectedType,
        sgstPer: sgst,
        cgstPer: cgst,
        igstPer: igst,
        salesacname: _selectedSalesAc ?? '',
        purchaseacname: _selectedPurchaseAc ?? '',
        sgstacname: _selectedSgstAc ?? '',
        cgstacname: _selectedCgstAc ?? '',
        igstacname: _selectedIgstAc ?? '',
      );

      final isEditing = _editingCategory != null && _editingCategory!.id != null;
      final response = isEditing
          ? await _api.updateCategory(token, _editingCategory!.id!, record)
          : await _api.createCategory(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? "Category '$name' updated successfully!" : "Category '$name' created successfully!",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _closeForm();
          await _loadData();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']?.toString() ?? "Failed to save category"),
              backgroundColor: GlassTheme.accentRose,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

        // Embedded In-Page Form
        if (_showForm) ...[
          _buildInPageEntryForm(isMobile),
          const SizedBox(height: 20),
        ],

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
                      StatusBadge(label: "Classifications", color: Color(0xFF3B82F6)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Define product categories, select Tax Master rules, and calculate GST rates automatically",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
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
                    border: Border.all(color: const Color(0xFFCBD5E1)),
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
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.textPrimary),
                tooltip: "Reload Categories",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm ? const Color(0xFF334155) : const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_showForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
                label: Text(
                  _showForm ? "Close Form" : "Add Category",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  if (_showForm) {
                    _closeForm();
                  } else {
                    _openForm();
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= IN-PAGE ENTRY FORM COMPONENT =================
  Widget _buildInPageEntryForm(bool isMobile) {
    final isEditing = _editingCategory != null;
    final List<String> ledgerNames = _accountHeads.map((h) => h.accountname).toList();

    final sgstVal = double.tryParse(_sgstPerController.text.trim()) ?? 0.0;
    final cgstVal = double.tryParse(_cgstPerController.text.trim()) ?? 0.0;
    final totalGst = sgstVal + cgstVal;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.5), width: 1.5),
        boxShadow: const [
          BoxShadow(color: Color(0x0C0F172A), blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: const Color(0xFF3B82F6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? "Edit Category (${_editingCategory!.catcode} - ${_editingCategory!.catname})" : "Create New Item Category",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing ? "Modify category details and linked Tax Master configuration" : "Define jewelry category (e.g. Ring, Chain, Bullion) and select tax type from Tax Master table",
                        style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Cancel and Close Form",
                  onPressed: _closeForm,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Section 1: Basic Information
            const Text(
              "1. General Category Details",
              style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Base Metal *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedMetalId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("Select Metal"),
                        items: _metals.map((m) {
                          return DropdownMenuItem<String>(
                            value: m.metalid,
                            child: Text("${m.metalname} (${m.metalid})", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedMetalId = val),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Category Name *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("e.g. Rings, Bangles, Chains, Gold Coins"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Name required";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Category Classification *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("Type"),
                        items: const [
                          DropdownMenuItem(value: 'ORNAMENTS/STONE', child: Text("ORNAMENTS / STONE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700))),
                          DropdownMenuItem(value: 'METAL', child: Text("METAL / BULLION", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700))),
                        ],
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedType = val);
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // Section 2: Tax Master Selector & Calculation Engine
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.receipt_long_rounded, color: Color(0xFF3B82F6), size: 20),
                          SizedBox(width: 8),
                          Text(
                            "2. Select Tax Type from Tax Master Table",
                            style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          "Calculated GST: ${totalGst.toStringAsFixed(2)}%",
                          style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Selecting a Tax Type automatically calculates SGST %, CGST %, IGST % and fills default ledger postings.",
                    style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),

                  // Tax Master Dropdown
                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: isMobile ? double.infinity : 360,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Tax Master Rule *", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            DropdownButtonFormField<TaxRecord>(
                              value: _selectedTaxRecord,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("Choose Tax Master Rule"),
                              isExpanded: true,
                              items: [
                                const DropdownMenuItem<TaxRecord>(
                                  value: null,
                                  child: Text("-- Select Tax Rule --", style: TextStyle(color: GlassTheme.textMuted, fontStyle: FontStyle.italic)),
                                ),
                                ..._taxRecords.map((t) {
                                  final totalRate = t.sgstPer + t.cgstPer + (t.igstPer > 0 && t.sgstPer == 0 ? t.igstPer : 0);
                                  return DropdownMenuItem<TaxRecord>(
                                    value: t,
                                    child: Text(
                                      "${t.taxname} (${t.taxcode} - ${totalRate.toStringAsFixed(1)}% GST)",
                                      style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700),
                                    ),
                                  );
                                }),
                              ],
                              onChanged: _onTaxRecordSelected,
                            ),
                          ],
                        ),
                      ),

                      // Live Calculated Tax Breakdown Tiles
                      SizedBox(
                        width: isMobile ? double.infinity : 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("SGST %", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _sgstPerController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("1.50"),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("CGST %", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _cgstPerController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("1.50"),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: isMobile ? double.infinity : 130,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("IGST %", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _igstPerController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("3.00"),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Section 3: Sales & Purchase Account Posting Ledgers (Account Heads)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.account_balance_wallet_rounded, color: GlassTheme.accentEmerald, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "3. Sales & Purchase Account Posting Ledgers",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Specify which Account Head from Master the sales and purchase transactions of this category will be posted into.",
                    style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),

                  Wrap(
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      // Sales Account Head (Where Sales Goes)
                      SizedBox(
                        width: isMobile ? double.infinity : 380,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.point_of_sale_rounded, color: GlassTheme.accentEmerald, size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Sales Account Head (Where Sales Goes) *",
                                  style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildAccountDropdown(
                              value: _selectedSalesAc,
                              options: ledgerNames,
                              hint: "Select Sales Ledger (e.g. Gold Sales A/c)",
                              onChanged: (val) => setState(() => _selectedSalesAc = val),
                            ),
                          ],
                        ),
                      ),

                      // Purchase Account Head (Where Purchase Goes)
                      SizedBox(
                        width: isMobile ? double.infinity : 380,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.shopping_bag_outlined, color: Color(0xFF3B82F6), size: 16),
                                SizedBox(width: 6),
                                Text(
                                  "Purchase Account Head (Where Purchase Goes) *",
                                  style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            _buildAccountDropdown(
                              value: _selectedPurchaseAc,
                              options: ledgerNames,
                              hint: "Select Purchase Ledger (e.g. Gold Purchase A/c)",
                              onChanged: (val) => setState(() => _selectedPurchaseAc = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassSecondaryButton(
                  label: "Clear Fields",
                  icon: Icons.refresh_rounded,
                  onPressed: _resetFormFields,
                ),
                const SizedBox(width: 12),
                GlassSecondaryButton(
                  label: "Cancel",
                  onPressed: _closeForm,
                ),
                const SizedBox(width: 12),
                GlassButton(
                  label: isEditing ? "Update Category" : "Save Category",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF1D4ED8)]),
                  isLoading: _isSaving,
                  onPressed: _saveCategoryForm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13, fontWeight: FontWeight.normal),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.accentRose, width: 1.5),
      ),
    );
  }

  Widget _buildAccountDropdown({
    required String? value,
    required List<String> options,
    required String hint,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white,
      style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
      decoration: _inputDecoration(hint),
      isExpanded: true,
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text("-- None (Optional) --", style: TextStyle(color: GlassTheme.textMuted, fontStyle: FontStyle.italic)),
        ),
        ...options.map((name) {
          return DropdownMenuItem<String>(
            value: name,
            child: Text(name, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
          );
        }),
      ],
      onChanged: onChanged,
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
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: GlassTheme.textSecondary, size: 20),
                hintText: "Search categories by code, name, metal, or posting ledgers...",
                hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
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
                  borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: GlassTheme.textSecondary, size: 18),
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
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(Icons.shopping_bag_rounded, size: 48, color: GlassTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching categories found" : "No Item Categories configured yet",
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query."
                  : "Get started by adding jewelry categories (e.g. Rings, Bangles, Coins, Chains).",
              style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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
                onPressed: () => _openForm(),
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
          children: _filteredCategoriesWithMeta().map((cat) {
            final double totalGstRate = cat.sgstPer + cat.cgstPer + (cat.igstPer > 0 && cat.sgstPer == 0 ? cat.igstPer : 0);

            return SizedBox(
              width: isMobile ? constraints.maxWidth : cardWidth,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: const [
                    BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
                  ],
                ),
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            cat.catname,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: cat.catcode, color: const Color(0xFF3B82F6)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow("Metal", "${cat.metalname ?? cat.metalid} (${cat.metalid})"),
                    const SizedBox(height: 6),
                    _buildInfoRow("Category Code", cat.catcode),
                    const SizedBox(height: 6),
                    _buildInfoRow("Type", cat.categorytype),
                    const SizedBox(height: 6),
                    _buildInfoRow(
                      "GST Rate",
                      totalGstRate > 0
                          ? "${totalGstRate.toStringAsFixed(2)}% (SGST: ${cat.sgstPer}% + CGST: ${cat.cgstPer}%)"
                          : "0.00% (Exempt)",
                    ),
                    const SizedBox(height: 6),
                    _buildInfoRow("Sales A/c", cat.salesacname.isNotEmpty ? cat.salesacname : "Not Assigned"),
                    const SizedBox(height: 6),
                    _buildInfoRow("Purchase A/c", cat.purchaseacname.isNotEmpty ? cat.purchaseacname : "Not Assigned"),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 20),
                          tooltip: "Edit Category",
                          onPressed: () => _openForm(cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 20),
                          tooltip: "Delete Category",
                          onPressed: () => _confirmDelete(cat),
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

  List<CategoryRecord> _filteredCategoriesWithMeta() {
    return _filteredCategories.map((c) {
      final metalMatch = _metals.where((m) => m.metalid == c.metalid).firstOrNull;
      if (metalMatch != null && (c.metalname == null || c.metalname!.isEmpty)) {
        return c.copyWith(metalname: metalMatch.metalname);
      }
      return c;
    }).toList();
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w800),
            textAlign: TextAlign.right,
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
        border: Border.all(color: const Color(0xFFCBD5E1)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
            dataRowColor: WidgetStateProperty.all(Colors.white),
            columns: const [
              DataColumn(label: Text("CODE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("CATEGORY NAME", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("METAL", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("TYPE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("GST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("SALES A/C (POSTING)", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("PURCHASE A/C (POSTING)", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
            ],
            rows: _filteredCategoriesWithMeta().map((cat) {
              final double totalGstRate = cat.sgstPer + cat.cgstPer + (cat.igstPer > 0 && cat.sgstPer == 0 ? cat.igstPer : 0);

              return DataRow(
                cells: [
                  DataCell(Text(cat.catcode, style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 13))),
                  DataCell(Text(cat.catname, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text("${cat.metalname ?? cat.metalid} (${cat.metalid})", style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text(cat.categorytype, style: const TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "${totalGstRate.toStringAsFixed(1)}%",
                        style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: GlassTheme.accentEmerald.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.salesacname.isEmpty ? "-" : cat.salesacname,
                        style: const TextStyle(color: GlassTheme.accentEmerald, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        cat.purchaseacname.isEmpty ? "-" : cat.purchaseacname,
                        style: const TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 18),
                          tooltip: "Edit",
                          onPressed: () => _openForm(cat),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete",
                          onPressed: () => _confirmDelete(cat),
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

  // ================= DELETE CONFIRMATION =================
  void _confirmDelete(CategoryRecord cat) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: GlassTheme.accentRose, size: 24),
            SizedBox(width: 8),
            Text(
              "Delete Category",
              style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete category '${cat.catcode} - ${cat.catname}'?",
          style: const TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        actions: [
          TextButton(
            child: const Text("Cancel", style: TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w700)),
            onPressed: () => Navigator.pop(dialogCtx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: GlassTheme.accentRose,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Delete", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (cat.id == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteCategory(token, cat.id!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? "Category deleted"),
                    backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                  ),
                );
                if (isOk) _loadData();
              }
            },
          ),
        ],
      ),
    );
  }
}
