import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/barcode_models.dart';
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
  LatestRatesSummary _latestRates = LatestRatesSummary();

  // Selection state
  PrepareSkuLotRecord? _selectedLot;
  BarcodeTemplate? _selectedTemplate;
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
  final FocusNode _purchaseStoneCostFocusNode = FocusNode();
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

  // Multi-Stone & Multi-Diamond dynamic line-items
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
    _purchaseStoneCostFocusNode.dispose();
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
        _api.getPrepareSkuLots(token),
        _api.getBarcodeTemplates(token),
        _api.getLatestRates(token),
        _api.getStockTags(token),
        _api.getStyles(token),
        _api.getSizes(token),
        _api.getPurities(token),
        _api.getProducts(token),
        _api.getSubProducts(token),
      ]);

      if (mounted) {
        // SKU Lots
        if (futures[0] is List<PrepareSkuLotRecord>) {
          _allLots = futures[0] as List<PrepareSkuLotRecord>;
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

        // NOTE: Screen opens with no default lot pre-selected as per requirement (Point 1).
        // User explicitly selects or searches the lot number.

        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error in _loadInitialData: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- Dynamic Stone & Diamond Products from Product Master (diastone = 'S' / 'D') ---
  List<ProductRecord> get _stoneProducts => _allProducts.where((p) {
    final d = p.diastone.toUpperCase().trim();
    return d == 'S' || d == 'STONE' || d == 'SYNTHETIC' || d == 'P' || d == 'PRECIOUS';
  }).toList();

  List<ProductRecord> get _diamondProducts => _allProducts.where((p) {
    final d = p.diastone.toUpperCase().trim();
    return d == 'D' || d == 'DIAMOND';
  }).toList();

  // --- Dynamic Multi-Item Totals for Calculations ---
  int get _totalStonePcs => _stoneItems.fold(0, (sum, i) => sum + i.pcs);
  double get _totalStoneWeight => _stoneItems.fold(0.0, (sum, i) => sum + i.weight);
  double get _totalStoneAmount => _stoneItems.fold(0.0, (sum, i) => sum + i.amount);
  double get _totalStoneLessGrams => _stoneItems.fold(0.0, (sum, i) => sum + i.weightInGrams);

  int get _totalDiamondPcs => _diamondItems.fold(0, (sum, i) => sum + i.pcs);
  double get _totalDiamondWeight => _diamondItems.fold(0.0, (sum, i) => sum + i.weight);
  double get _totalDiamondAmount => _diamondItems.fold(0.0, (sum, i) => sum + i.amount);
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

  // Available Styles & Sizes filtered by the Lot's Product
  List<StyleRecord> get _availableStyles {
    if (_selectedLot == null) return _allStyles;
    return _allStyles.where((s) => s.productid == _selectedLot!.productid).toList();
  }

  List<SizeRecord> get _availableSizes {
    if (_selectedLot == null) return _allSizes;
    return _allSizes.where((s) => s.productid == _selectedLot!.productid).toList();
  }

  Future<void> _onLotSelected(PrepareSkuLotRecord? lot) async {
    setState(() {
      _selectedLot = lot;
      _selectedItemIdsForPrint.clear();
      _grossWeightController.clear();
      _netWeightController.clear();
      _huidController.clear();
    });

    if (lot == null) return;

    // 1. Prefill Purity from Lot
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
                purity: 91.6,
                type: 'ORNAMENT',
              ),
      );
    } catch (_) {}

    // 2. Select default Style & Size for this Product
    final styles = _allStyles.where((s) => s.productid == lot.productid).toList();
    _selectedStyle = styles.isNotEmpty ? styles.first : null;

    final sizes = _allSizes.where((s) => s.productid == lot.productid).toList();
    _selectedSize = sizes.isNotEmpty ? sizes.first : null;

    // 3. Pre-fill Stone & Diamond items if Lot has prepared items
    if (lot.stoneItems.isNotEmpty) {
      _stoneItems = lot.stoneItems.map((s) => TagStoneItem(
        productId: s.stoneProductId,
        productName: s.stoneProductName,
        subProductId: s.stoneSubProductId,
        subProductName: s.stoneSubProductName,
        unit: s.stoneUnit.isNotEmpty ? s.stoneUnit : 'G',
        pcs: s.pcs,
        weight: s.weight,
        rate: 0.0,
        amount: 0.0,
      )).toList();
    } else if (lot.totalStonePcs > 0 || lot.totalStoneWeight > 0) {
      _stoneItems = [
        TagStoneItem(
          productId: lot.stoneProductid,
          subProductId: lot.stoneSubproductid,
          unit: lot.stoneUnit.isNotEmpty ? lot.stoneUnit : 'G',
          pcs: lot.totalStonePcs,
          weight: lot.totalStoneWeight,
          rate: 0.0,
          amount: 0.0,
        ),
      ];
    } else {
      _stoneItems = [];
    }

    if (lot.diamondItems.isNotEmpty) {
      _diamondItems = lot.diamondItems.map((d) => TagDiamondItem(
        productId: d.diamondProductId,
        productName: d.diamondProductName,
        subProductId: d.diamondSubProductId,
        subProductName: d.diamondSubProductName,
        unit: d.diamondUnit.isNotEmpty ? d.diamondUnit : 'C',
        pcs: d.pcs,
        weight: d.weight,
        rate: 0.0,
        amount: 0.0,
      )).toList();
    } else if (lot.totalDiamondPcs > 0 || lot.totalDiamondWeight > 0) {
      _diamondItems = [
        TagDiamondItem(
          productId: lot.diamondProductid,
          subProductId: lot.diamondSubproductid,
          unit: lot.diamondUnit.isNotEmpty ? lot.diamondUnit : 'C',
          pcs: lot.totalDiamondPcs,
          weight: lot.totalDiamondWeight,
          rate: 0.0,
          amount: 0.0,
        ),
      ];
    } else {
      _diamondItems = [];
    }

    // 4. Auto-fill Board Rate from Rate Master or Lot rate
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

    // 5. Auto Lookup VA Master
    await _lookupVaForWeight(lot.totalGrossWeight > 0 ? (lot.totalGrossWeight / (lot.totalPcs > 0 ? lot.totalPcs : 1)) : 10.0);

    // 6. Recalculate Net Weight
    _recalculateNetWeight();

    // 7. Focus on Gross Weight input
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_grossWeightFocusNode.canRequestFocus) {
        _grossWeightFocusNode.requestFocus();
      }
    });
  }

  Future<void> _lookupVaForWeight(double weight) async {
    if (_selectedLot == null) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final token = auth.authToken ?? '';

    setState(() => _isSearchingVa = true);
    final vaRes = await _api.lookupVaPriceSetting(
      token,
      companyId: _selectedLot!.companyid,
      branchId: _selectedLot!.branchid,
      productId: _selectedLot!.productid,
      subproductId: _selectedLot!.subproductid,
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
  Future<void> _openStoneDiamondDialog() async {
    final grs = double.tryParse(_grossWeightController.text.trim()) ?? 0.0;
    if (grs <= 0) {
      _showToast('Please enter Gross Weight first (e.g. 10.250g)', isError: true);
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
      rate: d.rate,
      amount: d.amount,
    )).toList();

    final tempOtherLessCtrl = TextEditingController(
      text: _otherLessWeightController.text == '0.000' || _otherLessWeightController.text == '0.0'
          ? ''
          : _otherLessWeightController.text,
    );

    // Stone & Diamond Products from product master where diastone IN ('S', 'D')
    final stoneProducts = _stoneProducts;
    final diamondProducts = _diamondProducts;

    // Quick Entry State for Adding Stones Row-by-Row
    int? quickStnProductId = stoneProducts.isNotEmpty ? stoneProducts.first.productid : null;
    String quickStnProductName = stoneProducts.isNotEmpty ? stoneProducts.first.productname : '';
    int? quickStnSubProductId;
    String quickStnSubProductName = '';
    String quickStnUnit = 'G';
    final quickStnPcsCtrl = TextEditingController(text: '1');
    final quickStnWtCtrl = TextEditingController();
    final quickStnRateCtrl = TextEditingController();
    final quickStnAmtCtrl = TextEditingController();
    final FocusNode quickStnPcsFocus = FocusNode();
    final FocusNode quickStnWtFocus = FocusNode();
    final FocusNode quickStnRateFocus = FocusNode();
    final FocusNode quickStnAmtFocus = FocusNode();
    String? stnNoticeMsg;

    // Quick Entry State for Adding Diamonds Row-by-Row
    int? quickDmdProductId = diamondProducts.isNotEmpty ? diamondProducts.first.productid : null;
    String quickDmdProductName = diamondProducts.isNotEmpty ? diamondProducts.first.productname : '';
    int? quickDmdSubProductId;
    String quickDmdSubProductName = '';
    String quickDmdUnit = 'C';
    final quickDmdPcsCtrl = TextEditingController(text: '1');
    final quickDmdWtCtrl = TextEditingController();
    final quickDmdRateCtrl = TextEditingController();
    final quickDmdAmtCtrl = TextEditingController();
    final FocusNode quickDmdPcsFocus = FocusNode();
    final FocusNode quickDmdWtFocus = FocusNode();
    final FocusNode quickDmdRateFocus = FocusNode();
    final FocusNode quickDmdAmtFocus = FocusNode();
    String? dmdNoticeMsg;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final stoneLessGrams = tempStones.fold(0.0, (sum, i) => sum + i.weightInGrams);
            final stoneTotalAmt = tempStones.fold(0.0, (sum, i) => sum + i.amount);
            final stoneTotalPcs = tempStones.fold(0, (sum, i) => sum + i.pcs);
            final stoneTotalWt = tempStones.fold(0.0, (sum, i) => sum + i.weight);

            final diamondLessGrams = tempDiamonds.fold(0.0, (sum, i) => sum + i.weightInGrams);
            final diamondTotalAmt = tempDiamonds.fold(0.0, (sum, i) => sum + i.amount);
            final diamondTotalPcs = tempDiamonds.fold(0, (sum, i) => sum + i.pcs);
            final diamondTotalWt = tempDiamonds.fold(0.0, (sum, i) => sum + i.weight);

            final otherLessGrams = double.tryParse(tempOtherLessCtrl.text.trim()) ?? 0.0;
            final totalLessGrams = stoneLessGrams + diamondLessGrams + otherLessGrams;
            final netWeightGrams = (grs - totalLessGrams).clamp(0.0, 999999.0);

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
              final rate = double.tryParse(quickStnRateCtrl.text.trim()) ?? 0.0;
              final manualAmt = double.tryParse(quickStnAmtCtrl.text.trim());
              final amt = manualAmt ?? (wt * rate);

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
                  rate: rate,
                  amount: amt,
                ));
                // Reset quick entry fields for the NEXT stone
                quickStnPcsCtrl.text = '1';
                quickStnWtCtrl.clear();
                quickStnRateCtrl.clear();
                quickStnAmtCtrl.clear();
                stnNoticeMsg = '✓ Stone #${tempStones.length} added! Enter next stone details above or click Apply & Done.';
              });

              // Re-focus back to weight input for the next stone
              quickStnWtFocus.requestFocus();
            }

            void addQuickDiamond() {
              final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
              final pcs = int.tryParse(quickDmdPcsCtrl.text.trim()) ?? 1;
              final rate = double.tryParse(quickDmdRateCtrl.text.trim()) ?? 0.0;
              final manualAmt = double.tryParse(quickDmdAmtCtrl.text.trim());
              final amt = manualAmt ?? (wt * rate);

              if (wt <= 0 && pcs <= 0) {
                setDialogState(() {
                  dmdNoticeMsg = '⚠️ Please enter diamond weight or pcs before adding.';
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
                  rate: rate,
                  amount: amt,
                ));
                // Reset quick entry fields for the NEXT diamond
                quickDmdPcsCtrl.text = '1';
                quickDmdWtCtrl.clear();
                quickDmdRateCtrl.clear();
                quickDmdAmtCtrl.clear();
                dmdNoticeMsg = '✓ Diamond #${tempDiamonds.length} added! Enter next diamond details above or click Apply & Done.';
              });

              // Re-focus back to weight input for the next diamond
              quickDmdWtFocus.requestFocus();
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                width: 1020,
                constraints: const BoxConstraints(maxHeight: 820),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 28, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
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
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.diamond_rounded, color: GlassTheme.accentAmber, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Stone & Diamond Itemization Grid',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Add stone and diamond rows sequentially. Press Enter to add and advance to next item.',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF0284C7)),
                            ),
                            child: Row(
                              children: [
                                const Text('Gross Weight: ', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12)),
                                Text(
                                  '${_weightFmt.format(grs)} g',
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Body
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. STONES SECTION (diastone = 'S')
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Stones Section Title
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF059669).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.grain_rounded, color: Color(0xFF34D399), size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "STONES (diastone = 'S')",
                                        style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      if (tempStones.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${tempStones.length} items | $stoneTotalPcs pcs | ${_weightFmt.format(stoneTotalWt)} | Less: ${_weightFmt.format(stoneLessGrams)}g',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (stnNoticeMsg != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF059669).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            stnNoticeMsg!,
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Quick Stone Entry Row (Grid Row Input)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF059669).withValues(alpha: 0.6)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text(
                                              'Add Stone Row (Fill & hit Enter or click "+ Add Stone Row")',
                                              style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // Stone Product Dropdown
                                            Expanded(
                                              flex: 3,
                                              child: DropdownButtonFormField<int?>(
                                                value: quickStnProductId,
                                                dropdownColor: const Color(0xFF1E293B),
                                                isExpanded: true,
                                                decoration: _buildDialogInputDecoration('Stone Product *'),
                                                items: stoneProducts.map((p) {
                                                  return DropdownMenuItem<int?>(
                                                    value: p.productid,
                                                    child: Text(
                                                      p.productname,
                                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  setDialogState(() {
                                                    quickStnProductId = val;
                                                    final match = stoneProducts.firstWhere((p) => p.productid == val, orElse: () => stoneProducts.first);
                                                    quickStnProductName = match.productname;
                                                    if (quickStnSubProductId != null && !matchingStnSubProducts.any((sp) => sp.subproductid == quickStnSubProductId && sp.productid == val)) {
                                                      quickStnSubProductId = null;
                                                      quickStnSubProductName = '';
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Stone Sub-product Dropdown
                                            Expanded(
                                              flex: 2,
                                              child: DropdownButtonFormField<int?>(
                                                value: quickStnSubProductId,
                                                dropdownColor: const Color(0xFF1E293B),
                                                isExpanded: true,
                                                decoration: _buildDialogInputDecoration('Sub-Product'),
                                                items: [
                                                  const DropdownMenuItem<int?>(
                                                    value: null,
                                                    child: Text('-- None --', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                                  ),
                                                  ...matchingStnSubProducts.map((sp) {
                                                    return DropdownMenuItem<int?>(
                                                      value: sp.subproductid,
                                                      child: Text(
                                                        sp.subproductname,
                                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    );
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
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Unit Dropdown
                                            SizedBox(
                                              width: 90,
                                              child: DropdownButtonFormField<String>(
                                                value: quickStnUnit,
                                                dropdownColor: const Color(0xFF1E293B),
                                                decoration: _buildDialogInputDecoration('Unit'),
                                                items: const [
                                                  DropdownMenuItem(value: 'G', child: Text('Gram (G)', style: TextStyle(color: Colors.white, fontSize: 11))),
                                                  DropdownMenuItem(value: 'C', child: Text('Carat (C)', style: TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold))),
                                                  DropdownMenuItem(value: 'cent', child: Text('Cent', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11))),
                                                ],
                                                onChanged: (val) {
                                                  setDialogState(() {
                                                    quickStnUnit = val ?? 'G';
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Pcs
                                            SizedBox(
                                              width: 65,
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
                                            const SizedBox(width: 8),

                                            // Weight
                                            SizedBox(
                                              width: 85,
                                              child: TextFormField(
                                                controller: quickStnWtCtrl,
                                                focusNode: quickStnWtFocus,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textInputAction: TextInputAction.next,
                                                onFieldSubmitted: (_) => quickStnRateFocus.requestFocus(),
                                                style: const TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold),
                                                decoration: _buildDialogInputDecoration('Weight *'),
                                                onChanged: (v) {
                                                  final wt = double.tryParse(v.trim()) ?? 0.0;
                                                  final rate = double.tryParse(quickStnRateCtrl.text.trim()) ?? 0.0;
                                                  if (rate > 0) {
                                                    quickStnAmtCtrl.text = (wt * rate).toStringAsFixed(2);
                                                  }
                                                  setDialogState(() {});
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Rate (₹)
                                            SizedBox(
                                              width: 85,
                                              child: TextFormField(
                                                controller: quickStnRateCtrl,
                                                focusNode: quickStnRateFocus,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textInputAction: TextInputAction.next,
                                                onFieldSubmitted: (_) => quickStnAmtFocus.requestFocus(),
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                decoration: _buildDialogInputDecoration('Rate (₹)'),
                                                onChanged: (v) {
                                                  final rate = double.tryParse(v.trim()) ?? 0.0;
                                                  final wt = double.tryParse(quickStnWtCtrl.text.trim()) ?? 0.0;
                                                  if (wt > 0) {
                                                    quickStnAmtCtrl.text = (wt * rate).toStringAsFixed(2);
                                                  }
                                                  setDialogState(() {});
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Amount (₹)
                                            SizedBox(
                                              width: 95,
                                              child: TextFormField(
                                                controller: quickStnAmtCtrl,
                                                focusNode: quickStnAmtFocus,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textInputAction: TextInputAction.done,
                                                onFieldSubmitted: (_) => addQuickStone(),
                                                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                                decoration: _buildDialogInputDecoration('Amt (₹)'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Add Button
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF059669),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const Icon(Icons.add, size: 16),
                                              label: const Text('Add Row', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: addQuickStone,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Grid Table of Added Stones
                                  if (tempStones.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "No stone items added yet. Fill in details above and click '+ Add Row' (or press Enter).",
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Column(
                                        children: [
                                          // Table Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1E293B),
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                            ),
                                            child: const Row(
                                              children: [
                                                SizedBox(width: 32, child: Text('#', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 3, child: Text('STONE PRODUCT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 2, child: Text('SUB-PRODUCT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 60, child: Text('UNIT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 50, child: Text('PCS', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 80, child: Text('WEIGHT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 80, child: Text('RATE (₹)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 90, child: Text('AMOUNT (₹)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 90, child: Text('LESS WT (g)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 40, child: Text('', textAlign: TextAlign.center)),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 1, color: Color(0xFF334155)),
                                          // Table Rows
                                          ...tempStones.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final item = entry.value;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: index.isOdd ? const Color(0xFF1E293B).withValues(alpha: 0.3) : Colors.transparent,
                                                border: const Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 32,
                                                    child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 11)),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      (item.productName != null && item.productName!.isNotEmpty) ? item.productName! : 'Stone Item',
                                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      (item.subProductName != null && item.subProductName!.isNotEmpty) ? item.subProductName! : '-',
                                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 60,
                                                    child: Text(item.unit, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                  SizedBox(
                                                    width: 50,
                                                    child: Text('${item.pcs}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                                  ),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Text(
                                                      '${_weightFmt.format(item.weight)} ${item.unit}',
                                                      style: const TextStyle(color: Color(0xFF34D399), fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Text(
                                                      item.rate > 0 ? '₹${item.rate.toStringAsFixed(2)}' : '-',
                                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      item.amount > 0 ? '₹${item.amount.toStringAsFixed(2)}' : '₹0.00',
                                                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      '-${_weightFmt.format(item.weightInGrams)}g',
                                                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 40,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: 'Remove Stone Row',
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          tempStones.removeAt(index);
                                                        });
                                                      },
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
                            const SizedBox(height: 16),

                            // 2. DIAMONDS SECTION (diastone = 'D')
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Diamond Section Title
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: const Icon(Icons.diamond_outlined, color: Color(0xFF38BDF8), size: 16),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        "DIAMONDS (diastone = 'D')",
                                        style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                                      ),
                                      if (tempDiamonds.isNotEmpty) ...[
                                        const SizedBox(width: 10),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            '${tempDiamonds.length} items | $diamondTotalPcs pcs | ${_weightFmt.format(diamondTotalWt)} | Less: ${_weightFmt.format(diamondLessGrams)}g',
                                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (dmdNoticeMsg != null)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                                          ),
                                          child: Text(
                                            dmdNoticeMsg!,
                                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Quick Diamond Entry Row (Grid Row Input)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.6)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Row(
                                          children: [
                                            Text(
                                              'Add Diamond Row (Fill & hit Enter or click "+ Add Diamond Row")',
                                              style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            // Diamond Product Dropdown
                                            Expanded(
                                              flex: 3,
                                              child: DropdownButtonFormField<int?>(
                                                value: quickDmdProductId,
                                                dropdownColor: const Color(0xFF1E293B),
                                                isExpanded: true,
                                                decoration: _buildDialogInputDecoration('Diamond Product *'),
                                                items: diamondProducts.map((p) {
                                                  return DropdownMenuItem<int?>(
                                                    value: p.productid,
                                                    child: Text(
                                                      p.productname,
                                                      style: const TextStyle(color: Colors.white, fontSize: 12),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  );
                                                }).toList(),
                                                onChanged: (val) {
                                                  setDialogState(() {
                                                    quickDmdProductId = val;
                                                    final match = diamondProducts.firstWhere((p) => p.productid == val, orElse: () => diamondProducts.first);
                                                    quickDmdProductName = match.productname;
                                                    if (quickDmdSubProductId != null && !matchingDmdSubProducts.any((sp) => sp.subproductid == quickDmdSubProductId && sp.productid == val)) {
                                                      quickDmdSubProductId = null;
                                                      quickDmdSubProductName = '';
                                                    }
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Diamond Subproduct Dropdown
                                            Expanded(
                                              flex: 2,
                                              child: DropdownButtonFormField<int?>(
                                                value: quickDmdSubProductId,
                                                dropdownColor: const Color(0xFF1E293B),
                                                isExpanded: true,
                                                decoration: _buildDialogInputDecoration('Sub-Product'),
                                                items: [
                                                  const DropdownMenuItem<int?>(
                                                    value: null,
                                                    child: Text('-- None --', style: TextStyle(color: Colors.white54, fontSize: 12)),
                                                  ),
                                                  ...matchingDmdSubProducts.map((sp) {
                                                    return DropdownMenuItem<int?>(
                                                      value: sp.subproductid,
                                                      child: Text(
                                                        sp.subproductname,
                                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    );
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
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Diamond Unit
                                            SizedBox(
                                              width: 90,
                                              child: DropdownButtonFormField<String>(
                                                value: quickDmdUnit,
                                                dropdownColor: const Color(0xFF1E293B),
                                                decoration: _buildDialogInputDecoration('Unit'),
                                                items: const [
                                                  DropdownMenuItem(value: 'C', child: Text('Carat (C)', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                  DropdownMenuItem(value: 'cent', child: Text('Cent', style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11))),
                                                  DropdownMenuItem(value: 'G', child: Text('Gram (G)', style: TextStyle(color: Colors.white, fontSize: 11))),
                                                ],
                                                onChanged: (val) {
                                                  setDialogState(() {
                                                    quickDmdUnit = val ?? 'C';
                                                  });
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Pcs
                                            SizedBox(
                                              width: 65,
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
                                            const SizedBox(width: 8),

                                            // Weight (Carats)
                                            SizedBox(
                                              width: 85,
                                              child: TextFormField(
                                                controller: quickDmdWtCtrl,
                                                focusNode: quickDmdWtFocus,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textInputAction: TextInputAction.next,
                                                onFieldSubmitted: (_) => quickDmdRateFocus.requestFocus(),
                                                style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold),
                                                decoration: _buildDialogInputDecoration('Wt (ct) *'),
                                                onChanged: (v) {
                                                  final wt = double.tryParse(v.trim()) ?? 0.0;
                                                  final rate = double.tryParse(quickDmdRateCtrl.text.trim()) ?? 0.0;
                                                  if (rate > 0) {
                                                    quickDmdAmtCtrl.text = (wt * rate).toStringAsFixed(2);
                                                  }
                                                  setDialogState(() {});
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Rate (₹/ct)
                                            SizedBox(
                                              width: 85,
                                              child: TextFormField(
                                                controller: quickDmdRateCtrl,
                                                focusNode: quickDmdRateFocus,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textInputAction: TextInputAction.next,
                                                onFieldSubmitted: (_) => quickDmdAmtFocus.requestFocus(),
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                decoration: _buildDialogInputDecoration('Rate /ct'),
                                                onChanged: (v) {
                                                  final rate = double.tryParse(v.trim()) ?? 0.0;
                                                  final wt = double.tryParse(quickDmdWtCtrl.text.trim()) ?? 0.0;
                                                  if (wt > 0) {
                                                    quickDmdAmtCtrl.text = (wt * rate).toStringAsFixed(2);
                                                  }
                                                  setDialogState(() {});
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Amount (₹)
                                            SizedBox(
                                              width: 95,
                                              child: TextFormField(
                                                controller: quickDmdAmtCtrl,
                                                focusNode: quickDmdAmtFocus,
                                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                                textInputAction: TextInputAction.done,
                                                onFieldSubmitted: (_) => addQuickDiamond(),
                                                style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                                decoration: _buildDialogInputDecoration('Amt (₹)'),
                                              ),
                                            ),
                                            const SizedBox(width: 8),

                                            // Add Button
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF0284C7),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                              ),
                                              icon: const Icon(Icons.add, size: 16),
                                              label: const Text('Add Row', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                              onPressed: addQuickDiamond,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Grid Table of Added Diamonds
                                  if (tempDiamonds.isEmpty)
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      alignment: Alignment.center,
                                      child: const Text(
                                        "No diamond items added yet. Fill in details above and click '+ Add Row' (or press Enter).",
                                        style: TextStyle(color: Colors.white54, fontSize: 12),
                                      ),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF334155)),
                                      ),
                                      child: Column(
                                        children: [
                                          // Table Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF1E293B),
                                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                            ),
                                            child: const Row(
                                              children: [
                                                SizedBox(width: 32, child: Text('#', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 3, child: Text('DIAMOND PRODUCT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                Expanded(flex: 2, child: Text('SUB-PRODUCT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 60, child: Text('UNIT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 50, child: Text('PCS', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 80, child: Text('WEIGHT', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 80, child: Text('RATE /ct', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 90, child: Text('AMOUNT (₹)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 90, child: Text('LESS WT (g)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.bold))),
                                                SizedBox(width: 40, child: Text('', textAlign: TextAlign.center)),
                                              ],
                                            ),
                                          ),
                                          const Divider(height: 1, color: Color(0xFF334155)),
                                          // Table Rows
                                          ...tempDiamonds.asMap().entries.map((entry) {
                                            final index = entry.key;
                                            final item = entry.value;
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: index.isOdd ? const Color(0xFF1E293B).withValues(alpha: 0.3) : Colors.transparent,
                                                border: const Border(bottom: BorderSide(color: Color(0xFF1E293B), width: 1)),
                                              ),
                                              child: Row(
                                                children: [
                                                  SizedBox(
                                                    width: 32,
                                                    child: Text('${index + 1}', style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 11)),
                                                  ),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Text(
                                                      (item.productName != null && item.productName!.isNotEmpty) ? item.productName! : 'Diamond Item',
                                                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 2,
                                                    child: Text(
                                                      (item.subProductName != null && item.subProductName!.isNotEmpty) ? item.subProductName! : '-',
                                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 60,
                                                    child: Text(item.unit, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                                  ),
                                                  SizedBox(
                                                    width: 50,
                                                    child: Text('${item.pcs}', style: const TextStyle(color: Colors.white, fontSize: 12)),
                                                  ),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Text(
                                                      '${_weightFmt.format(item.weight)} ${item.unit}',
                                                      style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 80,
                                                    child: Text(
                                                      item.rate > 0 ? '₹${item.rate.toStringAsFixed(2)}' : '-',
                                                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      item.amount > 0 ? '₹${item.amount.toStringAsFixed(2)}' : '₹0.00',
                                                      style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 90,
                                                    child: Text(
                                                      '-${_weightFmt.format(item.weightInGrams)}g',
                                                      style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                    width: 40,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                                      padding: EdgeInsets.zero,
                                                      constraints: const BoxConstraints(),
                                                      tooltip: 'Remove Diamond Row',
                                                      onPressed: () {
                                                        setDialogState(() {
                                                          tempDiamonds.removeAt(index);
                                                        });
                                                      },
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

                            // 3. OTHER LESS WEIGHT (Enamel, Thread, Wax, Dirt)
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
                                  const Text('Other Deductions / Less Weight (Enamel, Wax, Thread):',
                                      style: TextStyle(color: Colors.white70, fontSize: 11)),
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
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text('Stones/Dmd Value', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                      Text('₹ ${_currencyFmt.format(stoneTotalAmt + diamondTotalAmt)}', style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 14, fontWeight: FontWeight.bold)),
                                    ],
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
      });

      _showToast('✓ Net Weight: ${_netWeightController.text}g (Less: ${_weightFmt.format(_calculatedLessWeight)}g)');
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
  double get _currentStoneAmt => _totalStoneAmount;
  double get _currentDiamondAmt => _totalDiamondAmount;

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
  double get _purchaseStoneCost => double.tryParse(_purchaseStoneCostController.text) ?? 0.0;
  double get _purchaseDmdCost => double.tryParse(_purchaseDmdCostController.text) ?? 0.0;

  double get _piecePurchaseGoldCost =>
      _purchaseTouchPct > 0 ? (_currentPieceNetWt * (_purchaseTouchPct / 100.0) * _purchaseGoldRate) : (_currentPieceNetWt * _purchaseGoldRate);
  double get _pieceCalculatedPurchaseCost =>
      _piecePurchaseGoldCost + _purchaseMcAmt + _purchaseStoneCost + _purchaseDmdCost;

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
      'stone_amt': _totalStoneAmount,
      'stone_details': _stoneItems.map((s) => s.toJson()).toList(),
      'diamond_pcs': _totalDiamondPcs,
      'diamond_weight': _totalDiamondWeight,
      'diamond_amt': _totalDiamondAmount,
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
        _showToast('✓ Tag $sku generated successfully! (${_weightFmt.format(grs)}g)', isError: false);

        // Fetch refreshed tags
        final tagsRes = await _api.getStockTags(token);
        if (tagsRes['success'] == true && tagsRes['tags'] != null) {
          final newTags = (tagsRes['tags'] as List)
              .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
              .toList();
          setState(() {
            _taggedItems = newTags;
          });

          // Optional 1-click print
          if (andPrint && _selectedTemplate != null && newTags.isNotEmpty) {
            final newlyCreated = newTags.firstWhere((t) => t.skuCode == sku, orElse: () => newTags.first);
            BarcodePrinterService.directPrint(
              template: _selectedTemplate!,
              items: [newlyCreated],
              jobName: 'Tag_${newlyCreated.skuCode}',
            );
            _api.markStockTagsPrinted(token, itemIds: [newlyCreated.itemId]);
          }
        }

        // Reset inputs and focus back on Gross Weight for the next piece
        _grossWeightController.clear();
        _netWeightController.clear();
        _huidController.clear();
        _stoneItems.clear();
        _diamondItems.clear();
        _otherLessWeightController.text = '0.000';
        _calculatedLessWeight = 0.0;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_grossWeightFocusNode.canRequestFocus) {
            _grossWeightFocusNode.requestFocus();
          }
        });
      } else {
        _showToast(res['message'] ?? 'Failed to save tag.', isError: true);
      }
    }
  }

  /// Bulk Split Dialog for dividing all remaining untagged pieces equally
  Future<void> _showBatchSplitDialog() async {
    if (_selectedLot == null || _remainingPcs <= 0) {
      _showToast('No remaining pieces in this lot to batch split.', isError: true);
      return;
    }

    int splitCount = _remainingPcs;
    double splitGross = _remainingGrossWeight;
    final splitCountCtrl = TextEditingController(text: splitCount.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final count = int.tryParse(splitCountCtrl.text) ?? 1;
            final grsPer = count > 0 ? (splitGross / count) : 0.0;

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
                    child: const Icon(Icons.call_split_rounded, color: GlassTheme.accentAmber, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Text('Quick Batch Split Remaining', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lot ${_selectedLot!.lotNumber} has $splitCount remaining pieces totaling ${_weightFmt.format(splitGross)}g.',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: splitCountCtrl,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                      decoration: InputDecoration(
                        labelText: 'Number of SKU Tags to Generate',
                        labelStyle: const TextStyle(color: Color(0xFF38BDF8)),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Estimated Weight per Tag:', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          Text('${_weightFmt.format(grsPer)} g', style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GlassTheme.accentAmber,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.bolt_rounded, size: 18),
                  label: Text('Generate $count SKU Tags', style: const TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    setState(() => _isSaving = true);
                    final auth = Provider.of<AuthProvider>(context, listen: false);
                    final token = auth.authToken ?? '';

                    final payload = {
                      'lot_id': _selectedLot!.lotId,
                      'tags_count': count,
                      'styleid': _selectedStyle?.styleid,
                      'stylename': _selectedStyle?.stylename ?? '',
                      'sizeid': _selectedSize?.sizeid,
                      'sizename': _selectedSize?.sizename ?? '',
                      'purityid': _selectedPurity?.purityid ?? _selectedLot!.purityid,
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

                    final res = await _api.generateTagsFromLot(token, payload);
                    if (mounted) {
                      setState(() => _isSaving = false);
                      if (res['success'] == true) {
                        _showToast('✓ ${res['count']} SKU Tags created successfully!');
                        final tagsRes = await _api.getStockTags(token);
                        if (tagsRes['success'] == true && tagsRes['tags'] != null) {
                          setState(() {
                            _taggedItems = (tagsRes['tags'] as List)
                                .map((t) => StockTaggedItem.fromJson(t as Map<String, dynamic>))
                                .toList();
                          });
                        }
                      } else {
                        _showToast(res['message'] ?? 'Failed to batch split.', isError: true);
                      }
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Opens dialog to edit existing stock tag including its multi-stone & diamond items
  Future<void> _openEditTagDialog(StockTaggedItem item) async {
    final grsCtrl = TextEditingController(text: item.grossWeight.toStringAsFixed(3));
    final netCtrl = TextEditingController(text: item.netWeight.toStringAsFixed(3));
    final boardRateCtrl = TextEditingController(text: item.boardRate.toStringAsFixed(2));
    final vaCtrl = TextEditingController(text: item.salesVaPercent.toString());
    final wastageCtrl = TextEditingController(text: item.salesWastage.toString());
    final mcGCtrl = TextEditingController(text: item.salesMcPerGram.toString());
    final mChargeCtrl = TextEditingController(text: item.salesMCharge.toString());
    final purchaseTouchCtrl = TextEditingController(text: item.purchaseTouchPct.toString());
    final purchaseGoldRateCtrl = TextEditingController(text: item.purchaseGoldRate.toStringAsFixed(2));
    final purchaseMcCtrl = TextEditingController(text: item.purchaseMc.toString());
    final huidCtrl = TextEditingController(text: item.huid);
    final remarksCtrl = TextEditingController(text: item.remarks);

    int? selectedStyleId = item.styleId;
    String selectedStyleName = item.styleName;
    int? selectedSizeId = item.sizeId;
    String selectedSizeName = item.sizeName;
    int selectedPurityId = item.purityId;
    String selectedStatus = item.status;

    final List<TagStoneItem> editStones = item.parsedStoneItems.isNotEmpty
        ? item.parsedStoneItems
        : (item.stonePcs > 0 || item.stoneWeight > 0
            ? [
                TagStoneItem(
                  productId: item.productId,
                  pcs: item.stonePcs,
                  weight: item.stoneWeight,
                  rate: 0.0,
                  amount: item.stoneAmt,
                )
              ]
            : []);

    final List<TagDiamondItem> editDiamonds = item.parsedDiamondItems.isNotEmpty
        ? item.parsedDiamondItems
        : (item.diamondPcs > 0 || item.diamondWeight > 0
            ? [
                TagDiamondItem(
                  productId: item.productId,
                  pcs: item.diamondPcs,
                  weight: item.diamondWeight,
                  rate: 0.0,
                  amount: item.diamondAmt,
                )
              ]
            : []);

    final stoneProducts = _stoneProducts;
    final diamondProducts = _diamondProducts;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setModalState) {
            final grs = double.tryParse(grsCtrl.text.trim()) ?? 0.0;
            final stoneLess = editStones.fold(0.0, (sum, s) => sum + s.weightInGrams);
            final diamondLess = editDiamonds.fold(0.0, (sum, d) => sum + d.weightInGrams);
            final totalLess = stoneLess + diamondLess;
            final calcNet = (grs - totalLess).clamp(0.0, 999999.0);

            final bRate = double.tryParse(boardRateCtrl.text.trim()) ?? 0.0;
            final vaPct = double.tryParse(vaCtrl.text.trim()) ?? 0.0;
            final wstPct = double.tryParse(wastageCtrl.text.trim()) ?? 0.0;
            final mcG = double.tryParse(mcGCtrl.text.trim()) ?? 0.0;
            final mCharge = double.tryParse(mChargeCtrl.text.trim()) ?? 0.0;

            final stoneAmt = editStones.fold(0.0, (sum, s) => sum + s.amount);
            final dmdAmt = editDiamonds.fold(0.0, (sum, d) => sum + d.amount);

            final pureGoldValue = calcNet * bRate;
            final vaAmt = pureGoldValue * (vaPct / 100.0);
            final wstAmt = pureGoldValue * (wstPct / 100.0);
            final mcAmt = (calcNet * mcG) + mCharge;
            final salesMRP = pureGoldValue + vaAmt + wstAmt + mcAmt + stoneAmt + dmdAmt;

            final pTouch = double.tryParse(purchaseTouchCtrl.text.trim()) ?? 0.0;
            final pRate = double.tryParse(purchaseGoldRateCtrl.text.trim()) ?? bRate;
            final pMc = double.tryParse(purchaseMcCtrl.text.trim()) ?? 0.0;
            final pGoldCost = pTouch > 0 ? (calcNet * (pTouch / 100.0) * pRate) : (calcNet * pRate);
            final purchaseCost = pGoldCost + pMc + stoneAmt + dmdAmt;

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Container(
                width: 960,
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
                          const Icon(Icons.edit_note_rounded, color: GlassTheme.accentAmber, size: 24),
                          const SizedBox(width: 10),
                          Text(
                            'Edit Tag: ${item.skuCode} (Lot ${item.lotNumber})',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Basic Details Row
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: grsCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    decoration: _buildDialogInputDecoration('Gross Weight (g) *'),
                                    onChanged: (_) {
                                      netCtrl.text = _weightFmt.format(calcNet);
                                      setModalState(() {});
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextFormField(
                                    controller: netCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold),
                                    decoration: _buildDialogInputDecoration('Net Gold Weight (g)'),
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<int>(
                                    value: selectedPurityId,
                                    dropdownColor: const Color(0xFF1E293B),
                                    decoration: _buildDialogInputDecoration('Purity'),
                                    items: _allPurities.map((p) {
                                      return DropdownMenuItem<int>(
                                        value: p.purityid,
                                        child: Text(p.purityname, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                      );
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) setModalState(() => selectedPurityId = val);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: DropdownButtonFormField<int?>(
                                    value: selectedStyleId,
                                    dropdownColor: const Color(0xFF1E293B),
                                    decoration: _buildDialogInputDecoration('Style'),
                                    items: [
                                      const DropdownMenuItem<int?>(value: null, child: Text('Standard / None', style: TextStyle(color: Colors.white54, fontSize: 12))),
                                      ..._allStyles.where((s) => s.productid == item.productId).map((s) {
                                        return DropdownMenuItem<int?>(
                                          value: s.styleid,
                                          child: Text(s.stylename, style: const TextStyle(color: Colors.white, fontSize: 12)),
                                        );
                                      }),
                                    ],
                                    onChanged: (val) {
                                      setModalState(() {
                                        selectedStyleId = val;
                                        if (val != null) {
                                          final st = _allStyles.firstWhere((s) => s.styleid == val);
                                          selectedStyleName = st.stylename;
                                        } else {
                                          selectedStyleName = '';
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Multi-Stones Section
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
                                      const Text("💎 Stones (diastone = 'S')", style: TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold, fontSize: 12)),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF059669),
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('Add Stone', style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setModalState(() {
                                            editStones.add(TagStoneItem(
                                              productId: stoneProducts.isNotEmpty ? stoneProducts.first.productid : null,
                                              productName: stoneProducts.isNotEmpty ? stoneProducts.first.productname : '',
                                              unit: 'G',
                                              pcs: 1,
                                              weight: 0.0,
                                              rate: 0.0,
                                              amount: 0.0,
                                            ));
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  ...editStones.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final st = entry.value;
                                    final subProds = _allSubProducts.where((sp) => st.productId == null || sp.productid == st.productId).toList();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: DropdownButtonFormField<int?>(
                                              value: st.productId,
                                              dropdownColor: const Color(0xFF1E293B),
                                              decoration: _buildDialogInputDecoration('Product *'),
                                              items: stoneProducts.map((p) => DropdownMenuItem(value: p.productid, child: Text(p.productname, style: const TextStyle(color: Colors.white, fontSize: 11)))).toList(),
                                              onChanged: (v) {
                                                setModalState(() {
                                                  st.productId = v;
                                                  final match = stoneProducts.firstWhere((p) => p.productid == v);
                                                  st.productName = match.productname;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            flex: 2,
                                            child: DropdownButtonFormField<int?>(
                                              value: st.subProductId,
                                              dropdownColor: const Color(0xFF1E293B),
                                              decoration: _buildDialogInputDecoration('Sub-Prod'),
                                              items: [
                                                const DropdownMenuItem(value: null, child: Text('--', style: TextStyle(color: Colors.white54, fontSize: 11))),
                                                ...subProds.map((sp) => DropdownMenuItem(value: sp.subproductid, child: Text(sp.subproductname, style: const TextStyle(color: Colors.white, fontSize: 11)))),
                                              ],
                                              onChanged: (v) => setModalState(() => st.subProductId = v),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 80,
                                            child: DropdownButtonFormField<String>(
                                              value: st.unit.toUpperCase() == 'C' ? 'C' : 'G',
                                              dropdownColor: const Color(0xFF1E293B),
                                              decoration: _buildDialogInputDecoration('Unit'),
                                              items: const [
                                                DropdownMenuItem(value: 'G', child: Text('G', style: TextStyle(color: Colors.white, fontSize: 11))),
                                                DropdownMenuItem(value: 'C', child: Text('C', style: TextStyle(color: Color(0xFF34D399), fontSize: 11))),
                                              ],
                                              onChanged: (v) => setModalState(() => st.unit = v ?? 'G'),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 60,
                                            child: TextFormField(
                                              initialValue: st.pcs.toString(),
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                              decoration: _buildDialogInputDecoration('Pcs'),
                                              onChanged: (v) => setModalState(() => st.pcs = int.tryParse(v) ?? 0),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 75,
                                            child: TextFormField(
                                              initialValue: st.weight.toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                              decoration: _buildDialogInputDecoration('Wt'),
                                              onChanged: (v) {
                                                setModalState(() {
                                                  st.weight = double.tryParse(v) ?? 0.0;
                                                  if (st.rate > 0) st.amount = st.weight * st.rate;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 75,
                                            child: TextFormField(
                                              initialValue: st.amount.toStringAsFixed(2),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
                                              decoration: _buildDialogInputDecoration('Amt'),
                                              onChanged: (v) => setModalState(() => st.amount = double.tryParse(v) ?? 0.0),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                            onPressed: () => setModalState(() => editStones.removeAt(idx)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Multi-Diamonds Section
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
                                      const Text("💍 Diamonds (diastone = 'D')", style: TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12)),
                                      const Spacer(),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF0284C7),
                                          foregroundColor: Colors.white,
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(Icons.add, size: 14),
                                        label: const Text('Add Diamond', style: TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          setModalState(() {
                                            editDiamonds.add(TagDiamondItem(
                                              productId: diamondProducts.isNotEmpty ? diamondProducts.first.productid : null,
                                              productName: diamondProducts.isNotEmpty ? diamondProducts.first.productname : '',
                                              unit: 'C',
                                              pcs: 1,
                                              weight: 0.0,
                                              rate: 0.0,
                                              amount: 0.0,
                                            ));
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  ...editDiamonds.asMap().entries.map((entry) {
                                    final idx = entry.key;
                                    final dm = entry.value;
                                    final subProds = _allSubProducts.where((sp) => dm.productId == null || sp.productid == dm.productId).toList();
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 3,
                                            child: DropdownButtonFormField<int?>(
                                              value: dm.productId,
                                              dropdownColor: const Color(0xFF1E293B),
                                              decoration: _buildDialogInputDecoration('Product *'),
                                              items: diamondProducts.map((p) => DropdownMenuItem(value: p.productid, child: Text(p.productname, style: const TextStyle(color: Colors.white, fontSize: 11)))).toList(),
                                              onChanged: (v) {
                                                setModalState(() {
                                                  dm.productId = v;
                                                  final match = diamondProducts.firstWhere((p) => p.productid == v);
                                                  dm.productName = match.productname;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            flex: 2,
                                            child: DropdownButtonFormField<int?>(
                                              value: dm.subProductId,
                                              dropdownColor: const Color(0xFF1E293B),
                                              decoration: _buildDialogInputDecoration('Sub-Prod'),
                                              items: [
                                                const DropdownMenuItem(value: null, child: Text('--', style: TextStyle(color: Colors.white54, fontSize: 11))),
                                                ...subProds.map((sp) => DropdownMenuItem(value: sp.subproductid, child: Text(sp.subproductname, style: const TextStyle(color: Colors.white, fontSize: 11)))),
                                              ],
                                              onChanged: (v) => setModalState(() => dm.subProductId = v),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 80,
                                            child: DropdownButtonFormField<String>(
                                              value: dm.unit.toUpperCase() == 'G' ? 'G' : 'C',
                                              dropdownColor: const Color(0xFF1E293B),
                                              decoration: _buildDialogInputDecoration('Unit'),
                                              items: const [
                                                DropdownMenuItem(value: 'C', child: Text('C', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 11))),
                                                DropdownMenuItem(value: 'G', child: Text('G', style: TextStyle(color: Colors.white, fontSize: 11))),
                                              ],
                                              onChanged: (v) => setModalState(() => dm.unit = v ?? 'C'),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 60,
                                            child: TextFormField(
                                              initialValue: dm.pcs.toString(),
                                              keyboardType: TextInputType.number,
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                              decoration: _buildDialogInputDecoration('Pcs'),
                                              onChanged: (v) => setModalState(() => dm.pcs = int.tryParse(v) ?? 0),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 75,
                                            child: TextFormField(
                                              initialValue: dm.weight.toString(),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(color: Colors.white, fontSize: 11),
                                              decoration: _buildDialogInputDecoration('Wt (ct)'),
                                              onChanged: (v) {
                                                setModalState(() {
                                                  dm.weight = double.tryParse(v) ?? 0.0;
                                                  if (dm.rate > 0) dm.amount = dm.weight * dm.rate;
                                                });
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 75,
                                            child: TextFormField(
                                              initialValue: dm.amount.toStringAsFixed(2),
                                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                              style: const TextStyle(color: Color(0xFFFBBF24), fontSize: 11),
                                              decoration: _buildDialogInputDecoration('Amt'),
                                              onChanged: (v) => setModalState(() => dm.amount = double.tryParse(v) ?? 0.0),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                                            onPressed: () => setModalState(() => editDiamonds.removeAt(idx)),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Pricing details
                            Row(
                              children: [
                                Expanded(child: TextFormField(controller: boardRateCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('Board Rate'), onChanged: (_) => setModalState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: vaCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('VA %'), onChanged: (_) => setModalState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: wastageCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('Wastage %'), onChanged: (_) => setModalState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: mcGCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('MC /g'), onChanged: (_) => setModalState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: mChargeCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('M-Charge'), onChanged: (_) => setModalState(() {}))),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Expanded(child: TextFormField(controller: purchaseTouchCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('Touch %'), onChanged: (_) => setModalState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: purchaseMcCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('Smith MC (₹)'), onChanged: (_) => setModalState(() {}))),
                                const SizedBox(width: 8),
                                Expanded(child: TextFormField(controller: huidCtrl, style: const TextStyle(color: Colors.white), decoration: _buildDialogInputDecoration('HUID'))),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: selectedStatus,
                                    dropdownColor: const Color(0xFF1E293B),
                                    decoration: _buildDialogInputDecoration('Status'),
                                    items: const [
                                      DropdownMenuItem(value: 'IN_STOCK', child: Text('IN_STOCK', style: TextStyle(color: Colors.green, fontSize: 12))),
                                      DropdownMenuItem(value: 'SOLD', child: Text('SOLD', style: TextStyle(color: Colors.grey, fontSize: 12))),
                                      DropdownMenuItem(value: 'RESERVED', child: Text('RESERVED', style: TextStyle(color: Colors.amber, fontSize: 12))),
                                    ],
                                    onChanged: (v) => setModalState(() => selectedStatus = v ?? 'IN_STOCK'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Summary Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF34D399)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Net Wt: ${_weightFmt.format(calcNet)}g (Less: -${_weightFmt.format(totalLess)}g)", style: const TextStyle(color: Color(0xFF34D399), fontWeight: FontWeight.bold)),
                                  Text("Sales MRP: ₹ ${_currencyFmt.format(salesMRP)}", style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                                  Text("Smith Cost: ₹ ${_currencyFmt.format(purchaseCost)}", style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Actions
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
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF059669),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.save_rounded, size: 18),
                            label: const Text('Update Tag', style: TextStyle(fontWeight: FontWeight.bold)),
                            onPressed: () async {
                              final auth = Provider.of<AuthProvider>(context, listen: false);
                              final token = auth.authToken ?? '';

                              final updatePayload = {
                                'gross_weight': grs,
                                'net_weight': calcNet,
                                'styleid': selectedStyleId,
                                'stylename': selectedStyleName,
                                'sizeid': selectedSizeId,
                                'sizename': selectedSizeName,
                                'purityid': selectedPurityId,
                                'stone_pcs': editStones.fold(0, (sum, s) => sum + s.pcs),
                                'stone_weight': editStones.fold(0.0, (sum, s) => sum + s.weight),
                                'stone_amt': stoneAmt,
                                'stone_details': editStones.map((s) => s.toJson()).toList(),
                                'diamond_pcs': editDiamonds.fold(0, (sum, d) => sum + d.pcs),
                                'diamond_weight': editDiamonds.fold(0.0, (sum, d) => sum + d.weight),
                                'diamond_amt': dmdAmt,
                                'diamond_details': editDiamonds.map((d) => d.toJson()).toList(),
                                'board_rate': bRate,
                                'sales_va_percent': vaPct,
                                'sales_wastage': wstPct,
                                'sales_mc_per_gram': mcG,
                                'sales_m_charge': mCharge,
                                'sales_total_amt': salesMRP,
                                'purchase_touch_pct': pTouch,
                                'purchase_gold_rate': pRate,
                                'purchase_mc': pMc,
                                'purchase_stone_cost': stoneAmt,
                                'purchase_diamond_cost': dmdAmt,
                                'purchase_total_cost': purchaseCost,
                                'huid': huidCtrl.text.trim(),
                                'status': selectedStatus,
                                'remarks': remarksCtrl.text.trim(),
                              };

                              final res = await _api.updateStockTag(token, item.itemId, updatePayload);
                              if (ctx.mounted && res['success'] == true) {
                                Navigator.pop(ctx);
                                _showToast('✓ Tag ${item.skuCode} updated successfully!');
                                _loadInitialData();
                              } else if (res['success'] != true) {
                                _showToast(res['message'] ?? 'Failed to update tag.', isError: true);
                              }
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
  }

  /// Print Selected Tags
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
                width: 620,
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
                                                  const Spacer(),
                                                  Text(
                                                    '${lot.totalPcs} Pcs | ${_weightFmt.format(lot.totalGrossWeight)}g',
                                                    style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold, fontSize: 12),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Smith: ${lot.designername ?? 'N/A'} | Sub: ${lot.subproductname ?? '-'}',
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

              // 2. Scrollable Content (Top Lot Summary & Entry Form + Bottom Tagged Grid)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // LOT SUMMARY & PROGRESS BAR
                    _buildLotSummaryAndProgressCard(),
                    const SizedBox(height: 14),

                    // TOP PIECE TAGGING ENTRY FORM
                    _buildTopPieceTaggingForm(),
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
                'Stock Barcode & Item Tagging',
                style: TextStyle(color: GlassTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                'Piece-by-Piece Weight Entry, Style Master, Size Master, Purity, Price Setting & 1-Click Print',
                style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
              ),
            ],
          ),
          const Spacer(),

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

  // --- LOT SUMMARY & PROGRESS BAR ---
  Widget _buildLotSummaryAndProgressCard() {
    if (_selectedLot == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: GlassTheme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: GlassTheme.accentAmber.withValues(alpha: 0.6), width: 1.5),
          boxShadow: [
            BoxShadow(color: GlassTheme.accentAmber.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_rounded, color: GlassTheme.accentAmber, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select a Prepare SKU Lot to Start Tagging',
                    style: TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_allLots.length} lot(s) available in inventory. Choose from dropdown or click search.',
                    style: const TextStyle(color: GlassTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Quick Lot Dropdown
            if (_allLots.isNotEmpty)
              Container(
                width: 250,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: GlassTheme.bgSurfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GlassTheme.glassBorder),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: null,
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    hint: const Text('⚡ Quick Select Lot...', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                    items: _allLots.map((lot) {
                      return DropdownMenuItem<int>(
                        value: lot.lotId,
                        child: Text(
                          'Lot ${lot.lotNumber} - ${lot.productname ?? 'Ornament'} (${lot.totalPcs} pcs)',
                          style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (id) {
                      if (id != null) {
                        final chosen = _allLots.firstWhere((l) => l.lotId == id);
                        _onLotSelected(chosen);
                      }
                    },
                  ),
                ),
              ),
            const SizedBox(width: 10),

            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: GlassTheme.accentAmber,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Search & Select Lot', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              onPressed: _showLotPickerDialog,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: GlassTheme.bgSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Lot Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: GlassTheme.accentAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_rounded, size: 16, color: GlassTheme.accentAmber),
                    const SizedBox(width: 6),
                    Text('Lot ${_selectedLot!.lotNumber}',
                        style: const TextStyle(color: GlassTheme.accentAmber, fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Item details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_selectedLot!.productname ?? 'Ornament'} ${_selectedLot!.subproductname != null ? "- ${_selectedLot!.subproductname}" : ""} (${_selectedLot!.purityname ?? '22K'})',
                      style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Smith / Karigar: ${_selectedLot!.designername ?? 'N/A'}',
                      style: const TextStyle(color: GlassTheme.textSecondary, fontSize: 11),
                    ),
                  ],
                ),
              ),

              // Change Lot Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF0284C7)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16, color: Color(0xFF0284C7)),
                label: const Text('Change Lot', style: TextStyle(color: Color(0xFF0284C7), fontSize: 11, fontWeight: FontWeight.bold)),
                onPressed: _showLotPickerDialog,
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),

          // 3-Pill Counters: Lot Total, Tagged, Remaining
          Row(
            children: [
              _buildKpiCard(
                title: '📦 Lot Total',
                pcs: '$_lotTotalPcs Pcs',
                wt: '${_weightFmt.format(_lotTotalGrossWeight)} g',
                color: const Color(0xFF64748B),
              ),
              const SizedBox(width: 10),
              _buildKpiCard(
                title: '🏷️ Tagged Pieces',
                pcs: '$_taggedPcsCount Pcs',
                wt: '${_weightFmt.format(_taggedGrossWeight)} g',
                color: const Color(0xFF059669),
              ),
              const SizedBox(width: 10),
              _buildKpiCard(
                title: '⏳ Remaining to Tag',
                pcs: '$_remainingPcs Pcs',
                wt: '${_weightFmt.format(_remainingGrossWeight)} g',
                color: _remainingPcs > 0 ? const Color(0xFFD97706) : const Color(0xFF059669),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _taggingProgress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFE2E8F0),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _taggingProgress >= 1.0 ? const Color(0xFF059669) : const Color(0xFF0284C7),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${(_taggingProgress * 100).toStringAsFixed(0)}% ($_taggedPcsCount/$_lotTotalPcs Pcs)',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({required String title, required String pcs, required String wt, required Color color}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(pcs, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                Text(wt, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- TOP PIECE TAGGING ENTRY FORM ---
  Widget _buildTopPieceTaggingForm() {
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
          // Section Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: GlassTheme.primaryNeon.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit_note_rounded, color: GlassTheme.primaryNeon, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Piece Tag Entry (#${_taggedPcsCount + 1})',
                    style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                  const Text(
                    'Type weight, select style/size & press Enter or "Save & Tag Piece"',
                    style: TextStyle(color: GlassTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),
              if (_selectedLot == null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: GlassTheme.accentAmber.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GlassTheme.accentAmber),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline, size: 14, color: GlassTheme.accentAmber),
                      SizedBox(width: 4),
                      Text('Please select a Lot above to begin tagging', style: TextStyle(color: GlassTheme.accentAmber, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              if (_isSearchingVa)
                const Row(
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0284C7))),
                    SizedBox(width: 6),
                    Text('Auto VA Lookup...', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7))),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 14),

          // ROW 1: Weight Inputs (Gross, Net), Style Master, Size Master, Purity
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Pcs (default 1)
              SizedBox(
                width: 70,
                child: _buildFormField(
                  label: 'Pcs',
                  controller: _pcsController,
                  focusNode: _pcsFocusNode,
                  nextFocusNode: _grossWeightFocusNode,
                  isNum: true,
                ),
              ),
              const SizedBox(width: 10),

              // 2. GROSS WEIGHT (g) - Auto Focused & Enter opens Stone/Diamond popup or advances
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Gross Weight (g) *',
                          style: TextStyle(
                            color: _grossWeightFocusNode.hasFocus ? GlassTheme.accentAmber : GlassTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text('(Enter for Stones)', style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
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
                          _netWeightFocusNode.requestFocus();
                        } else {
                          _showToast('Please enter a valid Gross Weight (e.g. 10.250g)', isError: true);
                        }
                      },
                      onChanged: _onGrossWeightChanged,
                      style: const TextStyle(color: GlassTheme.accentAmber, fontSize: 15, fontWeight: FontWeight.w900),
                      decoration: InputDecoration(
                        hintText: 'e.g. 10.250',
                        hintStyle: TextStyle(color: GlassTheme.textMuted.withValues(alpha: 0.5), fontSize: 13),
                        filled: true,
                        fillColor: GlassTheme.accentAmber.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        isDense: true,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: GlassTheme.accentAmber.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: GlassTheme.accentAmber, width: 2.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // 3. STONES & LESS WEIGHT ACTION BUTTON / BADGE
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Stones / Less Wt', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: _openStoneDiamondDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: _calculatedLessWeight > 0 ? const Color(0xFF064E3B) : const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _calculatedLessWeight > 0 ? const Color(0xFF34D399) : const Color(0xFF475569),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.diamond_outlined,
                            size: 16,
                            color: _calculatedLessWeight > 0 ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
                          ),
                          const SizedBox(width: 6),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _calculatedLessWeight > 0 ? 'Less: -${_weightFmt.format(_calculatedLessWeight)}g' : '💎 Add Stones',
                                style: TextStyle(
                                  color: _calculatedLessWeight > 0 ? const Color(0xFF34D399) : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _calculatedLessWeight > 0 ? 'Tap to edit' : 'Click / Grid ↵',
                                style: TextStyle(
                                  color: _calculatedLessWeight > 0 ? Colors.white70 : const Color(0xFF94A3B8),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),

              // 4. NET WEIGHT (g)
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'Net Gold Wt (g)',
                  controller: _netWeightController,
                  focusNode: _netWeightFocusNode,
                  nextFocusNode: _boardRateFocusNode,
                  isNum: true,
                  hint: 'Auto calc',
                ),
              ),
              const SizedBox(width: 10),

              // 5. STYLE MASTER DROPDOWN
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Style Master *', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('(${_availableStyles.length})', style: const TextStyle(fontSize: 10, color: GlassTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: GlassTheme.bgSurfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GlassTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedStyle?.styleid,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          hint: const Text('Select Style (e.g. Plain, Antique)', style: TextStyle(color: GlassTheme.textMuted, fontSize: 12)),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('None / Standard', style: TextStyle(fontSize: 12, color: GlassTheme.textMuted)),
                            ),
                            ..._availableStyles.map((s) {
                              return DropdownMenuItem<int?>(
                                value: s.styleid,
                                child: Text(s.stylename, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              );
                            }),
                          ],
                          onChanged: (id) {
                            setState(() {
                              _selectedStyle = id != null ? _availableStyles.firstWhere((s) => s.styleid == id) : null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 6. SIZE MASTER DROPDOWN
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Item Size *', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 4),
                        Text('(${_availableSizes.length})', style: const TextStyle(fontSize: 10, color: GlassTheme.textMuted)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: GlassTheme.bgSurfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GlassTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedSize?.sizeid,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          hint: const Text('Select Size (e.g. 2.4, 14)', style: TextStyle(color: GlassTheme.textMuted, fontSize: 12)),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Free / N/A', style: TextStyle(fontSize: 12, color: GlassTheme.textMuted)),
                            ),
                            ..._availableSizes.map((sz) {
                              return DropdownMenuItem<int?>(
                                value: sz.sizeid,
                                child: Text(sz.sizename, style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                              );
                            }),
                          ],
                          onChanged: (id) {
                            setState(() {
                              _selectedSize = id != null ? _availableSizes.firstWhere((sz) => sz.sizeid == id) : null;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),

              // 7. PURITY DROPDOWN
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Purity *', style: TextStyle(color: GlassTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: GlassTheme.bgSurfaceMuted,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: GlassTheme.glassBorder),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _selectedPurity?.purityid ?? (_selectedLot?.purityid ?? (_allPurities.isNotEmpty ? _allPurities.first.purityid : null)),
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          items: _allPurities.map((p) {
                            return DropdownMenuItem<int>(
                              value: p.purityid,
                              child: Text('${p.purityname} (${p.purity}%)', style: const TextStyle(color: GlassTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
                            );
                          }).toList(),
                          onChanged: (id) {
                            if (id != null) {
                              setState(() {
                                _selectedPurity = _allPurities.firstWhere((p) => p.purityid == id);
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ROW 2: Stones & Diamonds (Interactive itemization trigger & dynamic chips)
          InkWell(
            onTap: _openStoneDiamondDialog,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty)
                    ? const Color(0xFF0284C7).withValues(alpha: 0.08)
                    : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty)
                      ? const Color(0xFF38BDF8)
                      : const Color(0xFFE2E8F0),
                  width: (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty) ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty)
                          ? const Color(0xFF0284C7).withValues(alpha: 0.15)
                          : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.diamond_rounded,
                      size: 16,
                      color: (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty)
                          ? const Color(0xFF0284C7)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "STONES & DIAMONDS ITEMIZATION (${_stoneItems.length} Stones, ${_diamondItems.length} Diamonds)",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty)
                                    ? const Color(0xFF0284C7)
                                    : const Color(0xFF475569),
                                letterSpacing: 0.5,
                              ),
                            ),
                            const Spacer(),
                            if (_totalLessWeight > 0 || _totalStoneAmount + _totalDiamondAmount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFFCA5A5)),
                                ),
                                child: Text(
                                  "Less Wt: -${_weightFmt.format(_totalLessWeight)} g",
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF6EE7B7)),
                                ),
                                child: Text(
                                  "Stn/Dmd Value: ₹ ${_currencyFmt.format(_totalStoneAmount + _totalDiamondAmount)}",
                                  style: const TextStyle(color: Color(0xFF059669), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Text(
                              "Click to Edit / Add Items ➜",
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                        if (_stoneItems.isNotEmpty || _diamondItems.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              ..._stoneItems.map((s) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Text(
                                      "💎 ${(s.productName != null && s.productName!.isNotEmpty) ? s.productName! : 'Stone'}: ${s.pcs}pcs (${s.weight}${s.unit}) = -${_weightFmt.format(s.weightInGrams)}g",
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF047857), fontWeight: FontWeight.w600),
                                    ),
                                  )),
                              ..._diamondItems.map((d) => Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF0F9FF),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFBAE6FD)),
                                    ),
                                    child: Text(
                                      "💍 ${(d.productName != null && d.productName!.isNotEmpty) ? d.productName! : 'Diamond'}: ${d.pcs}pcs (${d.weight}${d.unit}) = -${_weightFmt.format(d.weightInGrams)}g",
                                      style: const TextStyle(fontSize: 10, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                                    ),
                                  )),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ROW 3: Sales Pricing & Purchase Costing Dual Panel
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // SALES PRICING BOX
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sell_outlined, size: 14, color: Color(0xFF16A34A)),
                          const SizedBox(width: 6),
                          const Text('Sales Pricing (Price Setting)',
                              style: TextStyle(color: Color(0xFF15803D), fontSize: 11, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('MRP: ₹ ${_currencyFmt.format(_pieceCalculatedSalesPrice)}',
                              style: const TextStyle(color: Color(0xFF16A34A), fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildFormField(
                              label: 'Board Rate (/g)',
                              controller: _boardRateController,
                              focusNode: _boardRateFocusNode,
                              nextFocusNode: _salesVaFocusNode,
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'VA %',
                              controller: _salesVaController,
                              focusNode: _salesVaFocusNode,
                              nextFocusNode: _salesWastageFocusNode,
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'Wastage %',
                              controller: _salesWastageController,
                              focusNode: _salesWastageFocusNode,
                              nextFocusNode: _salesMcGSimpleFocusNode,
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'MC /g (₹)',
                              controller: _salesMcGSimpleController,
                              focusNode: _salesMcGSimpleFocusNode,
                              nextFocusNode: _salesMChargeFocusNode,
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 8),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // SMITH PURCHASE COSTING BOX
              Expanded(
                child: Container(
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
                          const Icon(Icons.monetization_on_outlined, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 6),
                          const Text('Smith Purchase Costing',
                              style: TextStyle(color: Color(0xFF92400E), fontSize: 11, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          Text('Cost: ₹ ${_currencyFmt.format(_pieceCalculatedPurchaseCost)} | Margin: ${_pieceMarginPct.toStringAsFixed(1)}%',
                              style: const TextStyle(color: Color(0xFFB45309), fontSize: 12, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
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
                              label: 'Purchase Rate',
                              controller: _purchaseGoldRateController,
                              focusNode: _purchaseGoldRateFocusNode,
                              nextFocusNode: _purchaseMcFocusNode,
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'Smith MC (₹)',
                              controller: _purchaseMcController,
                              focusNode: _purchaseMcFocusNode,
                              nextFocusNode: _purchaseStoneCostFocusNode,
                              isNum: true,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildFormField(
                              label: 'Stone Cost (₹)',
                              controller: _purchaseStoneCostController,
                              focusNode: _purchaseStoneCostFocusNode,
                              nextFocusNode: _huidFocusNode,
                              isNum: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ROW 4: HUID, Remarks & ACTION BUTTONS
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildFormField(
                  label: 'HUID (Hallmark Unique ID)',
                  controller: _huidController,
                  focusNode: _huidFocusNode,
                  nextFocusNode: _remarksFocusNode,
                  hint: 'e.g. HUID-916ABC',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _buildFormField(
                  label: 'Remarks / Notes',
                  controller: _remarksController,
                  focusNode: _remarksFocusNode,
                  nextFocusNode: _saveAndPrintFocusNode,
                  textInputAction: TextInputAction.next,
                  onFieldSubmitted: () {
                    if (_saveAndPrintFocusNode.canRequestFocus) {
                      _saveAndPrintFocusNode.requestFocus();
                    }
                  },
                  hint: 'e.g. Counter Tray 1 (Enter -> Save & Print)',
                ),
              ),
              const SizedBox(width: 14),

              // ACTION: Save & 1-Click Print (PRIMARY KEYBOARD FOCUS TARGET)
              ElevatedButton.icon(
                focusNode: _saveAndPrintFocusNode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0284C7),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: _saveAndPrintFocusNode.hasFocus ? 4 : 2,
                  side: _saveAndPrintFocusNode.hasFocus
                      ? const BorderSide(color: Color(0xFF38BDF8), width: 2.5)
                      : BorderSide.none,
                ),
                icon: _isSaving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.print_rounded, size: 18),
                label: Text(
                  _isSaving ? 'Tagging...' : 'Save & Print Tag (Enter)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: (_isSaving || _selectedLot == null) ? null : () => _saveAndTagSinglePiece(andPrint: true),
              ),
              const SizedBox(width: 8),

              // ACTION: Save & Tag Single Piece (SAVE ONLY)
              ElevatedButton.icon(
                focusNode: _saveOnlyFocusNode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  side: _saveOnlyFocusNode.hasFocus
                      ? const BorderSide(color: Color(0xFF34D399), width: 2.5)
                      : BorderSide.none,
                ),
                icon: const Icon(Icons.save_rounded, size: 18),
                label: const Text(
                  'Save Only',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: (_isSaving || _selectedLot == null) ? null : () => _saveAndTagSinglePiece(andPrint: false),
              ),
              const SizedBox(width: 8),

              // ACTION: Batch Split Remaining
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: GlassTheme.accentAmber),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                icon: const Icon(Icons.call_split_rounded, size: 16, color: GlassTheme.accentAmber),
                label: Text('Batch Split ($_remainingPcs)', style: const TextStyle(color: GlassTheme.accentAmber, fontWeight: FontWeight.bold, fontSize: 12)),
                onPressed: (_selectedLot == null || _remainingPcs <= 0) ? null : _showBatchSplitDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- BOTTOM TAGGED ITEMS TABLE ---
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
                                  child: InkWell(
                                    onTap: () => _openEditTagDialog(item),
                                    borderRadius: BorderRadius.circular(6),
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
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 16, color: Color(0xFF059669)),
                                  tooltip: 'Edit Tag / Stones',
                                  onPressed: () => _openEditTagDialog(item),
                                ),
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
                                      final auth = Provider.of<AuthProvider>(context, listen: false);
                                      final token = auth.authToken ?? '';
                                      _api.markStockTagsPrinted(token, itemIds: [item.itemId]);
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
        ],
      ),
    );
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
    return Focus(
      focusNode: focusNode != null ? null : null,
      child: Builder(
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
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                    borderSide: BorderSide(color: GlassTheme.accentAmber, width: 2.0),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
