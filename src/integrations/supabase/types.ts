export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never;
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      graphql: {
        Args: {
          extensions?: Json;
          operationName?: string;
          query?: string;
          variables?: Json;
        };
        Returns: Json;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
  public: {
    Tables: {
      audit_events: {
        Row: {
          action_key: string;
          actor_member_id: string | null;
          actor_user_id: string | null;
          branch_id: string | null;
          entity_id: string | null;
          entity_type: string;
          id: string;
          is_sensitive: boolean;
          metadata: Json;
          new_values: Json | null;
          occurred_at: string;
          old_values: Json | null;
          organization_id: string;
          request_id: string | null;
          source: string;
        };
        Insert: {
          action_key: string;
          actor_member_id?: string | null;
          actor_user_id?: string | null;
          branch_id?: string | null;
          entity_id?: string | null;
          entity_type: string;
          id?: string;
          is_sensitive?: boolean;
          metadata?: Json;
          new_values?: Json | null;
          occurred_at?: string;
          old_values?: Json | null;
          organization_id: string;
          request_id?: string | null;
          source?: string;
        };
        Update: {
          action_key?: string;
          actor_member_id?: string | null;
          actor_user_id?: string | null;
          branch_id?: string | null;
          entity_id?: string | null;
          entity_type?: string;
          id?: string;
          is_sensitive?: boolean;
          metadata?: Json;
          new_values?: Json | null;
          occurred_at?: string;
          old_values?: Json | null;
          organization_id?: string;
          request_id?: string | null;
          source?: string;
        };
        Relationships: [
          {
            foreignKeyName: "audit_events_actor_member_fk";
            columns: ["actor_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "audit_events_branch_fk";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "audit_events_organization_fk";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      booking_journey_stages: {
        Row: {
          created_at: string;
          created_by: string | null;
          id: string;
          is_active: boolean;
          label: string;
          organization_id: string;
          stage_key: string;
          stage_order: number;
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          created_at?: string;
          created_by?: string | null;
          id?: string;
          is_active?: boolean;
          label: string;
          organization_id: string;
          stage_key: string;
          stage_order: number;
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          created_at?: string;
          created_by?: string | null;
          id?: string;
          is_active?: boolean;
          label?: string;
          organization_id?: string;
          stage_key?: string;
          stage_order?: number;
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "booking_journey_stages_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      booking_journey_states: {
        Row: {
          booking_id: string;
          created_at: string;
          created_by: string;
          current_stage_id: string;
          organization_id: string;
          stage_entered_at: string;
          updated_at: string;
          updated_by: string;
          version: number;
        };
        Insert: {
          booking_id: string;
          created_at?: string;
          created_by: string;
          current_stage_id: string;
          organization_id: string;
          stage_entered_at?: string;
          updated_at?: string;
          updated_by: string;
          version?: number;
        };
        Update: {
          booking_id?: string;
          created_at?: string;
          created_by?: string;
          current_stage_id?: string;
          organization_id?: string;
          stage_entered_at?: string;
          updated_at?: string;
          updated_by?: string;
          version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "booking_journey_states_booking_fkey";
            columns: ["organization_id", "booking_id"];
            isOneToOne: false;
            referencedRelation: "bookings";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "booking_journey_states_created_by_fkey";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "booking_journey_states_stage_fkey";
            columns: ["organization_id", "current_stage_id"];
            isOneToOne: false;
            referencedRelation: "booking_journey_stages";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "booking_journey_states_updated_by_fkey";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      booking_stage_transitions: {
        Row: {
          booking_id: string;
          from_stage_id: string | null;
          id: string;
          organization_id: string;
          to_stage_id: string;
          transition_key: string;
          transitioned_at: string;
          transitioned_by: string;
        };
        Insert: {
          booking_id: string;
          from_stage_id?: string | null;
          id?: string;
          organization_id: string;
          to_stage_id: string;
          transition_key: string;
          transitioned_at?: string;
          transitioned_by: string;
        };
        Update: {
          booking_id?: string;
          from_stage_id?: string | null;
          id?: string;
          organization_id?: string;
          to_stage_id?: string;
          transition_key?: string;
          transitioned_at?: string;
          transitioned_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "booking_stage_transitions_actor_fkey";
            columns: ["transitioned_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "booking_stage_transitions_booking_fkey";
            columns: ["organization_id", "booking_id"];
            isOneToOne: false;
            referencedRelation: "bookings";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "booking_stage_transitions_from_stage_fkey";
            columns: ["organization_id", "from_stage_id"];
            isOneToOne: false;
            referencedRelation: "booking_journey_stages";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "booking_stage_transitions_to_stage_fkey";
            columns: ["organization_id", "to_stage_id"];
            isOneToOne: false;
            referencedRelation: "booking_journey_stages";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      bookings: {
        Row: {
          booking_reference: string;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          family_id: string | null;
          id: string;
          lead_id: string | null;
          organization_id: string;
          source_quotation_id: string;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          booking_reference: string;
          branch_id?: string | null;
          created_at?: string;
          created_by: string;
          family_id?: string | null;
          id?: string;
          lead_id?: string | null;
          organization_id: string;
          source_quotation_id: string;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          booking_reference?: string;
          branch_id?: string | null;
          created_at?: string;
          created_by?: string;
          family_id?: string | null;
          id?: string;
          lead_id?: string | null;
          organization_id?: string;
          source_quotation_id?: string;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "bookings_branch_fkey";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "bookings_created_by_fkey";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "bookings_family_fkey";
            columns: ["family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "bookings_lead_fkey";
            columns: ["organization_id", "lead_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "bookings_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "bookings_source_quotation_fkey";
            columns: ["organization_id", "source_quotation_id"];
            isOneToOne: true;
            referencedRelation: "quotations";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "bookings_updated_by_fkey";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      branches: {
        Row: {
          address_line1: string | null;
          address_line2: string | null;
          city: string | null;
          code: string;
          country_code: string;
          created_at: string;
          created_by: string | null;
          deleted_at: string | null;
          id: string;
          name: string;
          organization_id: string;
          phone: string | null;
          postal_code: string | null;
          state_region: string | null;
          status: Database["public"]["Enums"]["branch_status"];
          timezone: string | null;
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          address_line1?: string | null;
          address_line2?: string | null;
          city?: string | null;
          code: string;
          country_code?: string;
          created_at?: string;
          created_by?: string | null;
          deleted_at?: string | null;
          id?: string;
          name: string;
          organization_id: string;
          phone?: string | null;
          postal_code?: string | null;
          state_region?: string | null;
          status?: Database["public"]["Enums"]["branch_status"];
          timezone?: string | null;
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          address_line1?: string | null;
          address_line2?: string | null;
          city?: string | null;
          code?: string;
          country_code?: string;
          created_at?: string;
          created_by?: string | null;
          deleted_at?: string | null;
          id?: string;
          name?: string;
          organization_id?: string;
          phone?: string | null;
          postal_code?: string | null;
          state_region?: string | null;
          status?: Database["public"]["Enums"]["branch_status"];
          timezone?: string | null;
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "branches_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      business_calendar_days: {
        Row: {
          is_business_day: boolean;
          local_end: string | null;
          local_start: string | null;
          organization_id: string;
          timezone: string;
          weekday: number;
        };
        Insert: {
          is_business_day: boolean;
          local_end?: string | null;
          local_start?: string | null;
          organization_id: string;
          timezone?: string;
          weekday: number;
        };
        Update: {
          is_business_day?: boolean;
          local_end?: string | null;
          local_start?: string | null;
          organization_id?: string;
          timezone?: string;
          weekday?: number;
        };
        Relationships: [
          {
            foreignKeyName: "business_calendar_days_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      business_calendar_holidays: {
        Row: {
          holiday_date: string;
          id: string;
          label: string;
          organization_id: string;
        };
        Insert: {
          holiday_date: string;
          id?: string;
          label: string;
          organization_id: string;
        };
        Update: {
          holiday_date?: string;
          id?: string;
          label?: string;
          organization_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "business_calendar_holidays_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      children: {
        Row: {
          archived_at: string | null;
          archived_by: string | null;
          birth_date: string | null;
          child_reference: string;
          created_at: string;
          created_by: string;
          current_stage: Database["public"]["Enums"]["child_stage"] | null;
          expected_due_date: string | null;
          family_id: string;
          first_name: string | null;
          id: string;
          organization_id: string;
          privacy_restriction: Database["public"]["Enums"]["privacy_preference_type"] | null;
          status: Database["public"]["Enums"]["child_status"];
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          archived_at?: string | null;
          archived_by?: string | null;
          birth_date?: string | null;
          child_reference: string;
          created_at?: string;
          created_by: string;
          current_stage?: Database["public"]["Enums"]["child_stage"] | null;
          expected_due_date?: string | null;
          family_id: string;
          first_name?: string | null;
          id?: string;
          organization_id: string;
          privacy_restriction?: Database["public"]["Enums"]["privacy_preference_type"] | null;
          status?: Database["public"]["Enums"]["child_status"];
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          archived_at?: string | null;
          archived_by?: string | null;
          birth_date?: string | null;
          child_reference?: string;
          created_at?: string;
          created_by?: string;
          current_stage?: Database["public"]["Enums"]["child_stage"] | null;
          expected_due_date?: string | null;
          family_id?: string;
          first_name?: string | null;
          id?: string;
          organization_id?: string;
          privacy_restriction?: Database["public"]["Enums"]["privacy_preference_type"] | null;
          status?: Database["public"]["Enums"]["child_status"];
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "children_archived_by_fk";
            columns: ["archived_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "children_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "children_family_fk";
            columns: ["family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "children_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      commercial_addon_versions: {
        Row: {
          addon_id: string;
          amount_inr: number | null;
          approval_status: Database["public"]["Enums"]["commercial_version_approval_status"];
          approved_at: string | null;
          approved_by: string | null;
          created_at: string;
          created_by: string | null;
          currency: string;
          id: string;
          organization_id: string;
          percentage_value: number | null;
          pricing_type: Database["public"]["Enums"]["commercial_pricing_type"];
          source_document: string | null;
          source_revision: string | null;
          updated_at: string;
          updated_by: string | null;
          version_number: number;
        };
        Insert: {
          addon_id: string;
          amount_inr?: number | null;
          approval_status?: Database["public"]["Enums"]["commercial_version_approval_status"];
          approved_at?: string | null;
          approved_by?: string | null;
          created_at?: string;
          created_by?: string | null;
          currency?: string;
          id?: string;
          organization_id: string;
          percentage_value?: number | null;
          pricing_type: Database["public"]["Enums"]["commercial_pricing_type"];
          source_document?: string | null;
          source_revision?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          version_number: number;
        };
        Update: {
          addon_id?: string;
          amount_inr?: number | null;
          approval_status?: Database["public"]["Enums"]["commercial_version_approval_status"];
          approved_at?: string | null;
          approved_by?: string | null;
          created_at?: string;
          created_by?: string | null;
          currency?: string;
          id?: string;
          organization_id?: string;
          percentage_value?: number | null;
          pricing_type?: Database["public"]["Enums"]["commercial_pricing_type"];
          source_document?: string | null;
          source_revision?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          version_number?: number;
        };
        Relationships: [
          {
            foreignKeyName: "commercial_addon_versions_addon_fkey";
            columns: ["organization_id", "addon_id"];
            isOneToOne: false;
            referencedRelation: "commercial_addons";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      commercial_addons: {
        Row: {
          addon_key: string;
          applicable_package_keys: string[];
          applicable_service_categories: string[];
          created_at: string;
          created_by: string | null;
          description: string | null;
          id: string;
          organization_id: string;
          public_name: string;
          status: Database["public"]["Enums"]["commercial_package_status"];
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          addon_key: string;
          applicable_package_keys?: string[];
          applicable_service_categories: string[];
          created_at?: string;
          created_by?: string | null;
          description?: string | null;
          id?: string;
          organization_id: string;
          public_name: string;
          status?: Database["public"]["Enums"]["commercial_package_status"];
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          addon_key?: string;
          applicable_package_keys?: string[];
          applicable_service_categories?: string[];
          created_at?: string;
          created_by?: string | null;
          description?: string | null;
          id?: string;
          organization_id?: string;
          public_name?: string;
          status?: Database["public"]["Enums"]["commercial_package_status"];
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "commercial_addons_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      commercial_package_inclusions: {
        Row: {
          created_at: string;
          created_by: string | null;
          description: string | null;
          id: string;
          inclusion_key: string;
          label: string;
          metadata: Json;
          organization_id: string;
          package_version_id: string;
          quantity: number | null;
          sort_order: number;
          unit: string | null;
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          created_at?: string;
          created_by?: string | null;
          description?: string | null;
          id?: string;
          inclusion_key: string;
          label: string;
          metadata?: Json;
          organization_id: string;
          package_version_id: string;
          quantity?: number | null;
          sort_order?: number;
          unit?: string | null;
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          created_at?: string;
          created_by?: string | null;
          description?: string | null;
          id?: string;
          inclusion_key?: string;
          label?: string;
          metadata?: Json;
          organization_id?: string;
          package_version_id?: string;
          quantity?: number | null;
          sort_order?: number;
          unit?: string | null;
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "commercial_package_inclusions_version_fkey";
            columns: ["organization_id", "package_version_id"];
            isOneToOne: false;
            referencedRelation: "commercial_package_versions";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      commercial_package_versions: {
        Row: {
          approval_status: Database["public"]["Enums"]["commercial_version_approval_status"];
          approved_at: string | null;
          approved_by: string | null;
          created_at: string;
          created_by: string | null;
          currency: string;
          effective_from: string | null;
          effective_until: string | null;
          id: string;
          list_price_inr: number;
          organization_id: string;
          package_id: string;
          source_document: string | null;
          source_revision: string | null;
          updated_at: string;
          updated_by: string | null;
          version_number: number;
        };
        Insert: {
          approval_status?: Database["public"]["Enums"]["commercial_version_approval_status"];
          approved_at?: string | null;
          approved_by?: string | null;
          created_at?: string;
          created_by?: string | null;
          currency?: string;
          effective_from?: string | null;
          effective_until?: string | null;
          id?: string;
          list_price_inr: number;
          organization_id: string;
          package_id: string;
          source_document?: string | null;
          source_revision?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          version_number: number;
        };
        Update: {
          approval_status?: Database["public"]["Enums"]["commercial_version_approval_status"];
          approved_at?: string | null;
          approved_by?: string | null;
          created_at?: string;
          created_by?: string | null;
          currency?: string;
          effective_from?: string | null;
          effective_until?: string | null;
          id?: string;
          list_price_inr?: number;
          organization_id?: string;
          package_id?: string;
          source_document?: string | null;
          source_revision?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          version_number?: number;
        };
        Relationships: [
          {
            foreignKeyName: "commercial_package_versions_package_fkey";
            columns: ["organization_id", "package_id"];
            isOneToOne: false;
            referencedRelation: "commercial_packages";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      commercial_packages: {
        Row: {
          created_at: string;
          created_by: string | null;
          id: string;
          organization_id: string;
          package_key: string;
          public_name: string;
          service_category: string;
          status: Database["public"]["Enums"]["commercial_package_status"];
          tier: Database["public"]["Enums"]["commercial_package_tier"];
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          created_at?: string;
          created_by?: string | null;
          id?: string;
          organization_id: string;
          package_key: string;
          public_name: string;
          service_category: string;
          status?: Database["public"]["Enums"]["commercial_package_status"];
          tier: Database["public"]["Enums"]["commercial_package_tier"];
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          created_at?: string;
          created_by?: string | null;
          id?: string;
          organization_id?: string;
          package_key?: string;
          public_name?: string;
          service_category?: string;
          status?: Database["public"]["Enums"]["commercial_package_status"];
          tier?: Database["public"]["Enums"]["commercial_package_tier"];
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "commercial_packages_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      consultation_availability_windows: {
        Row: {
          booking_horizon_days: number;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          capacity: number;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          is_bookable: boolean;
          local_end: string;
          local_start: string;
          minimum_notice_minutes: number;
          organization_id: string;
          owner_member_id: string;
          timezone: string;
          updated_at: string;
          updated_by: string;
          weekday: number;
        };
        Insert: {
          booking_horizon_days?: number;
          buffer_after_minutes?: number;
          buffer_before_minutes?: number;
          capacity?: number;
          created_at?: string;
          created_by: string;
          duration_minutes?: number;
          id?: string;
          is_bookable?: boolean;
          local_end: string;
          local_start: string;
          minimum_notice_minutes?: number;
          organization_id: string;
          owner_member_id: string;
          timezone?: string;
          updated_at?: string;
          updated_by: string;
          weekday: number;
        };
        Update: {
          booking_horizon_days?: number;
          buffer_after_minutes?: number;
          buffer_before_minutes?: number;
          capacity?: number;
          created_at?: string;
          created_by?: string;
          duration_minutes?: number;
          id?: string;
          is_bookable?: boolean;
          local_end?: string;
          local_start?: string;
          minimum_notice_minutes?: number;
          organization_id?: string;
          owner_member_id?: string;
          timezone?: string;
          updated_at?: string;
          updated_by?: string;
          weekday?: number;
        };
        Relationships: [
          {
            foreignKeyName: "consultation_availability_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_availability_owner_fk";
            columns: ["owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_availability_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_availability_windows_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      consultation_blackouts: {
        Row: {
          created_at: string;
          created_by: string;
          ends_at: string;
          id: string;
          organization_id: string;
          owner_member_id: string | null;
          safe_reason: string;
          starts_at: string;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          ends_at: string;
          id?: string;
          organization_id: string;
          owner_member_id?: string | null;
          safe_reason: string;
          starts_at: string;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          ends_at?: string;
          id?: string;
          organization_id?: string;
          owner_member_id?: string | null;
          safe_reason?: string;
          starts_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "consultation_blackouts_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_blackouts_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "consultation_blackouts_owner_fk";
            columns: ["owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      consultation_private_notes: {
        Row: {
          consultation_id: string;
          created_at: string;
          created_by: string;
          id: string;
          note_text: string;
          organization_id: string;
        };
        Insert: {
          consultation_id: string;
          created_at?: string;
          created_by: string;
          id?: string;
          note_text: string;
          organization_id: string;
        };
        Update: {
          consultation_id?: string;
          created_at?: string;
          created_by?: string;
          id?: string;
          note_text?: string;
          organization_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "consultation_private_notes_consultation_fk";
            columns: ["consultation_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "consultations";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_private_notes_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_private_notes_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      consultation_schedule_history: {
        Row: {
          actor_member_id: string;
          consultation_id: string;
          created_at: string;
          event_type: string;
          id: string;
          new_end_at: string | null;
          new_start_at: string | null;
          notification_effect: string | null;
          organization_id: string;
          previous_end_at: string | null;
          previous_start_at: string | null;
          reason_recorded: boolean;
        };
        Insert: {
          actor_member_id: string;
          consultation_id: string;
          created_at?: string;
          event_type: string;
          id?: string;
          new_end_at?: string | null;
          new_start_at?: string | null;
          notification_effect?: string | null;
          organization_id: string;
          previous_end_at?: string | null;
          previous_start_at?: string | null;
          reason_recorded?: boolean;
        };
        Update: {
          actor_member_id?: string;
          consultation_id?: string;
          created_at?: string;
          event_type?: string;
          id?: string;
          new_end_at?: string | null;
          new_start_at?: string | null;
          notification_effect?: string | null;
          organization_id?: string;
          previous_end_at?: string | null;
          previous_start_at?: string | null;
          reason_recorded?: boolean;
        };
        Relationships: [
          {
            foreignKeyName: "consultation_schedule_history_actor_fk";
            columns: ["actor_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_schedule_history_consultation_fk";
            columns: ["consultation_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "consultations";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultation_schedule_history_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      consultations: {
        Row: {
          branch_id: string | null;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          business_summary: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          client_shareable_recap: string | null;
          completed_at: string | null;
          confirmed_emotional_goal: string | null;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          lead_id: string;
          missed_at: string | null;
          next_step: string | null;
          objections: string | null;
          organization_id: string;
          outcome: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit: string | null;
          privacy_clarification: string | null;
          rescheduled_from_id: string | null;
          safety_review: string | null;
          schedule_version: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status: Database["public"]["Enums"]["consultation_status"];
          timezone: string;
          timing_fit: string | null;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          branch_id?: string | null;
          buffer_after_minutes?: number;
          buffer_before_minutes?: number;
          business_summary?: string | null;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          client_shareable_recap?: string | null;
          completed_at?: string | null;
          confirmed_emotional_goal?: string | null;
          created_at?: string;
          created_by: string;
          duration_minutes: number;
          id?: string;
          lead_id: string;
          missed_at?: string | null;
          next_step?: string | null;
          objections?: string | null;
          organization_id: string;
          outcome?: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit?: string | null;
          privacy_clarification?: string | null;
          rescheduled_from_id?: string | null;
          safety_review?: string | null;
          schedule_version?: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status?: Database["public"]["Enums"]["consultation_status"];
          timezone?: string;
          timing_fit?: string | null;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          branch_id?: string | null;
          buffer_after_minutes?: number;
          buffer_before_minutes?: number;
          business_summary?: string | null;
          cancellation_reason?: string | null;
          cancelled_at?: string | null;
          client_shareable_recap?: string | null;
          completed_at?: string | null;
          confirmed_emotional_goal?: string | null;
          created_at?: string;
          created_by?: string;
          duration_minutes?: number;
          id?: string;
          lead_id?: string;
          missed_at?: string | null;
          next_step?: string | null;
          objections?: string | null;
          organization_id?: string;
          outcome?: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id?: string;
          package_fit?: string | null;
          privacy_clarification?: string | null;
          rescheduled_from_id?: string | null;
          safety_review?: string | null;
          schedule_version?: number;
          scheduled_end_at?: string;
          scheduled_start_at?: string;
          status?: Database["public"]["Enums"]["consultation_status"];
          timezone?: string;
          timing_fit?: string | null;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "consultations_branch_fk";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultations_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultations_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultations_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "consultations_owner_fk";
            columns: ["owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultations_rescheduled_from_fk";
            columns: ["rescheduled_from_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "consultations";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "consultations_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      families: {
        Row: {
          archived_at: string | null;
          archived_by: string | null;
          assigned_owner_member_id: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          display_name: string;
          family_code: string;
          id: string;
          merged_at: string | null;
          merged_by: string | null;
          merged_into_family_id: string | null;
          organization_id: string;
          sort_name: string;
          status: Database["public"]["Enums"]["family_status"];
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          archived_at?: string | null;
          archived_by?: string | null;
          assigned_owner_member_id?: string | null;
          branch_id?: string | null;
          created_at?: string;
          created_by: string;
          display_name: string;
          family_code: string;
          id?: string;
          merged_at?: string | null;
          merged_by?: string | null;
          merged_into_family_id?: string | null;
          organization_id: string;
          sort_name: string;
          status?: Database["public"]["Enums"]["family_status"];
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          archived_at?: string | null;
          archived_by?: string | null;
          assigned_owner_member_id?: string | null;
          branch_id?: string | null;
          created_at?: string;
          created_by?: string;
          display_name?: string;
          family_code?: string;
          id?: string;
          merged_at?: string | null;
          merged_by?: string | null;
          merged_into_family_id?: string | null;
          organization_id?: string;
          sort_name?: string;
          status?: Database["public"]["Enums"]["family_status"];
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "families_archived_by_fkey";
            columns: ["archived_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "families_assigned_owner_fkey";
            columns: ["assigned_owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "families_branch_fkey";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "families_created_by_fkey";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "families_merged_by_fkey";
            columns: ["merged_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "families_merged_into_fkey";
            columns: ["merged_into_family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "families_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "families_updated_by_fkey";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      family_communication_controls: {
        Row: {
          contactability_status: Database["public"]["Enums"]["contactability_status"];
          created_at: string;
          created_by: string;
          do_not_contact: boolean;
          do_not_contact_reason: string | null;
          family_id: string;
          id: string;
          notes: string | null;
          organization_id: string;
          preferred_channel_type: Database["public"]["Enums"]["contact_channel_type"] | null;
          quiet_hours_end: string | null;
          quiet_hours_start: string | null;
          timezone: string;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          contactability_status?: Database["public"]["Enums"]["contactability_status"];
          created_at?: string;
          created_by: string;
          do_not_contact?: boolean;
          do_not_contact_reason?: string | null;
          family_id: string;
          id?: string;
          notes?: string | null;
          organization_id: string;
          preferred_channel_type?: Database["public"]["Enums"]["contact_channel_type"] | null;
          quiet_hours_end?: string | null;
          quiet_hours_start?: string | null;
          timezone?: string;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          contactability_status?: Database["public"]["Enums"]["contactability_status"];
          created_at?: string;
          created_by?: string;
          do_not_contact?: boolean;
          do_not_contact_reason?: string | null;
          family_id?: string;
          id?: string;
          notes?: string | null;
          organization_id?: string;
          preferred_channel_type?: Database["public"]["Enums"]["contact_channel_type"] | null;
          quiet_hours_end?: string | null;
          quiet_hours_start?: string | null;
          timezone?: string;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_communication_controls_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_communication_controls_family_fk";
            columns: ["family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_communication_controls_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      family_contact_channels: {
        Row: {
          channel_type: Database["public"]["Enums"]["contact_channel_type"];
          channel_value: string;
          created_at: string;
          created_by: string;
          deactivated_at: string | null;
          deactivated_by: string | null;
          family_contact_id: string;
          id: string;
          is_active: boolean;
          is_preferred: boolean;
          is_verified: boolean;
          normalized_value: string;
          organization_id: string;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          channel_type: Database["public"]["Enums"]["contact_channel_type"];
          channel_value: string;
          created_at?: string;
          created_by: string;
          deactivated_at?: string | null;
          deactivated_by?: string | null;
          family_contact_id: string;
          id?: string;
          is_active?: boolean;
          is_preferred?: boolean;
          is_verified?: boolean;
          normalized_value: string;
          organization_id: string;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          channel_type?: Database["public"]["Enums"]["contact_channel_type"];
          channel_value?: string;
          created_at?: string;
          created_by?: string;
          deactivated_at?: string | null;
          deactivated_by?: string | null;
          family_contact_id?: string;
          id?: string;
          is_active?: boolean;
          is_preferred?: boolean;
          is_verified?: boolean;
          normalized_value?: string;
          organization_id?: string;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_contact_channels_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_contact_channels_deactivated_by_fk";
            columns: ["deactivated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_contact_channels_family_contact_fk";
            columns: ["family_contact_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "family_contacts";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_contact_channels_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      family_contacts: {
        Row: {
          created_at: string;
          created_by: string;
          deactivated_at: string | null;
          deactivated_by: string | null;
          family_id: string;
          full_name: string;
          id: string;
          is_active: boolean;
          is_primary: boolean;
          organization_id: string;
          relationship_label: string;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          deactivated_at?: string | null;
          deactivated_by?: string | null;
          family_id: string;
          full_name: string;
          id?: string;
          is_active?: boolean;
          is_primary?: boolean;
          organization_id: string;
          relationship_label: string;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          deactivated_at?: string | null;
          deactivated_by?: string | null;
          family_id?: string;
          full_name?: string;
          id?: string;
          is_active?: boolean;
          is_primary?: boolean;
          organization_id?: string;
          relationship_label?: string;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "family_contacts_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_contacts_deactivated_by_fk";
            columns: ["deactivated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_contacts_family_fk";
            columns: ["family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "family_contacts_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      lead_activity_events: {
        Row: {
          actor_member_id: string | null;
          branch_id: string | null;
          created_at: string;
          entity_id: string | null;
          entity_type: string;
          event_type: string;
          id: string;
          lead_id: string;
          metadata: Json;
          organization_id: string;
          summary: string;
        };
        Insert: {
          actor_member_id?: string | null;
          branch_id?: string | null;
          created_at?: string;
          entity_id?: string | null;
          entity_type: string;
          event_type: string;
          id?: string;
          lead_id: string;
          metadata?: Json;
          organization_id: string;
          summary: string;
        };
        Update: {
          actor_member_id?: string | null;
          branch_id?: string | null;
          created_at?: string;
          entity_id?: string | null;
          entity_type?: string;
          event_type?: string;
          id?: string;
          lead_id?: string;
          metadata?: Json;
          organization_id?: string;
          summary?: string;
        };
        Relationships: [
          {
            foreignKeyName: "lead_activity_events_actor_fk";
            columns: ["actor_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_activity_events_branch_fk";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_activity_events_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_activity_events_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      lead_communications: {
        Row: {
          branch_id: string | null;
          business_purpose: string;
          channel: Database["public"]["Enums"]["communication_channel"];
          consultation_id: string | null;
          created_at: string;
          created_by: string;
          direction: Database["public"]["Enums"]["communication_direction"];
          id: string;
          lead_id: string;
          occurred_at: string;
          organization_id: string;
          owner_member_id: string | null;
          provider_identifier: string | null;
          safe_summary: string;
          status: Database["public"]["Enums"]["communication_status"];
          template_key: string | null;
          template_version: string | null;
        };
        Insert: {
          branch_id?: string | null;
          business_purpose: string;
          channel: Database["public"]["Enums"]["communication_channel"];
          consultation_id?: string | null;
          created_at?: string;
          created_by: string;
          direction: Database["public"]["Enums"]["communication_direction"];
          id?: string;
          lead_id: string;
          occurred_at?: string;
          organization_id: string;
          owner_member_id?: string | null;
          provider_identifier?: string | null;
          safe_summary: string;
          status?: Database["public"]["Enums"]["communication_status"];
          template_key?: string | null;
          template_version?: string | null;
        };
        Update: {
          branch_id?: string | null;
          business_purpose?: string;
          channel?: Database["public"]["Enums"]["communication_channel"];
          consultation_id?: string | null;
          created_at?: string;
          created_by?: string;
          direction?: Database["public"]["Enums"]["communication_direction"];
          id?: string;
          lead_id?: string;
          occurred_at?: string;
          organization_id?: string;
          owner_member_id?: string | null;
          provider_identifier?: string | null;
          safe_summary?: string;
          status?: Database["public"]["Enums"]["communication_status"];
          template_key?: string | null;
          template_version?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "lead_communications_branch_fk";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_communications_consultation_fk";
            columns: ["consultation_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "consultations";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_communications_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_communications_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_communications_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lead_communications_owner_fk";
            columns: ["owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      lead_next_actions: {
        Row: {
          action_text: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          due_at: string | null;
          exception_reason: string | null;
          id: string;
          lead_id: string;
          organization_id: string;
          source: string;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          action_text?: string | null;
          branch_id?: string | null;
          created_at?: string;
          created_by: string;
          due_at?: string | null;
          exception_reason?: string | null;
          id?: string;
          lead_id: string;
          organization_id: string;
          source?: string;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          action_text?: string | null;
          branch_id?: string | null;
          created_at?: string;
          created_by?: string;
          due_at?: string | null;
          exception_reason?: string | null;
          id?: string;
          lead_id?: string;
          organization_id?: string;
          source?: string;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "lead_next_actions_branch_fk";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_next_actions_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_next_actions_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_next_actions_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lead_next_actions_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      lead_sla_overrides: {
        Row: {
          created_at: string;
          created_by: string;
          expires_at: string | null;
          id: string;
          lead_id: string;
          organization_id: string;
          reason: string;
          review_at: string | null;
          sla_key: string;
        };
        Insert: {
          created_at?: string;
          created_by: string;
          expires_at?: string | null;
          id?: string;
          lead_id: string;
          organization_id: string;
          reason: string;
          review_at?: string | null;
          sla_key: string;
        };
        Update: {
          created_at?: string;
          created_by?: string;
          expires_at?: string | null;
          id?: string;
          lead_id?: string;
          organization_id?: string;
          reason?: string;
          review_at?: string | null;
          sla_key?: string;
        };
        Relationships: [
          {
            foreignKeyName: "lead_sla_overrides_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_sla_overrides_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_sla_overrides_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      lead_sla_rules: {
        Row: {
          is_active: boolean;
          organization_id: string;
          sla_key: string;
          threshold_business_minutes: number;
        };
        Insert: {
          is_active?: boolean;
          organization_id: string;
          sla_key: string;
          threshold_business_minutes: number;
        };
        Update: {
          is_active?: boolean;
          organization_id?: string;
          sla_key?: string;
          threshold_business_minutes?: number;
        };
        Relationships: [
          {
            foreignKeyName: "lead_sla_rules_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      lead_tasks: {
        Row: {
          branch_id: string | null;
          completed_at: string | null;
          completed_by: string | null;
          created_at: string;
          created_by: string;
          due_at: string | null;
          escalated_at: string | null;
          id: string;
          idempotency_key: string | null;
          lead_id: string;
          organization_id: string;
          owner_member_id: string | null;
          priority: Database["public"]["Enums"]["lead_task_priority"];
          safe_summary: string | null;
          snoozed_until: string | null;
          source: string;
          status: Database["public"]["Enums"]["lead_task_status"];
          task_type: Database["public"]["Enums"]["lead_task_type"];
          title: string;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          branch_id?: string | null;
          completed_at?: string | null;
          completed_by?: string | null;
          created_at?: string;
          created_by: string;
          due_at?: string | null;
          escalated_at?: string | null;
          id?: string;
          idempotency_key?: string | null;
          lead_id: string;
          organization_id: string;
          owner_member_id?: string | null;
          priority?: Database["public"]["Enums"]["lead_task_priority"];
          safe_summary?: string | null;
          snoozed_until?: string | null;
          source?: string;
          status?: Database["public"]["Enums"]["lead_task_status"];
          task_type: Database["public"]["Enums"]["lead_task_type"];
          title: string;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          branch_id?: string | null;
          completed_at?: string | null;
          completed_by?: string | null;
          created_at?: string;
          created_by?: string;
          due_at?: string | null;
          escalated_at?: string | null;
          id?: string;
          idempotency_key?: string | null;
          lead_id?: string;
          organization_id?: string;
          owner_member_id?: string | null;
          priority?: Database["public"]["Enums"]["lead_task_priority"];
          safe_summary?: string | null;
          snoozed_until?: string | null;
          source?: string;
          status?: Database["public"]["Enums"]["lead_task_status"];
          task_type?: Database["public"]["Enums"]["lead_task_type"];
          title?: string;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "lead_tasks_branch_fk";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_tasks_completed_by_fk";
            columns: ["completed_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_tasks_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_tasks_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_tasks_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "lead_tasks_owner_fk";
            columns: ["owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "lead_tasks_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      leads: {
        Row: {
          archived_at: string | null;
          archived_by: string | null;
          assigned_owner_member_id: string | null;
          baby_age_or_pregnancy: string | null;
          branch_id: string | null;
          budget_comfort: string | null;
          city: string | null;
          converted_at: string | null;
          converted_by: string | null;
          converted_family_id: string | null;
          created_at: string;
          created_by: string;
          email: string | null;
          follow_up_at: string | null;
          id: string;
          internal_notes: string | null;
          lead_reference: string;
          location_preference: string | null;
          lost_reason: string | null;
          memory_goal: string | null;
          organization_id: string;
          package_interest: string | null;
          parent_name: string;
          phone: string | null;
          preferred_date: string | null;
          privacy_preference: Database["public"]["Enums"]["privacy_preference_type"] | null;
          session_type: string | null;
          source: string;
          status: Database["public"]["Enums"]["lead_status"];
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          archived_at?: string | null;
          archived_by?: string | null;
          assigned_owner_member_id?: string | null;
          baby_age_or_pregnancy?: string | null;
          branch_id?: string | null;
          budget_comfort?: string | null;
          city?: string | null;
          converted_at?: string | null;
          converted_by?: string | null;
          converted_family_id?: string | null;
          created_at?: string;
          created_by: string;
          email?: string | null;
          follow_up_at?: string | null;
          id?: string;
          internal_notes?: string | null;
          lead_reference: string;
          location_preference?: string | null;
          lost_reason?: string | null;
          memory_goal?: string | null;
          organization_id: string;
          package_interest?: string | null;
          parent_name: string;
          phone?: string | null;
          preferred_date?: string | null;
          privacy_preference?: Database["public"]["Enums"]["privacy_preference_type"] | null;
          session_type?: string | null;
          source: string;
          status?: Database["public"]["Enums"]["lead_status"];
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          archived_at?: string | null;
          archived_by?: string | null;
          assigned_owner_member_id?: string | null;
          baby_age_or_pregnancy?: string | null;
          branch_id?: string | null;
          budget_comfort?: string | null;
          city?: string | null;
          converted_at?: string | null;
          converted_by?: string | null;
          converted_family_id?: string | null;
          created_at?: string;
          created_by?: string;
          email?: string | null;
          follow_up_at?: string | null;
          id?: string;
          internal_notes?: string | null;
          lead_reference?: string;
          location_preference?: string | null;
          lost_reason?: string | null;
          memory_goal?: string | null;
          organization_id?: string;
          package_interest?: string | null;
          parent_name?: string;
          phone?: string | null;
          preferred_date?: string | null;
          privacy_preference?: Database["public"]["Enums"]["privacy_preference_type"] | null;
          session_type?: string | null;
          source?: string;
          status?: Database["public"]["Enums"]["lead_status"];
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "leads_archived_by_fkey";
            columns: ["organization_id", "archived_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "leads_assigned_owner_fkey";
            columns: ["organization_id", "assigned_owner_member_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "leads_branch_fkey";
            columns: ["organization_id", "branch_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "leads_converted_by_fkey";
            columns: ["organization_id", "converted_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "leads_converted_family_fkey";
            columns: ["organization_id", "converted_family_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "leads_created_by_fkey";
            columns: ["organization_id", "created_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "leads_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "leads_updated_by_fkey";
            columns: ["organization_id", "updated_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      member_role_grants: {
        Row: {
          branch_id: string | null;
          created_at: string;
          granted_at: string;
          granted_by: string | null;
          id: string;
          organization_id: string;
          organization_member_id: string;
          revocation_reason: string | null;
          revoked_at: string | null;
          revoked_by: string | null;
          role_id: string;
        };
        Insert: {
          branch_id?: string | null;
          created_at?: string;
          granted_at?: string;
          granted_by?: string | null;
          id?: string;
          organization_id: string;
          organization_member_id: string;
          revocation_reason?: string | null;
          revoked_at?: string | null;
          revoked_by?: string | null;
          role_id: string;
        };
        Update: {
          branch_id?: string | null;
          created_at?: string;
          granted_at?: string;
          granted_by?: string | null;
          id?: string;
          organization_id?: string;
          organization_member_id?: string;
          revocation_reason?: string | null;
          revoked_at?: string | null;
          revoked_by?: string | null;
          role_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "member_role_grants_branch_fkey";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "member_role_grants_granted_by_fkey";
            columns: ["granted_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "member_role_grants_member_fkey";
            columns: ["organization_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "member_role_grants_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "member_role_grants_revoked_by_fkey";
            columns: ["revoked_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "member_role_grants_role_id_fkey";
            columns: ["role_id"];
            isOneToOne: false;
            referencedRelation: "roles";
            referencedColumns: ["id"];
          },
        ];
      };
      memory_guide_analytics_events: {
        Row: {
          created_at: string;
          event_key: string;
          id: string;
          organization_id: string;
          properties: Json;
          session_id: string;
        };
        Insert: {
          created_at?: string;
          event_key: string;
          id?: string;
          organization_id: string;
          properties?: Json;
          session_id: string;
        };
        Update: {
          created_at?: string;
          event_key?: string;
          id?: string;
          organization_id?: string;
          properties?: Json;
          session_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_analytics_events_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memory_guide_analytics_events_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_answers: {
        Row: {
          answer_value: Json;
          created_at: string;
          field_key: string;
          guide_schema_version: string;
          id: string;
          organization_id: string;
          question_id: string;
          session_id: string;
          updated_at: string;
        };
        Insert: {
          answer_value: Json;
          created_at?: string;
          field_key: string;
          guide_schema_version: string;
          id?: string;
          organization_id: string;
          question_id: string;
          session_id: string;
          updated_at?: string;
        };
        Update: {
          answer_value?: Json;
          created_at?: string;
          field_key?: string;
          guide_schema_version?: string;
          id?: string;
          organization_id?: string;
          question_id?: string;
          session_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_answers_guide_schema_version_question_id_fkey";
            columns: ["guide_schema_version", "question_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_question_definitions";
            referencedColumns: ["guide_schema_version", "question_id"];
          },
          {
            foreignKeyName: "memory_guide_answers_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_config: {
        Row: {
          anonymous_session_ttl_days: number;
          catalogue_approval_status: string;
          created_at: string;
          guide_enabled: boolean;
          guide_schema_version: string;
          high_confidence_margin: number;
          linked_session_ttl_days: number;
          organization_id: string;
          package_catalogue_version: string;
          resume_ttl_hours: number;
          retention_approval_status: string;
          review_margin: number;
          scoring_approval_status: string;
          scoring_version: string;
          updated_at: string;
        };
        Insert: {
          anonymous_session_ttl_days: number;
          catalogue_approval_status: string;
          created_at?: string;
          guide_enabled?: boolean;
          guide_schema_version: string;
          high_confidence_margin: number;
          linked_session_ttl_days: number;
          organization_id: string;
          package_catalogue_version: string;
          resume_ttl_hours: number;
          retention_approval_status: string;
          review_margin: number;
          scoring_approval_status: string;
          scoring_version: string;
          updated_at?: string;
        };
        Update: {
          anonymous_session_ttl_days?: number;
          catalogue_approval_status?: string;
          created_at?: string;
          guide_enabled?: boolean;
          guide_schema_version?: string;
          high_confidence_margin?: number;
          linked_session_ttl_days?: number;
          organization_id?: string;
          package_catalogue_version?: string;
          resume_ttl_hours?: number;
          retention_approval_status?: string;
          review_margin?: number;
          scoring_approval_status?: string;
          scoring_version?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_config_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: true;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      memory_guide_contacts: {
        Row: {
          contact_email: string | null;
          contact_name: string;
          contact_permission: boolean;
          contact_phone: string;
          created_at: string;
          id: string;
          organization_id: string;
          permission_recorded_at: string;
          preferred_contact: string;
          session_id: string;
          updated_at: string;
        };
        Insert: {
          contact_email?: string | null;
          contact_name: string;
          contact_permission: boolean;
          contact_phone: string;
          created_at?: string;
          id?: string;
          organization_id: string;
          permission_recorded_at?: string;
          preferred_contact: string;
          session_id: string;
          updated_at?: string;
        };
        Update: {
          contact_email?: string | null;
          contact_name?: string;
          contact_permission?: boolean;
          contact_phone?: string;
          created_at?: string;
          id?: string;
          organization_id?: string;
          permission_recorded_at?: string;
          preferred_contact?: string;
          session_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_contacts_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_crm_outbox: {
        Row: {
          attempt_count: number;
          created_at: string;
          id: string;
          idempotency_key: string;
          last_attempt_at: string | null;
          last_error_code: string | null;
          lead_id: string | null;
          max_attempts: number;
          next_attempt_at: string | null;
          organization_id: string;
          session_id: string;
          status: string;
          updated_at: string;
        };
        Insert: {
          attempt_count?: number;
          created_at?: string;
          id?: string;
          idempotency_key: string;
          last_attempt_at?: string | null;
          last_error_code?: string | null;
          lead_id?: string | null;
          max_attempts?: number;
          next_attempt_at?: string | null;
          organization_id: string;
          session_id: string;
          status?: string;
          updated_at?: string;
        };
        Update: {
          attempt_count?: number;
          created_at?: string;
          id?: string;
          idempotency_key?: string;
          last_attempt_at?: string | null;
          last_error_code?: string | null;
          lead_id?: string | null;
          max_attempts?: number;
          next_attempt_at?: string | null;
          organization_id?: string;
          session_id?: string;
          status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_crm_outbox_lead_id_organization_id_fkey";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_crm_outbox_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memory_guide_crm_outbox_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_decisions: {
        Row: {
          alternative_package_snapshot: Json | null;
          assumptions: Json;
          confidence: string;
          created_at: string;
          decision_input_version: number;
          decision_trace: Json;
          explanation_text: string;
          future_milestone: string | null;
          guide_schema_version: string;
          id: string;
          next_actions: Json;
          organization_id: string;
          package_catalogue_version: string;
          primary_package_snapshot: Json | null;
          privacy_note: string;
          reason_codes: Json;
          review_codes: Json;
          review_required: boolean;
          score_snapshot: Json;
          scoring_version: string;
          service_category: string;
          session_id: string;
        };
        Insert: {
          alternative_package_snapshot?: Json | null;
          assumptions?: Json;
          confidence: string;
          created_at?: string;
          decision_input_version: number;
          decision_trace: Json;
          explanation_text: string;
          future_milestone?: string | null;
          guide_schema_version: string;
          id?: string;
          next_actions?: Json;
          organization_id: string;
          package_catalogue_version: string;
          primary_package_snapshot?: Json | null;
          privacy_note: string;
          reason_codes?: Json;
          review_codes?: Json;
          review_required?: boolean;
          score_snapshot: Json;
          scoring_version: string;
          service_category: string;
          session_id: string;
        };
        Update: {
          alternative_package_snapshot?: Json | null;
          assumptions?: Json;
          confidence?: string;
          created_at?: string;
          decision_input_version?: number;
          decision_trace?: Json;
          explanation_text?: string;
          future_milestone?: string | null;
          guide_schema_version?: string;
          id?: string;
          next_actions?: Json;
          organization_id?: string;
          package_catalogue_version?: string;
          primary_package_snapshot?: Json | null;
          privacy_note?: string;
          reason_codes?: Json;
          review_codes?: Json;
          review_required?: boolean;
          score_snapshot?: Json;
          scoring_version?: string;
          service_category?: string;
          session_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_decisions_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_lead_summaries: {
        Row: {
          alternative_package: Json | null;
          confidence: string;
          created_at: string;
          decision_versions: Json;
          emotional_goals: Json;
          future_milestone: string | null;
          id: string;
          lead_id: string;
          next_action: string | null;
          organization_id: string;
          participants_summary: Json;
          preferred_contact: string | null;
          primary_package: Json | null;
          privacy_choice: Database["public"]["Enums"]["privacy_preference_type"];
          reason_codes: Json;
          review_required: boolean;
          safety_review_required: boolean;
          service_category: string;
          session_id: string;
          session_reference: string;
          source_page: string | null;
          updated_at: string;
        };
        Insert: {
          alternative_package?: Json | null;
          confidence: string;
          created_at?: string;
          decision_versions: Json;
          emotional_goals?: Json;
          future_milestone?: string | null;
          id?: string;
          lead_id: string;
          next_action?: string | null;
          organization_id: string;
          participants_summary?: Json;
          preferred_contact?: string | null;
          primary_package?: Json | null;
          privacy_choice: Database["public"]["Enums"]["privacy_preference_type"];
          reason_codes?: Json;
          review_required: boolean;
          safety_review_required?: boolean;
          service_category: string;
          session_id: string;
          session_reference: string;
          source_page?: string | null;
          updated_at?: string;
        };
        Update: {
          alternative_package?: Json | null;
          confidence?: string;
          created_at?: string;
          decision_versions?: Json;
          emotional_goals?: Json;
          future_milestone?: string | null;
          id?: string;
          lead_id?: string;
          next_action?: string | null;
          organization_id?: string;
          participants_summary?: Json;
          preferred_contact?: string | null;
          primary_package?: Json | null;
          privacy_choice?: Database["public"]["Enums"]["privacy_preference_type"];
          reason_codes?: Json;
          review_required?: boolean;
          safety_review_required?: boolean;
          service_category?: string;
          session_id?: string;
          session_reference?: string;
          source_page?: string | null;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_lead_summaries_lead_id_organization_id_fkey";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_lead_summaries_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memory_guide_lead_summaries_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_package_catalogues: {
        Row: {
          catalogue_version: string;
          created_at: string;
          effective_from: string;
          organization_id: string;
          source_label: string;
          status: string;
        };
        Insert: {
          catalogue_version: string;
          created_at?: string;
          effective_from?: string;
          organization_id: string;
          source_label: string;
          status: string;
        };
        Update: {
          catalogue_version?: string;
          created_at?: string;
          effective_from?: string;
          organization_id?: string;
          source_label?: string;
          status?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_package_catalogues_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      memory_guide_packages: {
        Row: {
          active: boolean;
          catalogue_version: string;
          created_at: string;
          inclusions: Json;
          list_price_inr: number;
          organization_id: string;
          package_key: string;
          public_name: string;
          public_offer_enabled: boolean;
          service_category: string;
          source_document: string;
          source_offer_price_inr: number | null;
          summary: string;
          tier: string;
          updated_at: string;
        };
        Insert: {
          active?: boolean;
          catalogue_version: string;
          created_at?: string;
          inclusions?: Json;
          list_price_inr: number;
          organization_id: string;
          package_key: string;
          public_name: string;
          public_offer_enabled?: boolean;
          service_category: string;
          source_document: string;
          source_offer_price_inr?: number | null;
          summary: string;
          tier: string;
          updated_at?: string;
        };
        Update: {
          active?: boolean;
          catalogue_version?: string;
          created_at?: string;
          inclusions?: Json;
          list_price_inr?: number;
          organization_id?: string;
          package_key?: string;
          public_name?: string;
          public_offer_enabled?: boolean;
          service_category?: string;
          source_document?: string;
          source_offer_price_inr?: number | null;
          summary?: string;
          tier?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_packages_organization_id_catalogue_version_fkey";
            columns: ["organization_id", "catalogue_version"];
            isOneToOne: false;
            referencedRelation: "memory_guide_package_catalogues";
            referencedColumns: ["organization_id", "catalogue_version"];
          },
        ];
      };
      memory_guide_question_definitions: {
        Row: {
          classification: string;
          control_type: string;
          field_key: string;
          guide_schema_version: string;
          options: Json;
          privacy_rule: string | null;
          prompt: string;
          question_id: string;
          requirement: string;
          sort_order: number;
          stage_id: string;
          validation_rule: string | null;
        };
        Insert: {
          classification: string;
          control_type: string;
          field_key: string;
          guide_schema_version: string;
          options?: Json;
          privacy_rule?: string | null;
          prompt: string;
          question_id: string;
          requirement: string;
          sort_order: number;
          stage_id: string;
          validation_rule?: string | null;
        };
        Update: {
          classification?: string;
          control_type?: string;
          field_key?: string;
          guide_schema_version?: string;
          options?: Json;
          privacy_rule?: string | null;
          prompt?: string;
          question_id?: string;
          requirement?: string;
          sort_order?: number;
          stage_id?: string;
          validation_rule?: string | null;
        };
        Relationships: [];
      };
      memory_guide_resume_tokens: {
        Row: {
          attempt_count: number;
          created_at: string;
          expires_at: string;
          id: string;
          locked_until: string | null;
          organization_id: string;
          session_id: string;
          token_hash: string;
          used_at: string | null;
        };
        Insert: {
          attempt_count?: number;
          created_at?: string;
          expires_at: string;
          id?: string;
          locked_until?: string | null;
          organization_id: string;
          session_id: string;
          token_hash: string;
          used_at?: string | null;
        };
        Update: {
          attempt_count?: number;
          created_at?: string;
          expires_at?: string;
          id?: string;
          locked_until?: string | null;
          organization_id?: string;
          session_id?: string;
          token_hash?: string;
          used_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_resume_tokens_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_review_requests: {
        Row: {
          created_at: string;
          decision_id: string | null;
          due_at: string;
          id: string;
          lead_id: string | null;
          organization_id: string;
          owner_member_id: string;
          resolved_at: string | null;
          resolved_by: string | null;
          review_type: string;
          session_id: string;
          sla_minutes: number;
          status: string;
          trigger_code: string;
          updated_at: string;
          visibility: string;
        };
        Insert: {
          created_at?: string;
          decision_id?: string | null;
          due_at: string;
          id?: string;
          lead_id?: string | null;
          organization_id: string;
          owner_member_id: string;
          resolved_at?: string | null;
          resolved_by?: string | null;
          review_type: string;
          session_id: string;
          sla_minutes: number;
          status?: string;
          trigger_code: string;
          updated_at?: string;
          visibility: string;
        };
        Update: {
          created_at?: string;
          decision_id?: string | null;
          due_at?: string;
          id?: string;
          lead_id?: string | null;
          organization_id?: string;
          owner_member_id?: string;
          resolved_at?: string | null;
          resolved_by?: string | null;
          review_type?: string;
          session_id?: string;
          sla_minutes?: number;
          status?: string;
          trigger_code?: string;
          updated_at?: string;
          visibility?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_review_requests_decision_id_fkey";
            columns: ["decision_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_decisions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memory_guide_review_requests_lead_id_organization_id_fkey";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_review_requests_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memory_guide_review_requests_owner_member_id_organization__fkey";
            columns: ["owner_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_review_requests_resolved_by_organization_id_fkey";
            columns: ["resolved_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_review_requests_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_scoring_rules: {
        Row: {
          classification: string;
          created_at: string;
          field_key: string;
          match_value: string;
          organization_id: string;
          package_tier: string;
          points: number;
          priority: number;
          rationale: string;
          rule_id: string;
          scoring_version: string;
        };
        Insert: {
          classification: string;
          created_at?: string;
          field_key: string;
          match_value: string;
          organization_id: string;
          package_tier: string;
          points: number;
          priority?: number;
          rationale: string;
          rule_id: string;
          scoring_version: string;
        };
        Update: {
          classification?: string;
          created_at?: string;
          field_key?: string;
          match_value?: string;
          organization_id?: string;
          package_tier?: string;
          points?: number;
          priority?: number;
          rationale?: string;
          rule_id?: string;
          scoring_version?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_scoring_rules_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      memory_guide_sensitive_answers: {
        Row: {
          answer_value: Json;
          created_at: string;
          field_key: string;
          guide_schema_version: string;
          id: string;
          organization_id: string;
          question_id: string;
          session_id: string;
          updated_at: string;
        };
        Insert: {
          answer_value: Json;
          created_at?: string;
          field_key: string;
          guide_schema_version: string;
          id?: string;
          organization_id: string;
          question_id: string;
          session_id: string;
          updated_at?: string;
        };
        Update: {
          answer_value?: Json;
          created_at?: string;
          field_key?: string;
          guide_schema_version?: string;
          id?: string;
          organization_id?: string;
          question_id?: string;
          session_id?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_sensitive_answer_guide_schema_version_questio_fkey";
            columns: ["guide_schema_version", "question_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_question_definitions";
            referencedColumns: ["guide_schema_version", "question_id"];
          },
          {
            foreignKeyName: "memory_guide_sensitive_answers_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_session_events: {
        Row: {
          actor_member_id: string | null;
          created_at: string;
          event_type: string;
          id: string;
          organization_id: string;
          safe_metadata: Json;
          session_id: string;
          session_version: number;
        };
        Insert: {
          actor_member_id?: string | null;
          created_at?: string;
          event_type: string;
          id?: string;
          organization_id: string;
          safe_metadata?: Json;
          session_id: string;
          session_version: number;
        };
        Update: {
          actor_member_id?: string | null;
          created_at?: string;
          event_type?: string;
          id?: string;
          organization_id?: string;
          safe_metadata?: Json;
          session_id?: string;
          session_version?: number;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_session_events_actor_fk";
            columns: ["actor_member_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_session_events_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "memory_guide_session_events_session_id_organization_id_fkey";
            columns: ["session_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "memory_guide_sessions";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      memory_guide_sessions: {
        Row: {
          anonymous_token_hash: string;
          campaign_id: string | null;
          completed_at: string | null;
          created_at: string;
          current_stage: string;
          expires_at: string;
          guide_schema_version: string;
          id: string;
          last_saved_at: string | null;
          lead_id: string | null;
          next_action: string | null;
          organization_id: string;
          package_catalogue_version: string;
          progress_percent: number;
          scoring_version: string;
          service_preselection: string | null;
          session_reference: string;
          session_version: number;
          source_page: string | null;
          status: string;
          updated_at: string;
        };
        Insert: {
          anonymous_token_hash: string;
          campaign_id?: string | null;
          completed_at?: string | null;
          created_at?: string;
          current_stage?: string;
          expires_at: string;
          guide_schema_version: string;
          id?: string;
          last_saved_at?: string | null;
          lead_id?: string | null;
          next_action?: string | null;
          organization_id: string;
          package_catalogue_version: string;
          progress_percent?: number;
          scoring_version: string;
          service_preselection?: string | null;
          session_reference: string;
          session_version?: number;
          source_page?: string | null;
          status?: string;
          updated_at?: string;
        };
        Update: {
          anonymous_token_hash?: string;
          campaign_id?: string | null;
          completed_at?: string | null;
          created_at?: string;
          current_stage?: string;
          expires_at?: string;
          guide_schema_version?: string;
          id?: string;
          last_saved_at?: string | null;
          lead_id?: string | null;
          next_action?: string | null;
          organization_id?: string;
          package_catalogue_version?: string;
          progress_percent?: number;
          scoring_version?: string;
          service_preselection?: string | null;
          session_reference?: string;
          session_version?: number;
          source_page?: string | null;
          status?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_guide_sessions_lead_id_organization_id_fkey";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_guide_sessions_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      memory_profiles: {
        Row: {
          archived_at: string | null;
          archived_by: string | null;
          child_id: string | null;
          created_at: string;
          created_by: string;
          emotional_tags: string[];
          family_id: string;
          future_memory_notes: string | null;
          id: string;
          is_active: boolean;
          memory_goal: string | null;
          milestone_notes: string | null;
          organization_id: string;
          story_notes: string | null;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          archived_at?: string | null;
          archived_by?: string | null;
          child_id?: string | null;
          created_at?: string;
          created_by: string;
          emotional_tags?: string[];
          family_id: string;
          future_memory_notes?: string | null;
          id?: string;
          is_active?: boolean;
          memory_goal?: string | null;
          milestone_notes?: string | null;
          organization_id: string;
          story_notes?: string | null;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          archived_at?: string | null;
          archived_by?: string | null;
          child_id?: string | null;
          created_at?: string;
          created_by?: string;
          emotional_tags?: string[];
          family_id?: string;
          future_memory_notes?: string | null;
          id?: string;
          is_active?: boolean;
          memory_goal?: string | null;
          milestone_notes?: string | null;
          organization_id?: string;
          story_notes?: string | null;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "memory_profiles_archived_by_fk";
            columns: ["archived_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_profiles_child_fk";
            columns: ["child_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "children";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_profiles_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_profiles_family_fk";
            columns: ["family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "memory_profiles_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      notification_outbox: {
        Row: {
          attempt_count: number;
          channel: Database["public"]["Enums"]["communication_channel"];
          consultation_id: string;
          created_at: string;
          created_by: string;
          id: string;
          kind: Database["public"]["Enums"]["notification_kind"];
          last_attempt_at: string | null;
          last_error_code: string | null;
          lead_id: string;
          max_attempts: number;
          message_key: string;
          organization_id: string;
          provider_identifier: string | null;
          scheduled_for: string;
          status: Database["public"]["Enums"]["notification_status"];
          superseded_at: string | null;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          attempt_count?: number;
          channel?: Database["public"]["Enums"]["communication_channel"];
          consultation_id: string;
          created_at?: string;
          created_by: string;
          id?: string;
          kind: Database["public"]["Enums"]["notification_kind"];
          last_attempt_at?: string | null;
          last_error_code?: string | null;
          lead_id: string;
          max_attempts?: number;
          message_key: string;
          organization_id: string;
          provider_identifier?: string | null;
          scheduled_for: string;
          status?: Database["public"]["Enums"]["notification_status"];
          superseded_at?: string | null;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          attempt_count?: number;
          channel?: Database["public"]["Enums"]["communication_channel"];
          consultation_id?: string;
          created_at?: string;
          created_by?: string;
          id?: string;
          kind?: Database["public"]["Enums"]["notification_kind"];
          last_attempt_at?: string | null;
          last_error_code?: string | null;
          lead_id?: string;
          max_attempts?: number;
          message_key?: string;
          organization_id?: string;
          provider_identifier?: string | null;
          scheduled_for?: string;
          status?: Database["public"]["Enums"]["notification_status"];
          superseded_at?: string | null;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "notification_outbox_consultation_fk";
            columns: ["consultation_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "consultations";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "notification_outbox_created_by_fk";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "notification_outbox_lead_fk";
            columns: ["lead_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "notification_outbox_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "notification_outbox_updated_by_fk";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      organization_members: {
        Row: {
          created_at: string;
          created_by: string | null;
          display_name: string | null;
          email: string | null;
          exit_reason: string | null;
          exited_at: string | null;
          exited_by: string | null;
          id: string;
          joined_at: string;
          organization_id: string;
          phone: string | null;
          status: Database["public"]["Enums"]["member_status"];
          suspended_at: string | null;
          suspended_by: string | null;
          suspension_reason: string | null;
          updated_at: string;
          updated_by: string | null;
          user_id: string;
        };
        Insert: {
          created_at?: string;
          created_by?: string | null;
          display_name?: string | null;
          email?: string | null;
          exit_reason?: string | null;
          exited_at?: string | null;
          exited_by?: string | null;
          id?: string;
          joined_at?: string;
          organization_id: string;
          phone?: string | null;
          status?: Database["public"]["Enums"]["member_status"];
          suspended_at?: string | null;
          suspended_by?: string | null;
          suspension_reason?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          user_id: string;
        };
        Update: {
          created_at?: string;
          created_by?: string | null;
          display_name?: string | null;
          email?: string | null;
          exit_reason?: string | null;
          exited_at?: string | null;
          exited_by?: string | null;
          id?: string;
          joined_at?: string;
          organization_id?: string;
          phone?: string | null;
          status?: Database["public"]["Enums"]["member_status"];
          suspended_at?: string | null;
          suspended_by?: string | null;
          suspension_reason?: string | null;
          updated_at?: string;
          updated_by?: string | null;
          user_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "organization_members_created_by_fkey";
            columns: ["created_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "organization_members_exited_by_fkey";
            columns: ["exited_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "organization_members_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "organization_members_suspended_by_fkey";
            columns: ["suspended_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "organization_members_updated_by_fkey";
            columns: ["updated_by", "organization_id"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["id", "organization_id"];
          },
        ];
      };
      organization_settings: {
        Row: {
          brand_logo_url: string | null;
          brand_primary_color: string | null;
          broad_consent_reconfirmation_months: number;
          consent_link_expiry_days: number;
          created_at: string;
          date_format: string;
          delivery_link_expiry_days: number;
          locale: string;
          organization_id: string;
          philosophy_statement: string | null;
          proposal_link_expiry_days: number;
          updated_at: string;
          updated_by: string | null;
          week_starts_on: number;
        };
        Insert: {
          brand_logo_url?: string | null;
          brand_primary_color?: string | null;
          broad_consent_reconfirmation_months?: number;
          consent_link_expiry_days?: number;
          created_at?: string;
          date_format?: string;
          delivery_link_expiry_days?: number;
          locale?: string;
          organization_id: string;
          philosophy_statement?: string | null;
          proposal_link_expiry_days?: number;
          updated_at?: string;
          updated_by?: string | null;
          week_starts_on?: number;
        };
        Update: {
          brand_logo_url?: string | null;
          brand_primary_color?: string | null;
          broad_consent_reconfirmation_months?: number;
          consent_link_expiry_days?: number;
          created_at?: string;
          date_format?: string;
          delivery_link_expiry_days?: number;
          locale?: string;
          organization_id?: string;
          philosophy_statement?: string | null;
          proposal_link_expiry_days?: number;
          updated_at?: string;
          updated_by?: string | null;
          week_starts_on?: number;
        };
        Relationships: [
          {
            foreignKeyName: "organization_settings_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: true;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
        ];
      };
      organizations: {
        Row: {
          brand_prefix: string | null;
          created_at: string;
          created_by: string | null;
          currency_code: string;
          deleted_at: string | null;
          display_name: string;
          id: string;
          legal_name: string | null;
          slug: string;
          status: Database["public"]["Enums"]["organization_status"];
          timezone: string;
          updated_at: string;
          updated_by: string | null;
        };
        Insert: {
          brand_prefix?: string | null;
          created_at?: string;
          created_by?: string | null;
          currency_code?: string;
          deleted_at?: string | null;
          display_name: string;
          id?: string;
          legal_name?: string | null;
          slug: string;
          status?: Database["public"]["Enums"]["organization_status"];
          timezone?: string;
          updated_at?: string;
          updated_by?: string | null;
        };
        Update: {
          brand_prefix?: string | null;
          created_at?: string;
          created_by?: string | null;
          currency_code?: string;
          deleted_at?: string | null;
          display_name?: string;
          id?: string;
          legal_name?: string | null;
          slug?: string;
          status?: Database["public"]["Enums"]["organization_status"];
          timezone?: string;
          updated_at?: string;
          updated_by?: string | null;
        };
        Relationships: [];
      };
      permissions: {
        Row: {
          created_at: string;
          description: string | null;
          domain: string;
          id: string;
          key: string;
          label: string;
          requires_server_enforcement: boolean;
        };
        Insert: {
          created_at?: string;
          description?: string | null;
          domain: string;
          id?: string;
          key: string;
          label: string;
          requires_server_enforcement?: boolean;
        };
        Update: {
          created_at?: string;
          description?: string | null;
          domain?: string;
          id?: string;
          key?: string;
          label?: string;
          requires_server_enforcement?: boolean;
        };
        Relationships: [];
      };
      quotation_line_items: {
        Row: {
          catalogue_unit_price_inr: number | null;
          created_at: string;
          created_by: string;
          currency: string;
          description: string | null;
          id: string;
          item_key: string;
          item_name: string;
          line_total_inr: number;
          line_type: Database["public"]["Enums"]["quotation_line_type"];
          organization_id: string;
          pricing_source: Database["public"]["Enums"]["quotation_pricing_source"];
          quantity: number;
          quotation_id: string;
          quoted_unit_price_inr: number;
          sort_order: number;
          source_addon_version_id: string | null;
          source_package_version_id: string | null;
        };
        Insert: {
          catalogue_unit_price_inr?: number | null;
          created_at?: string;
          created_by: string;
          currency?: string;
          description?: string | null;
          id?: string;
          item_key: string;
          item_name: string;
          line_total_inr: number;
          line_type: Database["public"]["Enums"]["quotation_line_type"];
          organization_id: string;
          pricing_source: Database["public"]["Enums"]["quotation_pricing_source"];
          quantity?: number;
          quotation_id: string;
          quoted_unit_price_inr: number;
          sort_order?: number;
          source_addon_version_id?: string | null;
          source_package_version_id?: string | null;
        };
        Update: {
          catalogue_unit_price_inr?: number | null;
          created_at?: string;
          created_by?: string;
          currency?: string;
          description?: string | null;
          id?: string;
          item_key?: string;
          item_name?: string;
          line_total_inr?: number;
          line_type?: Database["public"]["Enums"]["quotation_line_type"];
          organization_id?: string;
          pricing_source?: Database["public"]["Enums"]["quotation_pricing_source"];
          quantity?: number;
          quotation_id?: string;
          quoted_unit_price_inr?: number;
          sort_order?: number;
          source_addon_version_id?: string | null;
          source_package_version_id?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: "quotation_line_items_addon_version_fkey";
            columns: ["organization_id", "source_addon_version_id"];
            isOneToOne: false;
            referencedRelation: "commercial_addon_versions";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "quotation_line_items_created_by_fkey";
            columns: ["organization_id", "created_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "quotation_line_items_package_version_fkey";
            columns: ["organization_id", "source_package_version_id"];
            isOneToOne: false;
            referencedRelation: "commercial_package_versions";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "quotation_line_items_quotation_fkey";
            columns: ["organization_id", "quotation_id"];
            isOneToOne: false;
            referencedRelation: "quotations";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      quotations: {
        Row: {
          accepted_at: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          currency: string;
          declined_at: string | null;
          discount_inr: number;
          expired_at: string | null;
          expires_at: string | null;
          family_id: string | null;
          id: string;
          lead_id: string | null;
          organization_id: string;
          quotation_reference: string;
          quoted_total_inr: number;
          ready_at: string | null;
          sent_at: string | null;
          status: Database["public"]["Enums"]["quotation_status"];
          subtotal_inr: number;
          superseded_at: string | null;
          supersedes_quotation_id: string | null;
          updated_at: string;
          updated_by: string;
        };
        Insert: {
          accepted_at?: string | null;
          branch_id?: string | null;
          created_at?: string;
          created_by: string;
          currency?: string;
          declined_at?: string | null;
          discount_inr?: number;
          expired_at?: string | null;
          expires_at?: string | null;
          family_id?: string | null;
          id?: string;
          lead_id?: string | null;
          organization_id: string;
          quotation_reference: string;
          quoted_total_inr?: number;
          ready_at?: string | null;
          sent_at?: string | null;
          status?: Database["public"]["Enums"]["quotation_status"];
          subtotal_inr?: number;
          superseded_at?: string | null;
          supersedes_quotation_id?: string | null;
          updated_at?: string;
          updated_by: string;
        };
        Update: {
          accepted_at?: string | null;
          branch_id?: string | null;
          created_at?: string;
          created_by?: string;
          currency?: string;
          declined_at?: string | null;
          discount_inr?: number;
          expired_at?: string | null;
          expires_at?: string | null;
          family_id?: string | null;
          id?: string;
          lead_id?: string | null;
          organization_id?: string;
          quotation_reference?: string;
          quoted_total_inr?: number;
          ready_at?: string | null;
          sent_at?: string | null;
          status?: Database["public"]["Enums"]["quotation_status"];
          subtotal_inr?: number;
          superseded_at?: string | null;
          supersedes_quotation_id?: string | null;
          updated_at?: string;
          updated_by?: string;
        };
        Relationships: [
          {
            foreignKeyName: "quotations_branch_fkey";
            columns: ["branch_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "branches";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "quotations_created_by_fkey";
            columns: ["organization_id", "created_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "quotations_family_fkey";
            columns: ["family_id", "organization_id"];
            isOneToOne: false;
            referencedRelation: "families";
            referencedColumns: ["id", "organization_id"];
          },
          {
            foreignKeyName: "quotations_lead_fkey";
            columns: ["organization_id", "lead_id"];
            isOneToOne: false;
            referencedRelation: "leads";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "quotations_organization_id_fkey";
            columns: ["organization_id"];
            isOneToOne: false;
            referencedRelation: "organizations";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "quotations_supersedes_quotation_fkey";
            columns: ["organization_id", "supersedes_quotation_id"];
            isOneToOne: false;
            referencedRelation: "quotations";
            referencedColumns: ["organization_id", "id"];
          },
          {
            foreignKeyName: "quotations_updated_by_fkey";
            columns: ["organization_id", "updated_by"];
            isOneToOne: false;
            referencedRelation: "organization_members";
            referencedColumns: ["organization_id", "id"];
          },
        ];
      };
      role_permissions: {
        Row: {
          created_at: string;
          id: string;
          permission_id: string;
          role_id: string;
        };
        Insert: {
          created_at?: string;
          id?: string;
          permission_id: string;
          role_id: string;
        };
        Update: {
          created_at?: string;
          id?: string;
          permission_id?: string;
          role_id?: string;
        };
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey";
            columns: ["permission_id"];
            isOneToOne: false;
            referencedRelation: "permissions";
            referencedColumns: ["id"];
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey";
            columns: ["role_id"];
            isOneToOne: false;
            referencedRelation: "roles";
            referencedColumns: ["id"];
          },
        ];
      };
      roles: {
        Row: {
          created_at: string;
          description: string | null;
          id: string;
          is_system_role: boolean;
          key: string;
          label: string;
          sort_order: number;
        };
        Insert: {
          created_at?: string;
          description?: string | null;
          id?: string;
          is_system_role?: boolean;
          key: string;
          label: string;
          sort_order?: number;
        };
        Update: {
          created_at?: string;
          description?: string | null;
          id?: string;
          is_system_role?: boolean;
          key?: string;
          label?: string;
          sort_order?: number;
        };
        Relationships: [];
      };
    };
    Views: {
      [_ in never]: never;
    };
    Functions: {
      accept_quotation: {
        Args: { p_quotation_id: string };
        Returns: {
          booking_reference: string;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          family_id: string | null;
          id: string;
          lead_id: string | null;
          organization_id: string;
          source_quotation_id: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "bookings";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      add_family_contact_channel: {
        Args: {
          p_channel_type: Database["public"]["Enums"]["contact_channel_type"];
          p_channel_value: string;
          p_family_contact_id: string;
          p_is_preferred?: boolean;
        };
        Returns: {
          channel_type: Database["public"]["Enums"]["contact_channel_type"];
          channel_value: string;
          created_at: string;
          created_by: string;
          deactivated_at: string | null;
          deactivated_by: string | null;
          family_contact_id: string;
          id: string;
          is_active: boolean;
          is_preferred: boolean;
          is_verified: boolean;
          normalized_value: string;
          organization_id: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "family_contact_channels";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      add_quotation_addon_line: {
        Args: {
          p_addon_version_id: string;
          p_override_unit_price_inr?: number;
          p_quantity?: number;
          p_quotation_id: string;
        };
        Returns: {
          catalogue_unit_price_inr: number | null;
          created_at: string;
          created_by: string;
          currency: string;
          description: string | null;
          id: string;
          item_key: string;
          item_name: string;
          line_total_inr: number;
          line_type: Database["public"]["Enums"]["quotation_line_type"];
          organization_id: string;
          pricing_source: Database["public"]["Enums"]["quotation_pricing_source"];
          quantity: number;
          quotation_id: string;
          quoted_unit_price_inr: number;
          sort_order: number;
          source_addon_version_id: string | null;
          source_package_version_id: string | null;
        };
        SetofOptions: {
          from: "*";
          to: "quotation_line_items";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      add_quotation_custom_line: {
        Args: {
          p_description: string;
          p_item_name: string;
          p_quantity: number;
          p_quotation_id: string;
          p_unit_price_inr: number;
        };
        Returns: {
          catalogue_unit_price_inr: number | null;
          created_at: string;
          created_by: string;
          currency: string;
          description: string | null;
          id: string;
          item_key: string;
          item_name: string;
          line_total_inr: number;
          line_type: Database["public"]["Enums"]["quotation_line_type"];
          organization_id: string;
          pricing_source: Database["public"]["Enums"]["quotation_pricing_source"];
          quantity: number;
          quotation_id: string;
          quoted_unit_price_inr: number;
          sort_order: number;
          source_addon_version_id: string | null;
          source_package_version_id: string | null;
        };
        SetofOptions: {
          from: "*";
          to: "quotation_line_items";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      add_quotation_package_line: {
        Args: {
          p_override_unit_price_inr?: number;
          p_package_version_id: string;
          p_quotation_id: string;
        };
        Returns: {
          catalogue_unit_price_inr: number | null;
          created_at: string;
          created_by: string;
          currency: string;
          description: string | null;
          id: string;
          item_key: string;
          item_name: string;
          line_total_inr: number;
          line_type: Database["public"]["Enums"]["quotation_line_type"];
          organization_id: string;
          pricing_source: Database["public"]["Enums"]["quotation_pricing_source"];
          quantity: number;
          quotation_id: string;
          quoted_unit_price_inr: number;
          sort_order: number;
          source_addon_version_id: string | null;
          source_package_version_id: string | null;
        };
        SetofOptions: {
          from: "*";
          to: "quotation_line_items";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      append_audit_event: {
        Args: {
          p_action_key: string;
          p_branch_id: string;
          p_entity_id: string;
          p_entity_type: string;
          p_is_sensitive: boolean;
          p_metadata: Json;
          p_new_values: Json;
          p_old_values: Json;
          p_organization_id: string;
          p_request_id: string;
          p_source: string;
        };
        Returns: {
          action_key: string;
          actor_member_id: string | null;
          actor_user_id: string | null;
          branch_id: string | null;
          entity_id: string | null;
          entity_type: string;
          id: string;
          is_sensitive: boolean;
          metadata: Json;
          new_values: Json | null;
          occurred_at: string;
          old_values: Json | null;
          organization_id: string;
          request_id: string | null;
          source: string;
        };
        SetofOptions: {
          from: "*";
          to: "audit_events";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      cancel_consultation: {
        Args: { p_consultation_id: string; p_reason: string };
        Returns: {
          branch_id: string | null;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          business_summary: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          client_shareable_recap: string | null;
          completed_at: string | null;
          confirmed_emotional_goal: string | null;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          lead_id: string;
          missed_at: string | null;
          next_step: string | null;
          objections: string | null;
          organization_id: string;
          outcome: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit: string | null;
          privacy_clarification: string | null;
          rescheduled_from_id: string | null;
          safety_review: string | null;
          schedule_version: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status: Database["public"]["Enums"]["consultation_status"];
          timezone: string;
          timing_fit: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "consultations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      cleanup_expired_memory_guide_sessions: {
        Args: { p_limit?: number };
        Returns: number;
      };
      complete_consultation: {
        Args: {
          p_business_summary: string;
          p_client_shareable_recap: string;
          p_confirmed_emotional_goal: string;
          p_consultation_id: string;
          p_next_action: string;
          p_next_action_due_at: string;
          p_next_step: string;
          p_objections: string;
          p_outcome: Database["public"]["Enums"]["consultation_outcome"];
          p_package_fit: string;
          p_privacy_clarification: string;
          p_private_note?: string;
          p_safety_review: string;
          p_timing_fit: string;
        };
        Returns: {
          branch_id: string | null;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          business_summary: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          client_shareable_recap: string | null;
          completed_at: string | null;
          confirmed_emotional_goal: string | null;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          lead_id: string;
          missed_at: string | null;
          next_step: string | null;
          objections: string | null;
          organization_id: string;
          outcome: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit: string | null;
          privacy_clarification: string | null;
          rescheduled_from_id: string | null;
          safety_review: string | null;
          schedule_version: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status: Database["public"]["Enums"]["consultation_status"];
          timezone: string;
          timing_fit: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "consultations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      convert_lead_to_family: {
        Args: {
          p_family_display_name?: string;
          p_family_sort_name?: string;
          p_lead_id: string;
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          assigned_owner_member_id: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          display_name: string;
          family_code: string;
          id: string;
          merged_at: string | null;
          merged_by: string | null;
          merged_into_family_id: string | null;
          organization_id: string;
          sort_name: string;
          status: Database["public"]["Enums"]["family_status"];
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "families";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_child: {
        Args: {
          p_birth_date: string;
          p_current_stage: Database["public"]["Enums"]["child_stage"];
          p_expected_due_date: string;
          p_family_id: string;
          p_first_name: string;
          p_privacy_restriction: Database["public"]["Enums"]["privacy_preference_type"];
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          birth_date: string | null;
          child_reference: string;
          created_at: string;
          created_by: string;
          current_stage: Database["public"]["Enums"]["child_stage"] | null;
          expected_due_date: string | null;
          family_id: string;
          first_name: string | null;
          id: string;
          organization_id: string;
          privacy_restriction: Database["public"]["Enums"]["privacy_preference_type"] | null;
          status: Database["public"]["Enums"]["child_status"];
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "children";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_consultation_blackout: {
        Args: { p_ends_at: string; p_safe_reason: string; p_starts_at: string };
        Returns: {
          created_at: string;
          created_by: string;
          ends_at: string;
          id: string;
          organization_id: string;
          owner_member_id: string | null;
          safe_reason: string;
          starts_at: string;
        };
        SetofOptions: {
          from: "*";
          to: "consultation_blackouts";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_family: {
        Args: {
          p_assigned_owner_member_id?: string;
          p_branch_id?: string;
          p_display_name: string;
          p_organization_id: string;
          p_sort_name: string;
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          assigned_owner_member_id: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          display_name: string;
          family_code: string;
          id: string;
          merged_at: string | null;
          merged_by: string | null;
          merged_into_family_id: string | null;
          organization_id: string;
          sort_name: string;
          status: Database["public"]["Enums"]["family_status"];
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "families";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_family_contact: {
        Args: {
          p_family_id: string;
          p_full_name: string;
          p_is_primary?: boolean;
          p_relationship_label: string;
        };
        Returns: {
          created_at: string;
          created_by: string;
          deactivated_at: string | null;
          deactivated_by: string | null;
          family_id: string;
          full_name: string;
          id: string;
          is_active: boolean;
          is_primary: boolean;
          organization_id: string;
          relationship_label: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "family_contacts";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_lead: {
        Args: {
          p_assigned_owner_member_id?: string;
          p_baby_age_or_pregnancy?: string;
          p_branch_id?: string;
          p_budget_comfort?: string;
          p_city?: string;
          p_email?: string;
          p_follow_up_at?: string;
          p_location_preference?: string;
          p_memory_goal?: string;
          p_organization_id: string;
          p_package_interest?: string;
          p_parent_name: string;
          p_phone?: string;
          p_preferred_date?: string;
          p_privacy_preference?: Database["public"]["Enums"]["privacy_preference_type"];
          p_session_type?: string;
          p_source: string;
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          assigned_owner_member_id: string | null;
          baby_age_or_pregnancy: string | null;
          branch_id: string | null;
          budget_comfort: string | null;
          city: string | null;
          converted_at: string | null;
          converted_by: string | null;
          converted_family_id: string | null;
          created_at: string;
          created_by: string;
          email: string | null;
          follow_up_at: string | null;
          id: string;
          internal_notes: string | null;
          lead_reference: string;
          location_preference: string | null;
          lost_reason: string | null;
          memory_goal: string | null;
          organization_id: string;
          package_interest: string | null;
          parent_name: string;
          phone: string | null;
          preferred_date: string | null;
          privacy_preference: Database["public"]["Enums"]["privacy_preference_type"] | null;
          session_type: string | null;
          source: string;
          status: Database["public"]["Enums"]["lead_status"];
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "leads";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_lead_sla_override: {
        Args: {
          p_expires_at?: string;
          p_lead_id: string;
          p_reason: string;
          p_review_at?: string;
          p_sla_key: string;
        };
        Returns: {
          created_at: string;
          created_by: string;
          expires_at: string | null;
          id: string;
          lead_id: string;
          organization_id: string;
          reason: string;
          review_at: string | null;
          sla_key: string;
        };
        SetofOptions: {
          from: "*";
          to: "lead_sla_overrides";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_lead_task: {
        Args: {
          p_due_at?: string;
          p_idempotency_key?: string;
          p_lead_id: string;
          p_owner_member_id?: string;
          p_priority?: Database["public"]["Enums"]["lead_task_priority"];
          p_safe_summary?: string;
          p_source?: string;
          p_task_type: Database["public"]["Enums"]["lead_task_type"];
          p_title: string;
        };
        Returns: {
          branch_id: string | null;
          completed_at: string | null;
          completed_by: string | null;
          created_at: string;
          created_by: string;
          due_at: string | null;
          escalated_at: string | null;
          id: string;
          idempotency_key: string | null;
          lead_id: string;
          organization_id: string;
          owner_member_id: string | null;
          priority: Database["public"]["Enums"]["lead_task_priority"];
          safe_summary: string | null;
          snoozed_until: string | null;
          source: string;
          status: Database["public"]["Enums"]["lead_task_status"];
          task_type: Database["public"]["Enums"]["lead_task_type"];
          title: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "lead_tasks";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      create_memory_guide_resume: {
        Args: { p_access_token: string };
        Returns: {
          resume_expires_at: string;
          resume_token: string;
        }[];
      };
      create_quotation: {
        Args: {
          p_branch_id?: string;
          p_expires_at?: string;
          p_family_id?: string;
          p_lead_id?: string;
          p_organization_id: string;
          p_supersedes_quotation_id?: string;
        };
        Returns: {
          accepted_at: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          currency: string;
          declined_at: string | null;
          discount_inr: number;
          expired_at: string | null;
          expires_at: string | null;
          family_id: string | null;
          id: string;
          lead_id: string | null;
          organization_id: string;
          quotation_reference: string;
          quoted_total_inr: number;
          ready_at: string | null;
          sent_at: string | null;
          status: Database["public"]["Enums"]["quotation_status"];
          subtotal_inr: number;
          superseded_at: string | null;
          supersedes_quotation_id: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "quotations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      current_organization_member: {
        Args: { p_organization_id: string };
        Returns: string;
      };
      current_user_organization_ids: { Args: never; Returns: string[] };
      effective_permissions: {
        Args: { p_branch_id?: string; p_organization_id: string };
        Returns: string[];
      };
      get_consultation_private_notes: {
        Args: { p_consultation_id: string };
        Returns: {
          consultation_id: string;
          created_at: string;
          created_by: string;
          id: string;
          note_text: string;
        }[];
      };
      get_memory_guide_sensitive_answers: {
        Args: { p_session_id: string };
        Returns: Json;
      };
      get_memory_guide_state: {
        Args: { p_access_token: string };
        Returns: Json;
      };
      has_branch_scope: {
        Args: { p_branch_id: string; p_organization_id: string };
        Returns: boolean;
      };
      has_permission: {
        Args: {
          p_branch_id?: string;
          p_organization_id: string;
          p_permission_key: string;
        };
        Returns: boolean;
      };
      lead_sla_snapshot: {
        Args: { p_lead_id: string };
        Returns: {
          detail: string;
          elapsed_business_minutes: number;
          override_until: string;
          sla_key: string;
          status: string;
          threshold_business_minutes: number;
        }[];
      };
      list_memory_guide_review_center: {
        Args: { p_organization_id: string };
        Returns: Json;
      };
      lsh_assert_audit_payload_safe: {
        Args: { p_label: string; p_payload: Json };
        Returns: undefined;
      };
      lsh_assert_founder_coverage: {
        Args: { p_organization_id: string };
        Returns: undefined;
      };
      lsh_bootstrap_canonical_founder: {
        Args: { p_expected_email: string; p_user_id: string };
        Returns: {
          activated: boolean;
          grant_created: boolean;
          grant_id: string;
          member_created: boolean;
          member_id: string;
          organization_id: string;
          user_id: string;
        }[];
      };
      lsh_business_minutes_between: {
        Args: { p_end: string; p_organization_id: string; p_start: string };
        Returns: number;
      };
      lsh_consultation_slot_is_available: {
        Args: {
          p_ends_at: string;
          p_exclude_consultation_id?: string;
          p_organization_id: string;
          p_owner_member_id: string;
          p_starts_at: string;
        };
        Returns: boolean;
      };
      lsh_family_code_suffix: { Args: never; Returns: string };
      lsh_guide_add_business_minutes: {
        Args: { p_from: string; p_minutes: number; p_organization_id: string };
        Returns: string;
      };
      lsh_guide_answer_matches: {
        Args: {
          p_field_key: string;
          p_match_value: string;
          p_session_id: string;
        };
        Returns: boolean;
      };
      lsh_guide_answer_text: {
        Args: { p_field_key: string; p_session_id: string };
        Returns: string;
      };
      lsh_guide_assert_safe_analytics: {
        Args: { p_properties: Json };
        Returns: undefined;
      };
      lsh_guide_create_review: {
        Args: {
          p_decision_id: string;
          p_review_type: string;
          p_session: Database["public"]["Tables"]["memory_guide_sessions"]["Row"];
          p_sla_minutes: number;
          p_trigger_code: string;
          p_visibility: string;
        };
        Returns: undefined;
      };
      lsh_guide_hash_token: { Args: { p_token: string }; Returns: string };
      lsh_guide_new_token: { Args: never; Returns: string };
      lsh_guide_organization_active: {
        Args: { p_organization_id: string };
        Returns: boolean;
      };
      lsh_guide_progress: { Args: { p_stage: string }; Returns: number };
      lsh_guide_public_decision: {
        Args: { p_decision_id: string };
        Returns: Json;
      };
      lsh_guide_record_event: {
        Args: {
          p_event_key: string;
          p_organization_id: string;
          p_properties?: Json;
          p_session_id: string;
        };
        Returns: undefined;
      };
      lsh_guide_review_owner: {
        Args: { p_organization_id: string; p_restricted?: boolean };
        Returns: string;
      };
      lsh_guide_session_event: {
        Args: {
          p_event_type: string;
          p_organization_id: string;
          p_safe_metadata?: Json;
          p_session_id: string;
          p_session_version: number;
        };
        Returns: undefined;
      };
      lsh_queue_consultation_notifications: {
        Args: { p_actor: string; p_consultation_id: string };
        Returns: undefined;
      };
      lsh_refresh_quotation_totals: {
        Args: { p_organization_id: string; p_quotation_id: string };
        Returns: undefined;
      };
      lsh_sprint6_activity: {
        Args: {
          p_branch_id: string;
          p_entity_id: string;
          p_entity_type: string;
          p_event_type: string;
          p_lead_id: string;
          p_metadata?: Json;
          p_organization_id: string;
          p_summary: string;
        };
        Returns: undefined;
      };
      lsh_sprint6_actor: {
        Args: {
          p_branch_id?: string;
          p_organization_id: string;
          p_permission_key: string;
        };
        Returns: string;
      };
      lsh_sprint6_audit: {
        Args: {
          p_action_key: string;
          p_branch_id: string;
          p_entity_id: string;
          p_entity_type: string;
          p_is_sensitive: boolean;
          p_metadata?: Json;
          p_new_values?: Json;
          p_old_values?: Json;
          p_organization_id: string;
        };
        Returns: undefined;
      };
      mark_consultation_missed: {
        Args: { p_consultation_id: string };
        Returns: {
          branch_id: string | null;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          business_summary: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          client_shareable_recap: string | null;
          completed_at: string | null;
          confirmed_emotional_goal: string | null;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          lead_id: string;
          missed_at: string | null;
          next_step: string | null;
          objections: string | null;
          organization_id: string;
          outcome: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit: string | null;
          privacy_clarification: string | null;
          rescheduled_from_id: string | null;
          safety_review: string | null;
          schedule_version: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status: Database["public"]["Enums"]["consultation_status"];
          timezone: string;
          timing_fit: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "consultations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      my_membership: {
        Args: { p_organization_id: string };
        Returns: {
          assigned_role_keys: string[];
          assigned_role_labels: string[];
          branch_names: string[];
          display_name: string;
          email: string;
          joined_at: string;
          member_status: Database["public"]["Enums"]["member_status"];
          organization_id: string;
          organization_name: string;
          organization_wide: boolean;
          phone: string;
        }[];
      };
      process_memory_guide_decision: {
        Args: { p_access_token: string; p_expected_version: number };
        Returns: Json;
      };
      record_lead_communication: {
        Args: {
          p_business_purpose: string;
          p_channel: Database["public"]["Enums"]["communication_channel"];
          p_consultation_id?: string;
          p_direction: Database["public"]["Enums"]["communication_direction"];
          p_lead_id: string;
          p_occurred_at?: string;
          p_provider_identifier?: string;
          p_safe_summary: string;
          p_status: Database["public"]["Enums"]["communication_status"];
          p_template_key?: string;
          p_template_version?: string;
        };
        Returns: {
          branch_id: string | null;
          business_purpose: string;
          channel: Database["public"]["Enums"]["communication_channel"];
          consultation_id: string | null;
          created_at: string;
          created_by: string;
          direction: Database["public"]["Enums"]["communication_direction"];
          id: string;
          lead_id: string;
          occurred_at: string;
          organization_id: string;
          owner_member_id: string | null;
          provider_identifier: string | null;
          safe_summary: string;
          status: Database["public"]["Enums"]["communication_status"];
          template_key: string | null;
          template_version: string | null;
        };
        SetofOptions: {
          from: "*";
          to: "lead_communications";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      record_memory_guide_next_action: {
        Args: { p_access_token: string; p_next_action: string };
        Returns: boolean;
      };
      remove_quotation_line: {
        Args: { p_line_item_id: string };
        Returns: undefined;
      };
      reschedule_consultation: {
        Args: {
          p_consultation_id: string;
          p_duration_minutes?: number;
          p_new_starts_at: string;
          p_reason: string;
        };
        Returns: {
          branch_id: string | null;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          business_summary: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          client_shareable_recap: string | null;
          completed_at: string | null;
          confirmed_emotional_goal: string | null;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          lead_id: string;
          missed_at: string | null;
          next_step: string | null;
          objections: string | null;
          organization_id: string;
          outcome: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit: string | null;
          privacy_clarification: string | null;
          rescheduled_from_id: string | null;
          safety_review: string | null;
          schedule_version: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status: Database["public"]["Enums"]["consultation_status"];
          timezone: string;
          timing_fit: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "consultations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      resume_memory_guide_session: {
        Args: { p_resume_token: string };
        Returns: {
          access_token: string;
          error_code: string;
          ok: boolean;
          session_version: number;
        }[];
      };
      retry_notification: {
        Args: { p_notification_id: string };
        Returns: {
          attempt_count: number;
          channel: Database["public"]["Enums"]["communication_channel"];
          consultation_id: string;
          created_at: string;
          created_by: string;
          id: string;
          kind: Database["public"]["Enums"]["notification_kind"];
          last_attempt_at: string | null;
          last_error_code: string | null;
          lead_id: string;
          max_attempts: number;
          message_key: string;
          organization_id: string;
          provider_identifier: string | null;
          scheduled_for: string;
          status: Database["public"]["Enums"]["notification_status"];
          superseded_at: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "notification_outbox";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      role_catalogue: {
        Args: never;
        Returns: {
          description: string;
          key: string;
          label: string;
          sort_order: number;
        }[];
      };
      save_memory_guide_answers: {
        Args: {
          p_access_token: string;
          p_answers: Json;
          p_expected_version: number;
          p_stage_id: string;
        };
        Returns: {
          current_stage: string;
          last_saved_at: string;
          progress_percent: number;
          session_version: number;
        }[];
      };
      save_memory_guide_contact: {
        Args: {
          p_access_token: string;
          p_contact_email: string;
          p_contact_name: string;
          p_contact_permission: boolean;
          p_contact_phone: string;
          p_preferred_contact: string;
        };
        Returns: boolean;
      };
      schedule_consultation: {
        Args: {
          p_duration_minutes?: number;
          p_lead_id: string;
          p_owner_member_id?: string;
          p_starts_at: string;
          p_timezone?: string;
        };
        Returns: {
          branch_id: string | null;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          business_summary: string | null;
          cancellation_reason: string | null;
          cancelled_at: string | null;
          client_shareable_recap: string | null;
          completed_at: string | null;
          confirmed_emotional_goal: string | null;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          lead_id: string;
          missed_at: string | null;
          next_step: string | null;
          objections: string | null;
          organization_id: string;
          outcome: Database["public"]["Enums"]["consultation_outcome"] | null;
          owner_member_id: string;
          package_fit: string | null;
          privacy_clarification: string | null;
          rescheduled_from_id: string | null;
          safety_review: string | null;
          schedule_version: number;
          scheduled_end_at: string;
          scheduled_start_at: string;
          status: Database["public"]["Enums"]["consultation_status"];
          timezone: string;
          timing_fit: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "consultations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      set_lead_next_action: {
        Args: {
          p_action_text: string;
          p_due_at: string;
          p_exception_reason?: string;
          p_lead_id: string;
          p_source?: string;
        };
        Returns: {
          action_text: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          due_at: string | null;
          exception_reason: string | null;
          id: string;
          lead_id: string;
          organization_id: string;
          source: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "lead_next_actions";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      set_quotation_discount: {
        Args: { p_discount_inr: number; p_quotation_id: string };
        Returns: {
          accepted_at: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          currency: string;
          declined_at: string | null;
          discount_inr: number;
          expired_at: string | null;
          expires_at: string | null;
          family_id: string | null;
          id: string;
          lead_id: string | null;
          organization_id: string;
          quotation_reference: string;
          quoted_total_inr: number;
          ready_at: string | null;
          sent_at: string | null;
          status: Database["public"]["Enums"]["quotation_status"];
          subtotal_inr: number;
          superseded_at: string | null;
          supersedes_quotation_id: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "quotations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      start_memory_guide: {
        Args: {
          p_campaign_id?: string;
          p_organization_id: string;
          p_service_preselection?: string;
          p_source_page?: string;
        };
        Returns: {
          access_token: string;
          current_stage: string;
          expires_at: string;
          progress_percent: number;
          session_id: string;
          session_reference: string;
          session_version: number;
        }[];
      };
      sync_memory_guide_to_crm: {
        Args: { p_session_id: string };
        Returns: Json;
      };
      team_directory: {
        Args: { p_organization_id: string };
        Returns: {
          assigned_branch_names: string[];
          assigned_role_keys: string[];
          assigned_role_labels: string[];
          display_name: string;
          email: string;
          joined_at: string;
          member_status: Database["public"]["Enums"]["member_status"];
          organization_wide: boolean;
          phone: string;
        }[];
      };
      transition_quotation: {
        Args: {
          p_quotation_id: string;
          p_target_status: Database["public"]["Enums"]["quotation_status"];
        };
        Returns: {
          accepted_at: string | null;
          branch_id: string | null;
          created_at: string;
          created_by: string;
          currency: string;
          declined_at: string | null;
          discount_inr: number;
          expired_at: string | null;
          expires_at: string | null;
          family_id: string | null;
          id: string;
          lead_id: string | null;
          organization_id: string;
          quotation_reference: string;
          quoted_total_inr: number;
          ready_at: string | null;
          sent_at: string | null;
          status: Database["public"]["Enums"]["quotation_status"];
          subtotal_inr: number;
          superseded_at: string | null;
          supersedes_quotation_id: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "quotations";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      update_child: {
        Args: {
          p_birth_date: string;
          p_child_id: string;
          p_current_stage: Database["public"]["Enums"]["child_stage"];
          p_expected_due_date: string;
          p_first_name: string;
          p_privacy_restriction: Database["public"]["Enums"]["privacy_preference_type"];
          p_status: Database["public"]["Enums"]["child_status"];
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          birth_date: string | null;
          child_reference: string;
          created_at: string;
          created_by: string;
          current_stage: Database["public"]["Enums"]["child_stage"] | null;
          expected_due_date: string | null;
          family_id: string;
          first_name: string | null;
          id: string;
          organization_id: string;
          privacy_restriction: Database["public"]["Enums"]["privacy_preference_type"] | null;
          status: Database["public"]["Enums"]["child_status"];
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "children";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      update_family_communication_controls: {
        Args: {
          p_contactability_status: Database["public"]["Enums"]["contactability_status"];
          p_do_not_contact: boolean;
          p_do_not_contact_reason: string;
          p_family_id: string;
          p_preferred_channel_type: Database["public"]["Enums"]["contact_channel_type"];
          p_quiet_hours_end: string;
          p_quiet_hours_start: string;
        };
        Returns: {
          contactability_status: Database["public"]["Enums"]["contactability_status"];
          created_at: string;
          created_by: string;
          do_not_contact: boolean;
          do_not_contact_reason: string | null;
          family_id: string;
          id: string;
          notes: string | null;
          organization_id: string;
          preferred_channel_type: Database["public"]["Enums"]["contact_channel_type"] | null;
          quiet_hours_end: string | null;
          quiet_hours_start: string | null;
          timezone: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "family_communication_controls";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      update_lead: {
        Args: {
          p_assigned_owner_member_id?: string;
          p_baby_age_or_pregnancy?: string;
          p_branch_id?: string;
          p_budget_comfort?: string;
          p_city?: string;
          p_email?: string;
          p_follow_up_at?: string;
          p_lead_id: string;
          p_location_preference?: string;
          p_lost_reason?: string;
          p_memory_goal?: string;
          p_package_interest?: string;
          p_parent_name: string;
          p_phone?: string;
          p_preferred_date?: string;
          p_privacy_preference?: Database["public"]["Enums"]["privacy_preference_type"];
          p_session_type?: string;
          p_source: string;
          p_status?: Database["public"]["Enums"]["lead_status"];
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          assigned_owner_member_id: string | null;
          baby_age_or_pregnancy: string | null;
          branch_id: string | null;
          budget_comfort: string | null;
          city: string | null;
          converted_at: string | null;
          converted_by: string | null;
          converted_family_id: string | null;
          created_at: string;
          created_by: string;
          email: string | null;
          follow_up_at: string | null;
          id: string;
          internal_notes: string | null;
          lead_reference: string;
          location_preference: string | null;
          lost_reason: string | null;
          memory_goal: string | null;
          organization_id: string;
          package_interest: string | null;
          parent_name: string;
          phone: string | null;
          preferred_date: string | null;
          privacy_preference: Database["public"]["Enums"]["privacy_preference_type"] | null;
          session_type: string | null;
          source: string;
          status: Database["public"]["Enums"]["lead_status"];
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "leads";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      update_lead_task: {
        Args: {
          p_due_at: string;
          p_escalate?: boolean;
          p_owner_member_id?: string;
          p_priority: Database["public"]["Enums"]["lead_task_priority"];
          p_snoozed_until?: string;
          p_status: Database["public"]["Enums"]["lead_task_status"];
          p_task_id: string;
        };
        Returns: {
          branch_id: string | null;
          completed_at: string | null;
          completed_by: string | null;
          created_at: string;
          created_by: string;
          due_at: string | null;
          escalated_at: string | null;
          id: string;
          idempotency_key: string | null;
          lead_id: string;
          organization_id: string;
          owner_member_id: string | null;
          priority: Database["public"]["Enums"]["lead_task_priority"];
          safe_summary: string | null;
          snoozed_until: string | null;
          source: string;
          status: Database["public"]["Enums"]["lead_task_status"];
          task_type: Database["public"]["Enums"]["lead_task_type"];
          title: string;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "lead_tasks";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      update_memory_guide_review: {
        Args: { p_review_id: string; p_status: string };
        Returns: Json;
      };
      upsert_consultation_availability: {
        Args: {
          p_booking_horizon_days?: number;
          p_buffer_after_minutes?: number;
          p_buffer_before_minutes?: number;
          p_capacity?: number;
          p_duration_minutes?: number;
          p_is_bookable?: boolean;
          p_local_end: string;
          p_local_start: string;
          p_minimum_notice_minutes?: number;
          p_timezone?: string;
          p_weekday: number;
        };
        Returns: {
          booking_horizon_days: number;
          buffer_after_minutes: number;
          buffer_before_minutes: number;
          capacity: number;
          created_at: string;
          created_by: string;
          duration_minutes: number;
          id: string;
          is_bookable: boolean;
          local_end: string;
          local_start: string;
          minimum_notice_minutes: number;
          organization_id: string;
          owner_member_id: string;
          timezone: string;
          updated_at: string;
          updated_by: string;
          weekday: number;
        };
        SetofOptions: {
          from: "*";
          to: "consultation_availability_windows";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
      upsert_memory_profile: {
        Args: {
          p_child_id: string;
          p_emotional_tags: string[];
          p_family_id: string;
          p_future_memory_notes: string;
          p_memory_goal: string;
          p_milestone_notes: string;
          p_story_notes: string;
        };
        Returns: {
          archived_at: string | null;
          archived_by: string | null;
          child_id: string | null;
          created_at: string;
          created_by: string;
          emotional_tags: string[];
          family_id: string;
          future_memory_notes: string | null;
          id: string;
          is_active: boolean;
          memory_goal: string | null;
          milestone_notes: string | null;
          organization_id: string;
          story_notes: string | null;
          updated_at: string;
          updated_by: string;
        };
        SetofOptions: {
          from: "*";
          to: "memory_profiles";
          isOneToOne: true;
          isSetofReturn: false;
        };
      };
    };
    Enums: {
      branch_status: "active" | "inactive" | "archived";
      child_stage: "expected" | "newborn" | "baby" | "sitter" | "toddler" | "child";
      child_status: "active" | "archived";
      commercial_package_status: "active" | "inactive" | "retired";
      commercial_package_tier: "bronze" | "gold" | "diamond" | "emerald";
      commercial_pricing_type: "fixed_amount" | "percentage" | "variable";
      commercial_version_approval_status: "draft" | "approved" | "retired";
      communication_channel:
        "whatsapp" | "email" | "sms" | "phone" | "portal" | "in_person" | "manual";
      communication_direction: "inbound" | "outbound" | "internal";
      communication_status:
        "queued" | "accepted" | "delivered" | "read" | "failed" | "unknown" | "manual_confirmed";
      consultation_outcome:
        | "quote_ready"
        | "needs_follow_up"
        | "future_milestone"
        | "not_a_fit"
        | "no_response"
        | "privacy_review"
        | "safety_review"
        | "reschedule_requested";
      consultation_status:
        | "pending_confirmation"
        | "tentative"
        | "scheduled"
        | "completed"
        | "missed"
        | "cancelled"
        | "rescheduled";
      contact_channel_type: "phone" | "email" | "whatsapp" | "other";
      contactability_status: "contactable" | "limited" | "do_not_contact";
      family_status: "active" | "inactive" | "archived" | "merged";
      lead_status:
        | "new_inquiry"
        | "contacted"
        | "qualified"
        | "consultation_scheduled"
        | "quote_ready"
        | "quote_sent"
        | "follow_up_needed"
        | "converted"
        | "lost"
        | "archived";
      lead_task_priority: "low" | "normal" | "high" | "urgent";
      lead_task_status: "open" | "in_progress" | "snoozed" | "completed" | "cancelled";
      lead_task_type:
        | "first_response"
        | "follow_up"
        | "consultation"
        | "quote"
        | "privacy_review"
        | "safety_review"
        | "stale_lead"
        | "reminder_recovery"
        | "assignment"
        | "document"
        | "internal_review"
        | "other";
      member_status: "active" | "suspended" | "left" | "revoked";
      notification_kind:
        | "confirmation"
        | "reminder_24h"
        | "reminder_2h"
        | "reschedule"
        | "cancellation"
        | "missed_follow_up"
        | "internal_upcoming";
      notification_status:
        "queued" | "processing" | "sent" | "failed" | "superseded" | "manual_action_required";
      organization_status: "active" | "suspended" | "archived";
      privacy_preference_type:
        | "full_privacy"
        | "selective_sharing"
        | "anonymous_sharing"
        | "portfolio_release"
        | "decide_later";
      quotation_line_type: "package" | "addon" | "custom";
      quotation_pricing_source: "catalogue" | "approved_offer" | "authorized_override";
      quotation_status:
        "draft" | "ready" | "sent" | "accepted" | "declined" | "expired" | "superseded";
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
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
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
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
    keyof DefaultSchema["Tables"] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
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
    keyof DefaultSchema["Enums"] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never;

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema["CompositeTypes"] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals;
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals;
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never;

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      branch_status: ["active", "inactive", "archived"],
      child_stage: ["expected", "newborn", "baby", "sitter", "toddler", "child"],
      child_status: ["active", "archived"],
      commercial_package_status: ["active", "inactive", "retired"],
      commercial_package_tier: ["bronze", "gold", "diamond", "emerald"],
      commercial_pricing_type: ["fixed_amount", "percentage", "variable"],
      commercial_version_approval_status: ["draft", "approved", "retired"],
      communication_channel: ["whatsapp", "email", "sms", "phone", "portal", "in_person", "manual"],
      communication_direction: ["inbound", "outbound", "internal"],
      communication_status: [
        "queued",
        "accepted",
        "delivered",
        "read",
        "failed",
        "unknown",
        "manual_confirmed",
      ],
      consultation_outcome: [
        "quote_ready",
        "needs_follow_up",
        "future_milestone",
        "not_a_fit",
        "no_response",
        "privacy_review",
        "safety_review",
        "reschedule_requested",
      ],
      consultation_status: [
        "pending_confirmation",
        "tentative",
        "scheduled",
        "completed",
        "missed",
        "cancelled",
        "rescheduled",
      ],
      contact_channel_type: ["phone", "email", "whatsapp", "other"],
      contactability_status: ["contactable", "limited", "do_not_contact"],
      family_status: ["active", "inactive", "archived", "merged"],
      lead_status: [
        "new_inquiry",
        "contacted",
        "qualified",
        "consultation_scheduled",
        "quote_ready",
        "quote_sent",
        "follow_up_needed",
        "converted",
        "lost",
        "archived",
      ],
      lead_task_priority: ["low", "normal", "high", "urgent"],
      lead_task_status: ["open", "in_progress", "snoozed", "completed", "cancelled"],
      lead_task_type: [
        "first_response",
        "follow_up",
        "consultation",
        "quote",
        "privacy_review",
        "safety_review",
        "stale_lead",
        "reminder_recovery",
        "assignment",
        "document",
        "internal_review",
        "other",
      ],
      member_status: ["active", "suspended", "left", "revoked"],
      notification_kind: [
        "confirmation",
        "reminder_24h",
        "reminder_2h",
        "reschedule",
        "cancellation",
        "missed_follow_up",
        "internal_upcoming",
      ],
      notification_status: [
        "queued",
        "processing",
        "sent",
        "failed",
        "superseded",
        "manual_action_required",
      ],
      organization_status: ["active", "suspended", "archived"],
      privacy_preference_type: [
        "full_privacy",
        "selective_sharing",
        "anonymous_sharing",
        "portfolio_release",
        "decide_later",
      ],
      quotation_line_type: ["package", "addon", "custom"],
      quotation_pricing_source: ["catalogue", "approved_offer", "authorized_override"],
      quotation_status: ["draft", "ready", "sent", "accepted", "declined", "expired", "superseded"],
    },
  },
} as const;
