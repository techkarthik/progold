import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/estimate_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../theme/glass_theme.dart';
import '../widgets/glass_widgets.dart';

class EstimateScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Function(String targetModule)? onNavigateModule;

  const EstimateScreen({super.key, this.onBack, this.onNavigateModule});

  @override
  State<EstimateScreen> createState() => _EstimateScreenState();
}

class _EstimateScreenState extends State<EstimateScreen> {
  final ApiService _api = ApiService();

  List<EstimateRecord> _estimates = [];
  List<EstimateRecord> _filteredEstimates = [];

  bool _isLoading = false;
  String _searchQuery = '';
  String _statusFilter = 'ALL';

  int _totalCount = 0;
  int _openCount = 0;
  double _totalValue = 0.0;
  String _nextEstimateNo = 'EST-1001';

  // Live gold & silver rates
  final double _rate24k = 7250.0;
  final double _rate22k = 6650.0;
  final double _rate18k = 5440.0;
  final double _rateSilver = 88.50;

  final TextEditingController _searchController = TextEditingController();

  // ================= IN-PAGE ESTIMATE GENERATOR STATE =================
  bool _showForm = false;
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _customerMobileCtrl = TextEditingController();
  final _customerAddressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  int _validDays = 7;

  // Item builder inputs
  final _itemNameCtrl = TextEditingController(text: "22K Gold Ornament");
  String _selectedMetal = "22K Gold (916)";
  final _grossWeightCtrl = TextEditingController(text: "12.500");
  final _stoneWeightCtrl = TextEditingController(text: "0.500");
  final _ratePerGramCtrl = TextEditingController(text: "6650");
  final _wastagePctCtrl = TextEditingController(text: "8.0");
  final _makingChargesCtrl = TextEditingController(text: "450");
  final _stoneChargesCtrl = TextEditingController(text: "1200");

