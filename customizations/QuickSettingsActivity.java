package com.gathin.tvhome;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

/**
 * The panel the remote's Settings button (and the Home screen Settings gear pill) opens:
 * a few glass rows under the Settings pill, over Home or whatever app is playing. Translucent and in a
 * task of its own, so the app behind keeps running and Back returns to it. Pressing Settings again
 * closes the panel.
 */
public final class QuickSettingsActivity extends Activity {

    private final Handler handler = new Handler(Looper.getMainLooper());
    private int[] settingsKeycodes = new int[0];
    private int[] settingsScancodes = new int[0];

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        Config cfg = Config.load(this);
        settingsKeycodes = cfg.settingsKeycodes;
        settingsScancodes = cfg.settingsScancodes;

        setContentView(R.layout.activity_quick_settings);
        findViewById(R.id.scrim).setOnClickListener(v -> finish());
        LinearLayout rows = findViewById(R.id.rows);
        addRow(rows, R.drawable.ic_settings, R.string.tv_settings, 0, SystemSettings.intent(this, Settings.ACTION_SETTINGS));
        addRow(rows, R.drawable.ic_picture, R.string.quick_picture, 0, SystemSettings.intent(this, Settings.ACTION_DISPLAY_SETTINGS));
        addRow(rows, R.drawable.ic_wifi, R.string.quick_network, 0, SystemSettings.intent(this, Settings.ACTION_WIFI_SETTINGS));
        addRow(rows, R.drawable.ic_apps, R.string.quick_apps, R.string.quick_apps_hint,
                SystemSettings.intent(this, Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS));
        // Through Home, so it rebuilds with the new choices when Launcher settings closes.
        addRow(rows, R.drawable.ic_home_settings, R.string.launcher_settings, 0,
                new Intent(this, MainActivity.class).setAction(MainActivity.ACTION_LAUNCHER_SETTINGS));

        addSeparator(rows);

        // Free up memory
        final TextView[] memStatus = new TextView[1];
        memStatus[0] = addActionRow(rows, 0, getString(R.string.free_memory),
                getString(R.string.memory_free, availableMb()), false, () -> freeMemory(memStatus[0]));

        // Screensaver
        addActionRow(rows, 0, getString(R.string.screensaver), null, true, this::startScreensaver);

        // Sleep timer
        final TextView[] timerStatus = new TextView[1];
        timerStatus[0] = addActionRow(rows, 0, getString(R.string.sleep_timer), sleepStatus(), false, () -> {
            Sleep.cycle(this);
            if (timerStatus[0] != null) timerStatus[0].setText(sleepStatus());
        });

        float density = getResources().getDisplayMetrics().density;
        View panel = findViewById(R.id.panel);
        panel.measure(View.MeasureSpec.UNSPECIFIED, View.MeasureSpec.UNSPECIFIED);
        ViewGroup.LayoutParams lp = panel.getLayoutParams();
        lp.width = Math.max((int) (220 * density), Math.min(panel.getMeasuredWidth(), (int) (340 * density)));
        panel.setLayoutParams(lp);

