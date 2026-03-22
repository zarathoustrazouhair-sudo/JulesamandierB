'use client';

import { useEffect, useRef, useState } from 'react';
import { supabase } from '@/lib/supabase/client';
import { RealtimeChannel } from '@supabase/supabase-js';

export interface KPIDashboard {
  solde_total: number;
  total_recettes: number;
  total_depenses: number;
  impayes_total: number;
  incidents_ouverts: number;
  runway: number;
  taux_recouvrement: number;
}

export function useKPIs() {
  const [data, setData] = useState<KPIDashboard | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  const isMountedRef = useRef(true);
  const channelRef = useRef<RealtimeChannel | null>(null);
  const intervalRef = useRef<NodeJS.Timeout | null>(null);

  useEffect(() => {
    isMountedRef.current = true;

    const fetchData = async () => {
      try {
        const { data: kpiData, error: rpcError } = await supabase.rpc('get_kpi_dashboard');

        if (rpcError) {
          throw new Error(rpcError.message);
        }

        if (isMountedRef.current) {
          // Force types
          const parsedData: KPIDashboard = {
            solde_total: Number((kpiData as any).solde_total || 0),
            total_recettes: Number((kpiData as any).total_recettes || 0),
            total_depenses: Number((kpiData as any).total_depenses || 0),
            impayes_total: Number((kpiData as any).impayes_total || 0),
            incidents_ouverts: Number((kpiData as any).incidents_ouverts || 0),
            runway: Number((kpiData as any).runway || 0),
            taux_recouvrement: Number((kpiData as any).taux_recouvrement || 0),
          };

          setData(parsedData);
          setIsLoading(false);
        }
      } catch (err) {
        if (isMountedRef.current) {
          setError(err instanceof Error ? err : new Error('Failed to fetch KPI data'));
          setIsLoading(false);
        }
      }
    };

    // 1. Initial fetch ONCE on mount
    fetchData();

    // 2. Setup 60s auto-refresh
    intervalRef.current = setInterval(() => {
      if (isMountedRef.current) {
        fetchData();
      }
    }, 60000);

    // 3. Setup Realtime subscription (using a distinct channel name)
    channelRef.current = supabase
      .channel('public:payments:kpi')
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'payments' },
        () => {
          if (isMountedRef.current) {
            fetchData();
          }
        }
      )
      .on(
        'postgres_changes',
        { event: '*', schema: 'public', table: 'flux_tresorerie' },
        () => {
          if (isMountedRef.current) {
            fetchData();
          }
        }
      )
      .subscribe();

    return () => {
      // 1. MUST set false BEFORE cleanup
      isMountedRef.current = false;

      // 2. Clear Interval
      if (intervalRef.current) {
        clearInterval(intervalRef.current);
      }

      // 3. Explicitly remove channel
      if (channelRef.current) {
        supabase.removeChannel(channelRef.current);
      }
    };
  }, []);

  return { data, isLoading, error };
}
