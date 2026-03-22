import React, { Suspense } from 'react';
import { KPIStrip } from '@/components/dashboard/KPIStrip';
import { ApartmentMatrix } from '@/components/dashboard/ApartmentMatrix';
import { IncidentAlertList } from '@/components/dashboard/IncidentAlertList';

export default function SyndicDashboard() {
  return (
    <div className="container mx-auto p-4 sm:p-6 lg:p-8">
      <h1 className="mb-6 text-3xl font-extrabold text-gray-900">
        Tableau de Bord Syndic
      </h1>

      <div className="flex flex-col gap-8">
        <Suspense fallback={<div className="h-64 w-full animate-pulse rounded-lg bg-gray-200"></div>}>
          <KPIStrip />
        </Suspense>

        <div>
          <h2 className="mb-4 text-2xl font-bold text-gray-800 border-b-2 pb-2">
            Matrice des Appartements
          </h2>
          <Suspense fallback={<div className="h-96 w-full animate-pulse rounded-lg bg-gray-200"></div>}>
            <ApartmentMatrix />
          </Suspense>
        </div>

        <Suspense fallback={<div className="h-40 w-full animate-pulse rounded-lg bg-gray-200"></div>}>
          <IncidentAlertList />
        </Suspense>
      </div>
    </div>
  );
}
