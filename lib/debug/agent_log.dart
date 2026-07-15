import 'agent_log_stub.dart'
    if (dart.library.html) 'agent_log_web.dart' as impl;

void agentLog(
  String hypothesisId,
  String location,
  String message,
  Map<String, dynamic> data,
) =>
    impl.agentLog(hypothesisId, location, message, data);
