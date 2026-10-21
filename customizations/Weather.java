package com.gathin.tvhome;

import android.content.Context;
import android.content.SharedPreferences;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationManager;
import android.os.Handler;
import android.os.Looper;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.util.Locale;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Current weather for the launcher header.
 * Uses Open-Meteo (free, no API key, privacy-respecting).
 * Location from Android system or IP geolocation once a day.
 * Weather updates every 30 minutes, cached locally.
 */
final class Weather {

    interface Listener {
        void onWeather(String text);
    }

    private static final String PREFS = "weather_prefs";
    private static final long WEATHER_MS = 30 * 60_000L;
    private static final long LOCATION_MS = 24 * 60 * 60_000L;
    private static final ExecutorService IO = Executors.newSingleThreadExecutor();
    private static final Handler MAIN = new Handler(Looper.getMainLooper());
    private static volatile boolean running;

    private Weather() {
    }

    static void refresh(Context ctx, Listener listener) {
        Context app = ctx.getApplicationContext();
        SharedPreferences p = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
        String cached = p.getString("text", null);
        if (cached != null) {
            listener.onWeather(cached);
        }

        long now = System.currentTimeMillis();
        boolean metric = isMetricPrimary(app);
        boolean hasDual = cached != null && cached.contains("(") && (metric ? cached.contains("°C (") : cached.contains("°F ("));
        if ((now - p.getLong("time", 0) < WEATHER_MS && hasDual) || running) {
            return;
        }

        running = true;
        IO.execute(() -> {
            try {
                String text = fetch(app, p);
                if (text != null) {
                    p.edit().putString("text", text).putLong("time", System.currentTimeMillis()).apply();
                    MAIN.post(() -> listener.onWeather(text));
                }
            } catch (Exception ignored) {
            } finally {
                running = false;
            }
        });
    }

    private static String fetch(Context ctx, SharedPreferences p) {
        try {
            boolean staleLoc = System.currentTimeMillis() - p.getLong("locTime", 0) > LOCATION_MS || !p.contains("lat");
            if (staleLoc) {
                boolean found = locateDevice(ctx, p);
                if (!found) {
                    found = locateByIp(p, "https://ipapi.co/json/") || locateByIp(p, "https://ipwho.is/");
                }
                if (!found && !p.contains("lat")) {
                    return null;
                }
            }

            float lat = p.getFloat("lat", 0);
            float lon = p.getFloat("lon", 0);

            // Fetch in standard metric (Celsius) by default, then compute both C and F
            String url = String.format(Locale.US,
                    "https://api.open-meteo.com/v1/forecast?latitude=%.4f&longitude=%.4f&current=temperature_2m,weather_code,is_day",
                    lat, lon);

            byte[] data = httpGet(url, 5000);
            if (data == null) return null;

            JSONObject root = new JSONObject(new String(data));
            JSONObject cur = root.getJSONObject("current");
            int code = cur.getInt("weather_code");
            boolean isDay = cur.optInt("is_day", 1) == 1;
            double tempC = cur.getDouble("temperature_2m");
            int c = (int) Math.round(tempC);
            int f = (int) Math.round(tempC * 9.0 / 5.0 + 32.0);

            boolean metric = isMetricPrimary(ctx);
            String tempStr = metric ? (c + "°C (" + f + "°F)") : (f + "°F (" + c + "°C)");

            return icon(code, isDay) + "  " + tempStr;
        } catch (Exception e) {
            return null;
        }
    }

