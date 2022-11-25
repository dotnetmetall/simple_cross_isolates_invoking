import 'src/command_executor.dart';
import 'src/command_sender.dart';
import 'src/common.dart';

export 'src/command_executor.dart';
export 'src/command_sender.dart';

class SimpleCrossIsolatesInvoking {
  SimpleCrossIsolatesInvoking._();

  static CommandExecutor createCommandExecutor(String id, Map<String, ExecutionCallback> commandNamesToCallbacksMap) {
    return CommandExecutor(id, commandNamesToCallbacksMap);
  }

  static CommandSender createCommandSender(String id, [Duration executionTimeout = const Duration(hours: 24)]) =>
      CommandSender(id, executionTimeout);
}
