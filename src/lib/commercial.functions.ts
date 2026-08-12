import { createServerFn } from "@tanstack/react-start";

import { requireSupabaseAuth } from "@/integrations/supabase/auth-middleware";
import type { Database } from "@/integrations/supabase/types";
import { ORGANIZATION_ID } from "@/lib/session";

type PackageRow = Database["public"]["Tables"]["commercial_packages"]["Row"];

type PackageVersionRow = Database["public"]["Tables"]["commercial_package_versions"]["Row"];

type PackageInclusionRow = Database["public"]["Tables"]["commercial_package_inclusions"]["Row"];

type AddonRow = Database["public"]["Tables"]["commercial_addons"]["Row"];

type AddonVersionRow = Database["public"]["Tables"]["commercial_addon_versions"]["Row"];

export type CommercialPackageTier = Database["public"]["Enums"]["commercial_package_tier"];

export type CommercialPricingType = Database["public"]["Enums"]["commercial_pricing_type"];

export type CommercialCatalogueInclusion = {
  id: string;
  inclusionKey: string;
  label: string;
  description: string | null;
  quantity: number | null;
  unit: string | null;
  sortOrder: number;
};

export type CommercialCataloguePackage = {
  id: string;
  packageKey: string;
  publicName: string;
  serviceCategory: string;
  tier: CommercialPackageTier;
  versionId: string;
  versionNumber: number;
  listPriceInr: number;
  currency: string;
  sourceDocument: string | null;
  sourceRevision: string | null;
  inclusions: CommercialCatalogueInclusion[];
};

export type CommercialCatalogueAddon = {
  id: string;
  addonKey: string;
  publicName: string;
  description: string | null;
  applicableServiceCategories: string[];
  applicablePackageKeys: string[];
  versionId: string;
  versionNumber: number;
  pricingType: CommercialPricingType;
  amountInr: number | null;
  percentageValue: number | null;
  currency: string;
};

export type CommercialCatalogueData = {
  packages: CommercialCataloguePackage[];
  addons: CommercialCatalogueAddon[];
};

const supportedServiceCategories = ["maternity", "newborn", "sitter"] as const;

const tierOrder: Record<CommercialPackageTier, number> = {
  bronze: 1,
  gold: 2,
  diamond: 3,
  emerald: 4,
};

function throwIfError(error: { message: string } | null) {
  if (error) {
    throw new Error(error.message);
  }
}

function packageVersionIsCurrent(version: PackageVersionRow, now: number) {
  if (version.approval_status !== "approved") {
    return false;
  }

  if (version.effective_from && Date.parse(version.effective_from) > now) {
    return false;
  }

  if (version.effective_until && Date.parse(version.effective_until) <= now) {
    return false;
  }

  return true;
}

function latestPackageVersions(rows: PackageVersionRow[]): Map<string, PackageVersionRow> {
  const now = Date.now();
  const result = new Map<string, PackageVersionRow>();

  for (const row of rows) {
    if (!packageVersionIsCurrent(row, now)) {
      continue;
    }

    const existing = result.get(row.package_id);

    if (!existing || row.version_number > existing.version_number) {
      result.set(row.package_id, row);
    }
  }

  return result;
}

function latestAddonVersions(rows: AddonVersionRow[]): Map<string, AddonVersionRow> {
  const result = new Map<string, AddonVersionRow>();

  for (const row of rows) {
    if (row.approval_status !== "approved") {
      continue;
    }

    const existing = result.get(row.addon_id);

    if (!existing || row.version_number > existing.version_number) {
      result.set(row.addon_id, row);
    }
  }

  return result;
}

