import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:telemetrics_app/companion/companion.dart';
import 'package:telemetrics_data_manager/telemetrics_data_manager.dart';

final telemetricsManagerProvider = Provider<TelemetricsManager>((ref) {
  return TelemetricsManager();
});

class CurrentRideStateNotifier extends StateNotifier<Ride?> {
  CurrentRideStateNotifier() : super(null);

  void updateRide(Ride ride) {
    state = ride;
  }
}

final currentRideProvider = StateNotifierProvider<CurrentRideStateNotifier, Ride?>(
  (ref) => CurrentRideStateNotifier(),
);

final listeningMessage = Provider.autoDispose.family<void, Car>((ref, car) {
  ref.watch(
    processingTelemetricsMessageProvider(
      ProcessingTelemetricsMessageData(
        car: car,
        onRecordStart: (message, car) async {
          final data = RideCreateData(
            name: 'My Ride ${message.time}',
            vin: message.startMessage.vehicleInfo.vin,
            vehicleName: car.name,
            startOdometer: message.startMessage.vehicleInfo.odometer,
          );

          final ride = await ref.watch(ridesRepositoryProvider).createRide(data);

          ref.watch(currentRideProvider.notifier).updateRide(ride);
        },
        onRecordUpdate: (message, car) {
          // final messageText = 'Measure length: ${message.measures.length}';
          // ref.read(messagesStateProvider.notifier).addMessage(messageText);
          // if (message.measures.isNotEmpty) {
          //   for (final element in message.measures) {
          //     final elementText = 'property name: ${element.propertyName}';
          //     ref.read(messagesStateProvider.notifier).addMessage(elementText);
          //   }
          // }
        },
        onRecordEnd: (message, car) {
          final messageText =
              'VIN: ${message.endMessage.vehicleInfo.vin}, odo: ${message.endMessage.vehicleInfo.odometer}';
          // ref.read(messagesStateProvider.notifier).addMessage(messageText);
        },
      ),
    ),
  );
});
