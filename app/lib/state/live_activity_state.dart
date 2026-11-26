import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notify/live_activity.dart';
import '../notify/notify_channel.dart';
import 'notify_state.dart' show notifyChannelProvider;

export '../notify/live_activity.dart' show LiveActivity, LiveKind;

final liveActivityProvider = Provider<LiveActivity?>((ref) => null);

final livePushProvider = Provider<LivePush>((ref) => const LivePush(enabled: false));

final liveActivityBridgeProvider = Provider<void>((ref) {});

final liveSystemStatusProvider = FutureProvider<LiveSystemStatus>(
  (ref) => ref.watch(notifyChannelProvider).liveStatus(),
);
