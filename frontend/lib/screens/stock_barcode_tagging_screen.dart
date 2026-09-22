import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/barcode_models.dart';
import '../models/branch_model.dart';
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

  // Collections from Backend
  List<PrepareSkuLotRecord> _allLots = [];
  List<BarcodeTemplate> _templates = [];
  List<StockTaggedItem> _taggedItems = [];
  List<StyleRecord> _allStyles = [];
  List<SizeRecord> _allSizes = [];
  List<Purity> _allPurities = [];
  List<ProductRecord> _allProducts = [];
  List<SubProductRecord> _allSubProducts = [];
  List<PriceSettingRecord> _priceSettings = [];
  List<DiamondPriceSettingRecord> _diamondPriceSettings = [];
  List<Branch> _allBranches = [];
  LatestRatesSummary _latestRates = LatestRatesSummary();

  // Selection state
  PrepareSkuLotRecord? _selectedLot;
  BarcodeTemplate? _selectedTemplate;
  Branch? _selectedBranch;
  ProductRecord? _selectedProduct;
  SubProductRecord? _selectedSubProduct;
  final Set<int> _selectedItemIdsForPrint = {};

  // Form Controls & Focus Nodes for Single Piece Tagging (Sequential Enter Key Navigation)
  final FocusNode _pcsFocusNode = FocusNode();
  final FocusNode _grossWeightFocusNode = FocusNode();
  final FocusNode _netWeightFocusNode = FocusNode();
  final FocusNode _boardRateFocusNode = FocusNode();
  final FocusNode _salesVaFocusNode = FocusNode();
  final FocusNode _salesWastageFocusNode = FocusNode();
  final FocusNode _salesMcGSimpleFocusNode = FocusNode();
  final FocusNode _salesMChargeFocusNode = FocusNode();
  final FocusNode _purchaseTouchFocusNode = FocusNode();
  final FocusNode _purchaseGoldRateFocusNode = FocusNode();
  final FocusNode _purchaseMcFocusNode = FocusNode();
  final FocusNode _purchaseWastageFocusNode = FocusNode();
  final FocusNode _purchaseStoneCostFocusNode = FocusNode();
  final FocusNode _purchaseDmdCostFocusNode = FocusNode();
  final FocusNode _huidFocusNode = FocusNode();
  final FocusNode _remarksFocusNode = FocusNode();
  final FocusNode _saveAndPrintFocusNode = FocusNode();
  final FocusNode _saveOnlyFocusNode = FocusNode();

  final TextEditingController _pcsController = TextEditingController(text: '1');
  final TextEditingController _grossWeightController = TextEditingController();
  final TextEditingController _netWeightController = TextEditingController();

  // Style, Size, Purity Selection
  StyleRecord? _selectedStyle;
  SizeRecord? _selectedSize;
  Purity? _selectedPurity;

  // Multi-Stone & Multi-Diamond dynamic line-items for current tag
  List<TagStoneItem> _stoneItems = [];
  List<TagDiamondItem> _diamondItems = [];
  final TextEditingController _otherLessWeightController = TextEditingController(text: '0.000');
  double _calculatedLessWeight = 0.0;

  // Sales Pricing (Price Setting / VA Master)
  final TextEditingController _boardRateController = TextEditingController();
  final TextEditingController _salesVaController = TextEditingController(text: '12.0');
  final TextEditingController _salesWastageController = TextEditingController(text: '0.0');
  final TextEditingController _salesMcGSimpleController = TextEditingController(text: '0.0');
  final TextEditingController _salesMChargeController = TextEditingController(text: '0.0');

  // Purchase Costing (Smith Inward)
  final TextEditingController _purchaseTouchController = TextEditingController(text: '94.0');
  final TextEditingController _purchaseGoldRateController = TextEditingController();
  final TextEditingController _purchaseMcController = TextEditingController(text: '0.0');
  final TextEditingController _purchaseWastageController = TextEditingController(text: '0.0');
  final TextEditingController _purchaseStoneCostController = TextEditingController(text: '0.0');
  final TextEditingController _purchaseDmdCostController = TextEditingController(text: '0.0');

  // Identification
  final TextEditingController _huidController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  // Table Filter & Search State
  bool _filterOnlyCurrentLot = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Loading / Busy states
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSearchingVa = false;

  @override
  void initState() {
    super.initState();
    _saveAndPrintFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _saveOnlyFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _loadInitialData();
  }

  @override
  void dispose() {
    _pcsFocusNode.dispose();
    _grossWeightFocusNode.dispose();
    _netWeightFocusNode.dispose();
    _boardRateFocusNode.dispose();
    _salesVaFocusNode.dispose();
    _salesWastageFocusNode.dispose();
    _salesMcGSimpleFocusNode.dispose();
    _salesMChargeFocusNode.dispose();
    _purchaseTouchFocusNode.dispose();
    _purchaseGoldRateFocusNode.dispose();
    _purchaseMcFocusNode.dispose();
    _purchaseWastageFocusNode.dispose();
    _purchaseStoneCostFocusNode.dispose();
    _purchaseDmdCostFocusNode.dispose();
    _huidFocusNode.dispose();
    _remarksFocusNode.dispose();
    _saveAndPrintFocusNode.dispose();
    _saveOnlyFocusNode.dispose();

    _pcsController.dispose();
    _grossWeightController.dispose();
    _netWeightController.dispose();
    _otherLessWeightController.dispose();

    _boardRateController.dispose();
    _salesVaController.dispose();
    _salesWastageController.dispose();
    _salesMcGSimpleController.dispose();
    _salesMChargeController.dispose();

    _purchaseTouchController.dispose();
    _purchaseGoldRateController.dispose();
    _purchaseMcController.dispose();
    _purchaseWastageController.dispose();
    _purchaseStoneCostController.dispose();
    _purchaseDmdCostController.dispose();

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
        _api.getPrepareSkuLots(token, isActive: '1'),
        _api.getBarcodeTemplates(token),
        _api.getLatestRates(token),
        _api.getStockTags(token),
        _api.getStyles(token),
        _api.getSizes(token),
        _api.getPurities(token),
        _api.getProducts(token),
        _api.getSubProducts(token),
        _api.getDiamondPriceSettingsData(token, companyId: auth.activeCompanyId),
        _api.getPriceSettingsData(token, companyId: auth.activeCompanyId),
        _api.getBranches(token, companyId: auth.activeCompanyId),
      ]);

      if (mounted) {
        // SKU Lots: Filter strictly to active, non-disabled lots for barcoding
        if (futures[0] is List<PrepareSkuLotRecord>) {
          final lotsList = futures[0] as List<PrepareSkuLotRecord>;
          _allLots = lotsList.where((l) => l.isActive && l.status.toUpperCase() != 'DISABLED').toList();
        }

        // Barcode Templates
        final f1 = futures[1] is Map<String, dynamic> ? futures[1] as Map<String, dynamic> : <String, dynamic>{};
        if (f1['success'] == true && f1['templates'] != null) {
          _templates = (f1['templates'] as List)
              .map((t) => BarcodeTemplate.fromJson(t as Map<String, dynamic>))
              .toList();
          if (_templates.isNotEmpty) {
            _selectedTemplate = _templates.firstWhere((t) => t.isDefault, orElse: () => _templates.first);
          }
        }

        // Rates
        if (futures[2] is LatestRatesSummary) {
          _latestRates = futures[2] as LatestRatesSummary;
        }

        // Tagged stock
        final f3 = futures[3] is Map<String, dynamic> ? futures[3] as Map<String, dynamic> : <String, dynamic>{};
        if (f3['success'] == true && f3['tags'] != null) {
          _taggedItems = (f3['tags'] as List)
              .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
              .toList();
        }

        // Styles, Sizes, Purities, Products, Subproducts
        if (futures[4] is List<StyleRecord>) _allStyles = futures[4] as List<StyleRecord>;
        if (futures[5] is List<SizeRecord>) _allSizes = futures[5] as List<SizeRecord>;
        if (futures[6] is List<Purity>) {
          _allPurities = (futures[6] as List<Purity>).where((p) {
            final type = p.type.toUpperCase().trim();
            return type.isEmpty || type == 'ORNAMENT' || type == 'ORNAMENTS';
          }).toList();
        }
        if (futures[7] is List<ProductRecord>) _allProducts = futures[7] as List<ProductRecord>;
        if (futures[8] is List<SubProductRecord>) _allSubProducts = futures[8] as List<SubProductRecord>;

        // Diamond Price Settings
        final f9 = futures[9] is Map<String, dynamic> ? futures[9] as Map<String, dynamic> : <String, dynamic>{};
        if (f9['success'] == true && f9['diamond_price_settings'] != null) {
          _diamondPriceSettings = (f9['diamond_price_settings'] as List<DiamondPriceSettingRecord>?) ?? [];
        }

        // Price Settings Master (Stone Sales VA / MC per gram / fixed charge)
        final f10 = futures[10] is Map<String, dynamic> ? futures[10] as Map<String, dynamic> : <String, dynamic>{};
        if (f10['success'] == true && f10['price_settings'] != null) {
          _priceSettings = (f10['price_settings'] as List<PriceSettingRecord>?) ?? [];
        }

        // Branches for target tagging
        if (futures[11] is List<Branch>) {
          _allBranches = futures[11] as List<Branch>;
          final userBranch = auth.currentUser?.branchId;
          final userBranchId = userBranch != null ? userBranch.toUpperCase().trim() : '';
          if (_allBranches.isNotEmpty) {
            _selectedBranch = _allBranches.firstWhere(
              (b) => userBranchId.isNotEmpty && b.branchId.toUpperCase() == userBranchId,
              orElse: () => _allBranches.first,
            );
          }
        }

        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error in _loadInitialData: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Dynamic Ornament, Stone & Diamond Products from Product Master ---
  List<ProductRecord> get _ornamentProducts => _allProducts.where((p) {
    final d = p.diastone.toUpperCase().trim();
    return d != 'S' && d != 'STONE' && d != 'SYNTHETIC' && d != 'P' && d != 'PRECIOUS' && d != 'D' && d != 'DIAMOND';
  }).toList();

  List<ProductRecord> get _stoneProducts => _allProducts.where((p) {
    final d = p.diastone.toUpperCase().trim();
    return d == 'S' || d == 'STONE' || d == 'SYNTHETIC' || d == 'P' || d == 'PRECIOUS';
  }).toList();

  List<ProductRecord> get _diamondProducts => _allProducts.where((p) {
    final d = p.diastone.toUpperCase().trim();
    return d == 'D' || d == 'DIAMOND';
  }).toList();

  // --- Dynamic Multi-Item Totals for Current Tag ---
  int get _totalStonePcs => _stoneItems.fold(0, (sum, i) => sum + i.pcs);
  double get _totalStoneWeight => _stoneItems.fold(0.0, (sum, i) => sum + i.weight);
  double get _totalStoneSalesAmount => _stoneItems.fold(0.0, (sum, i) => sum + i.amount);
  double get _totalStonePurchaseCost => _stoneItems.fold(0.0, (sum, i) => sum + i.purAmount);
  double get _totalStoneLessGrams => _stoneItems.fold(0.0, (sum, i) => sum + i.weightInGrams);

  int get _totalDiamondPcs => _diamondItems.fold(0, (sum, i) => sum + i.pcs);
  double get _totalDiamondWeight => _diamondItems.fold(0.0, (sum, i) => sum + i.weight);
  double get _totalDiamondSalesAmount => _diamondItems.fold(0.0, (sum, i) => sum + i.amount);
  double get _totalDiamondPurchaseCost => _diamondItems.fold(0.0, (sum, i) => sum + i.purAmount);
  double get _totalDiamondLessGrams => _diamondItems.fold(0.0, (sum, i) => sum + i.weightInGrams);

  double get _otherLessGrams => double.tryParse(_otherLessWeightController.text.trim()) ?? 0.0;
  double get _totalLessWeight => _totalStoneLessGrams + _totalDiamondLessGrams + _otherLessGrams;

  void _recalculateNetWeight() {
    final grs = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    _calculatedLessWeight = _totalLessWeight;
    final net = (grs - _calculatedLessWeight).clamp(0.0, 999999.0);
    _netWeightController.text = _weightFmt.format(net);
    setState(() {});
  }

  // --- Dynamic Lot Calculations ---
  List<StockTaggedItem> get _currentLotTaggedItems {
    if (_selectedLot == null) return [];
    return _taggedItems.where((t) => t.lotId == _selectedLot!.lotId).toList();
  }

  int get _lotTotalPcs => _selectedLot?.totalPcs ?? 0;
  double get _lotTotalGrossWeight => _selectedLot?.totalGrossWeight ?? 0.0;

  int get _taggedPcsCount => _currentLotTaggedItems.fold(0, (sum, t) => sum + t.pcs);
  double get _taggedGrossWeight => _currentLotTaggedItems.fold(0.0, (sum, t) => sum + t.grossWeight);

  int get _remainingPcs => (_lotTotalPcs - _taggedPcsCount).clamp(0, 999999);
  double get _remainingGrossWeight => (_lotTotalGrossWeight - _taggedGrossWeight).clamp(0.0, 999999.0);
  double get _taggingProgress => _lotTotalPcs > 0 ? (_taggedPcsCount / _lotTotalPcs).clamp(0.0, 1.0) : 0.0;

  // Effective Product, SubProduct & Names (Handles Assorted Lot override vs Fixed Lot)
  int? get _effectiveProductId => _selectedProduct?.productid ?? _selectedLot?.productid;
  int? get _effectiveSubProductId => _selectedSubProduct?.subproductid ?? _selectedLot?.subproductid;
  String get _effectiveProductName => _selectedProduct?.productname ?? (_selectedLot?.productname ?? '');
  String get _effectiveSubProductName => _selectedSubProduct?.subproductname ?? (_selectedLot?.subproductname ?? '');

  // Available Styles & Sizes filtered by the Effective Product
  List<StyleRecord> get _availableStyles {
    if (_effectiveProductId == null) return _allStyles;
    return _allStyles.where((s) => s.productid == _effectiveProductId).toList();
  }

  List<SizeRecord> get _availableSizes {
    if (_effectiveProductId == null) return _allSizes;
    return _allSizes.where((s) => s.productid == _effectiveProductId).toList();
  }

  List<SubProductRecord> get _availableSubProducts {
    if (_effectiveProductId == null) return [];
    return _allSubProducts.where((sp) => sp.productid == _effectiveProductId).toList();
  }

  Future<void> _onLotSelected(PrepareSkuLotRecord? lot) async {
    setState(() {
      _selectedLot = lot;
      _selectedItemIdsForPrint.clear();
      _grossWeightController.clear();
      _netWeightController.clear();
      _huidController.clear();
      _remarksController.clear();
      // Individual piece tag starts with fresh stones/diamonds (not copying all lot stones blindly)
      _stoneItems = [];
      _diamondItems = [];
      _calculatedLessWeight = 0.0;
      _otherLessWeightController.text = '0.000';
    });

    if (lot == null) {
      setState(() {
        _selectedProduct = null;
        _selectedSubProduct = null;
        _selectedStyle = null;
        _selectedSize = null;
      });
      return;
    }

    // 0. Set Target Branch from Lot or active branch
    if (_allBranches.isNotEmpty) {
      final lotBId = lot.branchid.toUpperCase().trim();
      final matchBranch = _allBranches.where((b) => b.branchId.toUpperCase() == lotBId).toList();
      if (matchBranch.isNotEmpty) {
        _selectedBranch = matchBranch.first;
      }
    }

    // 1. Assorted vs Standard Item selection
    if (lot.isAssorted.toUpperCase() == 'YES') {
      // User must choose product from dropdown in Column 2
      _selectedProduct = null;
      _selectedSubProduct = null;
      _selectedStyle = null;
      _selectedSize = null;
    } else {
      // Fixed product from Lot
      final matchingProds = _allProducts.where((p) => p.productid == lot.productid).toList();
      _selectedProduct = matchingProds.isNotEmpty
          ? matchingProds.first
          : ProductRecord(productid: lot.productid, categoryid: 0, productname: lot.productname ?? 'Ornament');

      if (lot.subproductid != null && lot.subproductid! > 0) {
        final matchingSub = _allSubProducts.where((sp) => sp.subproductid == lot.subproductid).toList();
        _selectedSubProduct = matchingSub.isNotEmpty ? matchingSub.first : null;
      } else {
        _selectedSubProduct = null;
      }

      // Default Style & Size for this Product
      final styles = _allStyles.where((s) => s.productid == lot.productid).toList();
      _selectedStyle = styles.isNotEmpty ? styles.first : null;

      final sizes = _allSizes.where((s) => s.productid == lot.productid).toList();
      _selectedSize = sizes.isNotEmpty ? sizes.first : null;
    }

    // 2. Prefill Purity from Lot
    try {
      _selectedPurity = _allPurities.firstWhere(
        (p) => p.purityid == lot.purityid,
        orElse: () => _allPurities.isNotEmpty
            ? _allPurities.first
            : Purity(
                purityid: lot.purityid,
                metalid: 'G',
                purityname: lot.purityname ?? '22KT',
                purityshortname: '22K',
                purity: (lot.purity != null && lot.purity! > 0) ? lot.purity! : 91.6,
                type: 'ORNAMENT',
              ),
      );
    } catch (_) {}

    // 3. Auto-fill Board Rate from Rate Master or Lot rate
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
    _purchaseTouchController.text = (lot.purity != null && lot.purity! > 0 ? lot.purity!.toStringAsFixed(1) : '91.6');

    // 4. Auto Lookup VA Master (if not assorted, or when product is already resolved)
    if (lot.isAssorted.toUpperCase() != 'YES') {
      await _lookupVaForWeight(lot.totalGrossWeight > 0 ? (lot.totalGrossWeight / (lot.totalPcs > 0 ? lot.totalPcs : 1)) : 10.0);
    }

    // 5. Recalculate Net Weight
    _recalculateNetWeight();

    // 6. Focus immediately on Gross Weight input in Column 2
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_grossWeightFocusNode.canRequestFocus) {
        _grossWeightFocusNode.requestFocus();
      }
    });
  }

  Future<void> _lookupVaForWeight(double weight) async {
    if (_selectedLot == null || _effectiveProductId == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    setState(() => _isSearchingVa = true);
    final vaRes = await _api.lookupVaPriceSetting(
      token,
      companyId: _selectedLot!.companyid,
      branchId: _selectedBranch?.branchId ?? _selectedLot!.branchid,
      productId: _effectiveProductId!,
      subproductId: _effectiveSubProductId,
      accode: _selectedLot!.designerAccode,
      weight: weight,
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
        if (_salesVaController.text.isEmpty) _salesVaController.text = '12.0';
      }
      setState(() {});
    }
  }

  void _onGrossWeightChanged(String val) {
    _recalculateNetWeight();
  }

  /// Opens the Multi-Stone & Multi-Diamond Itemization modal dialog.
  /// Pulls stone & diamond purchase rates from selected Lot, and sales rates from Master Settings.
  Future<void> _openStoneDiamondDialog() async {
    final grs = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    if (grs <= 0) {
      _showToast('Please enter a valid Gross Weight first (e.g. 10.500g)', isError: true);
      _grossWeightFocusNode.requestFocus();
      return;
    }

    // Clone current stone and diamond items for dialog editing
    final List<TagStoneItem> tempStones = _stoneItems.map((s) => TagStoneItem(
      productId: s.productId,
      productName: s.productName,
      subProductId: s.subProductId,
      subProductName: s.subProductName,
      unit: s.unit,
      pcs: s.pcs,
      weight: s.weight,
      purRate: s.purRate,
      purAmount: s.purAmount,
      rate: s.rate,
      amount: s.amount,
    )).toList();

    final List<TagDiamondItem> tempDiamonds = _diamondItems.map((d) => TagDiamondItem(
      productId: d.productId,
      productName: d.productName,
      subProductId: d.subProductId,
      subProductName: d.subProductName,
      unit: d.unit,
      pcs: d.pcs,
      weight: d.weight,
      purRate: d.purRate,
      purAmount: d.purAmount,
      rate: d.rate,
      amount: d.amount,
    )).toList();

    final tempOtherLessCtrl = TextEditingController(
      text: _otherLessWeightController.text == '0.000' || _otherLessWeightController.text == '0.0'
          ? ''
          : _otherLessWeightController.text,
    );

    final stoneProducts = _stoneProducts;
    final diamondProducts = _diamondProducts;

    // Quick Entry State for Adding Stones Row-by-Row
    int? quickStnProductId = stoneProducts.isNotEmpty ? stoneProducts.first.productid : null;
    String quickStnProductName = stoneProducts.isNotEmpty ? stoneProducts.first.productname : '';
    int? quickStnSubProductId;
    String quickStnSubProductName = '';
    String quickStnUnit = 'G';

    // Pre-select Stone product from Lot if present
    if (_selectedLot != null && _selectedLot!.stoneItems.isNotEmpty) {
      final firstLotStn = _selectedLot!.stoneItems.first;
      if (firstLotStn.stoneProductId != null) {
        final match = stoneProducts.where((p) => p.productid == firstLotStn.stoneProductId).toList();
        if (match.isNotEmpty) {
          quickStnProductId = match.first.productid;
          quickStnProductName = match.first.productname;
          quickStnSubProductId = firstLotStn.stoneSubProductId;
          if (firstLotStn.stoneUnit.isNotEmpty) quickStnUnit = firstLotStn.stoneUnit;
        }
      }
    }

    final quickStnPcsCtrl = TextEditingController(text: '1');
    final quickStnWtCtrl = TextEditingController();
    final quickStnPurRateCtrl = TextEditingController();
    final quickStnPurAmtCtrl = TextEditingController();
    final quickStnSalesRateCtrl = TextEditingController();
    final quickStnSalesAmtCtrl = TextEditingController();
    final FocusNode quickStnPcsFocus = FocusNode();
    final FocusNode quickStnWtFocus = FocusNode();
    final FocusNode quickStnPurRateFocus = FocusNode();
    final FocusNode quickStnPurAmtFocus = FocusNode();
    final FocusNode quickStnSalesRateFocus = FocusNode();
    final FocusNode quickStnSalesAmtFocus = FocusNode();
    String? stnNoticeMsg;

    // Helper: Lookup Stone Purchase Rate from Lot & Sales Rate from Master Settings
    // STRICT RULE: Only populates if wt > 0. If no master is found, sales rate is 0.00 (NO fallback to purchase rate).
    void lookupStoneRates(int? prodId, int? subProdId, double wt, String unit, StateSetter setDialogState) {
      if (prodId == null || wt <= 0) {
        setDialogState(() {
          quickStnPurRateCtrl.clear();
          quickStnPurAmtCtrl.clear();
          quickStnSalesRateCtrl.clear();
          quickStnSalesAmtCtrl.clear();
          stnNoticeMsg = null;
        });
        return;
      }

      // 1. Stone Purchase Rate from Lot
      double purRate = 0.0;
      if (_selectedLot != null && _selectedLot!.stoneItems.isNotEmpty) {
        final matchingLotStones = _selectedLot!.stoneItems.where((s) {
          if (s.stoneProductId != prodId) return false;
          if (subProdId != null && s.stoneSubProductId != null && s.stoneSubProductId != 0 && s.stoneSubProductId != subProdId) return false;
          return true;
        }).toList();

        if (matchingLotStones.isNotEmpty) {
          final lotStn = matchingLotStones.first;
          if (lotStn.rate > 0) {
            purRate = lotStn.rate;
            if (lotStn.stoneUnit.isNotEmpty && quickStnUnit != lotStn.stoneUnit) {
              quickStnUnit = lotStn.stoneUnit;
            }
          }
        } else {
          final prodLotStones = _selectedLot!.stoneItems.where((s) => s.stoneProductId == prodId).toList();
          if (prodLotStones.isNotEmpty && prodLotStones.first.rate > 0) {
            purRate = prodLotStones.first.rate;
            if (prodLotStones.first.stoneUnit.isNotEmpty && quickStnUnit != prodLotStones.first.stoneUnit) {
              quickStnUnit = prodLotStones.first.stoneUnit;
            }
          }
        }
      }

      // 2. Stone Sales Rate from Master Settings (strictly 0 if not found in master)
      double salesRate = 0.0;
      String? matchedSource;

      // A. Check in Price Setting Master (_priceSettings)
      final matchingPs = _priceSettings.where((ps) {
        if (ps.productid != prodId) return false;
        if (subProdId != null && ps.subproductid != null && ps.subproductid != 0 && ps.subproductid != subProdId) return false;
        if (ps.weightFrom > 0 || ps.weightTo > 0) {
          if (wt < ps.weightFrom || (ps.weightTo > 0 && wt > ps.weightTo)) return false;
        }
        return true;
      }).toList();

      if (matchingPs.isNotEmpty) {
        final ps = matchingPs.first;
        if (ps.mcPerGram > 0) {
          salesRate = ps.mcPerGram;
          matchedSource = 'Price Setting Master (₹${ps.mcPerGram}/g)';
        } else if (ps.mCharge > 0) {
          salesRate = ps.mCharge;
          matchedSource = 'Price Setting Master (Fixed ₹${ps.mCharge})';
        }
      } else {
        final fallbackPs = _priceSettings.where((ps) {
          if (ps.productid != prodId) return false;
          if (ps.weightFrom > 0 || ps.weightTo > 0) {
            if (wt < ps.weightFrom || (ps.weightTo > 0 && wt > ps.weightTo)) return false;
          }
          return true;
        }).toList();
        if (fallbackPs.isNotEmpty) {
          final ps = fallbackPs.first;
          if (ps.mcPerGram > 0) {
            salesRate = ps.mcPerGram;
            matchedSource = 'Price Setting Master (₹${ps.mcPerGram}/g)';
          } else if (ps.mCharge > 0) {
            salesRate = ps.mCharge;
            matchedSource = 'Price Setting Master (Fixed ₹${ps.mCharge})';
          }
        }
      }

      // B. Check in Diamond / Stone Price Settings (_diamondPriceSettings) if not found above
      if (salesRate <= 0) {
        final cents = unit.toUpperCase() == 'C' ? (wt * 100.0) : (wt * 500.0);
        final matchingDps = _diamondPriceSettings.where((dps) {
          if (dps.productid != prodId) return false;
          if (subProdId != null && dps.subproductid != null && dps.subproductid != 0 && dps.subproductid != subProdId) return false;
          if (dps.fromCent > 0 || dps.toCent > 0) {
            if (cents < dps.fromCent || (dps.toCent > 0 && cents > dps.toCent)) return false;
          }
          return true;
        }).toList();

        if (matchingDps.isNotEmpty && matchingDps.first.centRate > 0) {
          final dps = matchingDps.first;
          salesRate = unit.toUpperCase() == 'C' ? (dps.centRate * 100.0) : (dps.centRate * 500.0);
          matchedSource = 'Diamond/Stone Master (₹${dps.centRate}/cent)';
        } else {
          final fallbackDps = _diamondPriceSettings.where((dps) => dps.productid == prodId).toList();
          if (fallbackDps.isNotEmpty && fallbackDps.first.centRate > 0) {
            final dps = fallbackDps.first;
            salesRate = unit.toUpperCase() == 'C' ? (dps.centRate * 100.0) : (dps.centRate * 500.0);
            matchedSource = 'Diamond/Stone Master (₹${dps.centRate}/cent)';
          }
        }
      }

      final purAmt = wt * purRate;
      final salesAmt = wt * salesRate;

      setDialogState(() {
        quickStnPurRateCtrl.text = purRate > 0 ? purRate.toStringAsFixed(2) : '0.00';
        quickStnPurAmtCtrl.text = purAmt > 0 ? purAmt.toStringAsFixed(2) : '0.00';
        quickStnSalesRateCtrl.text = salesRate > 0 ? salesRate.toStringAsFixed(2) : '0.00';
        quickStnSalesAmtCtrl.text = salesAmt > 0 ? salesAmt.toStringAsFixed(2) : '0.00';

        if (matchedSource != null) {
          stnNoticeMsg = "✨ Stone Sales Rate from $matchedSource: ₹${salesRate.toStringAsFixed(2)}/$unit";
        } else if (purRate > 0) {
          stnNoticeMsg = "ℹ️ Stone Purchase Rate from Lot: ₹${purRate.toStringAsFixed(2)}/$unit | No Sales Master (Sales Rate: 0.00)";
        } else {
          stnNoticeMsg = "ℹ️ No Master/Lot rate found. Rates set to 0.00";
        }
      });
    }

    // Quick Entry State for Adding Diamonds Row-by-Row
    int? quickDmdProductId = diamondProducts.isNotEmpty ? diamondProducts.first.productid : null;
    String quickDmdProductName = diamondProducts.isNotEmpty ? diamondProducts.first.productname : '';
    int? quickDmdSubProductId;
    String quickDmdSubProductName = '';
    String quickDmdUnit = 'C';

    // Pre-select Diamond product from Lot if present
    if (_selectedLot != null && _selectedLot!.diamondItems.isNotEmpty) {
      final firstLotDmd = _selectedLot!.diamondItems.first;
      if (firstLotDmd.diamondProductId != null) {
        final match = diamondProducts.where((p) => p.productid == firstLotDmd.diamondProductId).toList();
        if (match.isNotEmpty) {
          quickDmdProductId = match.first.productid;
          quickDmdProductName = match.first.productname;
          quickDmdSubProductId = firstLotDmd.diamondSubProductId;
          if (firstLotDmd.diamondUnit.isNotEmpty) quickDmdUnit = firstLotDmd.diamondUnit;
        }
      }
    }

    final quickDmdPcsCtrl = TextEditingController(text: '1');
    final quickDmdWtCtrl = TextEditingController();
    final quickDmdPurRateCtrl = TextEditingController();
    final quickDmdPurAmtCtrl = TextEditingController();
    final quickDmdSalesRateCtrl = TextEditingController();
    final quickDmdSalesAmtCtrl = TextEditingController();
    final FocusNode quickDmdPcsFocus = FocusNode();
    final FocusNode quickDmdWtFocus = FocusNode();
    final FocusNode quickDmdPurRateFocus = FocusNode();
    final FocusNode quickDmdPurAmtFocus = FocusNode();
    final FocusNode quickDmdSalesRateFocus = FocusNode();
    final FocusNode quickDmdSalesAmtFocus = FocusNode();
    String? dmdNoticeMsg;

    // Helper: Lookup Diamond Purchase Rate from Lot & Sales Rate from Diamond Price Setting Master
    // STRICT RULE: Only populates if wt > 0. If no master is found, sales rate is 0.00 (NO fallback to purchase rate).
    void lookupDiamondRates(int? prodId, int? subProdId, double wt, String unit, StateSetter setDialogState) {
      if (prodId == null || wt <= 0) {
        setDialogState(() {
          quickDmdPurRateCtrl.clear();
          quickDmdPurAmtCtrl.clear();
          quickDmdSalesRateCtrl.clear();
          quickDmdSalesAmtCtrl.clear();
          dmdNoticeMsg = null;
        });
        return;
      }

      // 1. Diamond Purchase Rate from Lot
      double purRate = 0.0;
      if (_selectedLot != null && _selectedLot!.diamondItems.isNotEmpty) {
        final matchingLotDmds = _selectedLot!.diamondItems.where((d) {
          if (d.diamondProductId != prodId) return false;
          if (subProdId != null && d.diamondSubProductId != null && d.diamondSubProductId != 0 && d.diamondSubProductId != subProdId) return false;
          return true;
        }).toList();

        if (matchingLotDmds.isNotEmpty) {
          final lotDmd = matchingLotDmds.first;
          if (lotDmd.rate > 0) {
            purRate = lotDmd.rate;
            if (lotDmd.diamondUnit.isNotEmpty && quickDmdUnit != lotDmd.diamondUnit) {
              quickDmdUnit = lotDmd.diamondUnit;
            }
          }
        } else {
          final prodLotDmds = _selectedLot!.diamondItems.where((d) => d.diamondProductId == prodId).toList();
          if (prodLotDmds.isNotEmpty && prodLotDmds.first.rate > 0) {
            purRate = prodLotDmds.first.rate;
            if (prodLotDmds.first.diamondUnit.isNotEmpty && quickDmdUnit != prodLotDmds.first.diamondUnit) {
              quickDmdUnit = prodLotDmds.first.diamondUnit;
            }
          }
        }
      }

      // 2. Diamond Sales Rate from Diamond Price Setting Master (strictly 0 if not found in master)
      final cents = unit.toUpperCase() == 'C' ? (wt * 100.0) : (wt * 500.0);
      double salesRate = 0.0;
      double centRate = 0.0;
      String? matchedSource;

      final matched = _diamondPriceSettings.where((dps) {
        if (dps.productid != prodId) return false;
        if (subProdId != null && dps.subproductid != null && dps.subproductid != 0 && dps.subproductid != subProdId) return false;
        if (dps.fromCent > 0 || dps.toCent > 0) {
          if (cents < dps.fromCent || (dps.toCent > 0 && cents > dps.toCent)) return false;
        }
        return true;
      }).toList();

      if (matched.isNotEmpty && matched.first.centRate > 0) {
        final dps = matched.first;
        centRate = dps.centRate;
        salesRate = unit.toUpperCase() == 'C' ? (dps.centRate * 100.0) : (dps.centRate * 500.0);
        matchedSource = 'Diamond Master (₹${dps.centRate}/cent)';
      } else {
        final fallback = _diamondPriceSettings.where((dps) => dps.productid == prodId).toList();
        if (fallback.isNotEmpty && fallback.first.centRate > 0) {
          final dps = fallback.first;
          centRate = dps.centRate;
          salesRate = unit.toUpperCase() == 'C' ? (dps.centRate * 100.0) : (dps.centRate * 500.0);
          matchedSource = 'Diamond Master (₹${dps.centRate}/cent)';
        }
      }

      final purAmt = wt * purRate;
      final salesAmt = (centRate > 0 && cents > 0) ? (cents * centRate) : (wt * salesRate);

      setDialogState(() {
        quickDmdPurRateCtrl.text = purRate > 0 ? purRate.toStringAsFixed(2) : '0.00';
        quickDmdPurAmtCtrl.text = purAmt > 0 ? purAmt.toStringAsFixed(2) : '0.00';
        quickDmdSalesRateCtrl.text = salesRate > 0 ? salesRate.toStringAsFixed(2) : '0.00';
        quickDmdSalesAmtCtrl.text = salesAmt > 0 ? salesAmt.toStringAsFixed(2) : '0.00';

        if (matchedSource != null) {
          dmdNoticeMsg = "✨ Diamond Sales Rate: ₹$centRate/cent (₹${salesRate.toStringAsFixed(0)}/$unit)";
        } else if (purRate > 0) {
          dmdNoticeMsg = "ℹ️ Diamond Purchase Rate from Lot: ₹${purRate.toStringAsFixed(2)}/$unit | No Sales Master (Sales Rate: 0.00)";
        } else {
          dmdNoticeMsg = "ℹ️ No Master/Lot rate found. Rates set to 0.00";
        }
      });
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final stoneLessGrams = tempStones.fold(0.0, (sum, i) => sum + i.weightInGrams);
            final stoneTotalPurCost = tempStones.fold(0.0, (sum, i) => sum + i.purAmount);
            final stoneTotalSalesAmt = tempStones.fold(0.0, (sum, i) => sum + i.amount);
            final stoneTotalPcs = tempStones.fold(0, (sum, i) => sum + i.pcs);
            final stoneTotalWt = tempStones.fold(0.0, (sum, i) => sum + i.weight);

            final diamondLessGrams = tempDiamonds.fold(0.0, (sum, i) => sum + i.weightInGrams);
            final diamondTotalPurCost = tempDiamonds.fold(0.0, (sum, i) => sum + i.purAmount);
            final diamondTotalSalesAmt = tempDiamonds.fold(0.0, (sum, i) => sum + i.amount);
            final diamondTotalPcs = tempDiamonds.fold(0, (sum, i) => sum + i.pcs);
            final diamondTotalWt = tempDiamonds.fold(0.0, (sum, i) => sum + i.weight);

            final otherLessGrams = double.tryParse(tempOtherLessCtrl.text.trim()) ?? 0.0;
            final totalLessGrams = stoneLessGrams + diamondLessGrams + otherLessGrams;
            final netWeightGrams = (grs - totalLessGrams).clamp(0.0, 999999.0);

            final totalCombinedPurCost = stoneTotalPurCost + diamondTotalPurCost;
            final totalCombinedSalesAmt = stoneTotalSalesAmt + diamondTotalSalesAmt;

            final matchingStnSubProducts = _allSubProducts.where((sp) {
              if (quickStnProductId == null) return true;
              return sp.productid == quickStnProductId;
            }).toList();

            final matchingDmdSubProducts = _allSubProducts.where((sp) {
              if (quickDmdProductId == null) return true;
              return sp.productid == quickDmdProductId;
            }).toList();

            void addQuickStone() {
              final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
              final pcs = int.tryParse(quickStnPcsCtrl.text.trim()) ?? 1;
              final purRate = double.tryParse(quickStnPurRateCtrl.text.trim()) ?? 0.0;
              final purAmt = double.tryParse(quickStnPurAmtCtrl.text.trim()) ?? (wt * purRate);
              final salesRate = double.tryParse(quickStnSalesRateCtrl.text.trim()) ?? 0.0;
              final salesAmt = double.tryParse(quickStnSalesAmtCtrl.text.trim()) ?? (wt * salesRate);

              if (wt <= 0 && pcs <= 0) {
                setDialogState(() {
                  stnNoticeMsg = '⚠️ Please enter stone weight or pcs before adding.';
                });
                quickStnWtFocus.requestFocus();
                return;
              }

              setDialogState(() {
                tempStones.add(TagStoneItem(
                  productId: quickStnProductId,
                  productName: quickStnProductName,
                  subProductId: quickStnSubProductId,
                  subProductName: quickStnSubProductName,
                  unit: quickStnUnit,
                  pcs: pcs,
                  weight: wt,
                  purRate: purRate,
                  purAmount: purAmt,
                  rate: salesRate,
                  amount: salesAmt,
                ));
                // Reset quick entry fields for the NEXT stone
                quickStnPcsCtrl.text = '1';
                quickStnWtCtrl.clear();
                quickStnPurRateCtrl.clear();
                quickStnPurAmtCtrl.clear();
                quickStnSalesRateCtrl.clear();
                quickStnSalesAmtCtrl.clear();
                stnNoticeMsg = '✓ Stone #${tempStones.length} added! Pur Cost: ₹${purAmt.toStringAsFixed(2)}, Sales: ₹${salesAmt.toStringAsFixed(2)}';
              });

              quickStnPcsFocus.requestFocus();
            }

            void addQuickDiamond() {
              final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
              final pcs = int.tryParse(quickDmdPcsCtrl.text.trim()) ?? 1;
              final purRate = double.tryParse(quickDmdPurRateCtrl.text.trim()) ?? 0.0;
              final purAmt = double.tryParse(quickDmdPurAmtCtrl.text.trim()) ?? (wt * purRate);
              final salesRate = double.tryParse(quickDmdSalesRateCtrl.text.trim()) ?? 0.0;
              final salesAmt = double.tryParse(quickDmdSalesAmtCtrl.text.trim()) ?? (wt * salesRate);

              if (wt <= 0 && pcs <= 0) {
                setDialogState(() {
                  dmdNoticeMsg = '⚠️ Please enter diamond carats/weight before adding.';
                });
                quickDmdWtFocus.requestFocus();
                return;
              }

              setDialogState(() {
                tempDiamonds.add(TagDiamondItem(
                  productId: quickDmdProductId,
                  productName: quickDmdProductName,
                  subProductId: quickDmdSubProductId,
                  subProductName: quickDmdSubProductName,
                  unit: quickDmdUnit,
                  pcs: pcs,
                  weight: wt,
                  purRate: purRate,
                  purAmount: purAmt,
                  rate: salesRate,
                  amount: salesAmt,
                ));
                // Reset quick entry fields for the NEXT diamond
                quickDmdPcsCtrl.text = '1';
                quickDmdWtCtrl.clear();
                quickDmdPurRateCtrl.clear();
                quickDmdPurAmtCtrl.clear();
                quickDmdSalesRateCtrl.clear();
                quickDmdSalesAmtCtrl.clear();
                dmdNoticeMsg = '✓ Diamond #${tempDiamonds.length} added! Pur Cost: ₹${purAmt.toStringAsFixed(2)}, Sales: ₹${salesAmt.toStringAsFixed(2)}';
              });

              quickDmdPcsFocus.requestFocus();
            }

            // 1-Click Import Stones from Lot
            void importAllStonesFromLot() {
              if (_selectedLot == null || _selectedLot!.stoneItems.isEmpty) return;
              setDialogState(() {
                for (final stn in _selectedLot!.stoneItems) {
                  final purRate = stn.rate;
                  final wt = stn.weight;
                  final purAmt = stn.amount > 0 ? stn.amount : (wt * purRate);

                  // Calculate master sales rate (0.0 if not in master)
                  double salesRate = 0.0;
                  final matchingPs = _priceSettings.where((ps) {
                    if (ps.productid != stn.stoneProductId) return false;
                    if (stn.stoneSubProductId != null && ps.subproductid != null && ps.subproductid != 0 && ps.subproductid != stn.stoneSubProductId) return false;
                    if (ps.weightFrom > 0 || ps.weightTo > 0) {
                      if (wt < ps.weightFrom || (ps.weightTo > 0 && wt > ps.weightTo)) return false;
                    }
                    return true;
                  }).toList();

                  if (matchingPs.isNotEmpty) {
                    final ps = matchingPs.first;
                    salesRate = ps.mcPerGram > 0 ? ps.mcPerGram : ps.mCharge;
                  }
                  if (salesRate <= 0) {
                    final cents = stn.stoneUnit.toUpperCase() == 'C' ? (wt * 100.0) : (wt * 500.0);
                    final matchingDps = _diamondPriceSettings.where((dps) {
                      if (dps.productid != stn.stoneProductId) return false;
                      if (stn.stoneSubProductId != null && dps.subproductid != null && dps.subproductid != 0 && dps.subproductid != stn.stoneSubProductId) return false;
                      if (dps.fromCent > 0 || dps.toCent > 0) {
                        if (cents < dps.fromCent || (dps.toCent > 0 && cents > dps.toCent)) return false;
                      }
                      return true;
                    }).toList();
                    if (matchingDps.isNotEmpty && matchingDps.first.centRate > 0) {
                      salesRate = stn.stoneUnit.toUpperCase() == 'C' ? (matchingDps.first.centRate * 100.0) : (matchingDps.first.centRate * 500.0);
                    }
                  }
                  final salesAmt = wt * salesRate;

                  tempStones.add(TagStoneItem(
                    productId: stn.stoneProductId,
                    productName: stn.stoneProductName,
                    subProductId: stn.stoneSubProductId,
                    subProductName: stn.stoneSubProductName,
                    unit: stn.stoneUnit,
                    pcs: stn.pcs,
                    weight: stn.weight,
                    purRate: purRate,
                    purAmount: purAmt,
                    rate: salesRate,
                    amount: salesAmt,
                  ));
                }
                stnNoticeMsg = '⚡ Imported ${_selectedLot!.stoneItems.length} stones from Lot!';
              });
            }

            // 1-Click Import Diamonds from Lot
            void importAllDiamondsFromLot() {
              if (_selectedLot == null || _selectedLot!.diamondItems.isEmpty) return;
              setDialogState(() {
                for (final dmd in _selectedLot!.diamondItems) {
                  final purRate = dmd.rate;
                  final wt = dmd.weight;
                  final purAmt = dmd.amount > 0 ? dmd.amount : (wt * purRate);

                  // Calculate master diamond sales rate (0.0 if not in master)
                  double salesRate = 0.0;
                  double centRate = 0.0;
                  final cents = dmd.diamondUnit.toUpperCase() == 'C' ? (wt * 100.0) : (wt * 500.0);
                  final matchingDps = _diamondPriceSettings.where((dps) {
                    if (dps.productid != dmd.diamondProductId) return false;
                    if (dmd.diamondSubProductId != null && dps.subproductid != null && dps.subproductid != 0 && dps.subproductid != dmd.diamondSubProductId) return false;
                    if (dps.fromCent > 0 || dps.toCent > 0) {
                      if (cents < dps.fromCent || (dps.toCent > 0 && cents > dps.toCent)) return false;
                    }
                    return true;
                  }).toList();

                  if (matchingDps.isNotEmpty && matchingDps.first.centRate > 0) {
                    final dps = matchingDps.first;
                    centRate = dps.centRate;
                    salesRate = dmd.diamondUnit.toUpperCase() == 'C' ? (dps.centRate * 100.0) : (dps.centRate * 500.0);
                  } else {
                    final fallbackDps = _diamondPriceSettings.where((dps) => dps.productid == dmd.diamondProductId).toList();
                    if (fallbackDps.isNotEmpty && fallbackDps.first.centRate > 0) {
                      final dps = fallbackDps.first;
                      centRate = dps.centRate;
                      salesRate = dmd.diamondUnit.toUpperCase() == 'C' ? (dps.centRate * 100.0) : (dps.centRate * 500.0);
                    }
                  }
                  final salesAmt = (centRate > 0 && cents > 0) ? (cents * centRate) : (wt * salesRate);

                  tempDiamonds.add(TagDiamondItem(
                    productId: dmd.diamondProductId,
                    productName: dmd.diamondProductName,
                    subProductId: dmd.diamondSubProductId,
                    subProductName: dmd.diamondSubProductName,
                    unit: dmd.diamondUnit,
                    pcs: dmd.pcs,
                    weight: dmd.weight,
                    purRate: purRate,
                    purAmount: purAmt,
                    rate: salesRate,
                    amount: salesAmt,
                  ));
                }
                dmdNoticeMsg = '⚡ Imported ${_selectedLot!.diamondItems.length} diamonds from Lot!';
              });
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Container(
                width: 1180,
                constraints: const BoxConstraints(maxHeight: 780),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                        border: Border(bottom: BorderSide(color: Color(0xFF334155))),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.diamond_rounded, color: Color(0xFF38BDF8), size: 22),
                          const SizedBox(width: 10),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tag Stones & Diamonds Master Entry',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Stone & Diamond purchase rate auto-populated from Lot. Sales rate auto-matched from Price Setting Master.',
                                style: TextStyle(color: Colors.white60, fontSize: 11),
                              ),
                            ],
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white60),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. STONES SECTION
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.grain_rounded, size: 16, color: Color(0xFF34D399)),
                                      const SizedBox(width: 6),
                                      Text(
                                        "💎 Stones Line Items (${tempStones.length}) — Total Wt: ${_weightFmt.format(stoneTotalWt)}g ($stoneTotalPcs pcs) | Pur Cost: ₹${stoneTotalPurCost.toStringAsFixed(2)} | Sales: ₹${stoneTotalSalesAmt.toStringAsFixed(2)}",
                                        style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const Spacer(),
                                      if (_selectedLot != null && _selectedLot!.stoneItems.isNotEmpty)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669).withValues(alpha: 0.2),
                                            foregroundColor: const Color(0xFF34D399),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          icon: const Icon(Icons.download_rounded, size: 14),
                                          label: Text('⚡ Import Lot Stones (${_selectedLot!.stoneItems.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: importAllStonesFromLot,
                                        ),
                                      if (stnNoticeMsg != null) ...[
                                        const SizedBox(width: 8),
                                        Text(stnNoticeMsg!, style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Quick Add Stone Input Bar
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Row(
                                      children: [
                                        // Stone Product
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<int?>(
                                            initialValue: quickStnProductId,
                                            dropdownColor: const Color(0xFF1E293B),
                                            isExpanded: true,
                                            decoration: _buildDialogInputDecoration('Stone Product *'),
                                            items: stoneProducts.map((p) {
                                              final inLot = _selectedLot?.stoneItems.where((s) => s.stoneProductId == p.productid).toList();
                                              final lotLabel = (inLot != null && inLot.isNotEmpty && inLot.first.rate > 0)
                                                  ? ' [Lot: ₹${inLot.first.rate.toStringAsFixed(0)}]'
                                                  : '';
                                              return DropdownMenuItem<int?>(
                                                value: p.productid,
                                                child: Text(
                                                  '${p.productname}$lotLabel',
                                                  style: TextStyle(
                                                    color: lotLabel.isNotEmpty ? const Color(0xFF34D399) : Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: lotLabel.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setDialogState(() {
                                                quickStnProductId = val;
                                                final match = stoneProducts.firstWhere((p) => p.productid == val, orElse: () => stoneProducts.first);
                                                quickStnProductName = match.productname;
                                                final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
                                                lookupStoneRates(val, quickStnSubProductId, wt, quickStnUnit, setDialogState);
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Sub-product
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<int?>(
                                            initialValue: quickStnSubProductId,
                                            dropdownColor: const Color(0xFF1E293B),
                                            isExpanded: true,
                                            decoration: _buildDialogInputDecoration('Sub-Product'),
                                            items: [
                                              const DropdownMenuItem<int?>(value: null, child: Text('-- None --', style: TextStyle(color: Colors.white54, fontSize: 12))),
                                              ...matchingStnSubProducts.map((sp) {
                                                return DropdownMenuItem<int?>(value: sp.subproductid, child: Text(sp.subproductname, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis));
                                              }),
                                            ],
                                            onChanged: (val) {
                                              setDialogState(() {
                                                quickStnSubProductId = val;
                                                if (val != null) {
                                                  final sp = matchingStnSubProducts.firstWhere((s) => s.subproductid == val, orElse: () => matchingStnSubProducts.first);
                                                  quickStnSubProductName = sp.subproductname;
                                                } else {
                                                  quickStnSubProductName = '';
                                                }
                                                final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
                                                lookupStoneRates(quickStnProductId, val, wt, quickStnUnit, setDialogState);
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Unit
                                        SizedBox(
                                          width: 85,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: quickStnUnit,
                                            dropdownColor: const Color(0xFF1E293B),
                                            decoration: _buildDialogInputDecoration('Unit'),
                                            items: const [
                                              DropdownMenuItem(value: 'G', child: Text('Gram (G)', style: TextStyle(color: Colors.white, fontSize: 11))),
                                              DropdownMenuItem(value: 'C', child: Text('Carat (C)', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold))),
                                            ],
                                            onChanged: (val) {
                                              setDialogState(() => quickStnUnit = val ?? 'G');
                                              final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
                                              lookupStoneRates(quickStnProductId, quickStnSubProductId, wt, quickStnUnit, setDialogState);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Pcs
                                        SizedBox(
                                          width: 55,
                                          child: TextFormField(
                                            controller: quickStnPcsCtrl,
                                            focusNode: quickStnPcsFocus,
                                            keyboardType: TextInputType.number,
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickStnWtFocus.requestFocus(),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: _buildDialogInputDecoration('Pcs'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Weight
                                        SizedBox(
                                          width: 75,
                                          child: TextFormField(
                                            controller: quickStnWtCtrl,
                                            focusNode: quickStnWtFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickStnPurRateFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Weight *'),
                                            onChanged: (v) {
                                              final wt = double.tryParse(v.trim()) ?? 0.0;
                                              lookupStoneRates(quickStnProductId, quickStnSubProductId, wt, quickStnUnit, setDialogState);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Purchase Rate (₹) from Lot
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            controller: quickStnPurRateCtrl,
                                            focusNode: quickStnPurRateFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickStnPurAmtFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Pur Rate'),
                                            onChanged: (v) {
                                              final pr = double.tryParse(v.trim()) ?? 0.0;
                                              final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
                                              if (wt > 0) quickStnPurAmtCtrl.text = (wt * pr).toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Purchase Amount (₹)
                                        SizedBox(
                                          width: 85,
                                          child: TextFormField(
                                            controller: quickStnPurAmtCtrl,
                                            focusNode: quickStnPurAmtFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickStnSalesRateFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Pur Amt (₹)'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Sales Rate (₹) from Master
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            controller: quickStnSalesRateCtrl,
                                            focusNode: quickStnSalesRateFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickStnSalesAmtFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Sales Rate'),
                                            onChanged: (v) {
                                              final sr = double.tryParse(v.trim()) ?? 0.0;
                                              final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
                                              if (wt > 0) quickStnSalesAmtCtrl.text = (wt * sr).toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Sales Amount (₹)
                                        SizedBox(
                                          width: 85,
                                          child: TextFormField(
                                            controller: quickStnSalesAmtCtrl,
                                            focusNode: quickStnSalesAmtFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => addQuickStone(),
                                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Sales Amt (₹)'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Add Button
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF059669),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('+ Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: addQuickStone,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Table of Added Stones
                                  if (tempStones.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Column(
                                        children: [
                                          ...tempStones.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final item = entry.value;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: index < tempStones.length - 1 ? const Color(0xFF1E293B) : Colors.transparent)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text('#${index + 1}', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11)),
                                                  const SizedBox(width: 10),
                                                  Expanded(flex: 3, child: Text(item.productName ?? 'Stone Item', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                                  Expanded(flex: 2, child: Text(item.subProductName ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                                  Text('${item.pcs} pcs | ${_weightFmt.format(item.weight)} ${item.unit} (-${_weightFmt.format(item.weightInGrams)}g)', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4))),
                                                    child: Text('Pur: ₹${item.purRate}/u = ₹${item.purAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF34D399), fontSize: 10.5, fontWeight: FontWeight.w600)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFFD97706).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFD97706).withValues(alpha: 0.4))),
                                                    child: Text('Sales: ₹${item.rate}/u = ₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Focus(
                                                    canRequestFocus: false,
                                                    skipTraversal: true,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => setDialogState(() => tempStones.removeAt(index)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 2. DIAMONDS SECTION
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.diamond_outlined, size: 16, color: Color(0xFF38BDF8)),
                                      const SizedBox(width: 6),
                                      Text(
                                        "✨ Diamonds Line Items (${tempDiamonds.length}) — Total Wt: ${_weightFmt.format(diamondTotalWt)}ct ($diamondTotalPcs pcs) | Pur Cost: ₹${diamondTotalPurCost.toStringAsFixed(2)} | Sales: ₹${diamondTotalSalesAmt.toStringAsFixed(2)}",
                                        style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                                      ),
                                      const Spacer(),
                                      if (_selectedLot != null && _selectedLot!.diamondItems.isNotEmpty)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                            foregroundColor: const Color(0xFF38BDF8),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          icon: const Icon(Icons.download_rounded, size: 14),
                                          label: Text('⚡ Import Lot Diamonds (${_selectedLot!.diamondItems.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: importAllDiamondsFromLot,
                                        ),
                                      if (dmdNoticeMsg != null) ...[
                                        const SizedBox(width: 8),
                                        Text(dmdNoticeMsg!, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 10),

                                  // Quick Add Diamond Input Bar
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF334155)),
                                    ),
                                    child: Row(
                                      children: [
                                        // Diamond Product
                                        Expanded(
                                          flex: 3,
                                          child: DropdownButtonFormField<int?>(
                                            initialValue: quickDmdProductId,
                                            dropdownColor: const Color(0xFF1E293B),
                                            isExpanded: true,
                                            decoration: _buildDialogInputDecoration('Diamond Product *'),
                                            items: diamondProducts.map((p) {
                                              final inLot = _selectedLot?.diamondItems.where((d) => d.diamondProductId == p.productid).toList();
                                              final lotLabel = (inLot != null && inLot.isNotEmpty && inLot.first.rate > 0)
                                                  ? ' [Lot: ₹${inLot.first.rate.toStringAsFixed(0)}]'
                                                  : '';
                                              return DropdownMenuItem<int?>(
                                                value: p.productid,
                                                child: Text(
                                                  '${p.productname}$lotLabel',
                                                  style: TextStyle(
                                                    color: lotLabel.isNotEmpty ? const Color(0xFF38BDF8) : Colors.white,
                                                    fontSize: 12,
                                                    fontWeight: lotLabel.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              );
                                            }).toList(),
                                            onChanged: (val) {
                                              setDialogState(() {
                                                quickDmdProductId = val;
                                                final match = diamondProducts.firstWhere((p) => p.productid == val, orElse: () => diamondProducts.first);
                                                quickDmdProductName = match.productname;
                                                final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
                                                lookupDiamondRates(val, quickDmdSubProductId, wt, quickDmdUnit, setDialogState);
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Sub-product
                                        Expanded(
                                          flex: 2,
                                          child: DropdownButtonFormField<int?>(
                                            initialValue: quickDmdSubProductId,
                                            dropdownColor: const Color(0xFF1E293B),
                                            isExpanded: true,
                                            decoration: _buildDialogInputDecoration('Sub-Product'),
                                            items: [
                                              const DropdownMenuItem<int?>(value: null, child: Text('-- None --', style: TextStyle(color: Colors.white54, fontSize: 12))),
                                              ...matchingDmdSubProducts.map((sp) {
                                                return DropdownMenuItem<int?>(value: sp.subproductid, child: Text(sp.subproductname, style: const TextStyle(color: Colors.white, fontSize: 12), overflow: TextOverflow.ellipsis));
                                              }),
                                            ],
                                            onChanged: (val) {
                                              setDialogState(() {
                                                quickDmdSubProductId = val;
                                                if (val != null) {
                                                  final sp = matchingDmdSubProducts.firstWhere((s) => s.subproductid == val, orElse: () => matchingDmdSubProducts.first);
                                                  quickDmdSubProductName = sp.subproductname;
                                                } else {
                                                  quickDmdSubProductName = '';
                                                }
                                                final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
                                                lookupDiamondRates(quickDmdProductId, val, wt, quickDmdUnit, setDialogState);
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Unit
                                        SizedBox(
                                          width: 85,
                                          child: DropdownButtonFormField<String>(
                                            initialValue: quickDmdUnit,
                                            dropdownColor: const Color(0xFF1E293B),
                                            decoration: _buildDialogInputDecoration('Unit'),
                                            items: const [
                                              DropdownMenuItem(value: 'C', child: Text('Carat (C)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold))),
                                              DropdownMenuItem(value: 'G', child: Text('Gram (G)', style: TextStyle(color: Colors.white, fontSize: 11))),
                                            ],
                                            onChanged: (val) {
                                              setDialogState(() => quickDmdUnit = val ?? 'C');
                                              final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
                                              lookupDiamondRates(quickDmdProductId, quickDmdSubProductId, wt, quickDmdUnit, setDialogState);
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Pcs
                                        SizedBox(
                                          width: 55,
                                          child: TextFormField(
                                            controller: quickDmdPcsCtrl,
                                            focusNode: quickDmdPcsFocus,
                                            keyboardType: TextInputType.number,
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickDmdWtFocus.requestFocus(),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: _buildDialogInputDecoration('Pcs'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Carats / Weight (triggers diamond rate lookups)
                                        SizedBox(
                                          width: 75,
                                          child: TextFormField(
                                            controller: quickDmdWtCtrl,
                                            focusNode: quickDmdWtFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickDmdPurRateFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Carats *'),
                                            onChanged: (v) {
                                              final wt = double.tryParse(v.trim()) ?? 0.0;
                                              lookupDiamondRates(quickDmdProductId, quickDmdSubProductId, wt, quickDmdUnit, setDialogState);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Pur Rate (₹) from Lot
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            controller: quickDmdPurRateCtrl,
                                            focusNode: quickDmdPurRateFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickDmdPurAmtFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Pur Rate'),
                                            onChanged: (v) {
                                              final pr = double.tryParse(v.trim()) ?? 0.0;
                                              final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
                                              if (wt > 0) quickDmdPurAmtCtrl.text = (wt * pr).toStringAsFixed(2);
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Pur Amount (₹)
                                        SizedBox(
                                          width: 85,
                                          child: TextFormField(
                                            controller: quickDmdPurAmtCtrl,
                                            focusNode: quickDmdPurAmtFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickDmdSalesRateFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Pur Amt (₹)'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Sales Rate (₹/ct or ₹/cent) from Master
                                        SizedBox(
                                          width: 80,
                                          child: TextFormField(
                                            controller: quickDmdSalesRateCtrl,
                                            focusNode: quickDmdSalesRateFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) => quickDmdSalesAmtFocus.requestFocus(),
                                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Sales Rate'),
                                            onChanged: (v) {
                                              final rate = double.tryParse(v.trim()) ?? 0.0;
                                              final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
                                              if (wt > 0) {
                                                quickDmdSalesAmtCtrl.text = (wt * rate).toStringAsFixed(2);
                                              }
                                              setDialogState(() {});
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Sales Amount (₹)
                                        SizedBox(
                                          width: 85,
                                          child: TextFormField(
                                            controller: quickDmdSalesAmtCtrl,
                                            focusNode: quickDmdSalesAmtFocus,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => addQuickDiamond(),
                                            style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                            decoration: _buildDialogInputDecoration('Sales Amt (₹)'),
                                          ),
                                        ),
                                        const SizedBox(width: 6),

                                        // Add Button
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF0284C7),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                          ),
                                          icon: const Icon(Icons.add, size: 16),
                                          label: const Text('+ Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                          onPressed: addQuickDiamond,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Table of Added Diamonds
                                  if (tempDiamonds.isNotEmpty)
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Column(
                                        children: [
                                          ...tempDiamonds.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final item = entry.value;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                border: Border(bottom: BorderSide(color: index < tempDiamonds.length - 1 ? const Color(0xFF1E293B) : Colors.transparent)),
                                              ),
                                              child: Row(
                                                children: [
                                                  Text('#${index + 1}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                                                  const SizedBox(width: 10),
                                                  Expanded(flex: 3, child: Text(item.productName ?? 'Diamond Item', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                                  Expanded(flex: 2, child: Text(item.subProductName ?? '-', style: const TextStyle(color: Colors.white70, fontSize: 11))),
                                                  Text('${item.pcs} pcs | ${_weightFmt.format(item.weight)} ${item.unit} (-${_weightFmt.format(item.weightInGrams)}g)', style: const TextStyle(color: Color(0xFF34D399), fontSize: 11)),
                                                  const SizedBox(width: 12),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFF059669).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4))),
                                                    child: Text('Pur: ₹${item.purRate}/ct = ₹${item.purAmount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF34D399), fontSize: 10.5, fontWeight: FontWeight.w600)),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(color: const Color(0xFF0284C7).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4))),
                                                    child: Text('Sales: ₹${item.rate}/ct = ₹${item.amount.toStringAsFixed(2)}', style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.bold)),
                                                  ),
                                                  const SizedBox(width: 10),
                                                  Focus(
                                                    canRequestFocus: false,
                                                    skipTraversal: true,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      onPressed: () => setDialogState(() => tempDiamonds.removeAt(index)),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 3. OTHER LESS WEIGHT
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0xFF334155)),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.tune_rounded, size: 16, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  const Text('Other Deductions / Less Weight (Enamel, Wax, Thread):', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                  const SizedBox(width: 14),
                                  SizedBox(
                                    width: 120,
                                    child: TextFormField(
                                      controller: tempOtherLessCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                      decoration: _buildDialogInputDecoration('Other Less (g)'),
                                      onChanged: (_) => setDialogState(() {}),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // 4. LIVE SUMMARY BAR
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.6)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Gross Weight', style: TextStyle(color: Colors.white60, fontSize: 11)),
                                      Text('${_weightFmt.format(grs)} g', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Text('—', style: TextStyle(color: Colors.white60, fontSize: 18, fontWeight: FontWeight.bold)),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Total Less Wt', style: TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold)),
                                      Text('- ${_weightFmt.format(totalLessGrams)} g', style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const Text('=', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF34D399)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('NET GOLD WEIGHT', style: TextStyle(color: Color(0xFF34D399), fontSize: 10, fontWeight: FontWeight.w900)),
                                        Text('${_weightFmt.format(netWeightGrams)} g', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  // Total Purchase Cost
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF059669).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('TOTAL PUR COST', style: TextStyle(color: Color(0xFF34D399), fontSize: 9.5, fontWeight: FontWeight.w800)),
                                        Text('₹ ${_currencyFmt.format(totalCombinedPurCost)}', style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                  // Total Sales Amount
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: GlassTheme.accentAmber.withValues(alpha: 0.4)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        const Text('TOTAL SALES VALUE', style: TextStyle(color: GlassTheme.accentAmber, fontSize: 9.5, fontWeight: FontWeight.w800)),
                                        Text('₹ ${_currencyFmt.format(totalCombinedSalesAmt)}', style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 13, fontWeight: FontWeight.w900)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer Actions
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1E293B),
                        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        border: Border(top: BorderSide(color: Color(0xFF334155))),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF64748B)),
                              foregroundColor: Colors.white70,
                            ),
                            onPressed: () {
                              Navigator.pop(ctx, {
                                'stones': <TagStoneItem>[],
                                'diamonds': <TagDiamondItem>[],
                                'other_less_weight': 0.0,
                                'total_less_weight': 0.0,
                                'net_weight': grs,
                                'stone_purchase_cost': 0.0,
                                'diamond_purchase_cost': 0.0,
                                'stone_sales_amount': 0.0,
                                'diamond_sales_amount': 0.0,
                              });
                            },
                            child: const Text('Clear All (0 Less Wt)'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                            label: const Text('Apply & Done (Enter)', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.pop(ctx, {
                                'stones': tempStones,
                                'diamonds': tempDiamonds,
                                'other_less_weight': otherLessGrams,
                                'total_less_weight': totalLessGrams,
                                'net_weight': netWeightGrams,
                                'stone_purchase_cost': stoneTotalPurCost,
                                'diamond_purchase_cost': diamondTotalPurCost,
                                'stone_sales_amount': stoneTotalSalesAmt,
                                'diamond_sales_amount': diamondTotalSalesAmt,
                              });
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

    if (result != null) {
      setState(() {
        _stoneItems = (result['stones'] as List<TagStoneItem>?) ?? [];
        _diamondItems = (result['diamonds'] as List<TagDiamondItem>?) ?? [];
        _otherLessWeightController.text = _weightFmt.format(result['other_less_weight'] as double? ?? 0.0);
        _calculatedLessWeight = result['total_less_weight'] as double? ?? 0.0;
        _netWeightController.text = _weightFmt.format(result['net_weight'] as double? ?? grs);

        // Auto sync stone & diamond purchase costs in Column 3 from puramt!
        _purchaseStoneCostController.text = _totalStonePurchaseCost > 0 ? _totalStonePurchaseCost.toStringAsFixed(2) : '0.00';
        _purchaseDmdCostController.text = _totalDiamondPurchaseCost > 0 ? _totalDiamondPurchaseCost.toStringAsFixed(2) : '0.00';
      });

      _showToast('✓ Net: ${_netWeightController.text}g | Stone Pur Cost: ₹${_purchaseStoneCostController.text} | Dia Pur Cost: ₹${_purchaseDmdCostController.text}');
      _netWeightFocusNode.requestFocus();
    }
  }

  InputDecoration _buildDialogInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
      filled: true,
      fillColor: const Color(0xFF0F172A),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      isDense: true,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: Color(0xFF334155)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: const BorderSide(color: GlassTheme.accentAmber, width: 2.0),
      ),
    );
  }

  // --- Real-time Calculations for the Piece Entry ---
  double get _currentPieceGrossWt => double.tryParse(_grossWeightController.text) ?? 0.0;
  double get _currentPieceNetWt => double.tryParse(_netWeightController.text) ?? _currentPieceGrossWt;
  double get _currentBoardRate => double.tryParse(_boardRateController.text) ?? 0.0;
  double get _currentSalesVaPct => double.tryParse(_salesVaController.text) ?? 0.0;
  double get _currentSalesWstPct => double.tryParse(_salesWastageController.text) ?? 0.0;
  double get _currentSalesMcG => double.tryParse(_salesMcGSimpleController.text) ?? 0.0;
  double get _currentSalesMCharge => double.tryParse(_salesMChargeController.text) ?? 0.0;
  double get _currentStoneAmt => _totalStoneSalesAmount;
  double get _currentDiamondAmt => _totalDiamondSalesAmount;

  double get _pieceSalesGoldValue => _currentPieceNetWt * _currentBoardRate;
  double get _pieceSalesVaAmt => _pieceSalesGoldValue * (_currentSalesVaPct / 100.0);
  double get _pieceSalesWstAmt => _pieceSalesGoldValue * (_currentSalesWstPct / 100.0);
  double get _pieceSalesMcAmt => (_currentPieceNetWt * _currentSalesMcG) + _currentSalesMCharge;
  double get _pieceCalculatedSalesPrice =>
      _pieceSalesGoldValue + _pieceSalesVaAmt + _pieceSalesWstAmt + _pieceSalesMcAmt + _currentStoneAmt + _currentDiamondAmt;

  // Smith Costing
  double get _purchaseTouchPct => double.tryParse(_purchaseTouchController.text) ?? 94.0;
  double get _purchaseGoldRate => double.tryParse(_purchaseGoldRateController.text) ?? _currentBoardRate;
  double get _purchaseMcAmt => double.tryParse(_purchaseMcController.text) ?? 0.0;
  double get _purchaseWastagePct => double.tryParse(_purchaseWastageController.text) ?? 0.0;
  double get _purchaseStoneCost => double.tryParse(_purchaseStoneCostController.text) ?? 0.0;
  double get _purchaseDmdCost => double.tryParse(_purchaseDmdCostController.text) ?? 0.0;

  double get _piecePurchaseGoldCost =>
      _purchaseTouchPct > 0 ? (_currentPieceNetWt * (_purchaseTouchPct / 100.0) * _purchaseGoldRate) : (_currentPieceNetWt * _purchaseGoldRate);
  double get _piecePurchaseWastageCost => _piecePurchaseGoldCost * (_purchaseWastagePct / 100.0);
  double get _pieceCalculatedPurchaseCost =>
      _piecePurchaseGoldCost + _piecePurchaseWastageCost + _purchaseMcAmt + _purchaseStoneCost + _purchaseDmdCost;

  double get _pieceEstimatedMargin => _pieceCalculatedSalesPrice - _pieceCalculatedPurchaseCost;
  double get _pieceMarginPct =>
      _pieceCalculatedSalesPrice > 0 ? ((_pieceEstimatedMargin / _pieceCalculatedSalesPrice) * 100.0) : 0.0;

  // --- Actions ---

  /// Saves a single piece tag, generates next sequential SKU code, adds to table, and resets weight for next piece!
  Future<void> _saveAndTagSinglePiece({bool andPrint = false}) async {
    if (_selectedLot == null) {
      _showToast('Please select an Item Lot first.', isError: true);
      return;
    }

    if (_selectedBranch == null) {
      _showToast('Please select a Target Branch for this tag.', isError: true);
      return;
    }

    if (_selectedLot!.isAssorted.toUpperCase() == 'YES' && _selectedProduct == null) {
      _showToast('Assorted Lot: Please select an Item Name from the dropdown first.', isError: true);
      return;
    }

    final grs = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    if (grs <= 0) {
      _showToast('Please enter a valid Gross Weight (e.g. 10.250g)', isError: true);
      _grossWeightFocusNode.requestFocus();
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    setState(() => _isSaving = true);

    final payload = {
      'lot_id': _selectedLot!.lotId,
      'branchid': _selectedBranch!.branchId,
      'productid': _effectiveProductId,
      'subproductid': _effectiveSubProductId,
      'pcs': int.tryParse(_pcsController.text) ?? 1,
      'gross_weight': grs,
      'net_weight': _currentPieceNetWt,
      'styleid': _selectedStyle?.styleid,
      'stylename': _selectedStyle?.stylename ?? '',
      'sizeid': _selectedSize?.sizeid,
      'sizename': _selectedSize?.sizename ?? '',
      'purityid': _selectedPurity?.purityid ?? _selectedLot!.purityid,
      'stone_pcs': _totalStonePcs,
      'stone_weight': _totalStoneWeight,
      'stone_amt': _totalStoneSalesAmount,
      'stone_details': _stoneItems.map((s) => s.toJson()).toList(),
      'diamond_pcs': _totalDiamondPcs,
      'diamond_weight': _totalDiamondWeight,
      'diamond_amt': _totalDiamondSalesAmount,
      'diamond_details': _diamondItems.map((d) => d.toJson()).toList(),
      'board_rate': _currentBoardRate,
      'sales_va_percent': _currentSalesVaPct,
      'sales_wastage': _currentSalesWstPct,
      'sales_mc_per_gram': _currentSalesMcG,
      'sales_m_charge': _currentSalesMCharge,
      'sales_total_amt': _pieceCalculatedSalesPrice,
      'purchase_touch_pct': _purchaseTouchPct,
      'purchase_gold_rate': _purchaseGoldRate,
      'purchase_mc': _purchaseMcAmt,
      'purchase_stone_cost': _purchaseStoneCost,
      'purchase_diamond_cost': _purchaseDmdCost,
      'purchase_total_cost': _pieceCalculatedPurchaseCost,
      'huid': _huidController.text.trim(),
      'remarks': _remarksController.text.trim(),
    };

    final res = await _api.generateTagsFromLot(token, payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        final sku = res['first_sku'] ?? 'SKU Tag';
        final itemLabel = _effectiveSubProductName.isNotEmpty ? '$_effectiveProductName - $_effectiveSubProductName' : _effectiveProductName;
        _showToast('✓ Generated $sku ($itemLabel) successfully!');

        // Reload tags
        final tagsRes = await _api.getStockTags(token);
        if (mounted && tagsRes['success'] == true && tagsRes['tags'] != null) {
          setState(() {
            _taggedItems = (tagsRes['tags'] as List)
                .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
                .toList();
          });

          // Print if requested
          if (andPrint && _selectedTemplate != null) {
            final newTag = _taggedItems.firstWhere((t) => t.skuCode == sku, orElse: () => _taggedItems.last);
            BarcodePrinterService.directPrint(
              template: _selectedTemplate!,
              items: [newTag],
              jobName: 'Tag_$sku',
            );
            _api.markStockTagsPrinted(token, itemIds: [newTag.itemId]);
          }
        }

        // Clean inputs and reset focus for the next piece tag!
        setState(() {
          _grossWeightController.clear();
          _netWeightController.clear();
          _stoneItems = [];
          _diamondItems = [];
          _calculatedLessWeight = 0.0;
          _otherLessWeightController.text = '0.000';
          _huidController.clear();
          _remarksController.clear();
        });

        _grossWeightFocusNode.requestFocus();
      } else {
        _showToast(res['message'] ?? 'Failed to tag piece.', isError: true);
      }
    }
  }

  void _showLotPickerDialog() {
    String lotSearchQuery = '';
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final activeLots = _allLots.where((l) => l.isActive && l.status.toUpperCase() != 'DISABLED').toList();
            final filteredLots = activeLots.where((lot) {
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
                      color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: GlassTheme.accentAmber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Select Prepare SKU Lot', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      Text('${activeLots.length} active lots available', style: const TextStyle(color: Colors.white60, fontSize: 12)),
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
                width: 640,
                height: 480,
                child: Column(
                  children: [
                    TextField(
                      autofocus: true,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search by Lot No (e.g. 2627-1), Smith, Item...',
                        hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                        prefixIcon: const Icon(Icons.search, color: Colors.white70),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.white24)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onChanged: (val) => setDialogState(() => lotSearchQuery = val),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filteredLots.isEmpty
                          ? const Center(
                              child: Text('No matching SKU lots found.', style: TextStyle(color: Colors.white60)),
                            )
                          : ListView.separated(
                              itemCount: filteredLots.length,
                              separatorBuilder: (context, index) => const SizedBox(height: 8),
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
                                      color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.25) : const Color(0xFF0F172A),
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
                                            color: GlassTheme.accentAmber.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Lot ${lot.lotNumber}',
                                            style: const TextStyle(color: GlassTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 13),
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
                                                  if (lot.isAssorted.toUpperCase() == 'YES') ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFF59E0B)),
                                                      ),
                                                      child: const Text('ASSORTED', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 9, fontWeight: FontWeight.bold)),
                                                    ),
                                                  ],
                                                  const Spacer(),
                                                  Text(
                                                    '${lot.totalPcs} Pcs | ${_weightFmt.format(lot.totalGrossWeight)}g',
                                                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Smith: ${lot.designername ?? 'N/A'} | Sub: ${lot.subproductname ?? '-'} | Branch: ${lot.branchname ?? lot.branchid}',
                                                style: const TextStyle(color: Colors.white70, fontSize: 11),
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

  void _showToast(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF059669),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // --- Main Build ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: GlassTheme.bgDark,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayedTags = (_filterOnlyCurrentLot && _selectedLot != null
            ? _currentLotTaggedItems
            : _taggedItems)
        .where((t) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final match = t.skuCode.toLowerCase().contains(q) ||
            t.lotNumber.toLowerCase().contains(q) ||
            t.productName.toLowerCase().contains(q) ||
            t.styleName.toLowerCase().contains(q) ||
            t.sizeName.toLowerCase().contains(q) ||
            t.purityName.toLowerCase().contains(q) ||
            t.designerName.toLowerCase().contains(q) ||
            t.huid.toLowerCase().contains(q);
        if (!match) return false;
      }
      return true;
    }).toList();

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.f9): () {
          if (!_isSaving && _selectedLot != null) {
            _saveAndTagSinglePiece(andPrint: true);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyP, control: true): () {
          if (!_isSaving && _selectedLot != null) {
            _saveAndTagSinglePiece(andPrint: true);
          }
        },
        const SingleActivator(LogicalKeyboardKey.f8): () {
          if (!_isSaving && _selectedLot != null) {
            _saveAndTagSinglePiece(andPrint: false);
          }
        },
        const SingleActivator(LogicalKeyboardKey.f2): () {
          if (_grossWeightFocusNode.canRequestFocus) {
            _grossWeightFocusNode.requestFocus();
          }
        },
      },
      child: Scaffold(
        backgroundColor: GlassTheme.bgDark,
        body: SafeArea(
          child: Column(
            children: [
              // 1. Top Navigation Bar
              _buildTopActionBar(),

              // 2. Main Scrollable Content: 3-Column Tagging Station & Tagged Table
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 3-COLUMN TAGGING WORKSPACE
                      _buildMainThreeColumnWorkspace(),
                      const SizedBox(height: 20),

                      // BOTTOM TAGGED ITEMS TABLE
                      _buildBottomTaggedTableSection(displayedTags),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: GlassTheme.bgSurface,
        border: Border(bottom: BorderSide(color: GlassTheme.glassBorder)),
      ),
      child: Row(
        children: [
          if (widget.onBack != null) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, color: GlassTheme.textPrimary),
              onPressed: widget.onBack,
              tooltip: 'Back',
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock Barcode & Item Tagging Station',
                style: TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                '3-Column Workflow: Pending Lot Details | Sales & Stone Entry | Smith Purchase Costing & 1-Click Print',
                style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),

          // Target Branch Selector Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: GlassTheme.bgSurfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF0284C7)),
                const SizedBox(width: 6),
                const Text('Tag Branch: ', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11.5, fontWeight: FontWeight.bold)),
                DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedBranch?.branchId,
                    dropdownColor: Colors.white,
                    hint: const Text('Select Branch', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
                    items: _allBranches.map((b) {
                      return DropdownMenuItem<String>(
                        value: b.branchId,
                        child: Text(
                          '${b.branchName} (${b.branchId})',
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    }).toList(),
                    onChanged: (bId) {
                      if (bId != null) {
                        final found = _allBranches.firstWhere((b) => b.branchId == bId);
                        setState(() => _selectedBranch = found);
                        final grs = double.tryParse(_grossWeightController.text) ?? 10.0;
                        _lookupVaForWeight(grs);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Template Designer Button
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: GlassTheme.accentAmber),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.design_services_rounded, size: 16, color: GlassTheme.accentAmber),
            label: const Text('Barcode Template Designer',
                style: TextStyle(color: GlassTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _openTemplateDesigner,
          ),
          const SizedBox(width: 10),

          // Reload Button
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: GlassTheme.textSecondary),
            tooltip: 'Reload Data',
            onPressed: _loadInitialData,
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 3-COLUMN TAGGING WORKSPACE
  // =========================================================================
  Widget _buildMainThreeColumnWorkspace() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1000;
        if (isNarrow) {
          // Responsive fallback for small windows
          return Column(
            children: [
              _buildColumn1LotDetails(),
              const SizedBox(height: 14),
              _buildColumn2SalesEntry(),
              const SizedBox(height: 14),
              _buildColumn3PurchaseCosting(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // COLUMN 1: Pending Lot Selection & Summary (flex: 3)
            Expanded(
              flex: 3,
              child: _buildColumn1LotDetails(),
            ),
            const SizedBox(width: 14),

            // COLUMN 2: Sales & Piece Tag Entry (flex: 4)
            Expanded(
              flex: 4,
              child: _buildColumn2SalesEntry(),
            ),
            const SizedBox(width: 14),

            // COLUMN 3: Purchase Cost Details & Action Buttons (flex: 3)
            Expanded(
              flex: 3,
              child: _buildColumn3PurchaseCosting(),
            ),
          ],
        );
      },
    );
  }

  // ================= COLUMN 1: LOT DETAILS & PENDING CARD =================
  Widget _buildColumn1LotDetails() {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlassTheme.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 1 Header: Lot Selector & Search
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.inventory_2_rounded, color: GlassTheme.accentAmber, size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Column 1: Lot Details',
                      style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Select lot to start tagging',
                      style: TextStyle(color: GlassTheme.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, size: 18, color: GlassTheme.accentAmber),
                tooltip: 'Search & Pick Lot',
                onPressed: _showLotPickerDialog,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Quick Lot Dropdown
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: GlassTheme.bgSurfaceMuted,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: GlassTheme.glassBorder),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedLot?.lotId,
                isExpanded: true,
                dropdownColor: Colors.white,
                hint: const Text('⚡ Select SKU Lot...', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('-- Select Lot --', style: TextStyle(fontSize: 12, color: GlassTheme.textMuted)),
                  ),
                  ..._allLots.where((lot) => lot.isActive && lot.status.toUpperCase() != 'DISABLED').map((lot) {
                    return DropdownMenuItem<int?>(
                      value: lot.lotId,
                      child: Text(
                        'Lot ${lot.lotNumber} - ${lot.productname ?? 'Item'} (${lot.totalPcs} pcs)',
                        style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
                onChanged: (id) {
                  if (id != null) {
                    final chosen = _allLots.firstWhere((l) => l.lotId == id);
                    _onLotSelected(chosen);
                  } else {
                    setState(() => _selectedLot = null);
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Pending Lot Information Card
          if (_selectedLot == null)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  Icon(Icons.touch_app_rounded, size: 32, color: GlassTheme.accentAmber.withValues(alpha: 0.6)),
                  const SizedBox(height: 8),
                  const Text('No Lot Selected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569))),
                  const SizedBox(height: 4),
                  const Text(
                    'Pick a lot from above to load ornament & smith details.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Lot Number & Item Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: GlassTheme.accentAmber.withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'Lot ${_selectedLot!.lotNumber}',
                          style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                      Row(
                        children: [
                          if (_selectedLot!.isAssorted.toUpperCase() == 'YES') ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFFF59E0B)),
                              ),
                              child: const Text('ASSORTED', style: TextStyle(color: Color(0xFFB45309), fontSize: 9.5, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Text(
                            _selectedLot!.purityname ?? '22K',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF0F172A)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  Text(
                    _selectedLot!.isAssorted.toUpperCase() == 'YES'
                        ? 'Assorted Lot: Multi-Item Tagging'
                        : '${_selectedLot!.productname ?? 'Ornament'} ${_selectedLot!.subproductname != null ? "- ${_selectedLot!.subproductname}" : ""}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Smith: ${_selectedLot!.designername ?? 'N/A'}',
                          style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                        ),
                      ),
                      Text(
                        'Branch: ${_selectedBranch?.branchName ?? _selectedLot!.branchid}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                      ),
                    ],
                  ),
                  if (_selectedLot!.rate > 0) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Lot Rate: ₹ ${_currencyFmt.format(_selectedLot!.rate)} /g',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                    ),
                  ],
                  const Divider(height: 16, color: Color(0xFFE2E8F0)),

                  // Lot Metrics: Total, Tagged, Remaining
                  _buildCompactKpiRow('Total in Lot', '$_lotTotalPcs pcs', '${_weightFmt.format(_lotTotalGrossWeight)}g', const Color(0xFF64748B)),
                  const SizedBox(height: 4),
                  _buildCompactKpiRow('Tagged Pieces', '$_taggedPcsCount pcs', '${_weightFmt.format(_taggedGrossWeight)}g', const Color(0xFF059669)),
                  const SizedBox(height: 4),
                  _buildCompactKpiRow('Pending Remaining', '$_remainingPcs pcs', '${_weightFmt.format(_remainingGrossWeight)}g', const Color(0xFFD97706), isBold: true),
                  const SizedBox(height: 10),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _taggingProgress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _taggingProgress >= 1.0 ? const Color(0xFF059669) : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${(_taggingProgress * 100).toStringAsFixed(0)}% Tagged',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                    ),
                  ),

                  // Lot Stones & Diamonds Preview with Purchase Rates
                  if (_selectedLot!.stoneItems.isNotEmpty || _selectedLot!.diamondItems.isNotEmpty) ...[
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),
                    Row(
                      children: [
                        const Icon(Icons.diamond_rounded, size: 13, color: Color(0xFF0284C7)),
                        const SizedBox(width: 4),
                        Text(
                          'Lot Stones & Diamonds (${_selectedLot!.stoneItems.length + _selectedLot!.diamondItems.length})',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        ..._selectedLot!.stoneItems.map((s) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF059669).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '💎 ${s.stoneProductName ?? 'Stone'}: ${_weightFmt.format(s.weight)}${s.stoneUnit} @ ₹${s.rate.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF059669), fontWeight: FontWeight.bold),
                          ),
                        )),
                        ..._selectedLot!.diamondItems.map((d) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            '✨ ${d.diamondProductName ?? 'Dia'}: ${_weightFmt.format(d.weight)}${d.diamondUnit} @ ₹${d.rate.toStringAsFixed(0)}',
                            style: const TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold),
                          ),
                        )),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactKpiRow(String label, String pcs, String wt, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: isBold ? const Color(0xFF0F172A) : const Color(0xFF64748B), fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
        Row(
          children: [
            Text(pcs, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            const Text(' | ', style: TextStyle(fontSize: 10, color: Color(0xFFCBD5E1))),
            Text(wt, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ],
    );
  }

  // ================= COLUMN 2: SALES & PIECE TAG ENTRY =================
  Widget _buildColumn2SalesEntry() {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlassTheme.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 2 Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GlassTheme.primaryNeon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.sell_rounded, color: GlassTheme.primaryNeon, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Column 2: Sales & Piece Entry (#${_taggedPcsCount + 1})',
                      style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const Text(
                      'Gross Wt -> Stones (Enter) -> Sales Pricing',
                      style: TextStyle(color: GlassTheme.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
              if (_isSearchingVa)
                const Row(
                  children: [
                    SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
                    SizedBox(width: 4),
                    Text('Auto VA...', style: TextStyle(fontSize: 10, color: Color(0xFF0284C7))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ITEM / PRODUCT SELECTION (Assorted Lot Dropdown vs Standard Lot Fixed Banner)
          if (_selectedLot != null) ...[
            if (_selectedLot!.isAssorted.toUpperCase() == 'YES') ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('ASSORTED LOT', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Choose Item Name from dropdown for this tag *',
                            style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Item / Product Name Dropdown
                        Expanded(
                          flex: 6,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Item / Product Name *', style: TextStyle(color: Color(0xFF92400E), fontSize: 10.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: _selectedProduct == null ? Colors.red.shade400 : const Color(0xFFF59E0B),
                                    width: _selectedProduct == null ? 1.5 : 1.0,
                                  ),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: _selectedProduct?.productid,
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                    hint: const Text('⚡ Choose Item Name...', style: TextStyle(color: Color(0xFFD97706), fontSize: 12, fontWeight: FontWeight.bold)),
                                    items: _ornamentProducts.map((p) {
                                      return DropdownMenuItem<int>(
                                        value: p.productid,
                                        child: Text(
                                          p.productname,
                                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      );
                                    }).toList(),
                                    onChanged: (pId) {
                                      if (pId != null) {
                                        final match = _ornamentProducts.firstWhere((p) => p.productid == pId);
                                        setState(() {
                                          _selectedProduct = match;
                                          _selectedSubProduct = null;
                                          final styles = _allStyles.where((s) => s.productid == match.productid).toList();
                                          _selectedStyle = styles.isNotEmpty ? styles.first : null;
                                          final sizes = _allSizes.where((s) => s.productid == match.productid).toList();
                                          _selectedSize = sizes.isNotEmpty ? sizes.first : null;
                                        });
                                        final grs = double.tryParse(_grossWeightController.text) ?? 10.0;
                                        _lookupVaForWeight(grs);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Sub-Product Dropdown
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Sub-Product', style: TextStyle(color: Color(0xFF92400E), fontSize: 10.5, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 3),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFCBD5E1)),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int?>(
                                    value: _selectedSubProduct?.subproductid,
                                    isExpanded: true,
                                    dropdownColor: Colors.white,
                                    hint: const Text('None', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                                    items: [
                                      const DropdownMenuItem<int?>(value: null, child: Text('None', style: TextStyle(fontSize: 11, color: GlassTheme.textMuted))),
                                      ..._availableSubProducts.map((sp) => DropdownMenuItem<int?>(
                                        value: sp.subproductid,
                                        child: Text(sp.subproductname, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                      )),
                                    ],
                                    onChanged: (spId) {
                                      setState(() {
                                        _selectedSubProduct = spId != null ? _availableSubProducts.firstWhere((sp) => sp.subproductid == spId) : null;
                                      });
                                      final grs = double.tryParse(_grossWeightController.text) ?? 10.0;
                                      _lookupVaForWeight(grs);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 15, color: Color(0xFF64748B)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        children: [
                          const Text('Item Name: ', style: TextStyle(color: Color(0xFF64748B), fontSize: 11, fontWeight: FontWeight.w700)),
                          Text(
                            '${_selectedLot!.productname ?? 'Ornament'} ${_selectedLot!.subproductname != null && _selectedLot!.subproductname!.isNotEmpty ? '- ${_selectedLot!.subproductname}' : ''}',
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 12, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Fixed from Lot', style: TextStyle(color: Color(0xFF0284C7), fontSize: 9.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          // ROW 1: Pcs, Gross Wt, Stones Button, Net Wt
          Row(
            children: [
              // Pcs
              SizedBox(
                width: 60,
                child: _buildFormField(
                  label: 'Pcs',
                  controller: _pcsController,
                  focusNode: _pcsFocusNode,
                  nextFocusNode: _grossWeightFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 8),

              // Gross Weight
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Gross Wt (g) *',
                          style: TextStyle(
                            color: _grossWeightFocusNode.hasFocus ? GlassTheme.accentAmber : GlassTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('(↵ Stones)', style: TextStyle(fontSize: 9.5, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: _grossWeightController,
                      focusNode: _grossWeightFocusNode,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onSubmitted: (val) {
                        final grs = double.tryParse(val.trim()) ?? 0.0;
                        if (grs > 0) {
                          _openStoneDiamondDialog();
                        } else {
                          _showToast('Please enter a valid Gross Weight (e.g. 10.250g)', isError: true);
                        }
                      },
                      onChanged: _onGrossWeightChanged,
                      style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 14, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        hintText: '0.000',
                        hintStyle: TextStyle(color: GlassTheme.textMuted.withValues(alpha: 0.5), fontSize: 12),
                        filled: true,
                        fillColor: GlassTheme.accentAmber.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: GlassTheme.accentAmber.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: GlassTheme.accentAmber, width: 2.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Stones / Less Wt Trigger Button
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stones', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _openStoneDiamondDialog,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      height: 35,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: _calculatedLessWeight > 0 ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _calculatedLessWeight > 0 ? const Color(0xFF059669) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.diamond_outlined, size: 14, color: _calculatedLessWeight > 0 ? const Color(0xFF059669) : const Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          Text(
                            _calculatedLessWeight > 0 ? '-${_weightFmt.format(_calculatedLessWeight)}g' : '+ Stones',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _calculatedLessWeight > 0 ? const Color(0xFF059669) : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // Net Gold Weight
              Expanded(
                flex: 4,
                child: _buildFormField(
                  label: 'Net Wt (g)',
                  controller: _netWeightController,
                  focusNode: _netWeightFocusNode,
                  nextFocusNode: _boardRateFocusNode,
                  isNum: true,
                  hint: 'Auto calc',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ROW 2: Style Master, Size Master, Purity
          Row(
            children: [
              // Style Master
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Style Master', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: GlassTheme.bgSurfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GlassTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedStyle?.styleid,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          hint: const Text('Style', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Standard', style: TextStyle(fontSize: 11, color: GlassTheme.textMuted))),
                            ..._availableStyles.map((s) => DropdownMenuItem<int?>(value: s.styleid, child: Text(s.stylename, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
                          ],
                          onChanged: (id) => setState(() => _selectedStyle = id != null ? _availableStyles.firstWhere((s) => s.styleid == id) : null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Size Master
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Size', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: GlassTheme.bgSurfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GlassTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedSize?.sizeid,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          hint: const Text('Size', style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                          items: [
                            const DropdownMenuItem<int?>(value: null, child: Text('Free', style: TextStyle(fontSize: 11, color: GlassTheme.textMuted))),
                            ..._availableSizes.map((sz) => DropdownMenuItem<int?>(value: sz.sizeid, child: Text(sz.sizename, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)))),
                          ],
                          onChanged: (id) => setState(() => _selectedSize = id != null ? _availableSizes.firstWhere((sz) => sz.sizeid == id) : null),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // Purity
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Purity', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      decoration: BoxDecoration(
                        color: GlassTheme.bgSurfaceMuted,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: GlassTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedPurity?.purityid ?? (_selectedLot?.purityid ?? (_allPurities.isNotEmpty ? _allPurities.first.purityid : null)),
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          items: _allPurities.map((p) => DropdownMenuItem<int>(value: p.purityid, child: Text(p.purityname, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)))).toList(),
                          onChanged: (id) {
                            if (id != null) setState(() => _selectedPurity = _allPurities.firstWhere((p) => p.purityid == id));
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ROW 3: Sales Pricing Parameters (Board Rate, VA %, Wastage %, MC/g, Fixed MC)
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Board Rate (₹)',
                  controller: _boardRateController,
                  focusNode: _boardRateFocusNode,
                  nextFocusNode: _salesVaFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFormField(
                  label: 'Sales VA %',
                  controller: _salesVaController,
                  focusNode: _salesVaFocusNode,
                  nextFocusNode: _salesWastageFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFormField(
                  label: 'Wastage %',
                  controller: _salesWastageController,
                  focusNode: _salesWastageFocusNode,
                  nextFocusNode: _salesMcGSimpleFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFormField(
                  label: 'MC /g (₹)',
                  controller: _salesMcGSimpleController,
                  focusNode: _salesMcGSimpleFocusNode,
                  nextFocusNode: _salesMChargeFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildFormField(
                  label: 'M-Charge (₹)',
                  controller: _salesMChargeController,
                  focusNode: _salesMChargeFocusNode,
                  nextFocusNode: _purchaseTouchFocusNode,
                  isNum: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Live Total Sales MRP Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('TOTAL ESTIMATED SALES MRP', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF047857), letterSpacing: 0.5)),
                    Text(
                      '₹ ${_currencyFmt.format(_pieceCalculatedSalesPrice)}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF065F46)),
                    ),
                  ],
                ),
                Text(
                  'Gold: ₹${_currencyFmt.format(_pieceSalesGoldValue)} + VA/MC: ₹${_currencyFmt.format(_pieceSalesVaAmt + _pieceSalesWstAmt + _pieceSalesMcAmt)} + Stn: ₹${_currencyFmt.format(_currentStoneAmt + _currentDiamondAmt)}',
                  style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ================= COLUMN 3: SMITH PURCHASE COSTING & ACTIONS =================
  Widget _buildColumn3PurchaseCosting() {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlassTheme.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Column 3 Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFFD97706), size: 18),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Column 3: Purchase Cost & Actions',
                      style: TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Smith Inward Cost, Touch, MC & Print',
                      style: TextStyle(color: GlassTheme.textMuted, fontSize: 10.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ROW 1: Purchase Touch % & Purchase Gold Rate
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Smith Touch %',
                  controller: _purchaseTouchController,
                  focusNode: _purchaseTouchFocusNode,
                  nextFocusNode: _purchaseGoldRateFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormField(
                  label: 'Purchase Rate (₹/g)',
                  controller: _purchaseGoldRateController,
                  focusNode: _purchaseGoldRateFocusNode,
                  nextFocusNode: _purchaseMcFocusNode,
                  isNum: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ROW 2: Smith MC (₹) & Smith Wastage %
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Smith MC (₹)',
                  controller: _purchaseMcController,
                  focusNode: _purchaseMcFocusNode,
                  nextFocusNode: _purchaseWastageFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormField(
                  label: 'Purchase Wastage %',
                  controller: _purchaseWastageController,
                  focusNode: _purchaseWastageFocusNode,
                  nextFocusNode: _purchaseStoneCostFocusNode,
                  isNum: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ROW 3: Stone Cost (₹) & Diamond Cost (₹)
          Row(
            children: [
              Expanded(
                child: _buildFormField(
                  label: 'Stone Cost (₹)',
                  controller: _purchaseStoneCostController,
                  focusNode: _purchaseStoneCostFocusNode,
                  nextFocusNode: _purchaseDmdCostFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildFormField(
                  label: 'Diamond Cost (₹)',
                  controller: _purchaseDmdCostController,
                  focusNode: _purchaseDmdCostFocusNode,
                  nextFocusNode: _huidFocusNode,
                  isNum: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Live Total Purchase Cost & Margin Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SMITH PURCHASE COST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                    Text(
                      '₹ ${_currencyFmt.format(_pieceCalculatedPurchaseCost)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFFB45309)),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('ESTIMATED MARGIN', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
                    Text(
                      '${_pieceMarginPct.toStringAsFixed(1)}% (₹${_currencyFmt.format(_pieceEstimatedMargin)})',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: _pieceEstimatedMargin >= 0 ? const Color(0xFF059669) : const Color(0xFFDC2626)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ROW 4: HUID & Remarks
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'HUID (Hallmark)',
                  controller: _huidController,
                  focusNode: _huidFocusNode,
                  nextFocusNode: _remarksFocusNode,
                  hint: 'e.g. HUID-916ABC',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: _buildFormField(
                  label: 'Remarks / Notes',
                  controller: _remarksController,
                  focusNode: _remarksFocusNode,
                  nextFocusNode: _saveAndPrintFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: () => _saveAndPrintFocusNode.requestFocus(),
                  hint: 'Counter Tray / Box',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ROW 5: Action Buttons (Save & Print Tag vs Save Tag Only)
          Row(
            children: [
              // Save & 1-Click Print Tag Button
              Expanded(
                child: ElevatedButton.icon(
                  focusNode: _saveAndPrintFocusNode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: _saveAndPrintFocusNode.hasFocus ? 3 : 1,
                    side: _saveAndPrintFocusNode.hasFocus ? const BorderSide(color: Color(0xFF38BDF8), width: 2.0) : BorderSide.none,
                  ),
                  icon: _isSaving
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.print_rounded, size: 16),
                  label: Text(
                    _isSaving ? 'Tagging...' : 'Save & Print Tag (↵)',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                  ),
                  onPressed: (_isSaving || _selectedLot == null) ? null : () => _saveAndTagSinglePiece(andPrint: true),
                ),
              ),
              const SizedBox(width: 6),

              // Save Tag Only Button
              OutlinedButton.icon(
                focusNode: _saveOnlyFocusNode,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _saveOnlyFocusNode.hasFocus ? GlassTheme.primaryNeon : const Color(0xFFCBD5E1)),
                  foregroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.save_outlined, size: 15),
                label: const Text('Save Only', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: (_isSaving || _selectedLot == null) ? null : () => _saveAndTagSinglePiece(andPrint: false),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ================= BOTTOM SECTION: TAGGED STOCK ITEMS TABLE =================
  Widget _buildBottomTaggedTableSection(List<StockTaggedItem> displayedTags) {
    return Container(
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GlassTheme.glassBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Toolbar: Filter Switch, Search, Template Selector & Print Button
          Row(
            children: [
              // Filter Toggle: Current Lot Only vs All Stock
              Container(
                decoration: BoxDecoration(
                  color: GlassTheme.bgSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GlassTheme.glassBorder),
                ),
                child: Row(
                  children: [
                    _buildFilterTab(
                      title: 'Current Lot Tags (${_currentLotTaggedItems.length})',
                      isActive: _filterOnlyCurrentLot,
                      onTap: () => setState(() => _filterOnlyCurrentLot = true),
                    ),
                    _buildFilterTab(
                      title: 'All Inventory Stock (${_taggedItems.length})',
                      isActive: !_filterOnlyCurrentLot,
                      onTap: () => setState(() => _filterOnlyCurrentLot = false),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Search Box
              SizedBox(
                width: 240,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Search SKU, Style, Size, Lot...',
                    hintStyle: TextStyle(color: GlassTheme.textMuted.withValues(alpha: 0.6), fontSize: 12),
                    prefixIcon: const Icon(Icons.search, size: 16, color: GlassTheme.textMuted),
                    filled: true,
                    fillColor: GlassTheme.bgSurfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    isDense: true,
                    border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(8)), borderSide: BorderSide(color: GlassTheme.glassBorder)),
                  ),
                ),
              ),
              const Spacer(),

              // Print Template Picker
              const Text('Print Template:', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12)),
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
                        child: Text('${t.name} (${t.labelsPerRow}-Across)', style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12)),
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
              const SizedBox(width: 12),

              // Select All / Deselect All
              TextButton.icon(
                icon: Icon(
                  _selectedItemIdsForPrint.length == displayedTags.length && displayedTags.isNotEmpty
                      ? Icons.check_box
                      : Icons.check_box_outline_blank,
                  size: 16,
                  color: GlassTheme.accentAmber,
                ),
                label: Text(
                  _selectedItemIdsForPrint.length == displayedTags.length && displayedTags.isNotEmpty
                      ? 'Deselect All'
                      : 'Select All (${displayedTags.length})',
                  style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  setState(() {
                    if (_selectedItemIdsForPrint.length == displayedTags.length) {
                      _selectedItemIdsForPrint.clear();
                    } else {
                      _selectedItemIdsForPrint.addAll(displayedTags.map((t) => t.itemId));
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
          const SizedBox(height: 14),

          // Tagged Stock Items Table
          displayedTags.isEmpty
              ? Container(
                  height: 160,
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_rounded, size: 40, color: GlassTheme.textMuted.withValues(alpha: 0.4)),
                      const SizedBox(height: 8),
                      const Text('No SKU tags found for this view.', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text('Enter piece weight in the form above and click "Save & Tag Piece" to generate tags.',
                          style: TextStyle(color: GlassTheme.textMuted, fontSize: 11)),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(GlassTheme.bgSurfaceMuted),
                    dataRowMinHeight: 42,
                    dataRowMaxHeight: 50,
                    columns: const [
                      DataColumn(label: Text('SELECT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0284C7)))),
                      DataColumn(label: Text('SKU CODE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('LOT NO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('ITEM NAME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('STYLE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0284C7)))),
                      DataColumn(label: Text('SIZE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD97706)))),
                      DataColumn(label: Text('PURITY', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('GROSS WT (g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('STONES / DIA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0284C7)))),
                      DataColumn(label: Text('NET WT (g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('SALES MRP (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF059669)))),
                      DataColumn(label: Text('SMITH COST (₹)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFFD97706)))),
                      DataColumn(label: Text('HUID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('PRINT STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                      DataColumn(label: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Color(0xFF0F172A)))),
                    ],
                    rows: displayedTags.map((item) {
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
                          DataCell(Text(item.lotNumber, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12))),
                          DataCell(Text('${item.productName} ${item.subproductName}', style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.styleName.isNotEmpty ? item.styleName : 'Standard',
                                style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD97706).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                item.sizeName.isNotEmpty ? item.sizeName : 'Free',
                                style: const TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.bold, fontSize: 11),
                              ),
                            ),
                          ),
                          DataCell(Text(item.purityName, style: const TextStyle(color: GlassTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12))),
                          DataCell(Text(_weightFmt.format(item.grossWeight), style: const TextStyle(fontWeight: FontWeight.bold, color: GlassTheme.accentAmber))),
                          DataCell(
                            Builder(
                              builder: (ctx) {
                                final stones = item.parsedStoneItems;
                                final diamonds = item.parsedDiamondItems;
                                final totalStones = stones.length;
                                final totalDiamonds = diamonds.length;
                                final totalLessGrams = (item.grossWeight - item.netWeight).clamp(0.0, 999999.0);

                                if (totalStones == 0 && totalDiamonds == 0 && totalLessGrams == 0) {
                                  return const Text('-', style: TextStyle(color: GlassTheme.textMuted, fontSize: 12));
                                }

                                final tooltipLines = <String>[];
                                for (var s in stones) {
                                  final pName = (s.productName != null && s.productName!.isNotEmpty) ? s.productName! : 'Stone';
                                  final spName = (s.subProductName != null && s.subProductName!.isNotEmpty) ? s.subProductName! : '';
                                  tooltipLines.add('• Stone: $pName $spName - ${s.pcs}pcs, ${s.weight}${s.unit} (${s.weightInGrams.toStringAsFixed(3)}g) @ ₹${s.rate}/- = ₹${s.amount.toStringAsFixed(0)}');
                                }
                                for (var d in diamonds) {
                                  final pName = (d.productName != null && d.productName!.isNotEmpty) ? d.productName! : 'Diamond';
                                  final spName = (d.subProductName != null && d.subProductName!.isNotEmpty) ? d.subProductName! : '';
                                  tooltipLines.add('• Dia: $pName $spName - ${d.pcs}pcs, ${d.weight}${d.unit} (${d.weightInGrams.toStringAsFixed(3)}g) @ ₹${d.rate}/- = ₹${d.amount.toStringAsFixed(0)}');
                                }
                                final otherLess = (totalLessGrams - (item.stoneWeight + item.diamondWeight)).clamp(0.0, 999999.0);
                                if (otherLess > 0.0005) {
                                  tooltipLines.add('• Other Less: ${otherLess.toStringAsFixed(3)}g');
                                }

                                return Tooltip(
                                  message: tooltipLines.join('\n'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.diamond_outlined, size: 12, color: Color(0xFF0284C7)),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${totalStones > 0 ? '$totalStones Stn ' : ''}${totalDiamonds > 0 ? '$totalDiamonds Dia ' : ''}(-${_weightFmt.format(totalLessGrams)}g)',
                                          style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          DataCell(Text(_weightFmt.format(item.netWeight), style: const TextStyle(color: GlassTheme.textSecondary))),
                          DataCell(Text('₹ ${_currencyFmt.format(item.salesTotalAmt)}', style: const TextStyle(color: Color(0xFF059669), fontWeight: FontWeight.bold))),
                          DataCell(Text('₹ ${_currencyFmt.format(item.purchaseTotalCost)}', style: const TextStyle(color: Color(0xFFB45309), fontSize: 11))),
                          DataCell(Text(item.huid.isNotEmpty ? item.huid : '-', style: const TextStyle(color: GlassTheme.textMuted, fontSize: 11))),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: item.tagPrintedCount > 0 ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
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
                                Focus(
                                  canRequestFocus: false,
                                  skipTraversal: true,
                                  child: IconButton(
                                    icon: const Icon(Icons.print, size: 16, color: Color(0xFF0284C7)),
                                    tooltip: 'Print this tag',
                                    onPressed: () {
                                      if (_selectedTemplate != null) {
                                        BarcodePrinterService.directPrint(
                                          template: _selectedTemplate!,
                                          items: [item],
                                          jobName: 'Tag_${item.skuCode}',
                                        );
                                        final auth = Provider.of<AuthProvider>(context, listen: false);
                                        final token = auth.authToken ?? '';
                                        _api.markStockTagsPrinted(token, itemIds: [item.itemId]);
                                      }
                                    },
                                  ),
                                ),
                                Focus(
                                  canRequestFocus: false,
                                  skipTraversal: true,
                                  child: IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                    tooltip: 'Delete Tag',
                                    onPressed: () async {
                                      final auth = Provider.of<AuthProvider>(context, listen: false);
                                      final token = auth.authToken ?? '';
                                      await _api.deleteStockTag(token, item.itemId);
                                      _loadInitialData();
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _printSelectedTags() async {
    if (_selectedTemplate == null) {
      _showToast('Please select or create a Barcode Template first.', isError: true);
      return;
    }

    final itemsToPrint = _taggedItems.where((t) => _selectedItemIdsForPrint.contains(t.itemId)).toList();
    if (itemsToPrint.isEmpty) {
      _showToast('Please select at least one tagged item to print.', isError: true);
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    await BarcodePrinterService.directPrint(
      template: _selectedTemplate!,
      items: itemsToPrint,
      jobName: 'Tags_${_selectedLot?.lotNumber ?? 'Batch'}',
    );

    await _api.markStockTagsPrinted(token, itemIds: itemsToPrint.map((i) => i.itemId).toList());

    final tagsRes = await _api.getStockTags(token);
    if (mounted && tagsRes['success'] == true && tagsRes['tags'] != null) {
      setState(() {
        _taggedItems = (tagsRes['tags'] as List)
            .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
            .toList();
      });
    }
  }

  Widget _buildFilterTab({required String title, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isActive ? [const BoxShadow(color: Color(0x0A0F172A), blurRadius: 4, offset: Offset(0, 1))] : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
            color: isActive ? GlassTheme.primaryNeon : GlassTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    FocusNode? focusNode,
    FocusNode? nextFocusNode,
    VoidCallback? onFieldSubmitted,
    TextInputAction textInputAction = TextInputAction.next,
    bool isNum = false,
    String? hint,
    ValueChanged<String>? onChanged,
  }) {
    return Builder(
      builder: (ctx) {
        final isFocused = focusNode?.hasFocus ?? false;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isFocused ? GlassTheme.accentAmber : GlassTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
              textInputAction: textInputAction,
              onSubmitted: (v) {
                if (onFieldSubmitted != null) {
                  onFieldSubmitted();
                } else if (nextFocusNode != null) {
                  nextFocusNode.requestFocus();
                } else {
                  FocusScope.of(context).nextFocus();
                }
              },
              onChanged: (v) {
                if (onChanged != null) onChanged(v);
                setState(() {});
              },
              style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: GlassTheme.textMuted.withValues(alpha: 0.5), fontSize: 11),
                filled: true,
                fillColor: isFocused ? GlassTheme.accentAmber.withValues(alpha: 0.08) : GlassTheme.bgSurfaceMuted,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                isDense: true,
                enabledBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  borderSide: BorderSide(
                    color: isFocused ? GlassTheme.accentAmber : GlassTheme.glassBorder,
                    width: isFocused ? 2.0 : 1.0,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  borderSide: const BorderSide(color: GlassTheme.accentAmber, width: 2.0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
