// lib/data/services/payment_service.dart
import 'dart:async';
import 'dart:math';
import 'package:logger/logger.dart';

final _log = Logger();

enum PaymentStatus { initiated, pending, success, failed, cancelled }

class PaymentRequest {
  final String transactionId;
  final double amount;
  final String currency;
  final String phoneNumber;
  final String description;

  PaymentRequest({
    required this.transactionId,
    required this.amount,
    this.currency = 'BWP',
    required this.phoneNumber,
    required this.description,
  });
}

class PaymentResult {
  final PaymentStatus status;
  final String transactionId;
  final String? receiptNumber;
  final String? errorMessage;
  final DateTime timestamp;

  PaymentResult({
    required this.status,
    required this.transactionId,
    this.receiptNumber,
    this.errorMessage,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Orange Money API service — mock implementation.
/// Replace [_useMock] with false and provide real credentials for production.
class PaymentService {
  static const bool _useMock = true;
  static const String _orangeMoneyBaseUrl = 'https://api.orangemoney.bw/v1';
  static const String _mockApiKey = 'MOCK_KEY_spazastock_dev';

  final _random = Random();

  Future<PaymentResult> initiateOrangeMoneyPayment(
    PaymentRequest request,
  ) async {
    _log.i('Initiating Orange Money payment: BWP ${request.amount} → ${request.phoneNumber}');

    if (_useMock) {
      return _mockOrangeMoneyPayment(request);
    }

    // Real Orange Money integration (uncomment when credentials available)
    // return _realOrangeMoneyPayment(request);
    return _mockOrangeMoneyPayment(request);
  }

  // ── Mock implementation ───────────────────────────────────────────────────

  Future<PaymentResult> _mockOrangeMoneyPayment(
    PaymentRequest request,
  ) async {
    // Simulate network latency
    await Future.delayed(Duration(milliseconds: 800 + _random.nextInt(1200)));

    // 85% success rate for realism
    final success = _random.nextDouble() > 0.15;

    if (success) {
      final receipt = 'OM${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
      _log.i('Mock Orange Money success: receipt=$receipt');
      return PaymentResult(
        status: PaymentStatus.success,
        transactionId: request.transactionId,
        receiptNumber: receipt,
      );
    } else {
      _log.w('Mock Orange Money failed: insufficient funds');
      return PaymentResult(
        status: PaymentStatus.failed,
        transactionId: request.transactionId,
        errorMessage: 'Insufficient funds or service unavailable',
      );
    }
  }

  // ── Real Orange Money integration skeleton ────────────────────────────────

  // Future<PaymentResult> _realOrangeMoneyPayment(PaymentRequest request) async {
  //   final response = await http.post(
  //     Uri.parse('$_orangeMoneyBaseUrl/payments'),
  //     headers: {
  //       'Authorization': 'Bearer $_orangeMoneyApiKey',
  //       'Content-Type': 'application/json',
  //     },
  //     body: jsonEncode({
  //       'amount': request.amount,
  //       'currency': request.currency,
  //       'recipient': request.phoneNumber,
  //       'reference': request.transactionId,
  //       'description': request.description,
  //     }),
  //   );
  //   final body = jsonDecode(response.body);
  //   return PaymentResult(
  //     status: _parseStatus(body['status']),
  //     transactionId: body['transaction_id'],
  //     receiptNumber: body['receipt'],
  //   );
  // }

  Future<PaymentResult> initiateMyzakaPayment(
    PaymentRequest request,
  ) async {
    // MyZaka (BTC Botswana) — mock same as Orange Money
    _log.i('Initiating MyZaka payment: BWP ${request.amount}');
    await Future.delayed(Duration(milliseconds: 600 + _random.nextInt(800)));
    final success = _random.nextDouble() > 0.1;
    return PaymentResult(
      status: success ? PaymentStatus.success : PaymentStatus.failed,
      transactionId: request.transactionId,
      receiptNumber: success
          ? 'MZ${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}'
          : null,
      errorMessage: success ? null : 'Transaction declined',
    );
  }
}
