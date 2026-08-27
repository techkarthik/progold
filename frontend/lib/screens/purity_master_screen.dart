import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/inventory_models.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class PurityMasterScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const PurityMasterScreen({super.key, this.onBack});

  @override
  State<PurityMasterScreen> createState() => _PurityMasterScreenState();
}

class _PurityMasterScreenState extends State<PurityMasterScreen> {
  final ApiService _api = ApiService();

  List<Purity> _purities = [];
  List<Purity> _filteredPurities = [];
  List<Metal> _metals = [];
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
      _api.getPurities(token),
      _api.getMetals(token),
    ]);

    if (mounted) {
      setState(() {
        _purities = results[0] as List<Purity>;
        _metals = results[1] as List<Metal>;
        _applyFilter(_searchQuery);
        _isLoading = false;
      });
    }
  }

  void _applyFilter(String query) {
    _searchQuery = query.trim().toLowerCase();
    if (_searchQuery.isEmpty) {
      _filteredPurities = List.from(_purities);
    } else {
      _filteredPurities = _purities.where((p) {
        return p.purityname.toLowerCase().contains(_searchQuery) ||
            p.purityshortname.toLowerCase().contains(_searchQuery) ||
            (p.metalname ?? '').toLowerCase().contains(_searchQuery) ||
            p.type.toLowerCase().contains(_searchQuery);
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
        else if (_filteredPurities.isEmpty)
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
                  gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF047857)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Purity Master",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "Karat Weights", color: GlassTheme.accentEmerald),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Configure Karat gold purities, silver grades, and item classifications",
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
                tooltip: "Reload Purities",
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
                label: const Text("Add Purity", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
                hintText: "Search purities by name, metal, type...",
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
              child: const Icon(Icons.star_outline_rounded, size: 50, color: GlassTheme.textMuted),
            ),
            const SizedBox(height: 18),
            Text(
              _searchQuery.isNotEmpty ? "No matching purities found" : "No Purity weights configured yet",
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? "Try adjusting your search filters or clear keywords."
                  : "Get started by adding your first purity weight configurations.",
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
                label: const Text("Create Purity", style: TextStyle(fontWeight: FontWeight.bold)),
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
          children: _filteredPurities.map((purity) {
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
                                purity.purityname,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                purity.metalname ?? purity.metalid,
                                style: const TextStyle(fontSize: 11, color: GlassTheme.accentCyan, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        StatusBadge(label: purity.purityshortname, color: const Color(0xFF10B981)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Color(0x12FFFFFF)),
                    const SizedBox(height: 10),

                    // Details
                    _buildDetailRow(Icons.percent_rounded, "Purity Value: ${purity.purity.toStringAsFixed(2)}%"),
                    const SizedBox(height: 6),
                    _buildDetailRow(Icons.layers_outlined, "Type: ${purity.type}"),

                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 18),
                          tooltip: "Edit Purity",
                          onPressed: () => _showAddEditDialog(purity),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete Purity",
                          onPressed: () => _confirmDelete(purity),
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
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
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
              DataColumn(label: Text("METAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("PURITY NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("SHORT NAME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("PURITY VALUE (%)", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("TYPE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
            ],
            rows: _filteredPurities.map((purity) {
              return DataRow(
                cells: [
                  DataCell(Text(purity.metalname ?? purity.metalid, style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold))),
                  DataCell(Text(purity.purityname, style: const TextStyle(color: Colors.white))),
                  DataCell(Text(purity.purityshortname, style: const TextStyle(color: Colors.white70))),
                  DataCell(Text("${purity.purity.toStringAsFixed(2)}%", style: const TextStyle(color: Colors.white))),
                  DataCell(Text(purity.type, style: const TextStyle(color: GlassTheme.accentCyan))),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 16),
                          onPressed: () => _showAddEditDialog(purity),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 16),
                          onPressed: () => _confirmDelete(purity),
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
  void _showAddEditDialog([Purity? existing]) {
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
    final nameController = TextEditingController(text: existing?.purityname ?? '');
    final shortNameController = TextEditingController(text: existing?.purityshortname ?? '');
    final purityValController = TextEditingController(text: existing != null ? existing.purity.toString() : '91.6');

    String? selectedMetalId = existing != null && _metals.any((m) => m.metalid == existing.metalid)
        ? existing.metalid
        : _metals.first.metalid;

    String selectedType = existing?.type ?? 'ORNAMENT'; // 'ORNAMENT' or 'METAL'
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
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    existing == null ? "Add Purity" : "Edit Purity",
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
                width: 440,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Metal Link (Dropdown)
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

                        // Purity Name
                        const Text("Purity Name *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration("e.g. 22 Karat 916"),
                          maxLength: 20,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Purity Name is required";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Short Name
                        const Text("Short Name *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: shortNameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration("e.g. 22K, 18K"),
                          maxLength: 10,
                          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Short name is required";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Numeric Purity Value
                        const Text("Purity Numeric Value (%) *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: purityValController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: _inputDecoration("e.g. 91.60, 75.00, 100.00"),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return "Purity value is required";
                            final d = double.tryParse(val.trim());
                            if (d == null) return "Must be a valid percentage decimal number";
                            if (d < 0 || d > 100) return "Must be between 0 and 100";
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Purity Type: ORNAMENT or METAL (Option Dropdown)
                        const Text("Purity Type *", style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
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
                              value: selectedType,
                              dropdownColor: GlassTheme.bgSurface,
                              isExpanded: true,
                              items: const [
                                DropdownMenuItem<String>(value: 'ORNAMENT', child: Text("ORNAMENT", style: TextStyle(fontSize: 13, color: Colors.black))),
                                DropdownMenuItem<String>(value: 'METAL', child: Text("METAL (Bullion/Bar)", style: TextStyle(fontSize: 13, color: Colors.black))),
                              ],
                              selectedItemBuilder: (context) {
                                return const [
                                  Align(alignment: Alignment.centerLeft, child: Text("ORNAMENT", style: TextStyle(fontSize: 13, color: Colors.black))),
                                  Align(alignment: Alignment.centerLeft, child: Text("METAL", style: TextStyle(fontSize: 13, color: Colors.black))),
                                ];
                              },
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() => selectedType = val);
                                }
                              },
                            ),
                          ),
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

                          final purity = Purity(
                            purityid: existing?.purityid,
                            metalid: selectedMetalId!,
                            purityname: nameController.text.trim(),
                            purityshortname: shortNameController.text.trim(),
                            purity: double.tryParse(purityValController.text.trim()) ?? 0.0,
                            type: selectedType,
                          );

                          bool success = false;
                          String message = '';

                          if (existing == null) {
                            final res = await _api.createPurity(token, purity);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to create purity config';
                          } else {
                            final res = await _api.updatePurity(token, existing.purityid!, purity);
                            success = res['success'] == true;
                            message = res['message'] ?? 'Failed to update purity config';
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
                      : Text(existing == null ? "Save Purity" : "Update Purity"),
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
  void _confirmDelete(Purity purity) {
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
            "Are you sure you want to permanently delete the Purity Karat \"${purity.purityname} (${purity.purityshortname})\"? This action cannot be undone.",
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

                final res = await _api.deletePurity(token, purity.purityid!);
                final success = res['success'] == true;

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(res['message'] ?? 'Failed to delete purity config'),
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
