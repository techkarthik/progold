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

  // ================= IN-PAGE ENTRY FORM STATE =================
  bool _showForm = false;
  AccountHead? _editingHead;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  String _selectedGroup = 'Bank Name';
  int _selectedCountryId = 1; // India default
  StateItem? _selectedState;
  final _customStateController = TextEditingController();
  final _pinController = TextEditingController();
  final _gstController = TextEditingController();
  final _panController = TextEditingController();
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAccountHeads();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _customStateController.dispose();
    _pinController.dispose();
    _gstController.dispose();
    _panController.dispose();
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

  void _openForm([AccountHead? existing]) {
    setState(() {
      _editingHead = existing;
      _showForm = true;
      if (existing != null) {
        _nameController.text = existing.accountname;
        _selectedGroup = _groupOptions.contains(existing.groupname) ? existing.groupname : _groupOptions.first;
        _gstController.text = existing.gstno;
        _panController.text = existing.panno;
        _pinController.text = existing.pincode;
        _isActive = existing.active == 1;

        final matchedCountry = LocationData.getCountryByNameOrCode(existing.country);
        _selectedCountryId = matchedCountry?.id ?? 1;

        final statesForCountry = LocationData.getStatesForCountry(_selectedCountryId);
        _selectedState = statesForCountry.where((s) => s.name.toLowerCase() == existing.state.toLowerCase()).firstOrNull;
        _customStateController.text = _selectedState == null ? existing.state : '';
      } else {
        _resetFormFields();
      }
    });
  }

  void _resetFormFields() {
    _nameController.clear();
    _selectedGroup = _groupOptions.first;
    _selectedCountryId = 1;
    final indianStates = LocationData.indianStates;
    _selectedState = indianStates.where((s) => s.name == "Tamil Nadu").firstOrNull ?? (indianStates.isNotEmpty ? indianStates.first : null);
    _customStateController.clear();
    _pinController.clear();
    _gstController.clear();
    _panController.clear();
    _isActive = true;
  }

  void _closeForm() {
    setState(() {
      _showForm = false;
      _editingHead = null;
      _resetFormFields();
    });
  }

  Future<void> _saveAccountHeadForm() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final countryObj = LocationData.getCountryById(_selectedCountryId);
      final countryName = countryObj?.name ?? 'India';
      final stateName = _selectedState != null ? _selectedState!.name : _customStateController.text.trim();

      final record = AccountHead(
        accode: _editingHead?.accode ?? '',
        accountname: name,
        groupname: _selectedGroup,
        country: countryName,
        state: stateName,
        pincode: _pinController.text.trim(),
        gstno: _gstController.text.trim().toUpperCase(),
        panno: _panController.text.trim().toUpperCase(),
        active: _isActive ? 1 : 0,
      );

      final isEditing = _editingHead != null && _editingHead!.id != null;
      final response = isEditing
          ? await _api.updateAccountHead(token, _editingHead!.id!, record)
          : await _api.createAccountHead(token, record);

      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? "Account '$name' updated successfully!" : "Account '$name' created successfully!",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );
          _closeForm();
          await _loadAccountHeads();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message']?.toString() ?? "Failed to save account head"),
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
                tooltip: "Reload Accounts",
                onPressed: _loadAccountHeads,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm ? const Color(0xFF334155) : const Color(0xFFF43F5E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_showForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
                label: Text(
                  _showForm ? "Close Form" : "Add Account Head",
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
    final isEditing = _editingHead != null;
    final statesForCountry = LocationData.getStatesForCountry(_selectedCountryId);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF43F5E).withValues(alpha: 0.5), width: 1.5),
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
                    color: const Color(0xFFF43F5E).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                    color: const Color(0xFFF43F5E),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? "Edit Account Head (${_editingHead!.accode} - ${_editingHead!.accountname})" : "Create New Account Head / Ledger",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isEditing ? "Modify ledger groupings, GST & status" : "Define general ledger, group classification, statutory GST & PAN numbers",
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

            // Row 1: Account Name & Financial Group
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 360,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Account Head Name *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("e.g. HDFC Bank, Sundry Debtors - Walkin"),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) return "Account name is required";
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 280,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Financial Group *",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _selectedGroup,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("Select Group"),
                        items: _groupOptions.map((grp) {
                          return DropdownMenuItem(
                            value: grp,
                            child: Text(grp, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedGroup = val);
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Status",
                        style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _isActive ? "ACTIVE" : "INACTIVE",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _isActive ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                              ),
                            ),
                            Switch(
                              value: _isActive,
                              activeColor: GlassTheme.accentEmerald,
                              onChanged: (val) => setState(() => _isActive = val),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Statutory & Location Title
            const Text(
              "Statutory Details & Address",
              style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),

            // Row 2: GSTIN, PAN, Country, State, PIN
            Wrap(
              spacing: 16,
              runSpacing: 14,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 220,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("GSTIN (15 Chars)", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _gstController,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("e.g. 33AAAAA0000A1Z5"),
                        maxLength: 15,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PAN Number", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _panController,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("e.g. ABCDE1234F"),
                        maxLength: 10,
                        buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 180,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Country", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _selectedCountryId,
                        dropdownColor: Colors.white,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("Country"),
                        items: LocationData.countries.map((c) {
                          return DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCountryId = val;
                              final newStates = LocationData.getStatesForCountry(val);
                              _selectedState = newStates.isNotEmpty ? newStates.first : null;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("State", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      statesForCountry.isNotEmpty
                          ? DropdownButtonFormField<StateItem>(
                              value: _selectedState != null && statesForCountry.contains(_selectedState)
                                  ? _selectedState
                                  : (statesForCountry.isNotEmpty ? statesForCountry.first : null),
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("State"),
                              items: statesForCountry.map((s) {
                                return DropdownMenuItem(
                                  value: s,
                                  child: Text("${s.name} (${s.code})", style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w700)),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _selectedState = val),
                            )
                          : TextFormField(
                              controller: _customStateController,
                              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                              decoration: _inputDecoration("Enter State"),
                            ),
                    ],
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 140,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("PIN / Postal Code", style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _pinController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        decoration: _inputDecoration("e.g. 600001"),
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
                  label: isEditing ? "Update Account" : "Save Account",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFFF43F5E), Color(0xFFBE123C)]),
                  isLoading: _isSaving,
                  onPressed: _saveAccountHeadForm,
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
        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: GlassTheme.accentRose, width: 1.5),
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
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded, color: GlassTheme.textSecondary, size: 20),
                hintText: "Search accounts by code, name, group, GSTIN, or location...",
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
                  borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
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
              child: const Icon(Icons.account_balance_wallet_rounded, size: 48, color: GlassTheme.textSecondary),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching accounts found" : "No Account Heads created yet",
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search query."
                  : "Get started by adding accounts (e.g. Bank Account, Sundry Debtors, Sales, Tax Accounts).",
              style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
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
          children: _filteredAccountHeads.map((head) {
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
                            head.accountname,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(
                          label: head.active == 1 ? "ACTIVE" : "INACTIVE",
                          color: head.active == 1 ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 8),

                    _buildInfoRow("Account Code", head.accode),
                    const SizedBox(height: 6),
                    _buildInfoRow("Group", head.groupname),
                    const SizedBox(height: 6),
                    _buildInfoRow("State / Location", "${head.state}, ${head.country}"),
                    if (head.gstno.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _buildInfoRow("GSTIN", head.gstno),
                    ],

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 20),
                          tooltip: "Edit Account",
                          onPressed: () => _openForm(head),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 20),
                          tooltip: "Delete Account",
                          onPressed: () => _confirmDelete(head),
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

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
        Text(value, style: const TextStyle(fontSize: 13, color: GlassTheme.textPrimary, fontWeight: FontWeight.w800)),
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
              DataColumn(label: Text("ACCOUNT NAME", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("GROUP", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("GSTIN", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("STATE", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("STATUS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 12))),
            ],
            rows: _filteredAccountHeads.map((head) {
              return DataRow(
                cells: [
                  DataCell(Text(head.accode, style: const TextStyle(color: Color(0xFFF43F5E), fontWeight: FontWeight.w800, fontSize: 13))),
                  DataCell(Text(head.accountname, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13))),
                  DataCell(Text(head.groupname, style: const TextStyle(color: GlassTheme.primaryNeon, fontWeight: FontWeight.w700, fontSize: 13))),
                  DataCell(Text(head.gstno.isEmpty ? "-" : head.gstno, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(Text(head.state, style: const TextStyle(color: GlassTheme.textSecondary, fontWeight: FontWeight.w600, fontSize: 12))),
                  DataCell(
                    StatusBadge(
                      label: head.active == 1 ? "Active" : "Inactive",
                      color: head.active == 1 ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: GlassTheme.primaryNeon, size: 18),
                          tooltip: "Edit",
                          onPressed: () => _openForm(head),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete",
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

  // ================= DELETE CONFIRMATION =================
  void _confirmDelete(AccountHead head) {
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
              "Delete Account Head",
              style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Text(
          "Are you sure you want to delete account head '${head.accode} - ${head.accountname}'?",
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
              if (head.id == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteAccountHead(token, head.id!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? "Account head deleted"),
                    backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                  ),
                );
                if (isOk) _loadAccountHeads();
              }
            },
          ),
        ],
      ),
    );
  }
}
