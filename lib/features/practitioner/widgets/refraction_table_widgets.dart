import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/refraction_prescription_model.dart';

/// Editable refraction table widget for practitioner input
class RefractionTableWidget extends StatefulWidget {
  final String title;
  final SubjectiveRefractionData initialData;
  final Function(SubjectiveRefractionData) onDataChanged;
  final Function(bool) onVerifiedChanged;
  final bool showAddColumn;

  const RefractionTableWidget({
    super.key,
    required this.title,
    required this.initialData,
    required this.onDataChanged,
    required this.onVerifiedChanged,
    this.showAddColumn = true,
  });

  @override
  State<RefractionTableWidget> createState() => _RefractionTableWidgetState();
}

class _RefractionTableWidgetState extends State<RefractionTableWidget> {
  late TextEditingController _sphController;
  late TextEditingController _cylController;
  late TextEditingController _axisController;
  late TextEditingController _vnController;
  late TextEditingController _prismController;
  late TextEditingController _addController;

  // Track which fields have been edited
  final Map<String, bool> _edited = {};

  @override
  void initState() {
    super.initState();
    _sphController = TextEditingController(text: widget.initialData.sph);
    _cylController = TextEditingController(text: widget.initialData.cyl);
    _axisController = TextEditingController(text: widget.initialData.axis);
    _vnController = TextEditingController(text: widget.initialData.vn);
    _prismController = TextEditingController(text: widget.initialData.prism);
    _addController = TextEditingController(text: widget.initialData.add);

    // Add listeners to track edits
    _sphController.addListener(() => _markEdited('sph'));
    _cylController.addListener(() => _markEdited('cyl'));
    _axisController.addListener(() => _markEdited('axis'));
    _vnController.addListener(() => _markEdited('vn'));
    _prismController.addListener(() => _markEdited('prism'));
    _addController.addListener(() => _markEdited('add'));
  }

  void _markEdited(String field) {
    if (!_edited.containsKey(field)) {
      setState(() => _edited[field] = true);
      _checkVerificationStatus();
      _notifyChange();
    }
  }

  bool get _isAllVerified {
    final requiredFields = ['sph', 'cyl', 'axis', 'vn', 'prism'];
    if (widget.showAddColumn) {
      requiredFields.add('add');
    }
    for (final field in requiredFields) {
      if (!(_edited[field] ?? false)) return false;
    }
    return true;
  }

  void _verifyAll() {
    setState(() {
      _edited['sph'] = true;
      _edited['cyl'] = true;
      _edited['axis'] = true;
      _edited['vn'] = true;
      _edited['prism'] = true;
      _edited['add'] = true;
    });
    _checkVerificationStatus();
    _notifyChange();
  }

  void _checkVerificationStatus() {
    final requiredFields = ['sph', 'cyl', 'axis', 'vn', 'prism'];
    if (widget.showAddColumn) {
      requiredFields.add('add');
    }

    bool allVerified = true;
    for (final field in requiredFields) {
      if (!(_edited[field] ?? false)) {
        allVerified = false;
        break;
      }
    }
    widget.onVerifiedChanged(allVerified);
  }

  void _notifyChange() {
    widget.onDataChanged(
      SubjectiveRefractionData(
        sph: _sphController.text,
        cyl: _cylController.text,
        axis: _axisController.text,
        vn: _vnController.text,
        prism: _prismController.text,
        add: _addController.text,
      ),
    );
  }

