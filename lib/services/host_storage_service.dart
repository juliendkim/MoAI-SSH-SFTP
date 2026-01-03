import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/host.dart';

/// Service class for persisting host configurations.
///
/// Uses [SharedPreferences] to store the list of hosts as a JSON string.
class HostStorageService {
  static const String _hostsKey = 'hosts';

  /// Loads the list of hosts from [SharedPreferences].
  ///
  /// Returns an empty list if no hosts are found or if an error occurs.
  Future<List<Host>> loadHosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hostsJson = prefs.getString(_hostsKey);

      if (hostsJson == null) {
        return [];
      }

      final List<dynamic> hostsList = jsonDecode(hostsJson);
      final hosts = hostsList.map((json) => Host.fromJson(json)).toList();
      return hosts;
    } catch (e) {
      return [];
    }
  }

  /// Saves the given list of [hosts] to [SharedPreferences].
  ///
  /// The hosts are serialized to JSON before storage.
  Future<void> saveHosts(List<Host> hosts) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hostsJson = jsonEncode(hosts.map((h) => h.toJson()).toList());
      await prefs.setString(_hostsKey, hostsJson);
    } catch (e) {
      rethrow;
    }
  }

  /// Adds a single [host] to storage.
  ///
  /// This method first loads the existing hosts, appends the new one, and then saves the updated list.
  Future<void> addHost(Host host) async {
    final hosts = await loadHosts();
    hosts.add(host);
    await saveHosts(hosts);
  }

  /// Updates an existing [host] in storage.
  ///
  /// The host is identified by its ID. If found, it is replaced with the new data.
  Future<void> updateHost(Host host) async {
    final hosts = await loadHosts();
    final index = hosts.indexWhere((h) => h.id == host.id);
    if (index != -1) {
      hosts[index] = host;
      await saveHosts(hosts);
    }
  }

  /// Deletes a host with the given [hostId] from storage.
  Future<void> deleteHost(String hostId) async {
    final hosts = await loadHosts();
    hosts.removeWhere((h) => h.id == hostId);
    await saveHosts(hosts);
  }

  /// Retrieves a specific host by its [hostId].
  ///
  /// Returns `null` if the host is not found.
  Future<Host?> getHost(String hostId) async {
    final hosts = await loadHosts();
    try {
      return hosts.firstWhere((h) => h.id == hostId);
    } catch (e) {
      return null;
    }
  }
}