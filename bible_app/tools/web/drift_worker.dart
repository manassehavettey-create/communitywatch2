// Source of web/drift_worker.js (the drift database worker for the web
// build). Rebuild with:
//   dart compile js -O2 -o web/drift_worker.js tools/web/drift_worker.dart
import 'package:drift/wasm.dart';

void main() => WasmDatabase.workerMainForOpen();
