import 'package:flutter/foundation.dart';
import '../models/host.dart';
import '../services/host_storage_service.dart';

/// Provider class for managing the state of hosts in the application.
///
/// Handles loading, adding, updating, and deleting hosts using [HostStorageService].
/// Notifies listeners (UI components) when the list of hosts changes.
class HostProvider with ChangeNotifier {
  final HostStorageService _storageService = HostStorageService();
  List<Host> _hosts = [];
  bool _isLoading = false;

  /// Returns the list of currently loaded hosts.
  List<Host> get hosts => _hosts;

  /// Returns true if the hosts are currently being loaded from storage.
  bool get isLoading => _isLoading;

  /// Loads the list of hosts from persistent storage.
  ///
  /// Sets [isLoading] to true while loading and notifies listeners upon completion.
  Future<void> loadHosts() async {
    _isLoading = true;
    notifyListeners();

    try {
      _hosts = await _storageService.loadHosts();
    } catch (e) {
      _hosts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Adds a new host to the list and saves it to storage.
  ///
  /// [host] is the new host configuration to add.
  Future<void> addHost(Host host) async {
    try {
      await _storageService.addHost(host);
      _hosts.add(host);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Updates an existing host in the list and storage.
  ///
  /// [host] must have the same ID as the host to be updated.
  Future<void> updateHost(Host host) async {
    try {
      await _storageService.updateHost(host);
      final index = _hosts.indexWhere((h) => h.id == host.id);
      if (index != -1) {
        _hosts[index] = host;
        notifyListeners();
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Deletes a host from the list and storage by its ID.
  ///
  /// [hostId] is the unique identifier of the host to delete.
  Future<void> deleteHost(String hostId) async {
    try {
      await _storageService.deleteHost(hostId);
      _hosts.removeWhere((h) => h.id == hostId);
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  /// Retrieves a specific host by its ID from the current list.
  ///
  /// Returns `null` if no host with the given [hostId] is found.
  Host? getHost(String hostId) {
    try {
      return _hosts.firstWhere((h) => h.id == hostId);
    } catch (e) {
      return null;
    }
  }
}