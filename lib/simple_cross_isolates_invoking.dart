import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:uuid/uuid.dart';

typedef ExecutionCallback = FutureOr<dynamic> Function(dynamic args);

const String _invokerIdKey = "invoker_id";
const String _commandNameKey = "command_name";
const String _argsKey = "args";
const String _resultKey = "result";
const String _errorKey = "error";
const String _executorPrefix = "executor";
const String _senderPrefix = "sender";

class SimpleCrossIsolatesInvoking {
  SimpleCrossIsolatesInvoking._();

  static CommandExecutor createCommandExecutor(String id, Map<String, ExecutionCallback> commandNamesToCallbacksMap) {
    return CommandExecutor(id, commandNamesToCallbacksMap);
  }

  static CommandSender createCommandSender(String id, [Duration executionTimeout = const Duration(hours: 24)]) =>
      CommandSender(id, executionTimeout);
}

class CommandExecutor {
  late String _commandReceiverFullId;
  final Map<String, ExecutionCallback> _commandNamesToCallbacksMap;

  late String _senderFullId;
  late ReceivePort _commandReceivePort;

  CommandExecutor(String id, this._commandNamesToCallbacksMap) {
    _senderFullId = _senderPrefix + id;
    _commandReceiverFullId = _executorPrefix + id;
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
    String invokerId = invokingPacket[_invokerIdKey];
    String commandName = invokingPacket[_commandNameKey];

    dynamic args;
    if (invokingPacket.containsKey(_argsKey)) {
      args = invokingPacket[_argsKey];
    }

    try {
      var result = await _commandNamesToCallbacksMap[commandName]?.call(args);
      var resultPacket = <String, dynamic>{
        _invokerIdKey: invokerId,
        _resultKey: result,
      };
      IsolateNameServer.lookupPortByName(_senderFullId)?.send(resultPacket);
    } catch (error) {
      var resultPacket = <String, dynamic>{
        _invokerIdKey: invokerId,
        _errorKey: error,
      };
      IsolateNameServer.lookupPortByName(_senderFullId)?.send(resultPacket);
    }
  }
}

class CommandSender {
  final Map<String, Completer<dynamic>> _invokeCommandToResultMap = <String, Completer<dynamic>>{};
  final String _commandReceiverFullId;
  final String _senderFullId;
  final Duration _executionTimeout;

  late ReceivePort _resultReceivePort;

  CommandSender(String id, Duration executionTimeout)
      : _commandReceiverFullId = _executorPrefix + id,
        _senderFullId = _senderPrefix + id,
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
    var invokePacket = <String, dynamic>{_invokerIdKey: invokeId, _commandNameKey: commandName, _argsKey: args};

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
    String invokerId = resultPacket[_invokerIdKey];

    var completer = _invokeCommandToResultMap[invokerId];
    _invokeCommandToResultMap.remove(invokerId);

    if (resultPacket.containsKey(_errorKey)) {
      completer?.completeError(resultPacket[_errorKey]);
    } else {
      dynamic result = resultPacket[_resultKey];
      completer?.complete(result);
    }
  }
}
