import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/barcode_models.dart';
import '../models/branch_model.dart';
import '../models/company_model.dart';
import '../models/inventory_models.dart';
import '../models/rate_model.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/barcode_printer_service.dart';
import '../theme/glass_theme.dart';
import 'barcode_template_designer_screen.dart';

class StockBarcodeTaggingScreen extends StatefulWidget {
  final VoidCallback? onBack;

  const StockBarcodeTaggingScreen({super.key, this.onBack});

  @override
  State<StockBarcodeTaggingScreen> createState() => _StockBarcodeTaggingScreenState();
}

class _StockBarcodeTaggingScreenState extends State<StockBarcodeTaggingScreen> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  final NumberFormat _currencyFmt = NumberFormat("#,##,##0.00", "en_IN");
  final NumberFormat _weightFmt = NumberFormat("0.000", "en_US");

  // Collections
  List<Company> _companies = [];
  List<Branch> _branches = [];
  List<PrepareSkuLotRecord> _allLots = [];
  List<BarcodeTemplate> _templates = [];
  List<StockTaggedItem> _taggedItems = [];
  LatestRatesSummary _latestRates = LatestRatesSummary();

  // Selection state
  String? _selectedCompanyId;
  String? _selectedBranchId;
  PrepareSkuLotRecord? _selectedLot;
  BarcodeTemplate? _selectedTemplate;
  final Set<int> _selectedItemIdsForPrint = {};

  // Loading state
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearchingVa = false;

  // Pricing & Costing Form Controllers
  // 1. Sales Pricing (Price Setting / VA Master)
  final TextEditingController _boardRateController = TextEditingController();
  final TextEditingController _salesVaController = TextEditingController();
  final TextEditingController _salesWastageController = TextEditingController();
  final TextEditingController _salesMcGSimpleController = TextEditingController();
  final TextEditingController _salesMChargeController = TextEditingController();
  final TextEditingController _salesStoneAmtController = TextEditingController();
  final TextEditingController _salesDmdAmtController = TextEditingController();

  // 2. Purchase Costing (Smith Inward Costing)
  final TextEditingController _purchaseTouchController = TextEditingController(text: '94.0');
  final TextEditingController _purchaseGoldRateController = TextEditingController();
  final TextEditingController _purchaseMcController = TextEditingController(text: '0.0');
  final TextEditingController _purchaseStoneCostController = TextEditingController(text: '0.0');
  final TextEditingController _purchaseDmdCostController = TextEditingController(text: '0.0');

  // Tag Breakdown Controllers
  final TextEditingController _tagsCountController = TextEditingController(text: '1');
  final TextEditingController _huidController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Custom Tag Breakdown List (if custom piece breakdown is chosen)
  bool _useCustomBreakdown = false;
  List<Map<String, dynamic>> _customPieceRows = [];

  // Filter & Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _boardRateController.dispose();
    _salesVaController.dispose();
    _salesWastageController.dispose();
    _salesMcGSimpleController.dispose();
    _salesMChargeController.dispose();
    _salesStoneAmtController.dispose();
    _salesDmdAmtController.dispose();

    _purchaseTouchController.dispose();
    _purchaseGoldRateController.dispose();
    _purchaseMcController.dispose();
    _purchaseStoneCostController.dispose();
    _purchaseDmdCostController.dispose();

    _tagsCountController.dispose();
    _huidController.dispose();
    _remarksController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken;
    if (token == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final futures = await Future.wait([
        _api.getCompanies(token),
        _api.getBranches(token),
        _api.getPrepareSkuLots(token),
        _api.getBarcodeTemplates(token),
        _api.getLatestRates(token),
        _api.getStockTags(token),
      ]);

      if (mounted) {
        // Companies
        if (futures[0] is List<Company>) {
          _companies = futures[0] as List<Company>;
          if (_companies.isNotEmpty) _selectedCompanyId = _companies.first.companyId;
        }

        // Branches
        if (futures[1] is List<Branch>) {
          _branches = futures[1] as List<Branch>;
          if (_branches.isNotEmpty) _selectedBranchId = _branches.first.branchId;
        }

        // SKU Lots
        if (futures[2] is List<PrepareSkuLotRecord>) {
          _allLots = futures[2] as List<PrepareSkuLotRecord>;
        }

        // Barcode Templates
        final f3 = futures[3] is Map<String, dynamic> ? futures[3] as Map<String, dynamic> : <String, dynamic>{};
        if (f3['success'] == true && f3['templates'] != null) {
          _templates = (f3['templates'] as List)
              .map((t) => BarcodeTemplate.fromJson(t as Map<String, dynamic>))
              .toList();
          if (_templates.isNotEmpty) {
            _selectedTemplate = _templates.firstWhere((t) => t.isDefault, orElse: () => _templates.first);
          }
        }

        // Rates
        if (futures[4] is LatestRatesSummary) {
          _latestRates = futures[4] as LatestRatesSummary;
        }

        // Tagged stock
        final f5 = futures[5] is Map<String, dynamic> ? futures[5] as Map<String, dynamic> : <String, dynamic>{};
        if (f5['success'] == true && f5['tags'] != null) {
          _taggedItems = (f5['tags'] as List)
              .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
              .toList();
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error in _loadInitialData: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _onLotSelected(PrepareSkuLotRecord? lot) async {
    setState(() {
      _selectedLot = lot;
      _selectedItemIdsForPrint.clear();
    });

    if (lot == null) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    // 1. Auto-fill Board Rate from Rate Master or Lot rate
    double latestBoardRate = lot.rate;
    if (latestBoardRate <= 0) {
      final purityRate = _latestRates.purityRates.firstWhere(
        (r) => r.purityid == lot.purityid,
        orElse: () => PurityRateItem(purityid: 0, metalid: 'G', purityname: '', purity: 0, rate: 0),
      );
      if (purityRate.rate > 0) {
        latestBoardRate = purityRate.rate;
      } else if (_latestRates.gold22k > 0) {
        latestBoardRate = _latestRates.gold22k;
      }
    }
    _boardRateController.text = latestBoardRate > 0 ? latestBoardRate.toStringAsFixed(2) : '0.00';
    _purchaseGoldRateController.text = _boardRateController.text;

    // 2. Set default tags count from lot
    _tagsCountController.text = lot.totalPcs.toString();

    // 3. Auto Lookup VA Master (Price Setting) matching smith + product + weight
    setState(() => _isSearchingVa = true);
    final vaRes = await _api.lookupVaPriceSetting(
      token,
      companyId: lot.companyid,
      branchId: lot.branchid,
      productId: lot.productid,
      subproductId: lot.subproductid,
      accode: lot.designerAccode,
      weight: lot.totalGrossWeight,
    );

    if (mounted) {
      setState(() => _isSearchingVa = false);
      if (vaRes['success'] == true && vaRes['matched'] == true && vaRes['price_setting'] != null) {
        final ps = vaRes['price_setting'];
        _salesVaController.text = (ps['va_percent'] ?? 0.0).toString();
        _salesWastageController.text = (ps['wastage'] ?? 0.0).toString();
        _salesMcGSimpleController.text = (ps['mc_per_gram'] ?? 0.0).toString();
        _salesMChargeController.text = (ps['m_charge'] ?? 0.0).toString();
      } else {
        // Defaults
        _salesVaController.text = '12.0';
        _salesWastageController.text = '0.0';
        _salesMcGSimpleController.text = '0.0';
        _salesMChargeController.text = '0.0';
      }

      // 4. Initialize custom breakdown rows if needed
      _initCustomRows(lot.totalPcs, lot.totalGrossWeight, lot.totalNetWeight);
      setState(() {});
    }
  }

  void _showLotPickerDialog() {
    String lotSearchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final filteredLots = _allLots.where((lot) {
              if (lotSearchQuery.isEmpty) return true;
              final q = lotSearchQuery.toLowerCase();
              return lot.lotNumber.toLowerCase().contains(q) ||
                  (lot.productname ?? '').toLowerCase().contains(q) ||
                  (lot.subproductname ?? '').toLowerCase().contains(q) ||
                  (lot.designername ?? '').toLowerCase().contains(q) ||
                  (lot.purityname ?? '').toLowerCase().contains(q);
            }).toList();

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GlassTheme.accentAmber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.inventory_2_rounded, color: GlassTheme.accentAmber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Prepare SKU Lot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${_allLots.length} available lots in inventory', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              content: SizedBox(
                width: 600,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by Lot No (e.g. 2627-1), Smith, Product...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) {
                        setDialogState(() => lotSearchQuery = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredLots.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.search_off_rounded, size: 48, color: Colors.white24),
                                  const SizedBox(height: 8),
                                  Text(
                                    _allLots.isEmpty
                                        ? 'No Prepare SKU Lots found in the database.\nPlease create lots in Prepare for SKU screen.'
                                        : 'No lots matching "$lotSearchQuery"',
                                    style: const TextStyle(color: Colors.white60, fontSize: 13),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.separated(
                              itemCount: filteredLots.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final lot = filteredLots[idx];
                                final isSelected = _selectedLot?.lotId == lot.lotId;
                                return InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    _onLotSelected(lot);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF0284C7).withOpacity(0.2) : const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white12,
                                        width: isSelected ? 1.5 : 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: GlassTheme.accentAmber.withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Lot ${lot.lotNumber}',
                                            style: TextStyle(color: GlassTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Text(
                                                    '${lot.productname ?? 'Ornament'} (${lot.purityname ?? '22K'})',
                                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                                  ),
                                                  const Spacer(),
                                                  Text(
                                                    '${lot.totalPcs} Pcs | ${_weightFmt.format(lot.totalGrossWeight)}g',
                                                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  const Icon(Icons.engineering_rounded, size: 14, color: Colors.white54),
                                                  const SizedBox(width: 4),
                                                  Text('Smith: ${lot.designername ?? 'N/A'}', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                                                  if (lot.totalStonePcs > 0) ...[
                                                    const SizedBox(width: 12),
                                                    const Icon(Icons.diamond_outlined, size: 13, color: Colors.amberAccent),
                                                    const SizedBox(width: 3),
                                                    Text('${lot.totalStonePcs} Stones (${_weightFmt.format(lot.totalStoneWeight)}g)',
                                                        style: const TextStyle(color: Colors.amberAccent, fontSize: 11)),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isSelected)
                                          const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 22)
                                        else
                                          const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
                                      ],
                                    ),
                                  ),
                                );
                              },
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

  void _initCustomRows(int pcs, double totalGrs, double totalNet) {
    final count = pcs > 0 ? pcs : 1;
    final grsPer = totalGrs / count;
    final netPer = totalNet / count;

    _customPieceRows = List.generate(count, (i) {
      return {
        'pcs': 1,
        'gross_weight': grsPer,
        'net_weight': netPer,
        'stone_pcs': 0,
        'stone_weight': 0.0,
        'stone_amt': 0.0,
        'diamond_pcs': 0,
        'diamond_weight': 0.0,
        'diamond_amt': 0.0,
        'huid': '',
        'remarks': 'Piece ${i + 1} of $count',
      };
    });
  }

  // --- Calculations ---
  double get _currentNetWeight => _selectedLot?.totalNetWeight ?? 0.0;
  double get _currentGrossWeight => _selectedLot?.totalGrossWeight ?? 0.0;
  double get _currentBoardRate => double.tryParse(_boardRateController.text) ?? 0.0;
  double get _currentSalesVaPct => double.tryParse(_salesVaController.text) ?? 0.0;
  double get _currentSalesWstPct => double.tryParse(_salesWastageController.text) ?? 0.0;
  double get _currentSalesMcG => double.tryParse(_salesMcGSimpleController.text) ?? 0.0;
  double get _currentSalesMCharge => double.tryParse(_salesMChargeController.text) ?? 0.0;
  double get _currentSalesStoneAmt => double.tryParse(_salesStoneAmtController.text) ?? 0.0;
  double get _currentSalesDmdAmt => double.tryParse(_salesDmdAmtController.text) ?? 0.0;

  double get _totalSalesGoldValue => _currentNetWeight * _currentBoardRate;
  double get _totalSalesVaAmt => _totalSalesGoldValue * (_currentSalesVaPct / 100.0);
  double get _totalSalesWstAmt => _totalSalesGoldValue * (_currentSalesWstPct / 100.0);
  double get _totalSalesMcAmt => (_currentNetWeight * _currentSalesMcG) + _currentSalesMCharge;
  double get _totalEstimatedSalesPrice =>
      _totalSalesGoldValue + _totalSalesVaAmt + _totalSalesWstAmt + _totalSalesMcAmt + _currentSalesStoneAmt + _currentSalesDmdAmt;

  // Purchase Costing
  double get _purchaseTouchPct => double.tryParse(_purchaseTouchController.text) ?? 94.0;
  double get _purchaseGoldRate => double.tryParse(_purchaseGoldRateController.text) ?? _currentBoardRate;
  double get _purchaseMcAmt => double.tryParse(_purchaseMcController.text) ?? 0.0;
  double get _purchaseStoneCost => double.tryParse(_purchaseStoneCostController.text) ?? 0.0;
  double get _purchaseDmdCost => double.tryParse(_purchaseDmdCostController.text) ?? 0.0;

  double get _totalPurchaseGoldCost =>
      _purchaseTouchPct > 0 ? (_currentNetWeight * (_purchaseTouchPct / 100.0) * _purchaseGoldRate) : (_currentNetWeight * _purchaseGoldRate);
  double get _totalCalculatedPurchaseCost =>
      _totalPurchaseGoldCost + _purchaseMcAmt + _purchaseStoneCost + _purchaseDmdCost;

  double get _estimatedGrossMargin => _totalEstimatedSalesPrice - _totalCalculatedPurchaseCost;
  double get _marginPercentage =>
      _totalEstimatedSalesPrice > 0 ? ((_estimatedGrossMargin / _totalEstimatedSalesPrice) * 100.0) : 0.0;

  Future<void> _generateAndSaveTags() async {
    if (_selectedLot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Lot first.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    setState(() => _isSaving = true);

    Map<String, dynamic> payload;
    if (_useCustomBreakdown && _customPieceRows.isNotEmpty) {
      payload = {
        'lot_id': _selectedLot!.lotId,
        'tag_items': _customPieceRows.map((r) {
          final net = (r['net_weight'] as num?)?.toDouble() ?? 0.0;
          final goldVal = net * _currentBoardRate;
          final va = goldVal * (_currentSalesVaPct / 100.0);
          final wst = goldVal * (_currentSalesWstPct / 100.0);
          final mc = (net * _currentSalesMcG) + _currentSalesMCharge;
          final stn = (r['stone_amt'] as num?)?.toDouble() ?? 0.0;
          final dmd = (r['diamond_amt'] as num?)?.toDouble() ?? 0.0;
          final sTotal = goldVal + va + wst + mc + stn + dmd;

          final pGold = _purchaseTouchPct > 0 ? (net * (_purchaseTouchPct / 100.0) * _purchaseGoldRate) : (net * _purchaseGoldRate);
          final pTotal = pGold + _purchaseMcAmt + _purchaseStoneCost + _purchaseDmdCost;

          return {
            'pcs': r['pcs'] ?? 1,
            'gross_weight': r['gross_weight'] ?? 0.0,
            'net_weight': r['net_weight'] ?? 0.0,
            'stone_pcs': r['stone_pcs'] ?? 0,
            'stone_weight': r['stone_weight'] ?? 0.0,
            'stone_amt': stn,
            'diamond_pcs': r['diamond_pcs'] ?? 0,
            'diamond_weight': r['diamond_weight'] ?? 0.0,
            'diamond_amt': dmd,
            'board_rate': _currentBoardRate,
            'sales_va_percent': _currentSalesVaPct,
            'sales_wastage': _currentSalesWstPct,
            'sales_mc_per_gram': _currentSalesMcG,
            'sales_m_charge': _currentSalesMCharge,
            'sales_total_amt': sTotal,
            'purchase_touch_pct': _purchaseTouchPct,
            'purchase_gold_rate': _purchaseGoldRate,
            'purchase_mc': _purchaseMcAmt,
            'purchase_stone_cost': _purchaseStoneCost,
            'purchase_diamond_cost': _purchaseDmdCost,
            'purchase_total_cost': pTotal,
            'huid': r['huid'] ?? _huidController.text.trim(),
            'remarks': r['remarks'] ?? _remarksController.text.trim(),
          };
        }).toList(),
      };
    } else {
      payload = {
        'lot_id': _selectedLot!.lotId,
        'tags_count': int.tryParse(_tagsCountController.text) ?? _selectedLot!.totalPcs,
        'board_rate': _currentBoardRate,
        'sales_va_percent': _currentSalesVaPct,
        'sales_wastage': _currentSalesWstPct,
        'sales_mc_per_gram': _currentSalesMcG,
        'sales_m_charge': _currentSalesMCharge,
        'purchase_touch_pct': _purchaseTouchPct,
        'purchase_gold_rate': _purchaseGoldRate,
        'purchase_mc': _purchaseMcAmt,
        'purchase_stone_cost': _purchaseStoneCost,
        'purchase_diamond_cost': _purchaseDmdCost,
        'huid': _huidController.text.trim(),
        'remarks': _remarksController.text.trim(),
      };
    }

    final res = await _api.generateTagsFromLot(token, payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'SKU Tags generated successfully!'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        // Refresh tags
        final tagsRes = await _api.getStockTags(token);
        if (tagsRes['success'] == true && tagsRes['tags'] != null) {
          setState(() {
            _taggedItems = (tagsRes['tags'] as List)
                .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
                .toList();
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to generate tags.'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  Future<void> _printSelectedTags() async {
    if (_selectedTemplate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or create a Barcode Template first.')),
      );
      return;
    }

    final itemsToPrint = _taggedItems.where((t) => _selectedItemIdsForPrint.contains(t.itemId)).toList();
    if (itemsToPrint.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one tagged item to print.')),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    // Direct print via native spooler
    await BarcodePrinterService.directPrint(
      template: _selectedTemplate!,
      items: itemsToPrint,
      jobName: 'Tags_Lot_${_selectedLot?.lotNumber ?? 'Print'}',
    );

    // Mark tags as printed in backend
    await _api.markStockTagsPrinted(token, itemIds: itemsToPrint.map((i) => i.itemId).toList());

    // Refresh tagged list
    final tagsRes = await _api.getStockTags(token);
    if (mounted && tagsRes['success'] == true && tagsRes['tags'] != null) {
      setState(() {
        _taggedItems = (tagsRes['tags'] as List)
            .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
            .toList();
      });
    }
  }

  void _openTemplateDesigner() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => BarcodeTemplateDesignerScreen(
          onBack: () {
            Navigator.pop(ctx);
            _loadInitialData();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: GlassTheme.bgDark,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final filteredTags = _taggedItems.where((t) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = t.skuCode.toLowerCase().contains(q) ||
            t.lotNumber.toLowerCase().contains(q) ||
            t.productName.toLowerCase().contains(q) ||
            t.designerName.toLowerCase().contains(q) ||
            t.huid.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      backgroundColor: GlassTheme.bgDark,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation & Actions Bar
            _buildTopActionBar(),

            // Main Content Area (Split: Left Lot & Pricing Form, Right Tagged Inventory Grid)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Side: Lot Picker, VA & Sales Pricing, and Purchase Costing Window
                  SizedBox(
                    width: 520,
                    child: _buildLeftTaggingForm(),
                  ),

                  // Right Side: Generated Tags Grid, Template Selector & Print Actions
                  Expanded(
                    child: _buildRightTagsGrid(filteredTags),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        border: Border(bottom: BorderSide(color: GlassTheme.glassBorder)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: Icon(Icons.arrow_back, color: GlassTheme.textPrimary),
              onPressed: widget.onBack,
              tooltip: 'Back to Dashboard',
            ),
            const SizedBox(width: 8),
          ],
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: GlassTheme.cyanGradient,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock Barcode & RFID Tagging',
                style: TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                'Lot-based SKU generation, Price Setting VA lookup, Karigar Purchase Costing & Dynamic Printing',
                style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),

          // Template Designer Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: GlassTheme.accentAmber),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: Icon(Icons.design_services_rounded, size: 16, color: GlassTheme.accentAmber),
            label: Text('Barcode Template Designer',
                style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _openTemplateDesigner,
          ),
          const SizedBox(width: 10),

          // Refresh Button
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: GlassTheme.textSecondary),
            tooltip: 'Reload Data',
            onPressed: _loadInitialData,
          ),
        ],
      ),
    );
  }

  Widget _buildLeftTaggingForm() {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        border: Border(right: BorderSide(color: GlassTheme.glassBorder)),
      ),
      padding: const EdgeInsets.all(14),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Lot Selector
            Row(
              children: [
                Text('1. Select Prepare SKU Lot', style: TextStyle(color: GlassTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    minimumSize: const Size(40, 24),
                  ),
                  icon: const Icon(Icons.search, size: 14, color: Color(0xFF0284C7)),
                  label: const Text('Search Lots', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                  onPressed: _showLotPickerDialog,
                ),
              ],
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _showLotPickerDialog,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: GlassTheme.bgSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _selectedLot != null ? const Color(0xFF0284C7) : GlassTheme.accentAmber.withOpacity(0.6),
                    width: _selectedLot != null ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (_selectedLot != null ? const Color(0xFF0284C7) : GlassTheme.accentAmber).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.inventory_2_rounded,
                        size: 18,
                        color: _selectedLot != null ? const Color(0xFF0284C7) : GlassTheme.accentAmber,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedLot != null
                                ? 'Lot ${_selectedLot!.lotNumber} - ${_selectedLot!.productname ?? 'Ornament'} (${_selectedLot!.purityname ?? '22K'})'
                                : (_allLots.isEmpty ? 'No Lots Found (Click to open / create in Prepare SKU)' : 'Click to Pick Lot (e.g. Lot 2627-1, 2627-4...)'),
                            style: TextStyle(
                              color: _selectedLot != null ? GlassTheme.textPrimary : GlassTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: _selectedLot != null ? FontWeight.bold : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_selectedLot != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              '${_selectedLot!.totalPcs} pcs, ${_weightFmt.format(_selectedLot!.totalGrossWeight)}g | Smith: ${_selectedLot!.designername ?? 'N/A'}',
                              style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _selectedLot != null ? 'CHANGE' : 'SELECT',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Loaded Lot Info Summary Card
            if (_selectedLot != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _buildSummaryBadge('Smith / Dealer', _selectedLot!.designername ?? 'Smith', Icons.engineering_rounded),
                        const SizedBox(width: 8),
                        _buildSummaryBadge('Ornament Purity', _selectedLot!.purityname ?? '22KT', Icons.verified_rounded),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _buildSummaryBadge('Item / Subproduct', '${_selectedLot!.productname ?? ''} ${_selectedLot!.subproductname ?? ''}', Icons.category_rounded),
                        const SizedBox(width: 8),
                        _buildSummaryBadge('Total Wt', '${_weightFmt.format(_selectedLot!.totalGrossWeight)}g Grs / ${_weightFmt.format(_selectedLot!.totalNetWeight)}g Net', Icons.scale_rounded),
                      ],
                    ),
                    if (_selectedLot!.totalStonePcs > 0 || _selectedLot!.totalDiamondPcs > 0) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (_selectedLot!.totalStonePcs > 0)
                            _buildSummaryBadge('Stones', '${_selectedLot!.totalStonePcs} pcs / ${_weightFmt.format(_selectedLot!.totalStoneWeight)}g', Icons.diamond_outlined),
                          if (_selectedLot!.totalStonePcs > 0 && _selectedLot!.totalDiamondPcs > 0)
                            const SizedBox(width: 8),
                          if (_selectedLot!.totalDiamondPcs > 0)
                            _buildSummaryBadge('Diamonds', '${_selectedLot!.totalDiamondPcs} pcs / ${_weightFmt.format(_selectedLot!.totalDiamondWeight)}ct', Icons.auto_awesome_rounded),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // Section 2: Sales Pricing & VA Master Section
            Row(
              children: [
                Text('2. Sales Pricing & VA Master', style: TextStyle(color: GlassTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.bold)),
                const Spacer(),
                if (_isSearchingVa)
                  const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GlassTheme.bgSurfaceMuted,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: GlassTheme.glassBorder),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField('Today\'s Board Rate (/g)', _boardRateController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('VA % (Value Addition)', _salesVaController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('Wastage %', _salesWastageController, isNum: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField('MC per Gram (₹)', _salesMcGSimpleController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('Stone Value (₹)', _salesStoneAmtController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('Diamond Value (₹)', _salesDmdAmtController, isNum: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Calculated Sales Total Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Estimated Sales Total / MRP:', style: TextStyle(color: Color(0xFF047857), fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('₹ ${_currencyFmt.format(_totalEstimatedSalesPrice)}',
                            style: const TextStyle(color: Color(0xFF059669), fontSize: 14, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section 3: Dedicated Purchase Costing / Smith Inward Window
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFFD97706)),
                      const SizedBox(width: 6),
                      const Text('3. Smith / Karigar Purchase Costing (பர்ச்சேஸ் காஸ்ட்)',
                          style: TextStyle(color: Color(0xFF92400E), fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField('Smith Touch % (e.g. 94, 98)', _purchaseTouchController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('Purchase Gold Rate (/g)', _purchaseGoldRateController, isNum: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _buildFormField('Smith MC / Making Charge', _purchaseMcController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('Smith Stone Cost (₹)', _purchaseStoneCostController, isNum: true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFormField('Smith Diamond Cost (₹)', _purchaseDmdCostController, isNum: true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Calculated Purchase Total & Margin Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Purchase Cost from Smith:', style: TextStyle(color: Color(0xFF78350F), fontSize: 11)),
                            Text('₹ ${_currencyFmt.format(_totalCalculatedPurchaseCost)}',
                                style: const TextStyle(color: Color(0xFF92400E), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const Divider(color: Colors.black12, height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Projected Gross Margin:', style: TextStyle(color: Color(0xFF0369A1), fontSize: 12, fontWeight: FontWeight.bold)),
                            Text('₹ ${_currencyFmt.format(_estimatedGrossMargin)} (${_marginPercentage.toStringAsFixed(1)}%)',
                                style: const TextStyle(color: Color(0xFF0284C7), fontSize: 13, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Section 4: Tag Generation & Breakdown Mode
            Text('4. Tag Generation Settings', style: TextStyle(color: GlassTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _buildFormField('Number of Tags to Generate', _tagsCountController, isNum: true),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFormField('HUID (Hallmark ID)', _huidController),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildFormField('Remarks / Batch Notes', _remarksController),
            const SizedBox(height: 14),

            // Action: Generate & Save SKU Tags Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: GlassTheme.accentAmber,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.qr_code_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Generating SKU Tags...' : 'Generate & Save SKU Tags',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: (_isSaving || _selectedLot == null) ? null : _generateAndSaveTags,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRightTagsGrid(List<StockTaggedItem> filteredTags) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table Actions & Barcode Template Picker Toolbar
          Row(
            children: [
              // Search Input
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search SKU, Lot, Item, Smith...',
                    hintStyle: TextStyle(color: GlassTheme.textMuted.withOpacity(0.6), fontSize: 12),
                    prefixIcon: Icon(Icons.search, size: 16, color: GlassTheme.textMuted),
                    filled: true,
                    fillColor: GlassTheme.bgSurfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: GlassTheme.glassBorder)),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Barcode Template Selector
              Text('Print Template:', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: GlassTheme.bgSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GlassTheme.glassBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedTemplate?.templateId,
                    dropdownColor: Colors.white,
                    items: _templates.map((t) {
                      return DropdownMenuItem<int>(
                        value: t.templateId,
                        child: Text('${t.name} (${t.labelsPerRow}-Across)', style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12)),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final found = _templates.firstWhere((t) => t.templateId == id);
                        setState(() => _selectedTemplate = found);
                      }
                    },
                  ),
                ),
              ),
              const Spacer(),

              // Select All / Deselect All
              TextButton.icon(
                icon: Icon(
                  _selectedItemIdsForPrint.length == filteredTags.length && filteredTags.isNotEmpty
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 16,
                  color: GlassTheme.accentAmber,
                ),
                label: Text(
                  _selectedItemIdsForPrint.length == filteredTags.length && filteredTags.isNotEmpty
                      ? 'Deselect All'
                      : 'Select All (${filteredTags.length})',
                  style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12),
                ),
                onPressed: () {
                  setState(() {
                    if (_selectedItemIdsForPrint.length == filteredTags.length) {
                      _selectedItemIdsForPrint.clear();
                    } else {
                      _selectedItemIdsForPrint.addAll(filteredTags.map((t) => t.itemId));
                    }
                  });
                },
              ),
              const SizedBox(width: 8),

              // Print Selected Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: Text('Print Tags (${_selectedItemIdsForPrint.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: _selectedItemIdsForPrint.isEmpty ? null : _printSelectedTags,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tagged Stock Items Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: GlassTheme.bgSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GlassTheme.glassBorder),
              ),
              child: filteredTags.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 48, color: GlassTheme.textMuted.withOpacity(0.4)),
                          const SizedBox(height: 10),
                          Text('No SKU tags generated yet.', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 14)),
                          const SizedBox(height: 4),
                          Text('Select a Lot on the left and click "Generate & Save SKU Tags".',
                              style: TextStyle(color: GlassTheme.textMuted, fontSize: 12)),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(GlassTheme.bgSurfaceMuted),
                          dataRowMinHeight: 40,
                          dataRowMaxHeight: 48,
                          columns: const [
                            DataColumn(label: Text('SELECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0284C7)))),
                            DataColumn(label: Text('SKU CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('LOT NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('PURITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('GROSS WT (g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('NET WT (g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('STONES/DMDS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('SALES PRICE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF059669)))),
                            DataColumn(label: Text('SMITH TOUCH / COST', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD97706)))),
                            DataColumn(label: Text('PRINT STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                            DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                          ],
                          rows: filteredTags.map((item) {
                            final isChecked = _selectedItemIdsForPrint.contains(item.itemId);
                            return DataRow(
                              selected: isChecked,
                              cells: [
                                DataCell(
                                  Checkbox(
                                    value: isChecked,
                                    activeColor: GlassTheme.accentAmber,
                                    checkColor: Colors.white,
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedItemIdsForPrint.add(item.itemId);
                                        } else {
                                          _selectedItemIdsForPrint.remove(item.itemId);
                                        }
                                      });
                                    },
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      const Icon(Icons.qr_code, size: 16, color: Color(0xFF0284C7)),
                                      const SizedBox(width: 6),
                                      Text(item.skuCode, style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                DataCell(Text(item.lotNumber, style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12))),
                                DataCell(Text('${item.productName} ${item.subproductName}', style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12))),
                                DataCell(Text(item.purityName, style: TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                                DataCell(Text(_weightFmt.format(item.grossWeight), style: TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.textPrimary))),
                                DataCell(Text(_weightFmt.format(item.netWeight), style: TextStyle(color: GlassTheme.textSecondary))),
                                DataCell(
                                  Text(
                                    item.stonePcs > 0 || item.diamondPcs > 0
                                        ? 'S:${item.stonePcs} | D:${item.diamondPcs}'
                                        : '-',
                                    style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
                                  ),
                                ),
                                DataCell(Text('₹ ${_currencyFmt.format(item.salesTotalAmt)}', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                                DataCell(
                                  Text(
                                    '${item.purchaseTouchPct}% / ₹ ${_currencyFmt.format(item.purchaseTotalCost)}',
                                    style: const TextStyle(color: Color(0xFFB45309), fontSize: 11),
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: item.tagPrintedCount > 0 ? Colors.green.withOpacity(0.15) : Colors.amber.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      item.tagPrintedCount > 0 ? 'Printed x${item.tagPrintedCount}' : 'Pending Print',
                                      style: TextStyle(
                                        color: item.tagPrintedCount > 0 ? const Color(0xFF047857) : const Color(0xFFB45309),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: const Icon(Icons.print, size: 16, color: Color(0xFF0284C7)),
                                        tooltip: 'Print this tag',
                                        onPressed: () {
                                          if (_selectedTemplate != null) {
                                            BarcodePrinterService.directPrint(
                                              template: _selectedTemplate!,
                                              items: [item],
                                              jobName: 'Tag_${item.skuCode}',
                                            );
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                        tooltip: 'Delete Tag',
                                        onPressed: () async {
                                          final auth = Provider.of<AuthProvider>(context, listen: false);
                                          final token = auth.authToken ?? '';
                                          await _api.deleteStockTag(token, item.itemId);
                                          _loadInitialData();
                                        },
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: GlassTheme.bgSurfaceMuted,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: GlassTheme.glassBorder),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: GlassTheme.accentAmber),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: GlassTheme.textMuted, fontSize: 9)),
                  Text(value, style: TextStyle(color: GlassTheme.textPrimary, fontSize: 11, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormField(String label, TextEditingController controller, {bool isNum = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          onChanged: (_) => setState(() {}),
          style: TextStyle(color: GlassTheme.textPrimary, fontSize: 12),
          decoration: InputDecoration(
            filled: true,
            fillColor: GlassTheme.bgSurfaceMuted,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            isDense: true,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: GlassTheme.glassBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: GlassTheme.accentAmber)),
          ),
        ),
      ],
    );
  }
}
