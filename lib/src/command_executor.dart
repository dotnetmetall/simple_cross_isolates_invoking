import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'common.dart';

class CommandExecutor {
  late String _commandReceiverFullId;
  final Map<String, ExecutionCallback> _commandNamesToCallbacksMap;

  late String _senderFullId;
  late ReceivePort _commandReceivePort;

  CommandExecutor(String id, this._commandNamesToCallbacksMap) {
    _senderFullId = senderPrefix + id;
    _commandReceiverFullId = executorPrefix + id;
    _commandReceivePort = ReceivePort(_commandReceiverFullId);
    _commandReceivePort.listen(_onCommandReceive);
    IsolateNameServer.registerPortWithName(_commandReceivePort.sendPort, _commandReceiverFullId);
  }

  FutureOr<void> dispose() {
    IsolateNameServer.removePortNameMapping(_commandReceiverFullId);
    _commandReceivePort.close();
  }

  void _onCommandReceive(dynamic message) async {
    var invokingPacket = message as Map<String, dynamic>;
    String invokerId = invokingPacket[invokerIdKey];
    String commandName = invokingPacket[commandNameKey];

    dynamic args;
    if (invokingPacket.containsKey(argsKey)) {
      args = invokingPacket[argsKey];
    }

    try {
      var result = await _commandNamesToCallbacksMap[commandName]?.call(args);
      var resultPacket = <String, dynamic>{
        invokerIdKey: invokerId,
        resultKey: result,
      };
      IsolateNameServer.lookupPortByName(_senderFullId)?.send(resultPacket);
    } catch (error) {
      var resultPacket = <String, dynamic>{
        invokerIdKey: invokerId,
        errorKey: error,
      };
      IsolateNameServer.lookupPortByName(_senderFullId)?.send(resultPacket);
    }
  }
}