  void _adjustValue(
    TextEditingController controller,
    double delta, {
    bool isAxis = false,
    bool isDiopter = false,
    bool isVA = false,
    double min = -20.0,
    double max = 20.0,
  }) {
    if (isVA) {
      const vnList = [
        '6/6',
        '6/9',
        '6/12',
        '6/18',
        '6/24',
        '6/36',
        '6/60',
        '5/60',
        '4/60',
        '3/60',
        '2/60',
        '1/60',
        'PL',
        'NPL',
      ];
      String current = controller.text.toUpperCase().trim();
      int index = vnList.indexOf(current);
      if (index != -1) {
        int nextIndex = index + (delta > 0 ? -1 : 1);
        if (nextIndex >= 0 && nextIndex < vnList.length) {
          controller.text = vnList[nextIndex];
        }
      } else {
        controller.text = vnList[0];
      }
      return;
    }

    if (isAxis) {
      int val = int.tryParse(controller.text) ?? 0;
      val = (val + delta.toInt());
      if (val > 180) val = 1;
      if (val < 1) val = 180;
      controller.text = val.toString();
    } else if (isDiopter) {
      double current = double.tryParse(controller.text) ?? 0.0;
      double newVal = current + delta;
      // Round to nearest 0.25 step (Discrete value logic)
      newVal = (newVal / 0.25).roundToDouble() * 0.25;
      newVal = newVal.clamp(min, max);
      String sign = newVal > 0 ? '+' : '';
      if (newVal == 0) sign = '';
      controller.text = '$sign${newVal.toStringAsFixed(2)}';
    }
  }

