'use client';

import React, { useState } from 'react';
import { useMatrixData, MatrixData } from '@/hooks/useMatrixData';
import { ApartmentCell } from './ApartmentCell';
import { ApartmentDetailModal } from './ApartmentDetailModal';

export function ApartmentMatrix() {
  const { data, isLoading, error } = useMatrixData();
  const [selectedApartment, setSelectedApartment] = useState<MatrixData | null>(null);

  if (error) {
    return <div className="text-red-500">Erreur: {error.message}</div>;
  }

  if (isLoading) {
    // Skeleton loader
    return (
      <div className="w-full space-y-4 animate-pulse">
        {[...Array(5)].map((_, i) => (
          <div key={i}>
            <div className="mb-2 h-4 w-1/4 rounded bg-gray-300"></div>
            <div className="grid grid-cols-3 gap-2">
              {[...Array(3)].map((_, j) => (
                <div key={j} className="h-20 rounded bg-gray-300"></div>
              ))}
            </div>
          </div>
        ))}
      </div>
    );
  }

  // Handle case where RPC returns 0 rows (empty DB)
  if (!data || data.length === 0) {
    return <div className="text-gray-500">Aucun appartement trouvé.</div>;
  }

  // Extract unique floors and sort descending (5 to 1)
  const floors = Array.from(new Set(data.map((item) => item.etage))).sort((a, b) => b - a);

  return (
    <div className="w-full">
      {floors.map((floor) => {
        const apartments = data.filter((item) => item.etage === floor);
        return (
          <div key={floor} className="mb-6">
            <h3 className="mb-2 text-lg font-bold text-gray-700 border-b pb-1">
              Étage {floor}
            </h3>
            <div className="grid w-full grid-cols-3 gap-2">
              {apartments.map((apt) => (
                <ApartmentCell
                  key={apt.id}
                  data={apt}
                  onClick={setSelectedApartment}
                />
              ))}
            </div>
          </div>
        );
      })}

      {selectedApartment && (
        <ApartmentDetailModal
          apartment={selectedApartment}
          onClose={() => setSelectedApartment(null)}
        />
      )}
    </div>
  );
}
