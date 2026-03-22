'use client';

import React, { useEffect, useState } from 'react';
import { supabase } from '@/lib/supabase/client';
import { MatrixData } from '@/hooks/useMatrixData';
import Link from 'next/link';

interface ApartmentDetailModalProps {
  apartment: MatrixData | null;
  onClose: () => void;
}

export function ApartmentDetailModal({ apartment, onClose }: ApartmentDetailModalProps) {
  const [payments, setPayments] = useState<any[]>([]);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (!apartment) return;

    const fetchPayments = async () => {
      setIsLoading(true);
      const { data } = await supabase
        .from('payments')
        .select('*')
        .eq('appartement_id', apartment.id)
        .order('date_paiement', { ascending: false })
        .limit(6);

      setPayments(data || []);
      setIsLoading(false);
    };

    fetchPayments();
  }, [apartment]);

  if (!apartment) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-end bg-black bg-opacity-50 sm:items-center sm:justify-center">
      <div className="relative w-full rounded-t-xl bg-white p-6 shadow-xl transition-all sm:max-w-md sm:rounded-xl">
        <button
          onClick={onClose}
          className="absolute right-4 top-4 text-gray-500 hover:text-gray-700"
        >
          ✕
        </button>

        <h2 className="mb-2 text-2xl font-bold">Appartement {apartment.code}</h2>
        <div className="mb-6 text-sm text-gray-600">
          <p>Résident: {apartment.resident_nom || 'Vacant'}</p>
          <p>Étage: {apartment.etage} - Numéro: {apartment.numero}</p>
          <p>Balance: <span className="font-semibold">{apartment.balance} MAD</span></p>
        </div>

        <h3 className="mb-3 font-semibold text-gray-800">Derniers Paiements (6)</h3>
        {isLoading ? (
          <p className="text-gray-500">Chargement...</p>
        ) : payments.length > 0 ? (
          <ul className="mb-6 max-h-48 space-y-2 overflow-y-auto text-sm">
            {payments.map(p => (
              <li key={p.id} className="flex justify-between rounded border-b p-2">
                <span>{new Date(p.date_paiement).toLocaleDateString()}</span>
                <span className="font-medium">{p.montant} MAD</span>
                <span className={`px-2 rounded text-xs ${p.statut === 'valide' ? 'bg-green-100 text-green-800' : 'bg-yellow-100 text-yellow-800'}`}>
                  {p.statut}
                </span>
              </li>
            ))}
          </ul>
        ) : (
          <p className="mb-6 text-gray-500">Aucun paiement trouvé.</p>
        )}

        <div className="mt-6 flex justify-between">
          <Link
            href={`/syndic/payments?appartement_id=${apartment.id}`}
            className="rounded bg-blue-600 px-4 py-2 text-white hover:bg-blue-700"
          >
            Voir tous les paiements
          </Link>
          <button onClick={onClose} className="rounded border px-4 py-2 text-gray-700 hover:bg-gray-50">
            Fermer
          </button>
        </div>
      </div>
    </div>
  );
}
