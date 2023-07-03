import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telemetrics_app/companion/companion.dart';

final telemetricsManagerProvider = Provider<TelemetricsManager>((ref) {
  return TelemetricsManager();
});

final startRecordTelemetricsProvider = FutureProvider.autoDispose.family<bool, Car>((ref, car) async {
  return await ref.watch(telemetricsManagerProvider).createAndSendMessage(
        MessageType.RECORD_START,
        car,
      );
});

final stopRecordTelemetricsProvider = FutureProvider.autoDispose.family<bool, Car>(
  (ref, car) async {
    return await ref.watch(telemetricsManagerProvider).createAndSendMessage(
          MessageType.RECORD_END,
          car,
        );
  },
);

@immutable
class AckMessageData {
  final TelemetricsMessage message;
  final Car car;

  const AckMessageData({
    required this.message,
    required this.car,
  });
}

final sendAckMessageTelemetricsProvider = FutureProvider.family<bool, AckMessageData>(
  (ref, data) async {
    return await ref.watch(telemetricsManagerProvider).sendAckMessage(
          data.message.id,
          data.car,
        );
  },
);

final telemetricsMessageProvider = StreamProvider.autoDispose<TelemetricsMessageData>((ref) {
  return ref.watch(telemetricsManagerProvider).onTelemetricsChanged;
});

final onMessageReceivedProvider = StreamProvider.autoDispose<MessageReceived>((ref) {
  return ref.watch(telemetricsManagerProvider).onMessageReceived;
});

final onCarDisassociatedProvider = StreamProvider.autoDispose<CarDisassociated>((ref) {
  return ref.watch(telemetricsManagerProvider).onCarDisassociated;
});

class ProcessingTelemetricsMessageData {
  final Car car;
  final void Function(TelemetricsMessage message, Car car) onRecordStart;
  final void Function(TelemetricsMessage message, Car car) onRecordUpdate;
  final void Function(TelemetricsMessage message, Car car) onRecordEnd;

  ProcessingTelemetricsMessageData({
    required this.car,
    required this.onRecordStart,
    required this.onRecordUpdate,
    required this.onRecordEnd,
  });
}

final processingTelemetricsMessageProvider = Provider.autoDispose.family<void, ProcessingTelemetricsMessageData>((
  ref,
  processingData,
) {
  ref.listen(onMessageReceivedProvider, (previous, next) {
    next.whenOrNull(data: (messageReceived) {
      switch (messageReceived.message.type) {
        case MessageType.RECORD_START:
          print('RECORD_START');
          processingData.onRecordStart(
            messageReceived.message,
            processingData.car,
          );

          ref.watch(
            sendAckMessageTelemetricsProvider(
              AckMessageData(
                message: messageReceived.message,
                car: processingData.car,
              ),
            ),
          );
          break;

        case MessageType.RECORD_UPDATE:
          print('RECORD_UPDATE');
          processingData.onRecordUpdate(
            messageReceived.message,
            processingData.car,
          );

          ref.watch(
            sendAckMessageTelemetricsProvider(
              AckMessageData(
                message: messageReceived.message,
                car: processingData.car,
              ),
            ),
          );
          break;

        case MessageType.RECORD_END:
          print('RECORD_END');
          processingData.onRecordEnd(
            messageReceived.message,
            processingData.car,
          );

          ref.watch(
            sendAckMessageTelemetricsProvider(
              AckMessageData(
                message: messageReceived.message,
                car: processingData.car,
              ),
            ),
          );
          break;

        case MessageType.ACKNOWLEDGE:
          print('ACKNOWLEDGE');
          ref.watch(
            sendAckMessageTelemetricsProvider(
              AckMessageData(
                message: messageReceived.message,
                car: processingData.car,
              ),
            ),
          );
          break;
        case MessageType.ERROR:
          print('ERROR');
          // TODO: Handle this case.
          break;
        case MessageType.UNSPECIFIED_MESSAGE:
          print('UNSPECIFIED_MESSAGE');
          // TODO: Manage this case.
          break;
      }
    });
  });
});