        rows.getChildAt(0).requestFocus();
    }

    /** Settings pressed again while the panel is up. */
    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        finish();
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent event) {
        if (isSettingsKey(event)) {
            if (event.getAction() == KeyEvent.ACTION_UP && !event.isCanceled()) {
                finish();
            }
            return true;
        }
        return super.dispatchKeyEvent(event);
    }

    private boolean isSettingsKey(KeyEvent event) {
        if (event.getKeyCode() == KeyEvent.KEYCODE_SETTINGS) return true;
        for (int code : settingsKeycodes) if (event.getKeyCode() == code) return true;
        for (int code : settingsScancodes) if (event.getScanCode() == code) return true;
        return false;
    }

    /** Anything else taking the screen (Home, an app, a screensaver) closes the panel. */
    @Override
    protected void onPause() {
        super.onPause();
        finish();
        overridePendingTransition(0, 0);
    }

    private void addSeparator(LinearLayout rows) {
        float density = getResources().getDisplayMetrics().density;
        View line = new View(this);
        line.setBackgroundColor(0x1FFFFFFF);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, Math.max(1, (int) density));
        int m = (int) (6 * density), h = (int) (12 * density);
        lp.setMargins(h, m, h, m);
        rows.addView(line, lp);
    }

    private void addRow(LinearLayout rows, int icon, int title, int status, Intent target) {
        View row = getLayoutInflater().inflate(R.layout.item_input, rows, false);
        ((ImageView) row.findViewById(R.id.icon)).setImageResource(icon);
        ((TextView) row.findViewById(R.id.title)).setText(title);
        row.findViewById(R.id.dot).setVisibility(View.GONE);
        TextView hint = row.findViewById(R.id.status);
        if (status != 0) hint.setText(status);
        else hint.setVisibility(View.GONE);
        row.setOnClickListener(v -> {
            try {
                startActivity(target.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (ActivityNotFoundException | SecurityException e) {
                Toast.makeText(this, R.string.not_available, Toast.LENGTH_SHORT).show();
            }
            finish();
        });
        rows.addView(row);
    }

    private TextView addActionRow(LinearLayout rows, int icon, String title, String status,
                                  boolean closeOnClick, Runnable action) {
        View row = getLayoutInflater().inflate(R.layout.item_input, rows, false);
        ImageView iconView = row.findViewById(R.id.icon);
        if (icon != 0) {
            iconView.setImageResource(icon);
            iconView.setVisibility(View.VISIBLE);
        } else {
            iconView.setVisibility(View.GONE);
        }
        ((TextView) row.findViewById(R.id.title)).setText(title);
        row.findViewById(R.id.dot).setVisibility(View.GONE);
        TextView hint = row.findViewById(R.id.status);
        if (status != null) {
            hint.setText(status);
            hint.setVisibility(View.VISIBLE);
        } else {
            hint.setVisibility(View.GONE);
        }
        row.setOnClickListener(v -> {
            action.run();
            if (closeOnClick) {
                finish();
            }
        });
        rows.addView(row);
        return hint;
    }

    private String sleepStatus() {
        int left = Sleep.minutesLeft(this);
        return left > 0 ? getString(R.string.minutes_left, left) : getString(R.string.off);
    }

    private long availableMb() {
        ActivityManager am = getSystemService(ActivityManager.class);
        if (am == null) return 0;
        ActivityManager.MemoryInfo mi = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(mi);
        return mi.availMem / (1024 * 1024);
    }

    private void freeMemory(TextView statusView) {
        ActivityManager am = getSystemService(ActivityManager.class);
        if (am == null) return;
        ActivityManager.MemoryInfo before = new ActivityManager.MemoryInfo();
        am.getMemoryInfo(before);
        for (ApplicationInfo ai : getPackageManager().getInstalledApplications(0)) {
            if ((ai.flags & ApplicationInfo.FLAG_SYSTEM) != 0) continue;
            if (ai.packageName.equals(getPackageName())) continue;
            am.killBackgroundProcesses(ai.packageName);
        }
        final Context appContext = getApplicationContext();
        handler.postDelayed(() -> {
            ActivityManager.MemoryInfo after = new ActivityManager.MemoryInfo();
            am.getMemoryInfo(after);
            long avail = after.availMem / (1024 * 1024);
            long freed = Math.max(0, after.availMem - before.availMem) / (1024 * 1024);
            if (statusView != null && !isFinishing()) {
                statusView.setText(getString(R.string.memory_free, avail));
            }
            Toast.makeText(appContext, appContext.getString(R.string.memory_freed, freed, avail),
                    Toast.LENGTH_LONG).show();
        }, 800);
    }

    private void startScreensaver() {
        try {
            Intent dream = new Intent(Intent.ACTION_MAIN)
                    .setClassName("com.android.systemui", "com.android.systemui.Somnambulator")
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            if (getPackageManager().resolveActivity(dream, 0) == null) {
                dream = new Intent(this, ClockActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            }
            startActivity(dream);
        } catch (Exception e) {
            try {
                startActivity(new Intent("android.settings.DREAM_SETTINGS").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
            } catch (Exception ignored) {
            }
        }
    }
}
