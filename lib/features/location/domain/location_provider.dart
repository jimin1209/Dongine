import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dongine/features/location/data/location_repository.dart';
import 'package:dongine/shared/models/location_model.dart';

final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepository();
});

final familyLocationsProvider =
    StreamProvider.family<List<LocationModel>, String>((ref, familyId) {
  final repository = ref.watch(locationRepositoryProvider);
  return repository.getFamilyLocationsStream(familyId);
});

final locationSharingEnabledProvider = StateProvider<bool>((ref) => true);
