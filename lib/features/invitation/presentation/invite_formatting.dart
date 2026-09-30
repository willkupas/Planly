/// "dd/MM HH:mm" no fuso do aparelho (sem depender de dados de locale do `intl`).
String formatDateTimeShort(DateTime value) {
  final t = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(t.day)}/${two(t.month)} ${two(t.hour)}:${two(t.minute)}';
}
