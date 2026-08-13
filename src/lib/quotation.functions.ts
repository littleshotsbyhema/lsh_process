import { createServerFn } from "@tanstack/react-start";
import { z } from "zod";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Database } from "@/integrations/supabase/types";
import { ORGANIZATION_ID } from "@/lib/session";

export type QuotationRow = Database["public"]["Tables"]["quotations"]["Row"];

export type QuotationLineItemRow = Database["public"]["Tables"]["quotation_line_items"]["Row"];

export type BookingRow = Database["public"]["Tables"]["bookings"]["Row"];

export type QuoteSubject = {
  subjectType: "lead" | "family";
  id: string;
  reference: string;
  displayName: string;
  sessionType: string | null;
  branchId: string | null;
  status: string;
};

export type QuotationWorkspaceData = {
  subjects: QuoteSubject[];
  quotations: QuotationRow[];
  lineItems: QuotationLineItemRow[];
  bookings: BookingRow[];
};

const createQuotationSchema = z.object({
  subjectType: z.enum(["lead", "family"]),
  subjectId: z.string().uuid(),
});

const addPackageLineSchema = z.object({
  quotationId: z.string().uuid(),
  packageVersionId: z.string().uuid(),
});

const addAddonLineSchema = z.object({
  quotationId: z.string().uuid(),
  addonVersionId: z.string().uuid(),
  quantity: z.number().int().min(1).max(100),
});

const removeLineSchema = z.object({
  lineItemId: z.string().uuid(),
});

const transitionQuotationSchema = z.object({
  quotationId: z.string().uuid(),
  targetStatus: z.enum(["draft", "ready", "sent"]),
});

const acceptQuotationSchema = z.object({
  quotationId: z.string().uuid(),
});

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

export const listQuotationWorkspace = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<QuotationWorkspaceData> => {
    const [leadsResult, familiesResult, quotationsResult, bookingsResult] = await Promise.all([
      context.supabase
        .from("leads")
        .select(
          "id, branch_id, lead_reference, parent_name, session_type, status, converted_family_id, archived_at",
        )
        .eq("organization_id", ORGANIZATION_ID)
        .is("archived_at", null)
        .order("created_at", {
          ascending: false,
        }),

      context.supabase
        .from("families")
        .select("id, branch_id, family_code, display_name, status, archived_at")
        .eq("organization_id", ORGANIZATION_ID)
        .is("archived_at", null)
        .order("created_at", {
          ascending: false,
        }),

      context.supabase
        .from("quotations")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .order("created_at", {
          ascending: false,
        })
        .limit(100),

      context.supabase
        .from("bookings")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .order("created_at", {
          ascending: false,
        })
        .limit(100),
    ]);

    throwIfError(leadsResult.error);
    throwIfError(familiesResult.error);
    throwIfError(quotationsResult.error);
    throwIfError(bookingsResult.error);

    const leadSubjects: QuoteSubject[] = (leadsResult.data ?? [])
      .filter(
        (lead) =>
          lead.status !== "lost" && lead.status !== "converted" && !lead.converted_family_id,
      )
      .map((lead) => ({
        subjectType: "lead",
        id: lead.id,
        reference: lead.lead_reference,
        displayName: lead.parent_name,
        sessionType: lead.session_type,
        branchId: lead.branch_id,
        status: lead.status,
      }));

    const familySubjects: QuoteSubject[] = (familiesResult.data ?? []).map((family) => ({
      subjectType: "family",
      id: family.id,
      reference: family.family_code,
      displayName: family.display_name,
      sessionType: null,
      branchId: family.branch_id,
      status: family.status,
    }));

    const quotations = quotationsResult.data ?? [];
    const quotationIds = quotations.map((quotation) => quotation.id);

    let lineItems: QuotationLineItemRow[] = [];

    if (quotationIds.length > 0) {
      const lineItemsResult = await context.supabase
        .from("quotation_line_items")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("quotation_id", quotationIds)
        .order("sort_order", {
          ascending: true,
        })
        .order("created_at", {
          ascending: true,
        });

      throwIfError(lineItemsResult.error);

      lineItems = lineItemsResult.data ?? [];
    }

    return {
      subjects: [...leadSubjects, ...familySubjects],
      quotations,
      lineItems,
      bookings: bookingsResult.data ?? [],
    };
  });

