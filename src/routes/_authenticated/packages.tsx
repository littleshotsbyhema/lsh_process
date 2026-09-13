import { useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useQuery } from "@tanstack/react-query";
import { Loader2 } from "lucide-react";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import {
  listCommercialCatalogue,
  type CommercialCatalogueAddon,
  type CommercialCataloguePackage,
  type CommercialPackageTier,
} from "@/lib/commercial.functions";

export const Route = createFileRoute("/_authenticated/packages")({
  head: () => ({
    meta: [
      {
        title: "Package Catalogue · LittleShots by Hema OS",
      },
      {
        name: "description",
        content: "Authoritative commercial catalogue for Maternity, Newborn and Sitter sessions.",
      },
      {
        property: "og:title",
        content: "Package Catalogue · LittleShots by Hema OS",
      },
      {
        property: "og:description",
        content: "Authoritative commercial catalogue for Maternity, Newborn and Sitter sessions.",
      },
      {
        property: "og:type",
        content: "website",
      },
      {
        name: "twitter:card",
        content: "summary",
      },
    ],
  }),
  component: PackagesPage,
});

const categories = [
  {
    key: "maternity",
    label: "Maternity",
  },
  {
    key: "newborn",
    label: "Newborn",
  },
  {
    key: "sitter",
    label: "Sitter",
  },
] as const;

type ServiceCategory = (typeof categories)[number]["key"];

const tierLabels: Record<CommercialPackageTier, string> = {
  bronze: "Bronze",
  gold: "Gold",
  diamond: "Diamond",
  emerald: "Emerald",
};

function formatInr(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(value);
}

function addonPrice(addon: CommercialCatalogueAddon) {
  if (addon.pricingType === "fixed_amount" && addon.amountInr !== null) {
    return formatInr(addon.amountInr);
  }

  if (addon.pricingType === "percentage" && addon.percentageValue !== null) {
    return `${addon.percentageValue}%`;
  }

  return "Quoted separately";
}

function packageScope(addon: CommercialCatalogueAddon) {
  if (addon.applicablePackageKeys.length === 0) {
    return "Category-wide";
  }

  return addon.applicablePackageKeys
    .map((key) => {
      const tier = key.split("_").at(-1);

      if (tier === "bronze" || tier === "gold" || tier === "diamond" || tier === "emerald") {
        return tierLabels[tier];
      }

      return key;
    })
    .join(" · ");
}

function PackageCard({ item }: { item: CommercialCataloguePackage }) {
  return (
    <Card className="p-6">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
        {tierLabels[item.tier]}
      </div>

      <h3 className="mt-1 font-serif text-2xl text-primary">{item.publicName}</h3>

      <div className="mt-4">
        <div className="text-[10px] uppercase tracking-wider text-muted-foreground">List price</div>
        <div className="mt-1 font-serif text-2xl text-primary">{formatInr(item.listPriceInr)}</div>
      </div>

      <ul className="mt-5 space-y-2 text-sm text-primary">
        {item.inclusions.map((inclusion) => (
          <li key={inclusion.id} className="flex gap-2">
            <span className="text-gold">•</span>
            <span>
              {inclusion.label}
              {inclusion.description ? (
                <span className="block text-xs text-muted-foreground">{inclusion.description}</span>
              ) : null}
            </span>
          </li>
        ))}
      </ul>

      <div className="mt-5 border-t border-border pt-4 text-[10px] uppercase tracking-wider text-muted-foreground">
        Catalogue v{item.versionNumber}
      </div>
    </Card>
  );
}

function PackagesPage() {
  const [category, setCategory] = useState<ServiceCategory>("newborn");

  const catalogueQuery = useQuery({
    queryKey: ["commercial-catalogue"],
    queryFn: () => listCommercialCatalogue(),
  });

  const packages =
    catalogueQuery.data?.packages.filter((item) => item.serviceCategory === category) ?? [];

  const addons =
    catalogueQuery.data?.addons.filter((item) =>
      item.applicableServiceCategories.includes(category),
    ) ?? [];

  return (
    <AppShell>
      <PageHeader
        eyebrow="Commercial catalogue"
        title="Packages"
        subtitle="Use the approved catalogue as the commercial source of truth for every family."
        quote="Because these little moments become everything."
      />

      <Card className="mb-8 p-6">
        <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
          Session category
        </div>

        <div className="mt-3 flex flex-wrap gap-2">
          {categories.map((item) => (
            <button
              key={item.key}
              type="button"
              onClick={() => setCategory(item.key)}
              className={`rounded-full border px-4 py-2 text-sm transition-all ${
                category === item.key
                  ? "border-primary bg-primary text-primary-foreground"
                  : "border-border bg-card text-primary hover:bg-muted"
              }`}
            >
              {item.label}
            </button>
          ))}
        </div>

        <p className="mt-3 text-xs text-muted-foreground">
          Only Maternity, Newborn and Sitter currently have approved commercial catalogue pricing.
        </p>
      </Card>

      {catalogueQuery.isPending ? (
        <Card className="p-8">
          <div className="flex items-center gap-3 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Loading approved catalogue…
          </div>
        </Card>
      ) : catalogueQuery.isError ? (
        <Card className="p-8">
          <div className="text-sm text-destructive">
            Unable to load the commercial catalogue:{" "}
            {catalogueQuery.error instanceof Error ? catalogueQuery.error.message : "Unknown error"}
          </div>
        </Card>
      ) : (
        <>
          <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-4">
            {packages.map((item) => (
              <PackageCard key={item.id} item={item} />
            ))}
          </div>

          {packages.length === 0 ? (
            <Card className="p-8">
              <p className="text-sm text-muted-foreground">
                No current approved packages are available for this category.
              </p>
            </Card>
          ) : null}

          <div className="mt-10">
            <div className="mb-4">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Structured add-ons
              </div>
              <h2 className="mt-1 font-serif text-2xl text-primary">Approved additions</h2>
            </div>

            <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
              {addons.map((addon) => (
                <Card key={addon.id} className="p-5">
                  <div className="flex items-start justify-between gap-4">
                    <div>
                      <h3 className="font-medium text-primary">{addon.publicName}</h3>

                      {addon.description ? (
                        <p className="mt-1 text-xs text-muted-foreground">{addon.description}</p>
                      ) : null}
                    </div>

                    <div className="shrink-0 text-sm font-medium text-primary">
                      {addonPrice(addon)}
                    </div>
                  </div>

                  <div className="mt-4 border-t border-border pt-3 text-[10px] uppercase tracking-wider text-muted-foreground">
                    {packageScope(addon)}
                  </div>
                </Card>
              ))}
            </div>
          </div>

          <Card className="mt-8 p-5">
            <p className="text-xs leading-5 text-muted-foreground">
              Prices shown here are authoritative catalogue list prices. Source-document promotional
              “Offer Price” values are not applied automatically. Any commercial override must use
              the separately authorized pricing path.
            </p>
          </Card>
        </>
      )}
    </AppShell>
  );
}
