import '../../domain/models/enums.dart';

enum UnitSystem {
  metric('kg / cm'),
  imperial('lb / in');

  const UnitSystem(this.label);
  final String label;
}

/// Everything is stored metric; these convert only for display and input.
abstract final class Units {
  static const kgPerLb = 0.45359237;
  static const cmPerIn = 2.54;

  static double weightToDisplay(double kg, UnitSystem u) => u == UnitSystem.metric ? kg : kg / kgPerLb;
  static double weightFromDisplay(double v, UnitSystem u) => u == UnitSystem.metric ? v : v * kgPerLb;
  static double lengthToDisplay(double cm, UnitSystem u) => u == UnitSystem.metric ? cm : cm / cmPerIn;
  static double lengthFromDisplay(double v, UnitSystem u) => u == UnitSystem.metric ? v : v * cmPerIn;

  static String weightUnit(UnitSystem u) => u == UnitSystem.metric ? 'kg' : 'lb';
  static String lengthUnit(UnitSystem u) => u == UnitSystem.metric ? 'cm' : 'in';

  static String unitFor(MeasurementType t, UnitSystem u) =>
      t == MeasurementType.weight ? weightUnit(u) : lengthUnit(u);

  static double toDisplay(MeasurementType t, double metric, UnitSystem u) =>
      t == MeasurementType.weight ? weightToDisplay(metric, u) : lengthToDisplay(metric, u);

  static double fromDisplay(MeasurementType t, double v, UnitSystem u) =>
      t == MeasurementType.weight ? weightFromDisplay(v, u) : lengthFromDisplay(v, u);

  static String format(double v, {int decimals = 1}) {
    final s = v.toStringAsFixed(decimals);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  static String formatMeasurement(MeasurementType t, double metric, UnitSystem u) =>
      '${format(toDisplay(t, metric, u))} ${unitFor(t, u)}';

  static String formatDelta(MeasurementType t, double metricDelta, UnitSystem u) {
    final v = toDisplay(t, metricDelta, u);
    final sign = v > 0 ? '+' : (v < 0 ? '−' : '±');
    return '$sign${format(v.abs())} ${unitFor(t, u)}';
  }

  /// Feet + inches label for heights in imperial.
  static String height(double cm, UnitSystem u) {
    if (u == UnitSystem.metric) return '${cm.round()} cm';
    final totalIn = (cm / cmPerIn).round();
    return '${totalIn ~/ 12}′ ${totalIn % 12}″';
  }
}