  @override
  void dispose() {
    _sphController.dispose();
    _cylController.dispose();
    _axisController.dispose();
    _vnController.dispose();
    _prismController.dispose();
    _addController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _verifyAll,
                  icon: Icon(
                    _isAllVerified ? Icons.check_circle : Icons.done_all,
                    size: 16,
                  ),
                  label: Text(
                    _isAllVerified ? 'Verified' : 'Verify All',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _isAllVerified
                        ? AppColors.success
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // Table or Stacked View
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              if (isNarrow) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _buildStackedField(
                        'SPH',
                        _sphController,
                        'sph',
                        true,
                        min: -20.0,
                        max: 20.0,
                      ),
                      _buildStackedField(
                        'CYL',
                        _cylController,
                        'cyl',
                        true,
                        min: -6.0,
                        max: 6.0,
                      ),
                      _buildStackedField(
                        'AXIS',
                        _axisController,
                        'axis',
                        false,
                        isAxis: true,
                      ),
                      _buildStackedField(
                        'VN',
                        _vnController,
                        'vn',
                        false,
                        isVA: true,
                      ),
                      _buildStackedField(
                        'PRISM',
                        _prismController,
                        'prism',
                        true,
                        min: 0.0,
                        max: 10.0,
                      ),
                      if (widget.showAddColumn)
                        _buildStackedField(
                          'ADD',
                          _addController,
                          'add',
                          true,
                          min: 0.0,
                          max: 4.5,
                        ),
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 500),
                        child: Table(
                          border: TableBorder.all(
                            color: AppColors.border,
                            width: 0.5,
                          ),
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(0.8),
                            3: FlexColumnWidth(0.8),
                            4: FlexColumnWidth(0.8),
                            5: FlexColumnWidth(0.8),
                          },
                          children: [
                            // Header row
                            TableRow(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                              ),
                              children: [
                                _buildHeaderCell('SPH'),
                                _buildHeaderCell('CYL'),
                                _buildHeaderCell('AXIS'),
                                _buildHeaderCell('VN'),
                                _buildHeaderCell('PRISM'),
                                if (widget.showAddColumn)
                                  _buildHeaderCell('ADD'),
                              ],
                            ),
                            // Data row
                            TableRow(
                              children: [
                                _buildEditableCell(
                                  _sphController,
                                  'sph',
                                  isDiopter: true,
                                  min: -20.0,
                                  max: 20.0,
                                ),
                                _buildEditableCell(
                                  _cylController,
                                  'cyl',
                                  isDiopter: true,
                                  min: -6.0,
                                  max: 6.0,
                                ),
                                _buildEditableCell(
                                  _axisController,
                                  'axis',
                                  isAxis: true,
                                ),
                                _buildEditableCell(
                                  _vnController,
                                  'vn',
                                  isVisualAcuity: true,
                                ),
                                _buildEditableCell(
                                  _prismController,
                                  'prism',
                                  isDiopter: true,
                                  min: 0.0,
                                  max: 10.0,
                                ),
                                if (widget.showAddColumn)
                                  _buildEditableCell(
                                    _addController,
                                    'add',
                                    isDiopter: true,
                                    min: 0.0,
                                    max: 4.5,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  Widget _buildStackedField(
    String label,
    TextEditingController controller,
    String fieldName,
    bool isDiopter, {
    bool isAxis = false,
    bool isVA = false,
    double min = -20.0,
    double max = 20.0,
  }) {
    final isEdited = _edited[fieldName] ?? false;
    final backgroundColor = isEdited
        ? AppColors.white
        : Colors.yellow.withOpacity(0.1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              _buildTweakButton(Icons.remove, () {
                _adjustValue(
                  controller,
                  isAxis ? -5 : (isVA ? -1 : -0.25),
                  isAxis: isAxis,
                  isDiopter: isDiopter,
                  isVA: isVA,
                  min: min,
                  max: max,
                );
              }),
              Expanded(
                child: Container(
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border, width: 0.5),
                  ),
                  child: TextField(
                    controller: controller,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    keyboardType: isDiopter || isAxis
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    inputFormatters: isDiopter
                        ? [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^[+-]?\d*\.?\d*$'),
                            ),
                          ]
                        : isAxis
                        ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*$'))]
                        : [],
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      border: InputBorder.none,
                      hintText: isDiopter
                          ? '±0.00'
                          : isAxis
                          ? '0-180'
                          : isVA
                          ? '6/6'
                          : '',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ),
              _buildTweakButton(Icons.add, () {
                _adjustValue(
                  controller,
                  isAxis ? 5 : (isVA ? 1 : 0.25),
                  isAxis: isAxis,
                  isDiopter: isDiopter,
                  isVA: isVA,
                  min: min,
                  max: max,
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTweakButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: AppColors.primary.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
      ),
    );
  }

  Widget _buildEditableCell(
    TextEditingController controller,
    String fieldName, {
    bool isDiopter = false,
    bool isAxis = false,
    bool isVisualAcuity = false,
    double min = -20.0,
    double max = 20.0,
  }) {
    final isEdited = _edited[fieldName] ?? false;
    final backgroundColor = isEdited
        ? AppColors.white
        : Colors.yellow.withOpacity(0.1);

    return Container(
      color: backgroundColor,
      padding: const EdgeInsets.all(2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  keyboardType: isDiopter || isAxis
                      ? const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        )
                      : TextInputType.text,
                  inputFormatters: isDiopter
                      ? [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^[+-]?\d*\.?\d*$'),
                          ),
                        ]
                      : isAxis
                      ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*$'))]
                      : [],
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 6,
                    ),
                    border: InputBorder.none,
                    hintText: isDiopter
                        ? '±0.'
                        : isAxis
                        ? '0'
                        : isVisualAcuity
                        ? '6/6'
                        : '',
                    hintStyle: TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary.withOpacity(0.5),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isDiopter || isAxis)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildCellButton(Icons.remove, () {
                  _adjustValue(
                    controller,
                    isAxis ? -5 : (isVisualAcuity ? -1 : -0.25),
                    isAxis: isAxis,
                    isDiopter: isDiopter,
                    isVA: isVisualAcuity,
                    min: min,
                    max: max,
                  );
                }),
                const SizedBox(width: 4),
                _buildCellButton(Icons.add, () {
                  _adjustValue(
                    controller,
                    isAxis ? 5 : (isVisualAcuity ? 1 : 0.25),
                    isAxis: isAxis,
                    isDiopter: isDiopter,
                    isVA: isVisualAcuity,
                    min: min,
                    max: max,
                  );
                }),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCellButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 12, color: AppColors.primary),
      ),
    );
  }
}

/// Final prescription table (two rows: headers and values)
class FinalPrescriptionTableWidget extends StatefulWidget {
  final FinalPrescriptionData initialData;
  final Function(FinalPrescriptionData) onDataChanged;
  final Function(bool) onVerifiedChanged;

  const FinalPrescriptionTableWidget({
    super.key,
    required this.initialData,
    required this.onDataChanged,
    required this.onVerifiedChanged,
  });

  @override
  State<FinalPrescriptionTableWidget> createState() =>
      _FinalPrescriptionTableWidgetState();
}

