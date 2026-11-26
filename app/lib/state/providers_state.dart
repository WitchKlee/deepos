import 'dart:async';

import 'package:cc_gateway_client/cc_gateway_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'gateway_state.dart';
import 'sessions_state.dart';

final class ProvidersState {
  const ProvidersState({
    this.providers = const <CcProviderInfo>[],
    this.models = const <CcModelInfo>[],
    this.activeSelection,
    this.globalProviderId = 'anthropic',
    this.globalModel = '',
    this.globalEffort = '',
    this.loginStatus = const <String, Object?>{},
    this.billing = const <String, Object?>{},
    this.loading = false,
    this.error,
  });

  final List<CcProviderInfo> providers;
  final List<CcModelInfo> models;
  final CcSessionModelSelection? activeSelection;
  final String globalProviderId;
  final String globalModel;
  final String globalEffort;
  final Map<String, Object?> loginStatus;
  final Map<String, Object?> billing;
  final bool loading;
  final String? error;

  ProvidersState copyWith({
    List<CcProviderInfo>? providers,
    List<CcModelInfo>? models,
    CcSessionModelSelection? activeSelection,
    String? globalProviderId,
    String? globalModel,
    String? globalEffort,
    Map<String, Object?>? loginStatus,
    Map<String, Object?>? billing,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return ProvidersState(
      providers: providers ?? this.providers,
      models: models ?? this.models,
      activeSelection: activeSelection ?? this.activeSelection,
      globalProviderId: globalProviderId ?? this.globalProviderId,
      globalModel: globalModel ?? this.globalModel,
      globalEffort: globalEffort ?? this.globalEffort,
      loginStatus: loginStatus ?? this.loginStatus,
      billing: billing ?? this.billing,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProvidersController extends Notifier<ProvidersState> {
  @override
  ProvidersState build() {
    final client = ref.watch(gatewayClientProvider).value;
    final activeSid = ref.watch(
      sessionsProvider.select((s) => s.activeSessionId),
    );
    if (client != null) {
      unawaited(refresh(sessionId: activeSid));
    }
    return const ProvidersState();
  }

  Future<void> refresh({String? sessionId}) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final results = await Future.wait<Object?>(<Future<Object?>>[
        client.listProviders(),
        client.getSettings(),
        client.getSessionModel(sessionId: sessionId),
        client.getClaudeLoginStatus().catchError((_) => const <String, Object?>{}),
      ]);
      final providers = results[0]! as List<CcProviderInfo>;
      final settingsRes = results[1]! as Map<String, Object?>;
      final settings = settingsRes['settings'] is Map<String, Object?>
          ? settingsRes['settings']! as Map<String, Object?>
          : settingsRes;
      final sel = results[2]! as CcSessionModelSelection;
      final login = results[3]! as Map<String, Object?>;
      final models = await client
          .listModels(providerId: sel.provider)
          .catchError((_) => const <CcModelInfo>[]);
      state = state.copyWith(
        providers: providers,
        models: models,
        activeSelection: sel,
        globalProviderId: (settings['provider'] ?? 'anthropic').toString(),
        globalModel: (settings['model'] ?? '').toString(),
        globalEffort: (settings['effort'] ?? '').toString(),
        loginStatus: login,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> saveApiKey(String providerId, String apiKey) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.saveApiKey(providerId: providerId, apiKey: apiKey);
    await refresh(sessionId: ref.read(sessionsProvider).activeSessionId);
  }

  Future<void> selectGlobalProvider(String providerId) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.updateSettings(<String, Object?>{'provider': providerId});
    await refresh(sessionId: ref.read(sessionsProvider).activeSessionId);
  }

  Future<void> selectSessionModel({
    String? provider,
    String? model,
    String? effort,
    bool reset = false,
  }) async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    final sid = ref.read(sessionsProvider).activeSessionId;
    if (sid == null) {
      await client.updateSettings(<String, Object?>{
        'provider': ?provider,
        'model': ?model,
        'effort': ?effort,
      });
    } else {
      await client.setSessionModel(
        sessionId: sid,
        provider: provider,
        model: model,
        effort: effort,
        reset: reset,
      );
    }
    await refresh(sessionId: sid);
  }

  Future<String?> startClaudeOAuth() async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return null;
    final res = await client.startClaudeLogin();
    return res['url']?.toString();
  }

  Future<void> logoutClaude() async {
    final client = ref.read(gatewayClientProvider).value;
    if (client == null) return;
    await client.logoutClaude();
    await refresh(sessionId: ref.read(sessionsProvider).activeSessionId);
  }
}

final providersProvider = NotifierProvider<ProvidersController, ProvidersState>(
  ProvidersController.new,
);
