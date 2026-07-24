package org.matrix.TEESimulator.interception.keystore

import android.os.IBinder
import android.os.Parcel
import android.security.maintenance.IKeystoreMaintenance
import android.system.keystore2.Domain
import org.matrix.TEESimulator.interception.core.BinderInterceptor
import org.matrix.TEESimulator.util.SystemLogger
import org.matrix.TEESimulator.interception.keystore.shim.KeyMintSecurityLevelInterceptor

/**
 * Intercepts the keystore2 daemon's `android.security.maintenance` binder so our synthetic key
 * state follows the same lifecycle events the platform applies to real keys (Xiaomi/Samsung).
 * Pure side-effect hook: mutates only our synthetic state, then returns ContinueAndSkipPost so
 * the real keystore2 still performs the real operation.
 */
object Keystore2MaintenanceInterceptor : BinderInterceptor() {

    // Load the REAL framework Stub at runtime (the compileOnly stub carries no TRANSACTION_* codes).
    private val stubClass: Class<*>? = runCatching {
        Class.forName("android.security.maintenance.IKeystoreMaintenance\$Stub")
    }.getOrNull()

    private val CLEAR_NAMESPACE_TRANSACTION =
        stubClass?.let { InterceptorUtils.getTransactCode(it, "clearNamespace") } ?: -1
    private val DELETE_ALL_KEYS_TRANSACTION =
        stubClass?.let { InterceptorUtils.getTransactCode(it, "deleteAllKeys") } ?: -1

    val interceptedCodes: IntArray by lazy {
        listOf(CLEAR_NAMESPACE_TRANSACTION, DELETE_ALL_KEYS_TRANSACTION)
            .filter { it != -1 }
            .toIntArray()
    }

    override fun onPreTransact(
        txId: Long,
        target: IBinder,
        code: Int,
        flags: Int,
        callingUid: Int,
        callingPid: Int,
        data: Parcel,
    ): TransactionResult {
        runCatching {
            when (code) {
                CLEAR_NAMESPACE_TRANSACTION -> handleClearNamespace(data)
                DELETE_ALL_KEYS_TRANSACTION ->
                    KeyMintSecurityLevelInterceptor.clearAllGeneratedKeys("maintenance.deleteAllKeys")
            }
        }.onFailure { SystemLogger.error("maintenance onPreTransact failed", it) }
        return TransactionResult.ContinueAndSkipPost
    }

    private fun handleClearNamespace(data: Parcel) {
        data.enforceInterface(IKeystoreMaintenance.DESCRIPTOR)
        val domain = data.readInt()
        val nspace = data.readLong()
        if (domain == Domain.APP) {
            KeyMintSecurityLevelInterceptor.clearNamespaceKeys(nspace.toInt())
        }
    }
}
