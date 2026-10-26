package com.gathin.tvhome;

import android.app.AlarmManager;
import android.app.PendingIntent;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.widget.Toast;

/**
 * Standby and sleep timer. Standby is executed by {@link SleepService}.
 */
final class Sleep {

    private static final String PREFS = "sleep_prefs";
    private static final String AT = "sleep_at";
    private static final long STALE_MS = 2 * 60_000L;
    private static final int[] STEPS = {30, 60, 90};

    private Sleep() {
    }

    private static SharedPreferences prefs(Context c) {
        return c.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    /** BroadcastReceiver triggered when the sleep timer expires. */
    public static class Alarm extends BroadcastReceiver {
        @Override
        public void onReceive(Context c, Intent intent) {
            long at = prefs(c).getLong(AT, 0);
            prefs(c).edit().remove(AT).apply();
            if (at > 0 && Math.abs(System.currentTimeMillis() - at) < STALE_MS) {
                now(c);
            }
        }
    }

    /** Put TV into standby immediately. */
    static boolean now(Context c) {
        if (SleepService.lock()) {
            return true;
        }
        Toast.makeText(c, R.string.sleep_needs_setup, Toast.LENGTH_LONG).show();
        return false;
    }

    /** Minutes left on the running sleep timer, or 0 if off. */
    static int minutesLeft(Context c) {
        long at = prefs(c).getLong(AT, 0);
        long left = at - System.currentTimeMillis();
        return left > 0 ? (int) Math.ceil(left / 60_000.0) : 0;
    }

    /** Cycles through Off -> 30 -> 60 -> 90 -> Off. Returns new minutes. */
    static int cycle(Context c) {
        int left = minutesLeft(c);
        int next = 0;
        for (int s : STEPS) {
            if (s > left) {
                next = s;
                break;
            }
        }
        set(c, next);
        return next;
    }

    private static void set(Context c, int minutes) {
        AlarmManager am = c.getSystemService(AlarmManager.class);
        PendingIntent pi = PendingIntent.getBroadcast(c, 0, new Intent(c, Alarm.class),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        if (am != null) {
            am.cancel(pi);
        }
        if (minutes <= 0) {
            prefs(c).edit().remove(AT).apply();
            return;
        }
        long at = System.currentTimeMillis() + minutes * 60_000L;
        prefs(c).edit().putLong(AT, at).apply();
        if (am != null) {
            try {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC, at, pi);
            } catch (SecurityException e) {
                am.setAndAllowWhileIdle(AlarmManager.RTC, at, pi);
            }
        }
    }
}
