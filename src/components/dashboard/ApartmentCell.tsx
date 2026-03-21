'use client';

import React from 'react';
import { MatrixData } from '@/hooks/useMatrixData';
import { BALANCE_STATE_CLASSES } from '@/lib/utils/colors';

interface ApartmentCellProps {
  data: MatrixData;
  onClick: (data: MatrixData) => void;
}

export function ApartmentCell({ data, onClick }: ApartmentCellProps) {
  const balanceClass = BALANCE_STATE_CLASSES[data.balance_state] || 'bg-gray-100 border-gray-300';

  // Truncate name to 14 chars as required
  const truncateName = (name: string | null) => {
    if (!name) return 'Vacant';
    return name.length > 14 ? name.substring(0, 14) + '...' : name;
  };

  return (
    <div
      onClick={() => onClick(data)}
      className={`flex min-h-[80px] cursor-pointer flex-col justify-between rounded border-2 p-2 shadow-sm transition-opacity hover:opacity-80 ${balanceClass}`}
    >
      <div className="flex items-center justify-between">
        <span className="font-bold text-gray-800">{data.code}</span>
        <span className="text-xs font-semibold text-gray-600">{data.balance} MAD</span>
      </div>
      <div className="mt-2 text-sm text-gray-700">
        {truncateName(data.resident_nom)}
      </div>
    </div>
  );
}
