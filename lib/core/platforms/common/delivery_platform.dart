/// Delivery platforms the app calls directly (through the backend executor).
///
/// [id] matches the ids the rest of the app already uses (`keeta`,
/// `hungerstation`) and is sent to the executor as its `platform` label.
enum DeliveryPlatform {
  keeta('keeta', 'Keeta'),
  hungerStation('hungerstation', 'HungerStation');

  const DeliveryPlatform(this.id, this.label);

  final String id;
  final String label;
}
