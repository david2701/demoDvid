import 'dart:async';

import 'package:fixnum/fixnum.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../constants/connected_device_constants.dart' as connected_device_constants;
import '../constants/telemetrics_constants.dart' as telemetrics_constants;
import '../generated/host.pb.dart' as proto;
import '../generated/host.pb.dart';
import '../models/car.dart';
import '../models/telemetrics.dart';
import 'method_channel_handler.dart';

class TelemetricsManager extends MethodChannelHandler {
  final _telemetricsController = StreamController<TelemetricsMessageData>.broadcast();

  Stream<TelemetricsMessageData> get onTelemetricsChanged => _telemetricsController.stream;

  Stream<MessageReceived> get onMessageReceived =>
      onTelemetricsChanged.where((event) => event is MessageReceived).map((event) => event as MessageReceived);

  Stream<CarDisassociated> get onCarDisassociated =>
      onTelemetricsChanged.where((event) => event is CarDisassociated).map((event) => event as CarDisassociated);

  TelemetricsManager() : super(const MethodChannel(telemetrics_constants.TELEMETRICS_CHANNEL)) {
    methodChannel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case telemetrics_constants.ON_MESSAGE_RECEIVED:
          final telemetricsMessage = TelemetricsMessage.fromBuffer(
            call.arguments[telemetrics_constants.TELEMETRICS_MESSAGE_KEY],
          );

          _telemetricsController.add(
            MessageReceived(
              message: telemetricsMessage,
              car: Car.fromJson({
                connected_device_constants.CAR_ID_KEY: call.arguments[connected_device_constants.CAR_ID_KEY],
                connected_device_constants.CAR_NAME_KEY: call.arguments[connected_device_constants.CAR_NAME_KEY],
              }),
            ),
          );
          break;

        case telemetrics_constants.ON_CAR_DISASSOCIATED:
          print('ON_CAR_DISASSOCIATED');
          _telemetricsController.add(
            CarDisassociated(
              car: Car.fromJson(call.arguments),
            ),
          );
          break;
        default:
          throw MissingPluginException();
      }
    });
  }

  Future<bool> sendMessage(proto.TelemetricsMessage message, Car car) async {
    return await methodChannel.invokeMethod(telemetrics_constants.SEND_MESSAGE, <String, dynamic>{
      connected_device_constants.CAR_ID_KEY: car.id,
      connected_device_constants.CAR_NAME_KEY: car.name,
      telemetrics_constants.TELEMETRICS_MESSAGE_KEY: message.writeToBuffer(),
    });
  }

  Future<bool> createAndSendMessage(
    proto.MessageType messageType,
    Car car,
  ) async {
    final message = proto.TelemetricsMessage(
      type: messageType,
      id: Uuid().v4(),
      time: Int64(DateTime.now().microsecondsSinceEpoch.abs()),
    );

    return sendMessage(message, car);
  }

  Future<bool> sendAckMessage(
    String id,
    Car car,
  ) async {
    final message = proto.TelemetricsMessage(
      type: proto.MessageType.ACKNOWLEDGE,
      id: id,
      time: Int64(DateTime.now().microsecondsSinceEpoch.abs()),
    );

    final result = await sendMessage(message, car);

    return result;
  }
}
