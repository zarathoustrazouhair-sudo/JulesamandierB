'use client';

import React from 'react';
import { useKPIs } from '@/hooks/useKPIs';
import { KPICard } from './KPICard';
import { RunwayIndicator } from './RunwayIndicator';

export function KPIStrip() {
  const { data, isLoading, error } = useKPIs();

  if (error) {
    return <div className="text-red-500 rounded border p-4 bg-red-50">Erreur lors du chargement des KPI: {error.message}</div>;
  }

  if (isLoading) {
    // Skeleton loader matching 2x3 grid + RunwayIndicator
    return (
      <div className="mb-6 w-full animate-pulse space-y-4">
        <div className="h-24 w-full rounded-lg bg-gray-300"></div>
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
          {[...Array(6)].map((_, i) => (
            <div key={i} className="h-24 rounded-lg bg-gray-300"></div>
          ))}
        </div>
      </div>
    );
  }

  if (!data) return null;

  return (
    <div className="w-full space-y-4">
      <RunwayIndicator runway={data.runway} />
      <div className="grid grid-cols-2 gap-4 sm:grid-cols-3">
        <KPICard title="Solde Total" value={data.solde_total} isCurrency isSolde />
        <KPICard title="Total Recettes" value={data.total_recettes} isCurrency />
        <KPICard title="Total Dépenses" value={data.total_depenses} isCurrency />
        <KPICard title="Impayés Estimés" value={data.impayes_total} isCurrency />
        <KPICard title="Incidents Ouverts" value={data.incidents_ouverts} />
        <KPICard title="Recouvrement" value={data.taux_recouvrement} isPercentage />
      </div>
    </div>
  );
}
