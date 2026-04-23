extension DoubleFormat on double {
  /// Devuelve el número formateado con un máximo de 2 decimales,
  /// eliminando ceros innecesarios a la derecha (ej: 1.50 -> 1.5, 1.00 -> 1).
  String get formatoInventario {
    // Usamos toStringAsFixed(2) para redondear y evitar errores de precisión de punto flotante
    String s = toStringAsFixed(2);
    // Removemos ceros al final
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '');
      // Removemos el punto si quedó al final
      s = s.replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  /// Formato moneda con 2 decimales fijos.
  String get formatoMoneda => toStringAsFixed(2);
}