  List<EstimateItem> _currentItems = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadEstimates();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _customerNameCtrl.dispose();
    _customerMobileCtrl.dispose();
    _customerAddressCtrl.dispose();
    _notesCtrl.dispose();
    _itemNameCtrl.dispose();
    _grossWeightCtrl.dispose();
    _stoneWeightCtrl.dispose();
    _ratePerGramCtrl.dispose();
    _wastagePctCtrl.dispose();
    _makingChargesCtrl.dispose();
    _stoneChargesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEstimates() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isLoading = true);

    try {
      final data = await _api.getEstimatesData(token);
      if (mounted) {
        setState(() {
          _estimates = data['estimates'] as List<EstimateRecord>? ?? [];
          _totalCount = data['total_count'] ?? 0;
          _openCount = data['open_count'] ?? 0;
          _totalValue = (data['total_value'] as num?)?.toDouble() ?? 0.0;
          _nextEstimateNo = data['next_estimate_no'] ?? 'EST-1001';
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error loading estimates: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    }
  }

  void _applyFilter() {
    final query = _searchQuery.trim().toLowerCase();
    _filteredEstimates = _estimates.where((est) {
      final matchesStatus = _statusFilter == 'ALL' || est.status.toUpperCase() == _statusFilter;
      if (!matchesStatus) return false;

      if (query.isEmpty) return true;
      return est.estimateNo.toLowerCase().contains(query) ||
          est.customerName.toLowerCase().contains(query) ||
          est.customerMobile.toLowerCase().contains(query) ||
          est.netAmount.toString().contains(query);
    }).toList();
  }

  void _onMetalChanged(String metal) {
    setState(() {
      _selectedMetal = metal;
      if (metal.contains("24K")) {
        _ratePerGramCtrl.text = _rate24k.toStringAsFixed(0);
      } else if (metal.contains("22K")) {
        _ratePerGramCtrl.text = _rate22k.toStringAsFixed(0);
      } else if (metal.contains("18K")) {
        _ratePerGramCtrl.text = _rate18k.toStringAsFixed(0);
      } else if (metal.contains("Silver")) {
        _ratePerGramCtrl.text = _rateSilver.toStringAsFixed(2);
      }
    });
  }

  void _addItemToCurrentEstimate() {
    final itemName = _itemNameCtrl.text.trim();
    if (itemName.isEmpty) return;

    final gross = double.tryParse(_grossWeightCtrl.text.trim()) ?? 0.0;
    final stone = double.tryParse(_stoneWeightCtrl.text.trim()) ?? 0.0;
    final net = (gross - stone) > 0 ? (gross - stone) : gross;
    final rate = double.tryParse(_ratePerGramCtrl.text.trim()) ?? _rate22k;
    final wastagePct = double.tryParse(_wastagePctCtrl.text.trim()) ?? 0.0;
    final making = double.tryParse(_makingChargesCtrl.text.trim()) ?? 0.0;
    final stoneVal = double.tryParse(_stoneChargesCtrl.text.trim()) ?? 0.0;

    // Calculation: pure metal value + wastage weight + making + stone
    final wastageWeight = net * (wastagePct / 100.0);
    final totalGoldWeight = net + wastageWeight;
    final goldAmount = totalGoldWeight * rate;
    final totalAmount = goldAmount + making + stoneVal;

    setState(() {
      _currentItems.add(EstimateItem(
        itemName: itemName,
        metalType: _selectedMetal,
        grossWeight: gross,
        stoneWeight: stone,
        netWeight: net,
        ratePerGram: rate,
        wastagePercent: wastagePct,
        makingCharges: making,
        stoneCharges: stoneVal,
        totalAmount: totalAmount,
      ));

      // Reset item inputs
      _itemNameCtrl.text = "22K Gold Item";
      _grossWeightCtrl.text = "10.000";
      _stoneWeightCtrl.text = "0.000";
      _wastagePctCtrl.text = "8.0";
      _makingChargesCtrl.text = "350";
      _stoneChargesCtrl.text = "0";
    });
  }

  void _removeItem(int index) {
    setState(() {
      _currentItems.removeAt(index);
    });
  }

  double get _currentGrossWeight => _currentItems.fold(0.0, (sum, i) => sum + i.grossWeight);
  double get _currentNetWeight => _currentItems.fold(0.0, (sum, i) => sum + i.netWeight);
  double get _currentMetalValue => _currentItems.fold(0.0, (sum, i) => sum + (i.netWeight * i.ratePerGram));
  double get _currentMakingCharges => _currentItems.fold(0.0, (sum, i) => sum + i.makingCharges);
  double get _currentStoneCharges => _currentItems.fold(0.0, (sum, i) => sum + i.stoneCharges);
  double get _currentTaxableAmount => _currentItems.fold(0.0, (sum, i) => sum + i.totalAmount);
  double get _currentTaxAmount => _currentTaxableAmount * 0.03; // 3% GST on Gold Jewellery
  double get _currentNetAmount => _currentTaxableAmount + _currentTaxAmount;

  Future<void> _saveEstimate({bool printAfter = false}) async {
    if (!_formKey.currentState!.validate()) return;
    if (_currentItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please add at least one line item to the estimate."), backgroundColor: GlassTheme.accentRose),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    setState(() => _isSaving = true);

    try {
      final estimate = EstimateRecord(
        estimateNo: _nextEstimateNo,
        customerName: _customerNameCtrl.text.trim(),
        customerMobile: _customerMobileCtrl.text.trim(),
        customerAddress: _customerAddressCtrl.text.trim(),
        grossWeight: _currentGrossWeight,
        netWeight: _currentNetWeight,
        totalMetalValue: _currentMetalValue,
        totalMakingCharges: _currentMakingCharges,
        totalStoneCharges: _currentStoneCharges,
        taxableAmount: _currentTaxableAmount,
        taxAmount: _currentTaxAmount,
        netAmount: _currentNetAmount,
        validDays: _validDays,
        status: 'OPEN',
        items: _currentItems,
        notes: _notesCtrl.text.trim(),
      );

      final response = await _api.createEstimate(token, estimate);
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Estimate '${response['estimate_no'] ?? _nextEstimateNo}' created successfully!",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              backgroundColor: GlassTheme.accentEmerald,
            ),
          );

          if (printAfter) {
            _showPrintSlipDialog(estimate);
          }

          _resetForm();
          await _loadEstimates();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message']?.toString() ?? "Failed to save estimate"), backgroundColor: GlassTheme.accentRose),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving estimate: $e"), backgroundColor: GlassTheme.accentRose),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      _showForm = false;
      _customerNameCtrl.clear();
      _customerMobileCtrl.clear();
      _customerAddressCtrl.clear();
      _notesCtrl.clear();
      _currentItems = [];
      _validDays = 7;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isMobile = MediaQuery.of(context).size.width < 750;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(context, auth, isMobile),
        const SizedBox(height: 18),

        // KPI Summary Cards (Today's Estimates, Open, Value, Live Rates)
        _buildKpiSummaryCards(isMobile),
        const SizedBox(height: 20),

        // In-Page Estimate Generator
        if (_showForm) ...[
          _buildEstimateGenerator(isMobile),
          const SizedBox(height: 24),
        ],

        // Search & Status Filter
        _buildFilterToolbar(isMobile),
        const SizedBox(height: 16),

        // Estimates Register Table / Cards
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator(color: Color(0xFFF97316))),
          )
        else if (_filteredEstimates.isEmpty)
          _buildEmptyState()
        else
          _buildEstimatesTable(isMobile),
      ],
    );
  }

  // ================= HEADER BAR =================
  Widget _buildHeader(BuildContext context, AuthProvider auth, bool isMobile) {
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
                  tooltip: "Back to Home Dashboard",
                  onPressed: widget.onBack,
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFC2410C)]),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF97316).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.request_quote_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        "Estimate & Quotation Desk",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: GlassTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusBadge(label: "3rd Main Menu", color: Color(0xFFF97316)),
                    ],
                  ),
                  SizedBox(height: 2),
                  Text(
                    "Pre-sale customer quotations, live weight calculations, price locking & quotation slips",
                    style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: GlassTheme.textPrimary),
                tooltip: "Reload Estimates",
                onPressed: _loadEstimates,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showForm ? const Color(0xFF334155) : const Color(0xFFF97316),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(_showForm ? Icons.close_rounded : Icons.add_rounded, size: 18),
                label: Text(
                  _showForm ? "Close Form" : "New Estimate",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  setState(() => _showForm = !_showForm);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= KPI SUMMARY CARDS =================
  Widget _buildKpiSummaryCards(bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double itemWidth = isMobile ? constraints.maxWidth : (constraints.maxWidth - 36) / 3;

        return Wrap(
          spacing: 18,
          runSpacing: 14,
          children: [
            // 1. Total Estimates
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: "QUOTATIONS GENERATED",
                value: "$_totalCount Total",
                subtitle: "$_openCount Active / Open Quotations",
                icon: Icons.description_rounded,
                color: const Color(0xFFF97316),
              ),
            ),

            // 2. Total Estimated Value
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: "TOTAL ESTIMATED VALUE",
                value: "₹${_totalValue.toStringAsFixed(0)}",
                subtitle: "Pre-sales pipeline pipeline value",
                icon: Icons.currency_rupee_rounded,
                color: const Color(0xFF10B981),
              ),
            ),

            // 3. Today's Live Rates Indicator
            SizedBox(
              width: itemWidth,
              child: _buildMetricCard(
                title: "ACTIVE BOARD RATES",
                value: "22K: ₹${_rate22k.toStringAsFixed(0)}/g",
                subtitle: "24K: ₹${_rate24k.toStringAsFixed(0)} | Silver: ₹${_rateSilver.toStringAsFixed(2)}",
                icon: Icons.price_change_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(color: Color(0x080F172A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: GlassTheme.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GlassTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= IN-PAGE ESTIMATE GENERATOR =================
  Widget _buildEstimateGenerator(bool isMobile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF97316).withValues(alpha: 0.5), width: 1.5),
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
                    color: const Color(0xFFF97316).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calculate_rounded, color: Color(0xFFF97316), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            "New Estimate Quotation ($_nextEstimateNo)",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: GlassTheme.textPrimary),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF97316).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _nextEstimateNo,
                              style: const TextStyle(color: Color(0xFFC2410C), fontWeight: FontWeight.w800, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Add jewellery ornaments, calculate wastage & making charges, and generate instant quotation slip",
                        style: TextStyle(fontSize: 12, color: GlassTheme.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: GlassTheme.textPrimary),
                  tooltip: "Cancel and Close",
                  onPressed: _resetForm,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFE2E8F0)),

            // Section 1: Customer Details
            const Text(
              "CUSTOMER INFORMATION & VALIDITY",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GlassTheme.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 16,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: TextFormField(
                    controller: _customerNameCtrl,
                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: _inputDecoration("Customer Name *"),
                    validator: (val) => (val == null || val.trim().isEmpty) ? "Customer name required" : null,
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 200,
                  child: TextFormField(
                    controller: _customerMobileCtrl,
                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: _inputDecoration("Mobile Number"),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 240,
                  child: TextFormField(
                    controller: _customerAddressCtrl,
                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: _inputDecoration("City / Address"),
                  ),
                ),
                SizedBox(
                  width: isMobile ? double.infinity : 160,
                  child: DropdownButtonFormField<int>(
                    value: _validDays,
                    dropdownColor: Colors.white,
                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                    decoration: _inputDecoration("Validity"),
                    items: const [
                      DropdownMenuItem(value: 3, child: Text("3 Days Rate Lock")),
                      DropdownMenuItem(value: 7, child: Text("7 Days Valid")),
                      DropdownMenuItem(value: 15, child: Text("15 Days Valid")),
                      DropdownMenuItem(value: 30, child: Text("30 Days Valid")),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _validDays = val);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),

            // Section 2: Line Item Builder
            const Text(
              "ADD ORNAMENT / JEWELLERY ITEM",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GlassTheme.textSecondary, letterSpacing: 0.5),
            ),
            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: Column(
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Item Name
                      SizedBox(
                        width: isMobile ? double.infinity : 200,
                        child: TextFormField(
                          controller: _itemNameCtrl,
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Item Description"),
                        ),
                      ),

                      // Metal Type
                      SizedBox(
                        width: isMobile ? double.infinity : 160,
                        child: DropdownButtonFormField<String>(
                          value: _selectedMetal,
                          dropdownColor: Colors.white,
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Metal"),
                          items: const [
                            DropdownMenuItem(value: "22K Gold (916)", child: Text("22K Gold (916)")),
                            DropdownMenuItem(value: "24K Pure Gold", child: Text("24K Pure Gold")),
                            DropdownMenuItem(value: "18K Gold (750)", child: Text("18K Gold (750)")),
                            DropdownMenuItem(value: "Silver (92.5)", child: Text("Silver (92.5)")),
                          ],
                          onChanged: (val) {
                            if (val != null) _onMetalChanged(val);
                          },
                        ),
                      ),

                      // Gross Wt
                      SizedBox(
                        width: isMobile ? double.infinity : 110,
                        child: TextFormField(
                          controller: _grossWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Gross Wt (g)"),
                        ),
                      ),

                      // Stone Wt
                      SizedBox(
                        width: isMobile ? double.infinity : 100,
                        child: TextFormField(
                          controller: _stoneWeightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Stone (g)"),
                        ),
                      ),

                      // Rate / g
                      SizedBox(
                        width: isMobile ? double.infinity : 110,
                        child: TextFormField(
                          controller: _ratePerGramCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Rate / g"),
                        ),
                      ),

                      // Wastage %
                      SizedBox(
                        width: isMobile ? double.infinity : 100,
                        child: TextFormField(
                          controller: _wastagePctCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Wastage %"),
                        ),
                      ),

                      // Making Charges
                      SizedBox(
                        width: isMobile ? double.infinity : 110,
                        child: TextFormField(
                          controller: _makingChargesCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Making (₹)"),
                        ),
                      ),

                      // Stone Charges
                      SizedBox(
                        width: isMobile ? double.infinity : 110,
                        child: TextFormField(
                          controller: _stoneChargesCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
                          decoration: _inputDecoration("Stone (₹)"),
                        ),
                      ),

                      // Add Item Button
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 16),
                        label: const Text("Add Item", style: TextStyle(fontWeight: FontWeight.w800)),
                        onPressed: _addItemToCurrentEstimate,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 3: Line Items List Table
            if (_currentItems.isNotEmpty) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF1F5F9)),
                      columns: const [
                        DataColumn(label: Text("#", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("ITEM", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("METAL", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("GROSS (g)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("NET (g)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("RATE/g", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("WASTAGE", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("MAKING (₹)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("STONE (₹)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("AMOUNT (₹)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                        DataColumn(label: Text("DEL", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
                      ],
                      rows: _currentItems.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final item = entry.value;
                        return DataRow(
                          cells: [
                            DataCell(Text("${idx + 1}")),
                            DataCell(Text(item.itemName, style: const TextStyle(fontWeight: FontWeight.w800))),
                            DataCell(Text(item.metalType, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.w700))),
                            DataCell(Text("${item.grossWeight.toStringAsFixed(3)} g")),
                            DataCell(Text("${item.netWeight.toStringAsFixed(3)} g", style: const TextStyle(fontWeight: FontWeight.w700))),
                            DataCell(Text("₹${item.ratePerGram.toStringAsFixed(0)}")),
                            DataCell(Text("${item.wastagePercent}%")),
                            DataCell(Text("₹${item.makingCharges.toStringAsFixed(0)}")),
                            DataCell(Text("₹${item.stoneCharges.toStringAsFixed(0)}")),
                            DataCell(Text("₹${item.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981)))),
                            DataCell(
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                                onPressed: () => _removeItem(idx),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Section 4: Live Summary Card & Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Total Gross Wt: ${_currentGrossWeight.toStringAsFixed(3)} g  |  Net Wt: ${_currentNetWeight.toStringAsFixed(3)} g",
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Taxable: ₹${_currentTaxableAmount.toStringAsFixed(2)} + GST (3%): ₹${_currentTaxAmount.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text("NET ESTIMATED TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                      Text(
                        "₹${_currentNetAmount.toStringAsFixed(2)}",
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GlassSecondaryButton(
                  label: "Clear All",
                  onPressed: () {
                    setState(() => _currentItems.clear());
                  },
                ),
                const SizedBox(width: 12),
                GlassSecondaryButton(
                  label: "Cancel",
                  onPressed: _resetForm,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0284C7),
                    side: const BorderSide(color: Color(0xFF0284C7)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text("Save & Print Slip", style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () => _saveEstimate(printAfter: true),
                ),
                const SizedBox(width: 12),
                GlassButton(
                  label: "Save Estimate",
                  icon: Icons.check_circle_outline_rounded,
                  gradient: const LinearGradient(colors: [Color(0xFFF97316), Color(0xFFC2410C)]),
                  isLoading: _isSaving,
                  onPressed: () => _saveEstimate(printAfter: false),
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
      labelText: hint,
      labelStyle: const TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
      hintStyle: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFF97316), width: 2.0),
      ),
    );
  }

  // ================= FILTER & SEARCH TOOLBAR =================
  Widget _buildFilterToolbar(bool isMobile) {
    return GlassContainer(
      borderRadius: 14,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildFilterChip("ALL", "All Quotations"),
              const SizedBox(width: 8),
              _buildFilterChip("OPEN", "Open / Active"),
              const SizedBox(width: 8),
              _buildFilterChip("CONVERTED", "Converted to POS"),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
                _applyFilter();
              });
            },
            style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded, color: GlassTheme.textSecondary, size: 20),
              hintText: "Search quotations by Estimate #, Customer Name, Mobile or Amount...",
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
                borderSide: const BorderSide(color: Color(0xFFF97316), width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _statusFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: isSelected ? Colors.white : GlassTheme.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFF97316),
      backgroundColor: const Color(0xFFF1F5F9),
      showCheckmark: false,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _statusFilter = value;
            _applyFilter();
          });
        }
      },
    );
  }

  // ================= ESTIMATES REGISTER TABLE =================
  Widget _buildEstimatesTable(bool isMobile) {
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
            columns: const [
              DataColumn(label: Text("ESTIMATE #", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("CUSTOMER", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("MOBILE", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("NET WT (g)", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("NET AMOUNT", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("VALIDITY", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("STATUS", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              DataColumn(label: Text("ACTIONS", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
            ],
            rows: _filteredEstimates.map((est) {
              final isConverted = est.status == 'CONVERTED';

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      est.estimateNo,
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC2410C), fontSize: 13),
                    ),
                  ),
                  DataCell(Text(est.customerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
                  DataCell(Text(est.customerMobile.isNotEmpty ? est.customerMobile : '-')),
                  DataCell(Text("${est.netWeight.toStringAsFixed(3)} g", style: const TextStyle(fontWeight: FontWeight.w700))),
                  DataCell(
                    Text(
                      "₹${est.netAmount.toStringAsFixed(2)}",
                      style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF10B981), fontSize: 13),
                    ),
                  ),
                  DataCell(Text("${est.validDays} Days")),
                  DataCell(
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isConverted
                            ? const Color(0xFF10B981).withValues(alpha: 0.12)
                            : const Color(0xFFF97316).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        est.status,
                        style: TextStyle(
                          color: isConverted ? const Color(0xFF047857) : const Color(0xFFC2410C),
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                  DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.print_rounded, color: Color(0xFF0284C7), size: 18),
                          tooltip: "Print Quotation Slip",
                          onPressed: () => _showPrintSlipDialog(est),
                        ),
                        if (!isConverted)
                          IconButton(
                            icon: const Icon(Icons.shopping_cart_checkout_rounded, color: Color(0xFF10B981), size: 18),
                            tooltip: "Convert to POS Invoice",
                            onPressed: () => _convertToPos(est),
                          ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, color: GlassTheme.accentRose, size: 18),
                          tooltip: "Delete Estimate",
                          onPressed: () => _confirmDelete(est),
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

  // ================= CONVERT TO POS =================
  void _convertToPos(EstimateRecord est) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) return;

    final updated = EstimateRecord(
      estimateId: est.estimateId,
      estimateNo: est.estimateNo,
      customerName: est.customerName,
      customerMobile: est.customerMobile,
      customerAddress: est.customerAddress,
      grossWeight: est.grossWeight,
      netWeight: est.netWeight,
      totalMetalValue: est.totalMetalValue,
      totalMakingCharges: est.totalMakingCharges,
      totalStoneCharges: est.totalStoneCharges,
      taxableAmount: est.taxableAmount,
      taxAmount: est.taxAmount,
      netAmount: est.netAmount,
      validDays: est.validDays,
      status: 'CONVERTED',
      items: est.items,
      notes: est.notes,
    );

    if (est.estimateId != null) {
      await _api.updateEstimate(token, est.estimateId!, updated);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Estimate '${est.estimateNo}' marked as CONVERTED. Opening POS Billing..."),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      _loadEstimates();
      if (widget.onNavigateModule != null) {
        widget.onNavigateModule!("POS");
      }
    }
  }

  // ================= PRINT SLIP DIALOG =================
  void _showPrintSlipDialog(EstimateRecord est) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.receipt_long_rounded, color: Color(0xFFF97316), size: 24),
            const SizedBox(width: 8),
            Text("Quotation Slip: ${est.estimateNo}", style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Customer: ${est.customerName}", style: const TextStyle(fontWeight: FontWeight.w800)),
                    if (est.customerMobile.isNotEmpty) Text("Mobile: ${est.customerMobile}"),
                    Text("Validity: ${est.validDays} Days from quotation date"),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text("ITEMS BREAKDOWN:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GlassTheme.textSecondary)),
              const SizedBox(height: 6),
              ...est.items.map((i) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${i.itemName} (${i.netWeight}g)", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        Text("₹${i.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  )),
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Taxable Value:", style: TextStyle(fontWeight: FontWeight.w600)),
                  Text("₹${est.taxableAmount.toStringAsFixed(2)}"),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("GST (3%):", style: TextStyle(fontWeight: FontWeight.w600)),
                  Text("₹${est.taxAmount.toStringAsFixed(2)}"),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("NET ESTIMATED TOTAL:", style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFFC2410C))),
                  Text("₹${est.netAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFC2410C))),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFF97316), foregroundColor: Colors.white),
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text("Print Quotation"),
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Sending quotation to configured printer..."), backgroundColor: Color(0xFF10B981)),
              );
            },
          ),
        ],
      ),
    );
  }

  // ================= EMPTY STATE =================
  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFCBD5E1)),
              ),
              child: const Icon(Icons.request_quote_rounded, size: 48, color: Color(0xFFF97316)),
            ),
            const SizedBox(height: 18),
            const Text(
              "No Estimate Quotations Generated Yet",
              style: TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              "Create quick gold/silver pre-sale quotations with live rate calculations.",
              style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF97316),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text("Create First Estimate", style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => setState(() => _showForm = true),
            ),
          ],
        ),
      ),
    );
  }

  // ================= DELETE CONFIRMATION =================
  void _confirmDelete(EstimateRecord est) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Delete Estimate Quotation", style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text("Are you sure you want to delete estimate '${est.estimateNo}' for ${est.customerName}?"),
        actions: [
          TextButton(child: const Text("Cancel"), onPressed: () => Navigator.pop(ctx)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: GlassTheme.accentRose, foregroundColor: Colors.white),
            child: const Text("Delete"),
            onPressed: () async {
              Navigator.pop(ctx);
              if (est.estimateId == null) return;
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final token = auth.authToken;
              if (token == null) return;

              final res = await _api.deleteEstimate(token, est.estimateId!);
              if (mounted) {
                final isOk = res['success'] == true;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(res['message']?.toString() ?? "Estimate deleted"),
                    backgroundColor: isOk ? GlassTheme.accentEmerald : GlassTheme.accentRose,
                  ),
                );
                if (isOk) _loadEstimates();
              }
            },
          ),
        ],
      ),
    );
  }
}