export const createQuotationDraft = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(createQuotationSchema)
  .handler(async ({ context, data }): Promise<QuotationRow> => {
    let branchId: string | null = null;

    const args: Database["public"]["Functions"]["create_quotation"]["Args"] = {
      p_organization_id: ORGANIZATION_ID,
    };

    if (data.subjectType === "lead") {
      const subjectResult = await context.supabase
        .from("leads")
        .select("id, branch_id, status, converted_family_id, archived_at")
        .eq("organization_id", ORGANIZATION_ID)
        .eq("id", data.subjectId)
        .single();

      throwIfError(subjectResult.error);

      const subject = subjectResult.data;

      if (
        !subject ||
        subject.archived_at ||
        subject.status === "lost" ||
        subject.status === "converted" ||
        subject.converted_family_id
      ) {
        throw new Error("This inquiry is no longer available for a new quotation.");
      }

      branchId = subject.branch_id;
      args.p_lead_id = subject.id;
    } else {
      const subjectResult = await context.supabase
        .from("families")
        .select("id, branch_id, archived_at")
        .eq("organization_id", ORGANIZATION_ID)
        .eq("id", data.subjectId)
        .single();

      throwIfError(subjectResult.error);

      const subject = subjectResult.data;

      if (!subject || subject.archived_at) {
        throw new Error("This family is no longer available for a new quotation.");
      }

      branchId = subject.branch_id;
      args.p_family_id = subject.id;
    }

    if (branchId) {
      args.p_branch_id = branchId;
    }

    const quotationResult = await context.supabase.rpc("create_quotation", args);

    throwIfError(quotationResult.error);

    if (!quotationResult.data) {
      throw new Error("Quotation creation returned no row.");
    }

    return quotationResult.data;
  });

export const addQuotationPackageLine = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(addPackageLineSchema)
  .handler(async ({ context, data }): Promise<QuotationLineItemRow> => {
    const result = await context.supabase.rpc("add_quotation_package_line", {
      p_quotation_id: data.quotationId,
      p_package_version_id: data.packageVersionId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Package line creation returned no row.");
    }

    return result.data;
  });

export const addQuotationAddonLine = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(addAddonLineSchema)
  .handler(async ({ context, data }): Promise<QuotationLineItemRow> => {
    const result = await context.supabase.rpc("add_quotation_addon_line", {
      p_quotation_id: data.quotationId,
      p_addon_version_id: data.addonVersionId,
      p_quantity: data.quantity,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Add-on line creation returned no row.");
    }

    return result.data;
  });

export const removeQuotationLine = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(removeLineSchema)
  .handler(async ({ context, data }) => {
    const result = await context.supabase.rpc("remove_quotation_line", {
      p_line_item_id: data.lineItemId,
    });

    throwIfError(result.error);

    return {
      removed: true,
    };
  });

export const transitionQuotation = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(transitionQuotationSchema)
  .handler(async ({ context, data }): Promise<QuotationRow> => {
    const result = await context.supabase.rpc("transition_quotation", {
      p_quotation_id: data.quotationId,
      p_target_status: data.targetStatus,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Quotation transition returned no row.");
    }

    return result.data;
  });

export const acceptQuotation = createServerFn({
  method: "POST",
})
  .middleware([requireSupabaseAuth])
  .validator(acceptQuotationSchema)
  .handler(async ({ context, data }): Promise<BookingRow> => {
    const result = await context.supabase.rpc("accept_quotation", {
      p_quotation_id: data.quotationId,
    });

    throwIfError(result.error);

    if (!result.data) {
      throw new Error("Quotation acceptance returned no booking.");
    }

    return result.data;
  });
