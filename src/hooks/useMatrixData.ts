'use client';

import { useEffect, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase/client';
import { RealtimeChannel } from '@supabase/supabase-js';

export interface MatrixData {
  id: string;
  code: string;
  etage: number;
  numero: number;
  resident_nom: string | null;
  balance: number;
  balance_state: 'credit' | 'balanced' | 'debt' | 'vacant';
}

export function useMatrixData() {
  const [data, setData] = useState<MatrixData[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const isMountedRef = useRef(true);
  const channelRef = useRef<RealtimeChannel | null>(null);

  useEffect(() => {
    isMountedRef.current = true;

    const fetchData = async () => {
      try {
        const { data: matrixData, error: rpcError } = await supabase.rpc('get_matrix_data');

        if (rpcError) {
          throw new Error(rpcError.message);
        }

        if (isMountedRef.current) {
          // Assert type to any[] before mapping to avoid typescript 'never' error
          const rawData = (matrixData as any[]) || [];
          const mappedData = rawData.map((item: any) => ({
            ...item,
            // If there's no resident, UI logic says it is vacant
            balance_state: item.resident_nom ? (item.balance_state as 'credit' | 'balanced' | 'debt') : 'vacant'
          })) as MatrixData[];

          setData(mappedData);
          setIsLoading(false);
        }
      } catch (err) {
        if (isMountedRef.current) {
          setError(err instanceof Error ? err : new Error('Failed to fetch matrix data'));
          setIsLoading(false);
        }
      }
    };

    // 1. Initial fetch ONCE on mount
    fetchData();

    // 2. Setup Realtime subscription
    channelRef.current = supabase
      .channel('public:payments')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'payments' },
        () => {
          if (isMountedRef.current) {
            fetchData();
          }
        }
      )
      .subscribe();

    return () => {
      // isMountedRef.current MUST be false BEFORE async cleanup
      isMountedRef.current = false;

      // Explicit removeChannel is mandatory per AGENTS.md
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
      }
    };
  }, []);

  return { data, isLoading, error };
}