class _FinalPrescriptionTableWidgetState
    extends State<FinalPrescriptionTableWidget> {
  // Right eye controllers
  late TextEditingController _rightSphController;
  late TextEditingController _rightCylController;
  late TextEditingController _rightAxisController;
  late TextEditingController _rightVnController;
  late TextEditingController _rightPrismController;
  late TextEditingController _rightAddController;

  // Left eye controllers
  late TextEditingController _leftSphController;
  late TextEditingController _leftCylController;
  late TextEditingController _leftAxisController;
  late TextEditingController _leftVnController;
  late TextEditingController _leftPrismController;
  late TextEditingController _leftAddController;

  final Map<String, bool> _edited = {};

  @override
  void initState() {
    super.initState();
    _rightSphController = TextEditingController(
      text: widget.initialData.right.sph,
    );
    _rightCylController = TextEditingController(
      text: widget.initialData.right.cyl,
    );
    _rightAxisController = TextEditingController(
      text: widget.initialData.right.axis,
    );
    _rightVnController = TextEditingController(
      text: widget.initialData.right.vn,
    );
    _rightPrismController = TextEditingController(
      text: widget.initialData.right.prism,
    );
    _rightAddController = TextEditingController(
      text: widget.initialData.right.add,
    );

    _leftSphController = TextEditingController(
      text: widget.initialData.left.sph,
    );
    _leftCylController = TextEditingController(
      text: widget.initialData.left.cyl,
    );
    _leftAxisController = TextEditingController(
      text: widget.initialData.left.axis,
    );
    _leftVnController = TextEditingController(text: widget.initialData.left.vn);
    _leftPrismController = TextEditingController(
      text: widget.initialData.left.prism,
    );
    _leftAddController = TextEditingController(
      text: widget.initialData.left.add,
    );

    // Add listeners
    _rightSphController.addListener(() => _markEdited('rightSph'));
    _rightCylController.addListener(() => _markEdited('rightCyl'));
    _rightAxisController.addListener(() => _markEdited('rightAxis'));
    _rightVnController.addListener(() => _markEdited('rightVn'));
    _rightPrismController.addListener(() => _markEdited('rightPrism'));
    _rightAddController.addListener(() => _markEdited('rightAdd'));

    _leftSphController.addListener(() => _markEdited('leftSph'));
    _leftCylController.addListener(() => _markEdited('leftCyl'));
    _leftAxisController.addListener(() => _markEdited('leftAxis'));
    _leftVnController.addListener(() => _markEdited('leftVn'));
    _leftPrismController.addListener(() => _markEdited('leftPrism'));
    _leftAddController.addListener(() => _markEdited('leftAdd'));
  }

  void _markEdited(String field) {
    if (!_edited.containsKey(field)) {
      setState(() => _edited[field] = true);
      _checkVerificationStatus();
      _notifyChange();
    }
  }

  bool get _isAllVerified {
    final requiredFields = [
      'rightSph',
      'rightCyl',
      'rightAxis',
      'rightVn',
      'rightPrism',
      'rightAdd',
      'leftSph',
      'leftCyl',
      'leftAxis',
      'leftVn',
      'leftPrism',
      'leftAdd',
    ];
    for (final field in requiredFields) {
      if (!(_edited[field] ?? false)) return false;
    }
    return true;
  }

  void _verifyAll() {
    setState(() {
      _edited['rightSph'] = true;
      _edited['rightCyl'] = true;
      _edited['rightAxis'] = true;
      _edited['rightVn'] = true;
      _edited['rightPrism'] = true;
      _edited['rightAdd'] = true;
      _edited['leftSph'] = true;
      _edited['leftCyl'] = true;
      _edited['leftAxis'] = true;
      _edited['leftVn'] = true;
      _edited['leftPrism'] = true;
      _edited['leftAdd'] = true;
    });
    _checkVerificationStatus();
    _notifyChange();
  }

  void _checkVerificationStatus() {
    final requiredFields = [
      'rightSph',
      'rightCyl',
      'rightAxis',
      'rightVn',
      'rightPrism',
      'rightAdd',
      'leftSph',
      'leftCyl',
      'leftAxis',
      'leftVn',
      'leftPrism',
      'leftAdd',
    ];

    bool allVerified = true;
    for (final field in requiredFields) {
      if (!(_edited[field] ?? false)) {
        allVerified = false;
        break;
      }
    }
    widget.onVerifiedChanged(allVerified);
  }

  void _notifyChange() {
    widget.onDataChanged(
      FinalPrescriptionData(
        right: SubjectiveRefractionData(
          sph: _rightSphController.text,
          cyl: _rightCylController.text,
          axis: _rightAxisController.text,
          vn: _rightVnController.text,
          prism: _rightPrismController.text,
          add: _rightAddController.text,
        ),
        left: SubjectiveRefractionData(
          sph: _leftSphController.text,
          cyl: _leftCylController.text,
          axis: _leftAxisController.text,
          vn: _leftVnController.text,
          prism: _leftPrismController.text,
          add: _leftAddController.text,
        ),
      ),
    );
  }

  void _adjustValue(
    TextEditingController controller,
    double delta, {
    bool isAxis = false,
    bool isDiopter = false,
    bool isVA = false,
    double min = -20.0,
    double max = 20.0,
  }) {
    if (isVA) {
      const vnList = [
        '6/6',
        '6/9',
        '6/12',
        '6/18',
        '6/24',
        '6/36',
        '6/60',
        '5/60',
        '4/60',
        '3/60',
        '2/60',
        '1/60',
        'PL',
        'NPL',
      ];
      String current = controller.text.toUpperCase().trim();
      int index = vnList.indexOf(current);
      if (index != -1) {
        int nextIndex = index + (delta > 0 ? -1 : 1);
        if (nextIndex >= 0 && nextIndex < vnList.length) {
          controller.text = vnList[nextIndex];
        }
      } else {
        controller.text = vnList[0];
      }
      return;
    }

    if (isAxis) {
      int val = int.tryParse(controller.text) ?? 0;
      val = (val + delta.toInt());
      if (val > 180) val = 1;
      if (val < 1) val = 180;
      controller.text = val.toString();
    } else if (isDiopter) {
      double current = double.tryParse(controller.text) ?? 0.0;
      double newVal = current + delta;
      // Round to nearest 0.25 step (Discrete value logic)
      newVal = (newVal / 0.25).roundToDouble() * 0.25;
      newVal = newVal.clamp(min, max);
      String sign = newVal > 0 ? '+' : '';
      if (newVal == 0) sign = '';
      controller.text = '$sign${newVal.toStringAsFixed(2)}';
    }
  }

  @override
  void dispose() {
    _rightSphController.dispose();
    _rightCylController.dispose();
    _rightAxisController.dispose();
    _rightVnController.dispose();
    _rightPrismController.dispose();
    _rightAddController.dispose();
    _leftSphController.dispose();
    _leftCylController.dispose();
    _leftAxisController.dispose();
    _leftVnController.dispose();
    _leftPrismController.dispose();
    _leftAddController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Final Prescription',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton.icon(
                  onPressed: _verifyAll,
                  icon: Icon(
                    _isAllVerified ? Icons.check_circle : Icons.done_all,
                    size: 16,
                  ),
                  label: Text(
                    _isAllVerified ? 'Verified' : 'Verify All',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: _isAllVerified
                        ? AppColors.success
                        : AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // Table with LEFT and RIGHT columns
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 450;
              if (isNarrow) {
                return Column(
                  children: [
                    _buildSectionHeader('LEFT'),
                    _buildEyeDataColumn(
                      sphController: _leftSphController,
                      cylController: _leftCylController,
                      axisController: _leftAxisController,
                      vnController: _leftVnController,
                      prismController: _leftPrismController,
                      addController: _leftAddController,
                      prefix: 'left',
                    ),
                    const Divider(height: 1),
                    _buildSectionHeader('RIGHT'),
                    _buildEyeDataColumn(
                      sphController: _rightSphController,
                      cylController: _rightCylController,
                      axisController: _rightAxisController,
                      vnController: _rightVnController,
                      prismController: _rightPrismController,
                      addController: _rightAddController,
                      prefix: 'right',
                    ),
                  ],
                );
              }

              return Table(
                border: TableBorder.all(color: AppColors.border, width: 0.5),
                children: [
                  // Row 1: LEFT | RIGHT headers
                  TableRow(
                    decoration: BoxDecoration(color: AppColors.surface),
                    children: [
                      _buildSectionHeader('LEFT'),
                      _buildSectionHeader('RIGHT'),
                    ],
                  ),
                  // Row 2: Full prescription data
                  TableRow(
                    children: [
                      _buildEyeDataColumn(
                        sphController: _leftSphController,
                        cylController: _leftCylController,
                        axisController: _leftAxisController,
                        vnController: _leftVnController,
                        prismController: _leftPrismController,
                        addController: _leftAddController,
                        prefix: 'left',
                      ),
                      _buildEyeDataColumn(
                        sphController: _rightSphController,
                        cylController: _rightCylController,
                        axisController: _rightAxisController,
                        vnController: _rightVnController,
                        prismController: _rightPrismController,
                        addController: _rightAddController,
                        prefix: 'right',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildEyeDataColumn({
    required TextEditingController sphController,
    required TextEditingController cylController,
    required TextEditingController axisController,
    required TextEditingController vnController,
    required TextEditingController prismController,
    TextEditingController? addController,
    required String prefix,
    bool showAdd = true,
  }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactField(
            'SPH',
            sphController,
            '${prefix}Sph',
            true,
            min: -20.0,
            max: 20.0,
          ),
          _buildCompactField(
            'CYL',
            cylController,
            '${prefix}Cyl',
            true,
            min: -6.0,
            max: 6.0,
          ),
          _buildCompactField(
            'AXIS',
            axisController,
            '${prefix}Axis',
            false,
            isAxis: true,
          ),
          _buildCompactField(
            'VN',
            vnController,
            '${prefix}Vn',
            false,
            isVA: true,
          ),
          _buildCompactField(
            'PRISM',
            prismController,
            '${prefix}Prism',
            true,
            min: 0.0,
            max: 10.0,
          ),
          if (showAdd && addController != null)
            _buildCompactField(
              'ADD',
              addController,
              '${prefix}Add',
              true,
              min: 0.0,
              max: 4.5,
            ),
        ],
      ),
    );
  }

  Widget _buildCompactField(
    String label,
    TextEditingController controller,
    String fieldName,
    bool isDiopter, {
    bool isAxis = false,
    bool isVA = false,
    double min = -20.0,
    double max = 20.0,
  }) {
    final isEdited = _edited[fieldName] ?? false;
    final backgroundColor = isEdited
        ? AppColors.white
        : Colors.yellow.withOpacity(0.1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 45,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          _buildCompactTweakButton(Icons.remove, () {
            _adjustValue(
              controller,
              isAxis ? -5 : (isVA ? -1 : -0.25),
              isAxis: isAxis,
              isDiopter: isDiopter,
              isVA: isVA,
              min: min,
              max: max,
            );
          }),
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                keyboardType: isDiopter || isAxis
                    ? const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      )
                    : TextInputType.text,
                inputFormatters: isDiopter
                    ? [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^[+-]?\d*\.?\d*$'),
                        ),
                      ]
                    : isAxis
                    ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*$'))]
                    : [],
                decoration: InputDecoration(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  border: InputBorder.none,
                  hintText: isDiopter
                      ? '±0.00'
                      : isAxis
                      ? '0'
                      : isVA
                      ? '6/6'
                      : '',
                  hintStyle: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary.withOpacity(0.5),
                  ),
                ),
              ),
            ),
          ),
          _buildCompactTweakButton(Icons.add, () {
            _adjustValue(
              controller,
              isAxis ? 5 : (isVA ? 1 : 0.25),
              isAxis: isAxis,
              isDiopter: isDiopter,
              isVA: isVA,
              min: min,
              max: max,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildCompactTweakButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 14, color: AppColors.primary),
      ),
    );
  }
}
