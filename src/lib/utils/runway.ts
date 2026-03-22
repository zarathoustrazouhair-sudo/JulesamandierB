export type RunwayState = 'healthy' | 'warning' | 'critical';

export const RUNWAY_CLASSES: Record<RunwayState, string> = {
  healthy: 'text-green-600 bg-green-50',
  warning: 'text-yellow-600 bg-yellow-50',
  critical: 'text-red-600 bg-red-50 animate-pulse',
};

export function classifyRunway(runwayValue: number): RunwayState {
  if (runwayValue > 6 || runwayValue === 999) {
    return 'healthy';
  }
  if (runwayValue >= 3) {
    return 'warning';
  }
  return 'critical';
}
