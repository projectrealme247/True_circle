import 'agent_log_stub.dart'
    if (dart.library.js_interop) 'agent_log_web.dart' as impl;

void agentLog({
  required String location,
  required String message,
  required Map<String, Object?> data,
  required String hypothesisId,
  String runId = 'pre-fix',
}) =>
    impl.agentLog(
      location: location,
      message: message,
      data: data,
      hypothesisId: hypothesisId,
      runId: runId,
    );
