package app.deepos

import android.content.Context
import app.deepos.priv.PrivPlugin
import app.deepos.runtime.RuntimePlugin
import app.deepos.theme.DynamicColorPlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor

/** Singleton FlutterEngine shared across Activity recreations so SSE streams stay warm. */
object DeepOsFlutterEngine {
    const val ENGINE_ID = "deepos-main"

    @Synchronized
    fun getOrCreate(context: Context): FlutterEngine {
        val cache = FlutterEngineCache.getInstance()
        cache.get(ENGINE_ID)?.let { return it }
        return FlutterEngine(context.applicationContext).also { engine ->
            engine.plugins.add(RuntimePlugin())
            engine.plugins.add(PrivPlugin())
            engine.plugins.add(DynamicColorPlugin())
            engine.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint.createDefault())
            cache.put(ENGINE_ID, engine)
        }
    }
}
