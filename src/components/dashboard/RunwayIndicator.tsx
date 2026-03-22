'use client';

import React from 'react';
import { classifyRunway, RUNWAY_CLASSES } from '@/lib/utils/runway';

export function RunwayIndicator({ runway }: { runway: number }) {
  const classification = classifyRunway(runway);
  const colorClass = RUNWAY_CLASSES[classification];
  const displayRunway = runway === 999 ? '∞' : runway.toFixed(1);

  return (
    <div className={`mb-6 flex w-full items-center justify-between rounded-lg p-6 shadow-md transition-colors ${colorClass}`}>
      <div className="flex flex-col">
        <h3 className="text-sm font-semibold uppercase tracking-wide opacity-80">Runway de Trésorerie</h3>
        <p className="mt-1 max-w-sm text-sm opacity-90">
          Mois de couverture des charges fixes (base 200 MAD/unité).
        </p>
      </div>
      <div className="text-right">
        <span className="text-4xl font-extrabold">{displayRunway}</span>
        <span className="ml-2 text-lg font-medium opacity-80">Mois</span>
      </div>
    </div>
  );
}
