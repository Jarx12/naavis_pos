import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/create_order_dto.dart';
import '../data/orders_repository.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final List<OrderItemIn> cartItems;
  final double subtotal;
  final double? currentRate;
  final Future<void> Function(CreateOrderIn orderPayload) onSubmitOrder;

  const CheckoutScreen({
    super.key,
    required this.cartItems,
    required this.subtotal,
    this.currentRate,
    required this.onSubmitOrder,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameCtrl = TextEditingController();
  final _paymentRefCtrl = TextEditingController();
  final _couponCodeCtrl = TextEditingController();
  final _discountVolumenCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Coupon state
  bool _isValidatingCoupon = false;
  double _couponDiscount = 0.0;
  String? _couponMessage;
  bool _isCouponValid = false;

  double? get _subtotalBs =>
      widget.currentRate != null ? widget.subtotal * widget.currentRate! : null;

  double? get _totalDiscountBs =>
      widget.currentRate != null ? _totalDiscount * widget.currentRate! : null;

  double? get _calculatedTotalBs =>
      widget.currentRate != null
          ? _calculatedTotal * widget.currentRate!
          : null;

  String _selectedDeliveryType = 'PICKUP';
  String _selectedPaymentMethod = 'PAGOMOVIL';
  bool _isSubmitting = false;

  final List<Map<String, String>> _deliveryOptions = const [
    {'value': 'PICKUP', 'label': 'Retiro en Tienda (Pickup)'},
    {'value': 'DELIVERY', 'label': 'Delivery Local'},
    {'value': 'NACIONAL', 'label': 'Envío Nacional'},
  ];

  final List<Map<String, String>> _paymentOptions = const [
    {'value': 'PAGOMOVIL', 'label': 'PagoMóvil'},
    {'value': 'EFECTIVO_USD', 'label': 'Efectivo (\$)'},
    {'value': 'EFECTIVO_BS', 'label': 'Efectivo (Bs)'},
    {'value': 'BINANCE', 'label': 'Binance Pay'},
    {'value': 'PAYPAL', 'label': 'PayPal'},
  ];

  bool get _requiresRef =>
      _selectedPaymentMethod == 'PAGOMOVIL' ||
      _selectedPaymentMethod == 'BINANCE' ||
      _selectedPaymentMethod == 'PAYPAL';

  double get _volumenDiscount =>
      double.tryParse(_discountVolumenCtrl.text) ?? 0.0;
  double get _totalDiscount => _volumenDiscount + _couponDiscount;
  double get _calculatedTotal =>
      (widget.subtotal - _totalDiscount).clamp(0.0, double.infinity);

  /// Descuentos rápidos expresados como fracción del subtotal.
  static const List<double> _quickDiscountFractions = [0.10, 0.20, 0.30];

  /// Aplica un descuento rápido del subtotal al campo "Desc. Volumen".
  void _applyQuickDiscount(double fraction) {
    final amount = widget.subtotal * fraction;
    _discountVolumenCtrl.text = amount.toStringAsFixed(2);
    setState(() {});
  }

  /// Limpia el descuento por volumen introducido.
  void _clearVolumeDiscount() {
    _discountVolumenCtrl.clear();
    setState(() {});
  }

  /// Fila de botones rápidos (10% / 20% / 30%) con el monto que aplican,
  /// más un botón para limpiar el descuento.
  Widget _buildQuickDiscountButtons() {
    final current = _volumenDiscount;

    Widget button(double fraction) {
      final amount = widget.subtotal * fraction;
      final selected = (current - amount).abs() < 0.005;
      final scheme = Theme.of(context).colorScheme;

      return OutlinedButton(
        onPressed: () => _applyQuickDiscount(fraction),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          backgroundColor: selected ? scheme.primaryContainer : null,
          foregroundColor:
              selected ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${(fraction * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        for (final fraction in _quickDiscountFractions) ...[
          Expanded(child: button(fraction)),
          const SizedBox(width: 8),
        ],
        // Limpia el descuento actual. Se deshabilita si no hay nada que limpiar.
        OutlinedButton.icon(
          onPressed: current > 0 ? _clearVolumeDiscount : null,
          icon: const Icon(Icons.close, size: 16),
          label: const Text(
            'Limpiar',
            style: TextStyle(fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
        ),
      ],
    );
  }

  Future<void> _validateCoupon() async {
    final code = _couponCodeCtrl.text.trim();
    if (code.isEmpty) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isValidatingCoupon = true;
      _couponMessage = null;
    });

    try {
      final ordersRepo = ref.read(ordersRepositoryProvider);
      final result = await ordersRepo.validateCoupon(
        code: code,
        cartTotal: widget.subtotal,
      );

      setState(() {
        _isCouponValid = result.valid;
        _couponMessage = result.message;
        _couponDiscount = result.valid ? result.discountAmount : 0.0;
      });
    } catch (e) {
      setState(() {
        _isCouponValid = false;
        _couponMessage = e.toString().replaceAll('Exception: ', '');
        _couponDiscount = 0.0;
      });
    } finally {
      if (mounted) {
        setState(() => _isValidatingCoupon = false);
      }
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = CreateOrderIn(
      customerName: _customerNameCtrl.text.trim(),
      deliveryType: _selectedDeliveryType,
      paymentMethod: _selectedPaymentMethod,
      paymentRef: _paymentRefCtrl.text.trim(),
      couponCode: _couponCodeCtrl.text.trim(),
      discountVolumen: _volumenDiscount,
      note: _noteCtrl.text.trim(),
      items: widget.cartItems,
    );

    try {
      await widget.onSubmitOrder(payload);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _customerNameCtrl.dispose();
    _paymentRefCtrl.dispose();
    _couponCodeCtrl.dispose();
    _discountVolumenCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El inset del teclado se aplica UNA sola vez, en el `Padding` de
      // `showModalBottomSheet` (ver `PosScreen.openCheckoutModal`): la hoja
      // modal está anclada al borde inferior, así que necesita crecer para
      // quedar por encima del teclado.
      //
      // Si además este `Scaffold` lo descontara, se contaría dos veces y
      // quedaría un área en blanco del tamaño del teclado tapando los campos.
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Completar Cobro'),
      ),
      body: SafeArea(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            // Constrain width so it looks good on tablets / wide screens.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: ListView(
                  // Padding fijo: el teclado NO se cuenta aquí. El inset se
                  // aplica una sola vez en el `Padding` de
                  // `showModalBottomSheet` (ver `PosScreen.openCheckoutModal`),
                  // y la lista hace scroll para mantener visible el campo
                  // enfocado.
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    // ── Datos del Cliente ─────────────────────────────
                    const Text(
                      'Datos del Cliente',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customerNameCtrl,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del cliente *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // ── Método de Entrega ─────────────────────────────
                    const Text(
                      'Método de Entrega',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDeliveryType,
                      isExpanded: true,
                      items: _deliveryOptions
                          .map((e) => DropdownMenuItem(
                                value: e['value'],
                                child: Text(
                                  e['label']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedDeliveryType = v!),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.local_shipping),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Método de Pago ────────────────────────────────
                    const Text(
                      'Método de Pago',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedPaymentMethod,
                      isExpanded: true,
                      items: _paymentOptions
                          .map((e) => DropdownMenuItem(
                                value: e['value'],
                                child: Text(
                                  e['label']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _selectedPaymentMethod = v!),
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Referencia (si aplica) ────────────────────────
                    if (_requiresRef) ...[
                      TextFormField(
                        controller: _paymentRefCtrl,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.text,
                        decoration: const InputDecoration(
                          labelText:
                              'Número de Referencia de Pago (Opcional)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.numbers),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Descuentos y Notas ────────────────────────────
                    const Text(
                      'Descuentos y Notas',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),

                    // Coupon + Volumen discount.
                    // Use a LayoutBuilder so on very narrow screens they
                    // stack vertically instead of cramping.
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 380;

                        final couponField = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _couponCodeCtrl,
                                    textInputAction: TextInputAction.done,
                                    textCapitalization:
                                        TextCapitalization.characters,
                                    onFieldSubmitted: (_) => _validateCoupon(),
                                    decoration: const InputDecoration(
                                      labelText: 'Cupón (Opcional)',
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton.filledTonal(
                                  onPressed: _isValidatingCoupon
                                      ? null
                                      : _validateCoupon,
                                  icon: _isValidatingCoupon
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : const Icon(Icons.check),
                                  tooltip: 'Validar Cupón',
                                ),
                              ],
                            ),
                            if (_couponMessage != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                _couponMessage!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _isCouponValid
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                            ],
                          ],
                        );

                        final volumeField = TextFormField(
                          controller: _discountVolumenCtrl,
                          textInputAction: TextInputAction.done,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'^\d*\.?\d*')),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'Desc. Volumen (\$)',
                            // "0.0" es solo un ejemplo (hint), no texto real:
                            // el campo arranca vacío para que el usuario pueda
                            // escribir su valor de inmediato sin borrar nada.
                            hintText: '0.0',
                            border: OutlineInputBorder(),
                          ),
                          // Al enfocar se selecciona todo el contenido para
                          // poder sobrescribirlo escribiendo directamente.
                          onTap: () => _discountVolumenCtrl.selection =
                              const TextSelection(
                                baseOffset: 0,
                                extentOffset: 9999,
                              ),
                          onChanged: (_) => setState(() {}),
                        );

                        // Campo + botones rápidos de descuento por volumen.
                        final volumeSection = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            volumeField,
                            const SizedBox(height: 6),
                            _buildQuickDiscountButtons(),
                          ],
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              couponField,
                              const SizedBox(height: 12),
                              volumeSection,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: couponField),
                            const SizedBox(width: 8),
                            Expanded(child: volumeSection),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 12),

                    TextFormField(
                      controller: _noteCtrl,
                      maxLines: 2,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) =>
                          FocusScope.of(context).unfocus(),
                      decoration: const InputDecoration(
                        labelText: 'Nota (Opcional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Resumen de Montos ─────────────────────────────
                    Card(
                      elevation: 0,
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            // Subtotal
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Subtotal:'),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                        '\$${widget.subtotal.toStringAsFixed(2)}'),
                                    if (_subtotalBs != null)
                                      Text(
                                        'Bs ${_subtotalBs!.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),

                            // Descuento
                            if (_totalDiscount > 0) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Descuento Total:'),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '-\$${_totalDiscount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                            color: Colors.green),
                                      ),
                                      if (_totalDiscountBs != null)
                                        Text(
                                          '-Bs ${_totalDiscountBs!.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[400],
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ],

                            const Divider(height: 20),

                            // Total
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'TOTAL A PAGAR:',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${_calculatedTotal.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: Colors.indigo,
                                      ),
                                    ),
                                    if (_calculatedTotalBs != null)
                                      Text(
                                        'Bs ${_calculatedTotalBs!.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.teal,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Botón Generar Orden ───────────────────────────
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'PROCESAR ORDEN',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),

                    // A little breathing room at the very bottom.
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}