package com.gathin.tvhome;

import android.accessibilityservice.AccessibilityService;
import android.content.Intent;
import android.view.accessibility.AccessibilityEvent;

/**
 * Turns the TV into standby for Control Center and the sleep timer.
 * Uses the standard accessibility "lock screen" action.
 * It listens to no events and reads no screen content.
 */
public class SleepService extends AccessibilityService {

    private static SleepService running;
    private boolean repairRecord;

    /** True when the TV went to standby; false when the service is not enabled. */
    static boolean lock() {
        return running != null && running.performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN);
    }

    @Override
    protected void onServiceConnected() {
        super.onServiceConnected();
        running = this;
        try {
            repairRecord = Config.load(this).restoreKeyServices;
            if (repairRecord) ServiceRepair.connected(this, getClass());
        } catch (Throwable ignored) {
        }
    }

    @Override
    public boolean onUnbind(Intent intent) {
        running = null;
        if (repairRecord) ServiceRepair.disconnected(this, getClass());
        return super.onUnbind(intent);
    }

    @Override
    public void onAccessibilityEvent(AccessibilityEvent event) {
    }

    @Override
    public void onInterrupt() {
    }
}
