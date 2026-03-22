'use client';

import React from 'react';

interface KPICardProps {
  title: string;
  value: number;
  isCurrency?: boolean;
  isPercentage?: boolean;
  isSolde?: boolean;
}

export function KPICard({ title, value, isCurrency = false, isPercentage = false, isSolde = false }: KPICardProps) {
  let displayValue = value.toString();

  if (isPercentage) {
    if (value === 0 || isNaN(value)) {
      displayValue = 'N/A';
    } else {
      displayValue = `${value.toFixed(1)}%`;
    }
  } else if (isCurrency) {
    displayValue = value.toLocaleString('fr-MA', {
      style: 'currency',
      currency: 'MAD',
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    });
  }

  // Solde Total is negative = Red
  const isNegativeSolde = isSolde && value < 0;

  return (
    <div className="flex flex-col justify-center rounded-lg border bg-white p-4 shadow-sm transition-shadow hover:shadow-md">
      <h4 className="mb-1 text-sm font-medium text-gray-500">{title}</h4>
      <p className={`text-xl font-bold sm:text-2xl ${isNegativeSolde ? 'text-red-600' : 'text-gray-900'}`}>
        {displayValue}
      </p>
    </div>
  );
}
