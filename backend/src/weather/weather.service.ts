import { Injectable, Logger } from '@nestjs/common';

export interface Weather {
  temperatureC: number;
  /** WMO weather interpretation code (0 clear … 95 thunderstorm). */
  code: number;
}

type Fetch = (url: string, init?: { signal?: AbortSignal }) => Promise<{ ok: boolean; json(): Promise<unknown> }>;

const TTL_MS = 15 * 60_000;

/**
 * Current weather from Open-Meteo (free, no API key), cached per location.
 * Failures return null so the Home screen simply hides the weather.
 */
@Injectable()
export class WeatherService {
  private readonly logger = new Logger(WeatherService.name);
  private readonly cache = new Map<string, { at: number; value: Weather | null }>();

  /** Overridable in tests. */
  fetch: Fetch = (url, init) => globalThis.fetch(url, init);

  async current(latitude: number | null, longitude: number | null): Promise<Weather | null> {
    if (latitude == null || longitude == null) return null;
    const key = `${latitude.toFixed(2)},${longitude.toFixed(2)}`;
    const cached = this.cache.get(key);
    if (cached && Date.now() - cached.at < TTL_MS) return cached.value;

    let value: Weather | null = null;
    try {
      const url =
        `https://api.open-meteo.com/v1/forecast?latitude=${latitude}&longitude=${longitude}` +
        '&current=temperature_2m,weather_code';
      const res = await this.fetch(url, { signal: AbortSignal.timeout(3000) });
      if (res.ok) {
        const body = (await res.json()) as { current?: { temperature_2m?: number; weather_code?: number } };
        if (typeof body.current?.temperature_2m === 'number' && typeof body.current.weather_code === 'number') {
          value = { temperatureC: Math.round(body.current.temperature_2m), code: body.current.weather_code };
        }
      }
    } catch (error) {
      this.logger.warn(`Weather unavailable: ${(error as Error).message}`);
    }
    this.cache.set(key, { at: Date.now(), value });
    return value;
  }
}
