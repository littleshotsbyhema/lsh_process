export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5";
  };
  public: {
    Tables: {
      alignment_scores: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      bookings: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      client_links: {
        Row: {
          booking_id: string | null;
          created_at: string;
          expires_at: string | null;
          kind: string;
          lead_id: string | null;
          payload: Json;
          token: string;
        };
        Insert: {
          booking_id?: string | null;
          created_at?: string;
          expires_at?: string | null;
          kind: string;
          lead_id?: string | null;
          payload?: Json;
          token: string;
        };
        Update: {
          booking_id?: string | null;
          created_at?: string;
          expires_at?: string | null;
          kind?: string;
          lead_id?: string | null;
          payload?: Json;
          token?: string;
        };
        Relationships: [];
      };
      client_submissions: {
        Row: {
          created_at: string;
          id: string;
          kind: string;
          payload: Json;
          token: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          kind: string;
          payload?: Json;
          token: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          kind?: string;
          payload?: Json;
          token?: string;
        };
        Relationships: [
          {
            foreignKeyName: "client_submissions_token_fkey";
            columns: ["token"];
            isOneToOne: false;
            referencedRelation: "client_links";
            referencedColumns: ["token"];
          },
        ];
      };
      clients: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      editing_jobs: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      follow_ups: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      governance_runs: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      heirloom_jobs: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      leads: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      memory_profiles: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      pixieset_records: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      privacy_records: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      profiles: {
        Row: {
          created_at: string;
          email: string | null;
          full_name: string | null;
          id: string;
        };
        Insert: {
          created_at?: string;
          email?: string | null;
          full_name?: string | null;
          id: string;
        };
        Update: {
          created_at?: string;
          email?: string | null;
          full_name?: string | null;
          id?: string;
        };
        Relationships: [];
      };
      reviews: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      safety_submissions: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      studio_invites: {
        Row: {
          accepted_at: string | null;
          accepted_by: string | null;
          created_at: string;
          email: string;
          expires_at: string;
          full_name: string | null;
          id: string;
          invited_by: string | null;
          roles: Database["public"]["Enums"]["app_role"][];
          status: string;
          token: string;
          updated_at: string;
        };
        Insert: {
          accepted_at?: string | null;
          accepted_by?: string | null;
          created_at?: string;
          email: string;
          expires_at?: string;
          full_name?: string | null;
          id?: string;
          invited_by?: string | null;
          roles?: Database["public"]["Enums"]["app_role"][];
          status?: string;
          token?: string;
          updated_at?: string;
        };
        Update: {
          accepted_at?: string | null;
          accepted_by?: string | null;
          created_at?: string;
          email?: string;
          expires_at?: string;
          full_name?: string | null;
          id?: string;
          invited_by?: string | null;
          roles?: Database["public"]["Enums"]["app_role"][];
          status?: string;
          token?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      studio_meta: {
        Row: {
          created_at: string;
          key: string;
          updated_at: string;
          value: Json;
        };
        Insert: {
          created_at?: string;
          key: string;
          updated_at?: string;
          value?: Json;
        };
        Update: {
          created_at?: string;
          key?: string;
          updated_at?: string;
          value?: Json;
        };
        Relationships: [];
      };
      tasks: {
        Row: {
          created_at: string;
          data: Json;
          id: string;
          updated_at: string;
        };
        Insert: {
          created_at?: string;
          data: Json;
          id: string;
          updated_at?: string;
        };
        Update: {
          created_at?: string;
          data?: Json;
          id?: string;
          updated_at?: string;
        };
        Relationships: [];
      };
      user_roles: {
        Row: {
          created_at: string;
          id: string;
          role: Database["public"]["Enums"]["app_role"];
          user_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          role: Database["public"]["Enums"]["app_role"];
          user_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          role?: Database["public"]["Enums"]["app_role"];
          user_id?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      has_any_role: {
        Args: {
          _roles: Database["public"]["Enums"]["app_role"][];
          _user_id: string;
        };
        Returns: boolean;
      };
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"];
          _user_id: string;
        };
        Returns: boolean;
      };
      is_staff: { Args: { _user_id: string }; Returns: boolean };
    };
    Enums: {
      app_role:
        | "founder"
        | "coordinator"
        | "sales"
        | "photographer"
        | "assistant"
        | "stylist"
        | "editor"
        | "album"
        | "marketing"
        | "accounts";
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">;

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">];

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R;
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R;
      }
      ? R
      : never
    : never;

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I;
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I;
      }
      ? I
      : never
    : never;

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U;
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U;
      }
      ? U
      : never
    : never;

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  public: {
    Enums: {
      app_role: [
        "founder",
        "coordinator",
        "sales",
        "photographer",
        "assistant",
        "stylist",
        "editor",
        "album",
        "marketing",
        "accounts",
      ],
    },
  },
} as const;
