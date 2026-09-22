import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notificaciones_esm/services/notification_service.dart';

void main() {
  const channelId = 'birthday_alarm_channel_v3';

  group('NotificationService.isChannelEnabledIn', () {
    test('sin canales propios se considera activo (aún no se creó)', () {
      expect(
        NotificationService.isChannelEnabledIn(const [], channelId),
        isTrue,
      );
    });

    test('detecta el canal desactivado por el usuario', () {
      const channels = [
        AndroidNotificationChannel('otro_canal', 'Otro'),
        AndroidNotificationChannel(
          channelId,
          'Cumpleaños',
          importance: Importance.none,
        ),
      ];

      expect(
        NotificationService.isChannelEnabledIn(channels, channelId),
        isFalse,
      );
    });

    test('canal activo con importancia máxima', () {
      const channels = [
        AndroidNotificationChannel(
          channelId,
          'Cumpleaños',
          importance: Importance.max,
        ),
      ];

      expect(
        NotificationService.isChannelEnabledIn(channels, channelId),
        isTrue,
      );
    });

    test('ignora canales que no son el de cumpleaños', () {
      const channels = [
        AndroidNotificationChannel(
          'otro_canal',
          'Otro',
          importance: Importance.none,
        ),
      ];

      expect(
        NotificationService.isChannelEnabledIn(channels, channelId),
        isTrue,
      );
    });
  });
}