    private static boolean isMetricPrimary(Context ctx) {
        // 1. Check Config overlay (config.json / config.xml)
        try {
            Config config = Config.load(ctx);
            if (config.temperatureUnit != null && !config.temperatureUnit.isEmpty()) {
                if ("celsius".equalsIgnoreCase(config.temperatureUnit) || "metric".equalsIgnoreCase(config.temperatureUnit) || "c".equalsIgnoreCase(config.temperatureUnit)) {
                    return true;
                }
                if ("fahrenheit".equalsIgnoreCase(config.temperatureUnit) || "imperial".equalsIgnoreCase(config.temperatureUnit) || "f".equalsIgnoreCase(config.temperatureUnit)) {
                    return false;
                }
            }
        } catch (Throwable ignored) {
        }

        // 2. Query system settings if available on OEM firmware
        try {
            String unit = android.provider.Settings.System.getString(ctx.getContentResolver(), "temperature_unit");
            if (unit == null) {
                unit = android.provider.Settings.Global.getString(ctx.getContentResolver(), "temperature_unit");
            }
            if (unit != null) {
                if ("celsius".equalsIgnoreCase(unit) || "metric".equalsIgnoreCase(unit) || "c".equalsIgnoreCase(unit)) {
                    return true;
                }
                if ("fahrenheit".equalsIgnoreCase(unit) || "imperial".equalsIgnoreCase(unit) || "f".equalsIgnoreCase(unit)) {
                    return false;
                }
            }
        } catch (Throwable ignored) {
        }

        // 3. Query ICU Measurement System from Android Locale
        try {
            android.icu.util.LocaleData.MeasurementSystem ms =
                    android.icu.util.LocaleData.getMeasurementSystem(android.icu.util.ULocale.getDefault());
            if (ms == android.icu.util.LocaleData.MeasurementSystem.SI) {
                return true;
            }
            if (ms == android.icu.util.LocaleData.MeasurementSystem.US) {
                return false;
            }
        } catch (Throwable ignored) {
        }

        // 4. Default by locale country (US, LR, MM default to Fahrenheit, rest of world defaults to Celsius)
        Locale l = Locale.getDefault();
        String country = l.getCountry();
        return !("US".equalsIgnoreCase(country) || "LR".equalsIgnoreCase(country) || "MM".equalsIgnoreCase(country));
    }

    private static boolean locateDevice(Context ctx, SharedPreferences p) {
        try {
            if (ctx.checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED) {
                return false;
            }
            LocationManager lm = ctx.getSystemService(LocationManager.class);
            if (lm == null) return false;

            Location best = null;
            for (String provider : lm.getProviders(true)) {
                Location loc = lm.getLastKnownLocation(provider);
                if (loc != null && (best == null || loc.getTime() > best.getTime())) {
                    best = loc;
                }
            }
            if (best != null) {
                p.edit().putFloat("lat", (float) best.getLatitude())
                        .putFloat("lon", (float) best.getLongitude())
                        .putLong("locTime", System.currentTimeMillis()).apply();
                return true;
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private static boolean locateByIp(SharedPreferences p, String endpoint) {
        try {
            byte[] data = httpGet(endpoint, 4000);
            if (data == null) return false;
            JSONObject json = new JSONObject(new String(data));
            double lat = json.optDouble("latitude", json.optDouble("lat", Double.NaN));
            double lon = json.optDouble("longitude", json.optDouble("lon", Double.NaN));
            if (!Double.isNaN(lat) && !Double.isNaN(lon)) {
                p.edit().putFloat("lat", (float) lat)
                        .putFloat("lon", (float) lon)
                        .putLong("locTime", System.currentTimeMillis()).apply();
                return true;
            }
        } catch (Exception ignored) {
        }
        return false;
    }

    private static byte[] httpGet(String urlStr, int timeoutMs) {
        try {
            HttpURLConnection conn = (HttpURLConnection) new URL(urlStr).openConnection();
            conn.setConnectTimeout(timeoutMs);
            conn.setReadTimeout(timeoutMs);
            conn.setRequestProperty("User-Agent", "CleanYourTV/1.0");
            try (InputStream in = conn.getInputStream(); ByteArrayOutputStream out = new ByteArrayOutputStream()) {
                byte[] buf = new byte[2048];
                int n;
                while ((n = in.read(buf)) != -1) {
                    out.write(buf, 0, n);
                }
                return out.toByteArray();
            }
        } catch (Exception e) {
            return null;
        }
    }

    /** Map WMO Weather Codes to weather emojis. */
    private static String icon(int code, boolean isDay) {
        switch (code) {
            case 0: // Clear sky
                return isDay ? "☀️" : "🌙";
            case 1: // Mainly clear
            case 2: // Partly cloudy
                return isDay ? "⛅" : "☁️";
            case 3: // Overcast
                return "☁️";
            case 45: // Fog
            case 48:
                return "🌫️";
            case 51: // Drizzle
            case 53:
            case 55:
            case 61: // Rain
            case 63:
            case 65:
            case 80:
            case 81:
            case 82:
                return "🌧️";
            case 71: // Snow
            case 73:
            case 75:
            case 77:
            case 85:
            case 86:
                return "❄️";
            case 95: // Thunderstorm
            case 96:
            case 99:
                return "⛈️";
            default:
                return isDay ? "☀️" : "🌙";
        }
    }
}
