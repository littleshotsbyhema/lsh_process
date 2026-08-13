import { useMemo, useState } from "react";
import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Loader2, Plus, Trash2 } from "lucide-react";

import { AppShell, Card, PageHeader } from "@/components/AppShell";
import {
  listCommercialCatalogue,
  type CommercialCatalogueAddon,
  type CommercialCataloguePackage,
} from "@/lib/commercial.functions";
import {
  acceptQuotation,
  addQuotationAddonLine,
  addQuotationPackageLine,
  createQuotationDraft,
  listQuotationWorkspace,
  removeQuotationLine,
  transitionQuotation,
  type QuoteSubject,
  type QuotationLineItemRow,
  type QuotationRow,
} from "@/lib/quotation.functions";

export const Route = createFileRoute("/_authenticated/quote")({
  head: () => ({
    meta: [
      {
        title: "Quotation Workspace · Little Moments OS",
      },
      {
        name: "description",
        content: "Create clear, catalogue-backed quotations for families.",
      },
      {
        property: "og:title",
        content: "Quotation Workspace · Little Moments OS",
      },
      {
        property: "og:description",
        content: "Create clear, catalogue-backed quotations for families.",
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
  component: QuotationWorkspace,
});

const fieldClass =
  "w-full rounded-lg border border-border bg-card px-3 py-2 text-sm text-foreground";

const primaryButtonClass =
  "inline-flex items-center justify-center gap-2 rounded-lg bg-primary px-4 py-2 text-sm font-medium text-primary-foreground transition-opacity disabled:cursor-not-allowed disabled:opacity-50";

const secondaryButtonClass =
  "inline-flex items-center justify-center gap-2 rounded-lg border border-border bg-card px-3 py-2 text-sm font-medium text-primary transition-colors hover:bg-muted disabled:cursor-not-allowed disabled:opacity-50";

function formatInr(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(value);
}

function errorMessage(error: unknown) {
  if (error instanceof Error) {
    return error.message;
  }

  return "Something went wrong.";
}

function subjectLabel(subject: QuoteSubject) {
  const session = subject.sessionType ? ` · ${subject.sessionType}` : "";

  return `${subject.reference} · ${subject.displayName}${session}`;
}

function categoryForSubject(subject: QuoteSubject | undefined) {
  const session = subject?.sessionType?.trim().toLowerCase();

  if (!session) {
    return null;
  }

  if (session.includes("maternity")) {
    return "maternity";
  }

  if (session.includes("newborn")) {
    return "newborn";
  }

  if (session.includes("sitter")) {
    return "sitter";
  }

  return null;
}

function StatusPill({ status }: { status: QuotationRow["status"] }) {
  return (
    <span className="rounded-full border border-border bg-muted px-2.5 py-1 text-[10px] uppercase tracking-wider text-muted-foreground">
      {status}
    </span>
  );
}

function LineItem({
  item,
  editable,
  removing,
  onRemove,
}: {
  item: QuotationLineItemRow;
  editable: boolean;
  removing: boolean;
  onRemove: () => void;
}) {
  return (
    <div className="flex items-start justify-between gap-4 border-b border-border py-3 last:border-b-0">
      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <span className="font-medium text-primary">{item.item_name}</span>

          <span className="text-[10px] uppercase tracking-wider text-muted-foreground">
            {item.line_type}
          </span>
        </div>

        {item.description ? (
          <p className="mt-1 text-xs text-muted-foreground">{item.description}</p>
        ) : null}

        <div className="mt-1 text-xs text-muted-foreground">
          {item.quantity} × {formatInr(item.quoted_unit_price_inr)}
          {item.pricing_source !== "catalogue" ? ` · ${item.pricing_source}` : ""}
        </div>
      </div>

      <div className="flex shrink-0 items-center gap-3">
        <div className="text-sm font-medium text-primary">{formatInr(item.line_total_inr)}</div>

        {editable ? (
          <button
            type="button"
            onClick={onRemove}
            disabled={removing}
            className="rounded-md p-1.5 text-muted-foreground transition-colors hover:bg-muted hover:text-destructive disabled:opacity-50"
            aria-label={`Remove ${item.item_name}`}
          >
            {removing ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Trash2 className="h-4 w-4" />
            )}
          </button>
        ) : null}
      </div>
    </div>
  );
}

function AddonCard({
  addon,
  disabled,
  adding,
  onAdd,
}: {
  addon: CommercialCatalogueAddon;
  disabled: boolean;
  adding: boolean;
  onAdd: () => void;
}) {
  const isVariable = addon.pricingType === "variable";

  let priceLabel = "Quoted separately";

  if (addon.pricingType === "fixed_amount" && addon.amountInr !== null) {
    priceLabel = formatInr(addon.amountInr);
  }

  if (addon.pricingType === "percentage" && addon.percentageValue !== null) {
    priceLabel = `${addon.percentageValue}%`;
  }

  return (
    <Card className="p-4">
      <div className="flex items-start justify-between gap-4">
        <div>
          <div className="font-medium text-primary">{addon.publicName}</div>

          {addon.description ? (
            <p className="mt-1 text-xs text-muted-foreground">{addon.description}</p>
          ) : null}
        </div>

        <div className="shrink-0 text-sm font-medium text-primary">{priceLabel}</div>
      </div>

      <div className="mt-4">
        {isVariable ? (
          <p className="text-xs text-muted-foreground">
            Requires the separately authorized commercial override path.
          </p>
        ) : (
          <button
            type="button"
            className={secondaryButtonClass}
            disabled={disabled || adding}
            onClick={onAdd}
          >
            {adding ? <Loader2 className="h-4 w-4 animate-spin" /> : <Plus className="h-4 w-4" />}
            Add
          </button>
        )}
      </div>
    </Card>
  );
}

function QuotationWorkspace() {
  const queryClient = useQueryClient();

  const workspaceQuery = useQuery({
    queryKey: ["quotation-workspace"],
    queryFn: () => listQuotationWorkspace(),
  });

  const catalogueQuery = useQuery({
    queryKey: ["commercial-catalogue"],
    queryFn: () => listCommercialCatalogue(),
  });

  const [subjectKey, setSubjectKey] = useState("");
  const [packageVersionId, setPackageVersionId] = useState("");
  const [selectedQuotationId, setSelectedQuotationId] = useState<string | null>(null);
  const [removingLineId, setRemovingLineId] = useState<string | null>(null);
  const [addingAddonVersionId, setAddingAddonVersionId] = useState<string | null>(null);

  const subjects = workspaceQuery.data?.subjects ?? [];

  const effectiveSubjectKey =
    subjectKey || (subjects[0] ? `${subjects[0].subjectType}:${subjects[0].id}` : "");

  const selectedSubject = useMemo(() => {
    if (!effectiveSubjectKey) {
      return undefined;
    }

    const [subjectType, subjectId] = effectiveSubjectKey.split(":");

    return subjects.find(
      (subject) => subject.subjectType === subjectType && subject.id === subjectId,
    );
  }, [effectiveSubjectKey, subjects]);

  const subjectCategory = categoryForSubject(selectedSubject);

  const cataloguePackages = useMemo(() => {
    const items = catalogueQuery.data?.packages ?? [];

    if (!subjectCategory) {
      return items;
    }

    return items.filter((item) => item.serviceCategory === subjectCategory);
  }, [catalogueQuery.data?.packages, subjectCategory]);

  const effectivePackageVersionId = packageVersionId || cataloguePackages[0]?.versionId || "";

  const quotations = workspaceQuery.data?.quotations ?? [];

  const effectiveQuotationId = selectedQuotationId ?? quotations[0]?.id ?? null;

  const selectedQuotation =
    quotations.find((quotation) => quotation.id === effectiveQuotationId) ?? null;

  const selectedBooking =
    workspaceQuery.data?.bookings.find(
      (booking) => booking.source_quotation_id === selectedQuotation?.id,
    ) ?? null;

  const selectedLines =
    workspaceQuery.data?.lineItems.filter((item) => item.quotation_id === selectedQuotation?.id) ??
    [];

  const packageLine = selectedLines.find((item) => item.line_type === "package");

  const selectedCataloguePackage = packageLine
    ? catalogueQuery.data?.packages.find(
        (item) => item.versionId === packageLine.source_package_version_id,
      )
    : undefined;

  const applicableAddons = useMemo(() => {
    if (!selectedCataloguePackage) {
      return [];
    }

    return (
      catalogueQuery.data?.addons.filter((addon) => {
        if (!addon.applicableServiceCategories.includes(selectedCataloguePackage.serviceCategory)) {
          return false;
        }

        if (addon.applicablePackageKeys.length === 0) {
          return true;
        }

        return addon.applicablePackageKeys.includes(selectedCataloguePackage.packageKey);
      }) ?? []
    );
  }, [catalogueQuery.data?.addons, selectedCataloguePackage]);

  const refreshWorkspace = async () => {
    await queryClient.invalidateQueries({
      queryKey: ["quotation-workspace"],
    });
  };

  const createDraftMutation = useMutation({
    mutationFn: async () => {
      if (!selectedSubject) {
        throw new Error("Choose an inquiry or family first.");
      }

      return createQuotationDraft({
        data: {
          subjectType: selectedSubject.subjectType,
          subjectId: selectedSubject.id,
        },
      });
    },
    onSuccess: async (quotation) => {
      setSelectedQuotationId(quotation.id);
      await refreshWorkspace();
    },
  });

  const addPackageMutation = useMutation({
    mutationFn: async () => {
      if (!selectedQuotation || !effectivePackageVersionId) {
        throw new Error("Choose a draft quotation and package.");
      }

      return addQuotationPackageLine({
        data: {
          quotationId: selectedQuotation.id,
          packageVersionId: effectivePackageVersionId,
        },
      });
    },
    onSuccess: refreshWorkspace,
  });

  const addAddonMutation = useMutation({
    mutationFn: async (addonVersionId: string) => {
      if (!selectedQuotation) {
        throw new Error("Choose a draft quotation first.");
      }

      setAddingAddonVersionId(addonVersionId);

      try {
        return await addQuotationAddonLine({
          data: {
            quotationId: selectedQuotation.id,
            addonVersionId,
            quantity: 1,
          },
        });
      } finally {
        setAddingAddonVersionId(null);
      }
    },
    onSuccess: refreshWorkspace,
  });

  const removeLineMutation = useMutation({
    mutationFn: async (lineItemId: string) => {
      setRemovingLineId(lineItemId);

      try {
        return await removeQuotationLine({
          data: {
            lineItemId,
          },
        });
      } finally {
        setRemovingLineId(null);
      }
    },
    onSuccess: refreshWorkspace,
  });

  const transitionMutation = useMutation({
    mutationFn: async (targetStatus: "draft" | "ready" | "sent") => {
      if (!selectedQuotation) {
        throw new Error("Choose a quotation first.");
      }

      return transitionQuotation({
        data: {
          quotationId: selectedQuotation.id,
          targetStatus,
        },
      });
    },
    onSuccess: refreshWorkspace,
  });

  const acceptMutation = useMutation({
    mutationFn: async () => {
      if (!selectedQuotation) {
        throw new Error("Choose a quotation first.");
      }

      return acceptQuotation({
        data: {
          quotationId: selectedQuotation.id,
        },
      });
    },
    onSuccess: refreshWorkspace,
  });

  const editable = selectedQuotation?.status === "draft";

  const hasPackage = Boolean(packageLine);

  const mutationError =
    createDraftMutation.error ??
    addPackageMutation.error ??
    addAddonMutation.error ??
    removeLineMutation.error ??
    transitionMutation.error ??
    acceptMutation.error;

  const isLoading = workspaceQuery.isPending || catalogueQuery.isPending;

  return (
    <AppShell>
      <PageHeader
        eyebrow="Quotation workspace"
        title="Build a clear, catalogue-backed quote"
        subtitle="The database is authoritative for package identity, line pricing and totals."
        quote="A quote is a promise of care, written in numbers."
      />

      {isLoading ? (
        <Card className="p-8">
          <div className="flex items-center gap-3 text-sm text-muted-foreground">
            <Loader2 className="h-4 w-4 animate-spin" />
            Loading quotation workspace…
          </div>
        </Card>
      ) : workspaceQuery.isError ? (
        <Card className="p-8">
          <p className="text-sm text-destructive">
            Unable to load quotations: {errorMessage(workspaceQuery.error)}
          </p>
        </Card>
      ) : catalogueQuery.isError ? (
        <Card className="p-8">
          <p className="text-sm text-destructive">
            Unable to load catalogue: {errorMessage(catalogueQuery.error)}
          </p>
        </Card>
      ) : (
        <div className="grid gap-6 xl:grid-cols-[360px_minmax(0,1fr)]">
          <div className="space-y-6">
            <Card className="p-6">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                New quotation
              </div>

              <h2 className="mt-1 font-serif text-2xl text-primary">Start a draft</h2>

              <div className="mt-5 space-y-4">
                <label className="block">
                  <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                    Inquiry / family
                  </span>

                  <select
                    className={`${fieldClass} mt-1.5`}
                    value={effectiveSubjectKey}
                    onChange={(event) => {
                      setSubjectKey(event.target.value);
                      setPackageVersionId("");
                    }}
                  >
                    {subjects.length === 0 ? (
                      <option value="">No quote subjects available</option>
                    ) : null}

                    {subjects.map((subject) => (
                      <option
                        key={`${subject.subjectType}:${subject.id}`}
                        value={`${subject.subjectType}:${subject.id}`}
                      >
                        {subjectLabel(subject)}
                      </option>
                    ))}
                  </select>
                </label>

                <button
                  type="button"
                  className={primaryButtonClass}
                  disabled={!selectedSubject || createDraftMutation.isPending}
                  onClick={() => createDraftMutation.mutate()}
                >
                  {createDraftMutation.isPending ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                  ) : (
                    <Plus className="h-4 w-4" />
                  )}
                  Create draft
                </button>
              </div>
            </Card>

            <Card className="p-6">
              <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                Quotations
              </div>

              <div className="mt-4 space-y-2">
                {quotations.length === 0 ? (
                  <p className="text-sm text-muted-foreground">No quotations yet.</p>
                ) : (
                  quotations.map((quotation) => (
                    <button
                      key={quotation.id}
                      type="button"
                      onClick={() => setSelectedQuotationId(quotation.id)}
                      className={`w-full rounded-lg border p-3 text-left transition-colors ${
                        effectiveQuotationId === quotation.id
                          ? "border-primary bg-muted"
                          : "border-border bg-card hover:bg-muted"
                      }`}
                    >
                      <div className="flex items-center justify-between gap-3">
                        <span className="text-sm font-medium text-primary">
                          {quotation.quotation_reference}
                        </span>

                        <StatusPill status={quotation.status} />
                      </div>

                      <div className="mt-2 text-xs text-muted-foreground">
                        {formatInr(quotation.quoted_total_inr)}
                      </div>
                    </button>
                  ))
                )}
              </div>
            </Card>
          </div>

          <div className="space-y-6">
            {!selectedQuotation ? (
              <Card className="p-8">
                <p className="text-sm text-muted-foreground">Create a quotation draft to begin.</p>
              </Card>
            ) : (
              <>
                <Card className="p-6">
                  <div className="flex flex-wrap items-start justify-between gap-4">
                    <div>
                      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                        Quotation
                      </div>

                      <h2 className="mt-1 font-serif text-2xl text-primary">
                        {selectedQuotation.quotation_reference}
                      </h2>
                    </div>

                    <StatusPill status={selectedQuotation.status} />
                  </div>

                  <div className="mt-5 flex flex-wrap items-center gap-2 border-t border-border pt-4">
                    {selectedQuotation.status === "draft" ? (
                      <button
                        type="button"
                        className={secondaryButtonClass}
                        disabled={!hasPackage || transitionMutation.isPending}
                        onClick={() => transitionMutation.mutate("ready")}
                      >
                        {transitionMutation.isPending ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : null}
                        Mark ready
                      </button>
                    ) : null}

                    {selectedQuotation.status === "ready" ? (
                      <>
                        <button
                          type="button"
                          className={secondaryButtonClass}
                          disabled={transitionMutation.isPending}
                          onClick={() => transitionMutation.mutate("draft")}
                        >
                          {transitionMutation.isPending ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : null}
                          Return to draft
                        </button>

                        <button
                          type="button"
                          className={primaryButtonClass}
                          disabled={!hasPackage || transitionMutation.isPending}
                          onClick={() => transitionMutation.mutate("sent")}
                        >
                          {transitionMutation.isPending ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : null}
                          Mark sent
                        </button>
                      </>
                    ) : null}

                    {selectedQuotation.status === "sent" ? (
                      <div className="space-y-3">
                        <p className="max-w-2xl text-xs leading-5 text-muted-foreground">
                          Acceptance is irreversible for this quotation and creates one tentative
                          booking shell at Advance Pending. It does not reserve a date, confirm the
                          booking, or record payment.
                        </p>

                        <button
                          type="button"
                          className={primaryButtonClass}
                          disabled={!hasPackage || acceptMutation.isPending}
                          onClick={() => {
                            const confirmed = window.confirm(
                              "Accept this quotation and create its tentative booking at Advance Pending? This does not confirm payment or reserve a date.",
                            );

                            if (confirmed) {
                              acceptMutation.mutate();
                            }
                          }}
                        >
                          {acceptMutation.isPending ? (
                            <Loader2 className="h-4 w-4 animate-spin" />
                          ) : null}
                          Accept quotation
                        </button>
                      </div>
                    ) : null}

                    {selectedQuotation.status === "accepted" ? (
                      <div className="space-y-1">
                        <p className="text-xs leading-5 text-muted-foreground">
                          Accepted. The quotation is immutable and its tentative booking now waits
                          for the separate advance-confirmation condition before Booking Confirmed.
                        </p>

                        {selectedBooking ? (
                          <p className="text-sm font-medium text-primary">
                            Booking {selectedBooking.booking_reference}
                          </p>
                        ) : null}
                      </div>
                    ) : null}
                  </div>

                  {editable && !hasPackage ? (
                    <div className="mt-6 rounded-lg border border-border bg-muted/40 p-4">
                      <label className="block">
                        <span className="text-[11px] uppercase tracking-wider text-muted-foreground">
                          Approved package
                        </span>

                        <select
                          className={`${fieldClass} mt-1.5`}
                          value={effectivePackageVersionId}
                          onChange={(event) => setPackageVersionId(event.target.value)}
                        >
                          {cataloguePackages.map((item) => (
                            <option key={item.versionId} value={item.versionId}>
                              {item.publicName} — {formatInr(item.listPriceInr)}
                            </option>
                          ))}
                        </select>
                      </label>

                      <button
                        type="button"
                        className={`${primaryButtonClass} mt-4`}
                        disabled={!effectivePackageVersionId || addPackageMutation.isPending}
                        onClick={() => addPackageMutation.mutate()}
                      >
                        {addPackageMutation.isPending ? (
                          <Loader2 className="h-4 w-4 animate-spin" />
                        ) : (
                          <Plus className="h-4 w-4" />
                        )}
                        Add package
                      </button>
                    </div>
                  ) : null}

                  <div className="mt-6">
                    {selectedLines.length === 0 ? (
                      <p className="text-sm text-muted-foreground">
                        This draft has no line items yet.
                      </p>
                    ) : (
                      selectedLines.map((item) => (
                        <LineItem
                          key={item.id}
                          item={item}
                          editable={editable}
                          removing={removingLineId === item.id}
                          onRemove={() => removeLineMutation.mutate(item.id)}
                        />
                      ))
                    )}
                  </div>

                  <div className="mt-6 grid gap-3 border-t border-border pt-5 sm:grid-cols-3">
                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                        Subtotal
                      </div>
                      <div className="mt-1 text-lg font-medium text-primary">
                        {formatInr(selectedQuotation.subtotal_inr)}
                      </div>
                    </div>

                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                        Discount
                      </div>
                      <div className="mt-1 text-lg font-medium text-primary">
                        {formatInr(selectedQuotation.discount_inr)}
                      </div>
                    </div>

                    <div>
                      <div className="text-[10px] uppercase tracking-wider text-muted-foreground">
                        Quote total
                      </div>
                      <div className="mt-1 font-serif text-2xl text-primary">
                        {formatInr(selectedQuotation.quoted_total_inr)}
                      </div>
                    </div>
                  </div>
                </Card>

                {editable && selectedCataloguePackage ? (
                  <div>
                    <div className="mb-4">
                      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
                        Approved additions
                      </div>

                      <h2 className="mt-1 font-serif text-2xl text-primary">Add-ons</h2>
                    </div>

                    <div className="grid gap-4 md:grid-cols-2">
                      {applicableAddons.map((addon) => (
                        <AddonCard
                          key={addon.versionId}
                          addon={addon}
                          disabled={addAddonMutation.isPending}
                          adding={addingAddonVersionId === addon.versionId}
                          onAdd={() => addAddonMutation.mutate(addon.versionId)}
                        />
                      ))}
                    </div>
                  </div>
                ) : null}

                {!editable ? (
                  <Card className="p-5">
                    <p className="text-xs leading-5 text-muted-foreground">
                      This quotation is no longer editable in the draft workspace. Lifecycle actions
                      are handled separately.
                    </p>
                  </Card>
                ) : null}
              </>
            )}

            {mutationError ? (
              <Card className="border-destructive/40 p-5">
                <p className="text-sm text-destructive">{errorMessage(mutationError)}</p>
              </Card>
            ) : null}

            <Card className="p-5">
              <p className="text-xs leading-5 text-muted-foreground">
                Catalogue list prices are the authoritative pricing source. Promotional “Offer
                Price” values are not applied automatically. Variable pricing, custom lines,
                discounts and price overrides are intentionally excluded from this draft workspace
                until their separately authorized commercial path is enabled.
              </p>
            </Card>
          </div>
        </div>
      )}
    </AppShell>
  );
}
