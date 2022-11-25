import 'dart:async';

typedef ExecutionCallback = FutureOr<dynamic> Function(dynamic args);

const String invokerIdKey = "invoker_id";
const String commandNameKey = "command_name";
const String argsKey = "args";
const String resultKey = "result";
const String errorKey = "error";
const String executorPrefix = "executor";
const String senderPrefix = "sender";
