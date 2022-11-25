import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:uuid/uuid.dart';
import 'common.dart';

class CommandSender {
  final Map<String, Completer<dynamic>> _invokeCommandToResultMap = <String, Completer<dynamic>>{};
  final String _commandReceiverFullId;
  final String _senderFullId;
  final Duration _executionTimeout;

  late ReceivePort _resultReceivePort;

  CommandSender(String id, Duration executionTimeout)
      : _commandReceiverFullId = executorPrefix + id,
        _senderFullId = senderPrefix + id,
        _executionTimeout = executionTimeout {
    _resultReceivePort = ReceivePort(_senderFullId);
    _resultReceivePort.listen(_onResultReceive);
    if (IsolateNameServer.lookupPortByName(_senderFullId) != null) {
      IsolateNameServer.removePortNameMapping(_senderFullId);
    }
    IsolateNameServer.registerPortWithName(_resultReceivePort.sendPort, _senderFullId);
  }

  FutureOr<dynamic> invokeAsync(String commandName, dynamic args) async {
    var uuid = const Uuid();
    var invokeId = uuid.v1();
    var invokePacket = <String, dynamic>{invokerIdKey: invokeId, commandNameKey: commandName, argsKey: args};

    var completer = Completer<dynamic>();
    _invokeCommandToResultMap[invokeId] = completer;
    IsolateNameServer.lookupPortByName(_commandReceiverFullId)?.send(invokePacket);
    return await completer.future.timeout(_executionTimeout);
  }

  FutureOr<void> dispose() {
    IsolateNameServer.removePortNameMapping(_senderFullId);
    _resultReceivePort.close();
  }

  void _onResultReceive(dynamic message) {
    var resultPacket = message as Map<String, dynamic>;
    String invokerId = resultPacket[invokerIdKey];

    var completer = _invokeCommandToResultMap[invokerId];
    _invokeCommandToResultMap.remove(invokerId);

    if (resultPacket.containsKey(errorKey)) {
      completer?.completeError(resultPacket[errorKey]);
    } else {
      dynamic result = resultPacket[resultKey];
      completer?.complete(result);
    }
  }
}