export const listCommercialCatalogue = createServerFn({
  method: "GET",
})
  .middleware([requireSupabaseAuth])
  .handler(async ({ context }): Promise<CommercialCatalogueData> => {
    const [packagesResult, packageVersionsResult, addonsResult, addonVersionsResult] =
      await Promise.all([
        context.supabase
          .from("commercial_packages")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .eq("status", "active")
          .in("service_category", [...supportedServiceCategories]),
        context.supabase
          .from("commercial_package_versions")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .eq("approval_status", "approved"),
        context.supabase
          .from("commercial_addons")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .eq("status", "active"),
        context.supabase
          .from("commercial_addon_versions")
          .select("*")
          .eq("organization_id", ORGANIZATION_ID)
          .eq("approval_status", "approved"),
      ]);

    throwIfError(packagesResult.error);
    throwIfError(packageVersionsResult.error);
    throwIfError(addonsResult.error);
    throwIfError(addonVersionsResult.error);

    const packageRows = (packagesResult.data ?? []) as PackageRow[];

    const currentPackageVersions = latestPackageVersions(
      (packageVersionsResult.data ?? []) as PackageVersionRow[],
    );

    const activeVersionIds = Array.from(currentPackageVersions.values(), (version) => version.id);

    let inclusionRows: PackageInclusionRow[] = [];

    if (activeVersionIds.length > 0) {
      const inclusionResult = await context.supabase
        .from("commercial_package_inclusions")
        .select("*")
        .eq("organization_id", ORGANIZATION_ID)
        .in("package_version_id", activeVersionIds)
        .order("sort_order", { ascending: true });

      throwIfError(inclusionResult.error);

      inclusionRows = (inclusionResult.data ?? []) as PackageInclusionRow[];
    }

    const inclusionsByVersion = new Map<string, PackageInclusionRow[]>();

    for (const inclusion of inclusionRows) {
      const rows = inclusionsByVersion.get(inclusion.package_version_id) ?? [];

      rows.push(inclusion);
      inclusionsByVersion.set(inclusion.package_version_id, rows);
    }

    const packages = packageRows
      .flatMap((row): CommercialCataloguePackage[] => {
        const version = currentPackageVersions.get(row.id);

        if (!version) {
          return [];
        }

        const inclusions = inclusionsByVersion.get(version.id) ?? [];

        return [
          {
            id: row.id,
            packageKey: row.package_key,
            publicName: row.public_name,
            serviceCategory: row.service_category,
            tier: row.tier,
            versionId: version.id,
            versionNumber: version.version_number,
            listPriceInr: version.list_price_inr,
            currency: version.currency,
            sourceDocument: version.source_document,
            sourceRevision: version.source_revision,
            inclusions: inclusions.map((inclusion) => ({
              id: inclusion.id,
              inclusionKey: inclusion.inclusion_key,
              label: inclusion.label,
              description: inclusion.description,
              quantity: inclusion.quantity,
              unit: inclusion.unit,
              sortOrder: inclusion.sort_order,
            })),
          },
        ];
      })
      .sort((a, b) => {
        if (a.serviceCategory !== b.serviceCategory) {
          return a.serviceCategory.localeCompare(b.serviceCategory);
        }

        return tierOrder[a.tier] - tierOrder[b.tier];
      });

    const currentAddonVersions = latestAddonVersions(
      (addonVersionsResult.data ?? []) as AddonVersionRow[],
    );

    const addons = ((addonsResult.data ?? []) as AddonRow[])
      .flatMap((row): CommercialCatalogueAddon[] => {
        const version = currentAddonVersions.get(row.id);

        if (!version) {
          return [];
        }

        return [
          {
            id: row.id,
            addonKey: row.addon_key,
            publicName: row.public_name,
            description: row.description,
            applicableServiceCategories: row.applicable_service_categories,
            applicablePackageKeys: row.applicable_package_keys,
            versionId: version.id,
            versionNumber: version.version_number,
            pricingType: version.pricing_type,
            amountInr: version.amount_inr,
            percentageValue: version.percentage_value,
            currency: version.currency,
          },
        ];
      })
      .sort((a, b) => a.publicName.localeCompare(b.publicName));

    return {
      packages,
      addons,
    };
  });
