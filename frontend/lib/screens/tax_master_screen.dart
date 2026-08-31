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

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  TaxRecord? _editingRecord;
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _sgstPerController = TextEditingController(text: '0.0');
  final _cgstPerController = TextEditingController(text: '0.0');
  final _igstPerController = TextEditingController(text: '0.0');

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
    _codeController.dispose();
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

  void _openForm([TaxRecord? existing]) {
    setState(() {
      _editingRecord = existing;
      _showForm = true;
      if (existing != null) {
        _codeController.text = existing.taxcode;
        _nameController.text = existing.taxname;
        _sgstPerController.text = existing.sgstPer.toString();
        _cgstPerController.text = existing.cgstPer.toString();
        _igstPerController.text = existing.igstPer.toString();

        final accountNames = _accountHeads.map((h) => h.accountname).toList();
        _selectedSgstAc = accountNames.contains(existing.sgstacname) ? existing.sgstacname : null;
        _selectedCgstAc = accountNames.contains(existing.cgstacname) ? existing.cgstacname : null;
        _selectedIgstAc = accountNames.contains(existing.igstacname) ? existing.igstacname : null;
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _codeController.clear();
    _nameController.clear();
    _sgstPerController.text = '0.0';
    _cgstPerController.text = '0.0';
    _igstPerController.text = '0.0';
    _selectedSgstAc = null;
    _selectedCgstAc = null;
    _selectedIgstAc = null;
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingRecord = null;
      _resetFormFields();
    });
  }

  Future<void> _saveTaxForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final code = _codeController.text.trim().toUpperCase();
      final name = _nameController.text.trim();
      final sgst = double.tryParse(_sgstPerController.text.trim()) ?? 0.0;
      final cgst = double.tryParse(_cgstPerController.text.trim()) ?? 0.0;
      final igst = double.tryParse(_igstPerController.text.trim()) ?? 0.0;

      final record = TaxRecord(
        taxcode: code,
        taxname: name,
        sgstPer: sgst,
        sgstacname: _selectedSgstAc ?? '',
        cgstPer: cgst,
        cgstacname: _selectedCgstAc ?? '',
        igstPer: igst,
        igstacname: _selectedIgstAc ?? '',
      );

      final isEditing = _editingRecord != null && _editingRecord!.taxid != null;
      final response = isEditing
          ? await _api.updateTaxRecord(token, _editingRecord!.taxid!, record)
          : await _api.createTaxRecord(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? "Tax Config '$code' updated successfully!" : "Tax Config '$code' created successfully!",
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
              content: Text(response['message']?.toString() ?? "Failed to save tax config"),
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
                tooltip: "Reload Taxes",
                onPressed: _loadData,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm ? const Color(0xFF334155) : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_showForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
                label: Text(
                  _showForm ? "Close Form" : "Add Tax Config",
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
    final isEditing = _editingRecord != null;
    final List<String> accountNames = _accountHeads.map((h) => h.accountname).toList();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.5),
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
            // Form Top Bar
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: const Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? "Edit Tax Configuration (${_editingRecord!.taxcode})" : "Create New Tax Configuration",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing ? "Modify tax rates and accounting ledger postings" : "Define tax identifier, GST rates and ledger account mapping",
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

            // Field Row 1: Tax Code & Tax Name
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tax Code (max 3 chars) *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _codeController,
                        enabled: !isEditing,
                        style: TextStyle(
                          color: !isEditing ? GlassTheme.textPrimary : GlassTheme.textMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        decoration: _inputDecoration("e.g. G03, G18"),
                        maxLength: 3,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(3),
                          FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                        ],
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Code required";
                          if (val.trim().length > 3) return "Max 3 chars";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Tax Name *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        decoration: _inputDecoration("e.g. GST 3.00% (Jewellery)"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Tax Name is required";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Rates and posting accounts title
            const Text(
              "GST Rates & Ledger Postings",
              style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            // Field Row 2: SGST % & Account
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SGST %", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _sgstPerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("0.0"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Required";
                          if (double.tryParse(val) == null) return "Invalid";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("SGST Posting Ledger Account", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      _buildAccountDropdown(
                        value: _selectedSgstAc,
                        options: accountNames,
                        hint: "Select SGST Account Head",
                        onChanged: (val) => setState(() => _selectedSgstAc = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Field Row 3: CGST % & Account
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CGST %", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _cgstPerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("0.0"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Required";
                          if (double.tryParse(val) == null) return "Invalid";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("CGST Posting Ledger Account", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      _buildAccountDropdown(
                        value: _selectedCgstAc,
                        options: accountNames,
                        hint: "Select CGST Account Head",
                        onChanged: (val) => setState(() => _selectedCgstAc = val),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Field Row 4: IGST % & Account
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 150,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("IGST %", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _igstPerController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("0.0"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Required";
                          if (double.tryParse(val) == null) return "Invalid";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 320,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("IGST Posting Ledger Account", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      _buildAccountDropdown(
                        value: _selectedIgstAc,
                        options: accountNames,
                        hint: "Select IGST Account Head",
                        onChanged: (val) => setState(() => _selectedIgstAc = val),
                      ),
                    ],
                  ),
                ),
              ],
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
                  label: isEditing ? "Update Tax Config" : "Save Tax Config",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                  isLoading: _isSaving,
                  onPressed: _saveTaxForm,
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
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2.0),
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
                hintText: "Search tax configs by name, code, posting accounts...",
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
                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
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
              child: const Icon(Icons.percent_rounded, size: 48, color: GlassTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching tax rates found" : "No Tax Configs created yet",
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search filters or clear keywords."
                  : "Get started by adding your first tax configuration rate (e.g. GST, VAT).",
              style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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
          children: _filteredTaxRecords.map((tax) {
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
                            tax.taxname,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(label: tax.taxcode, color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
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
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 20),
                          tooltip: "Edit Tax Config",
                          onPressed: () => _openForm(tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 20),
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
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          "${percentage.toStringAsFixed(2)}%",
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            account.isNotEmpty ? "Posting: $account" : "No account mapped",
            style: TextStyle(
              fontSize: 12,
              color: account.isNotEmpty ? GlassTheme.primaryNeon : GlassTheme.textMuted,
              fontWeight: FontWeight.w600,
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
              DataColumn(label: Text("TAX NAME", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("SGST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("SGST ACCOUNT", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("CGST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("CGST ACCOUNT", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("IGST %", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("IGST ACCOUNT", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
            ],
            rows: _filteredTaxRecords.map((tax) {
              return DataRow(
                cells: [
                  DataCell(Text(tax.taxcode, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w800, fontSize: 13))),
                  DataCell(Text(tax.taxname, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text("${tax.sgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text(tax.sgstacname.isEmpty ? "-" : tax.sgstacname, style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text("${tax.cgstPer.toStringAsFixed(2)}%", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text(tax.cgstacname.isEmpty ? "-" : tax.cgstacname, style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text("${tax.igstPer.toStringAsFixed(2)}%", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text(tax.igstacname.isEmpty ? "-" : tax.igstacname, style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 18),
                          tooltip: "Edit",
                          onPressed: () => _openForm(tax),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete",
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

  // ================= DELETE CONFIRMATION =================
  void _confirmDelete(TaxRecord tax) {
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
              "Delete Tax Config",
              style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete tax configuration '${tax.taxcode} - ${tax.taxname}'?",
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
              if (tax.taxid == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteTaxRecord(token, tax.taxid!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? "Tax record deleted"),
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
