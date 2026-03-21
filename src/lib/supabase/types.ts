export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      ag_presences: {
        Row: {
          id: string
          ag_session_id: string
          resident_id: string
          present: boolean
          pouvoir_a: string | null
          created_at: string
        }
        Insert: {
          id?: string
          ag_session_id: string
          resident_id: string
          present?: boolean
          pouvoir_a?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          ag_session_id?: string
          resident_id?: string
          present?: boolean
          pouvoir_a?: string | null
          created_at?: string
        }
      }
      ag_sessions: {
        Row: {
          id: string
          date_session: string
          titre: string
          statut: string
          created_by: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          date_session: string
          titre: string
          statut?: string
          created_by: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          date_session?: string
          titre?: string
          statut?: string
          created_by?: string
          created_at?: string
          updated_at?: string
        }
      }
      apartments: {
        Row: {
          id: string
          code: string
          etage: number
          numero: number
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          code: string
          etage: number
          numero: number
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          code?: string
          etage?: number
          numero?: number
          created_at?: string
          updated_at?: string
        }
      }
      audit_log: {
        Row: {
          id: string
          table_name: string
          objet_id: string
          action: string
          old_data: Json | null
          new_data: Json | null
          changed_by: string | null
          changed_at: string
        }
        Insert: {
          id?: string
          table_name: string
          objet_id: string
          action: string
          old_data?: Json | null
          new_data?: Json | null
          changed_by?: string | null
          changed_at?: string
        }
        Update: {
          id?: string
          table_name?: string
          objet_id?: string
          action?: string
          old_data?: Json | null
          new_data?: Json | null
          changed_by?: string | null
          changed_at?: string
        }
      }
      documents: {
        Row: {
          id: string
          titre: string
          type: string
          storage_path: string
          created_by: string
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          titre: string
          type: string
          storage_path: string
          created_by: string
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          titre?: string
          type?: string
          storage_path?: string
          created_by?: string
          created_at?: string
          updated_at?: string
        }
      }
      flux_tresorerie: {
        Row: {
          id: string
          serial_id: string
          type: Database["public"]["Enums"]["flux_type"]
          montant: number
          date_flux: string
          description: string
          source_id: string | null
          created_at: string
        }
        Insert: {
          id?: string
          serial_id: string
          type: Database["public"]["Enums"]["flux_type"]
          montant: number
          date_flux: string
          description: string
          source_id?: string | null
          created_at?: string
        }
        Update: {
          id?: string
          serial_id?: string
          type?: Database["public"]["Enums"]["flux_type"]
          montant?: number
          date_flux?: string
          description?: string
          source_id?: string | null
          created_at?: string
        }
      }
      incidents: {
        Row: {
          id: string
          titre: string
          description: string
          statut: Database["public"]["Enums"]["incident_statut"]
          reported_by: string
          assigned_to: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          titre: string
          description: string
          statut?: Database["public"]["Enums"]["incident_statut"]
          reported_by: string
          assigned_to?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          titre?: string
          description?: string
          statut?: Database["public"]["Enums"]["incident_statut"]
          reported_by?: string
          assigned_to?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      payments: {
        Row: {
          id: string
          appartement_id: string
          periode: string
          montant: number
          mode_paiement: Database["public"]["Enums"]["payment_mode"]
          date_paiement: string
          statut: Database["public"]["Enums"]["payment_statut"]
          reference_transaction: string | null
          created_by: string
          valide_par: string | null
          valide_at: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          appartement_id: string
          periode: string
          montant: number
          mode_paiement: Database["public"]["Enums"]["payment_mode"]
          date_paiement: string
          statut?: Database["public"]["Enums"]["payment_statut"]
          reference_transaction?: string | null
          created_by: string
          valide_par?: string | null
          valide_at?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          appartement_id?: string
          periode?: string
          montant?: number
          mode_paiement?: Database["public"]["Enums"]["payment_mode"]
          date_paiement?: string
          statut?: Database["public"]["Enums"]["payment_statut"]
          reference_transaction?: string | null
          created_by?: string
          valide_par?: string | null
          valide_at?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      residence_settings: {
        Row: {
          id: string
          cle: string
          valeur: Json
          updated_by: string | null
          updated_at: string
        }
        Insert: {
          id?: string
          cle: string
          valeur: Json
          updated_by?: string | null
          updated_at?: string
        }
        Update: {
          id?: string
          cle?: string
          valeur?: Json
          updated_by?: string | null
          updated_at?: string
        }
      }
      residents: {
        Row: {
          id: string
          user_id: string
          appartement_id: string
          is_proprietaire: boolean
          date_entree: string
          date_sortie: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id?: string
          user_id: string
          appartement_id: string
          is_proprietaire?: boolean
          date_entree: string
          date_sortie?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          user_id?: string
          appartement_id?: string
          is_proprietaire?: boolean
          date_entree?: string
          date_sortie?: string | null
          created_at?: string
          updated_at?: string
        }
      }
      users: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["user_role"]
          email: string
          nom: string
          prenom: string
          telephone: string | null
          created_at: string
          updated_at: string
        }
        Insert: {
          id: string
          role: Database["public"]["Enums"]["user_role"]
          email: string
          nom: string
          prenom: string
          telephone?: string | null
          created_at?: string
          updated_at?: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["user_role"]
          email?: string
          nom?: string
          prenom?: string
          telephone?: string | null
          created_at?: string
          updated_at?: string
        }
      }
    }
    Views: {
      v_apartment_balance: {
        Row: {
          id: string | null
          code: string | null
          charge_totale: number | null
          total_paye: number | null
          balance: number | null
          statut_financier: string | null
        }
      }
    }
    Functions: {
      generate_serial_id: {
        Args: {
          prefix: string
        }
        Returns: string
      }
      get_kpi_dashboard: {
        Args: Record<PropertyKey, never>
        Returns: Json
      }
      get_matrix_data: {
        Args: Record<PropertyKey, never>
        Returns: {
          id: string
          code: string
          etage: number
          numero: number
          resident_nom: string
          balance: number
          statut_financier: string
        }[]
      }
      get_server_time: {
        Args: Record<PropertyKey, never>
        Returns: string
      }
    }
    Enums: {
      flux_type: "recette" | "depense"
      incident_statut: "ouvert" | "en_cours" | "resolu" | "ferme"
      payment_mode: "especes" | "virement" | "cheque"
      payment_statut: "en_attente" | "valide" | "rejete"
      user_role: "syndic" | "resident" | "gardien" | "admin"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}
