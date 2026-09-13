import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mocks the `com.forma.app/*` platform channels at the binary-messenger
/// level so tests exercise the real `IosNativeBridge` code path.
const formaMethodChannel = MethodChannel('com.forma.app/native');
const formaEventChannelName = 'com.forma.app/capture_events';

/// Routes Dart→native method calls on the Forma method channel.
void mockFormaMethods(Future<Object?>? Function(MethodCall call)? handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    formaMethodChannel,
    handler == null ? null : (call) => handler(call),
  );
}

/// Makes the event channel's internal listen/cancel calls succeed.
void mockFormaEventChannel() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(
    const MethodChannel(formaEventChannelName),
    (call) async => null,
  );
}

/// Delivers a native→Dart event on the Forma event channel.
Future<void> emitFormaEvent(Map<Object?, Object?> event) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    formaEventChannelName,
    const StandardMethodCodec().encodeSuccessEnvelope(event),
    (data) {},
  );
  await Future<void>.delayed(Duration.zero);
}

/// Removes all Forma channel mocks.
void clearFormaChannelMocks() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
    ..setMockMethodCallHandler(formaMethodChannel, null)
    ..setMockMethodCallHandler(
      const MethodChannel(formaEventChannelName),
      null,
    );
}
