import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Estado del ahorro de batería de Android.
///
/// Los fabricantes agresivos (Xiaomi, Samsung, Huawei, Oppo, Vivo…) congelan
/// las apps que no están excluidas y las alarmas de las 7:00 AM no suenan.
/// Este servicio consulta el estado y abre los ajustes del sistema.
class BatteryOptimizationService {
  BatteryOptimizationService._();

  static final BatteryOptimizationService instance =
      BatteryOptimizationService._();

  static const MethodChannel _channel = MethodChannel(
    'notificaciones_esm/battery',
  );

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;

  /// Indica si el sistema todavía puede congelar la app.
  ///
  /// Fuera de Android, o si la consulta falla, devuelve `false` para no
  /// mostrar la guía sin certeza.
  Future<bool> isOptimized() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('isBatteryOptimized') ?? false;
    } catch (error) {
      debugPrint('No se pudo consultar el ahorro de batería: $error');
      return false;
    }
  }

  /// Abre la pantalla del sistema para excluir la app del ahorro de batería.
  Future<bool> openSettings() async {
    if (!_isAndroid) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>('openBatterySettings') ?? false;
    } catch (error) {
      debugPrint('No se pudieron abrir los ajustes de batería: $error');
      return false;
    }
  }
}
