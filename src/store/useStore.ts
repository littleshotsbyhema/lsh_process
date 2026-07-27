import { create } from "zustand";
import type {
  BookingStatus,
  EditingStatus,
  JourneyStage,
  LeadStatus,
  LegacyInterest,
  EmotionalPriority,
  SessionType,
  PixiesetGalleryStatus,
  PixiesetOrderStatus,
  PixiesetPriceSheet,
  WhatsappMessageType,
  FollowUpStatus,
  TeamRole,
  TaskPriority,
  TaskStatus,
  ReviewPlatform,
  ReviewRequestStatus,
  IssueCategory,
  IssueStatus,
  AlignmentDimension,
  GovernanceCadence,
} from "@/lib/mock-data";
import {
  leads as seedLeads,
  clients as seedClients,
  bookings as seedBookings,
  privacyRecords as seedPrivacy,
  editingJobs as seedEditing,
  heirloomJobs as seedHeirloom,
  whatsappTemplates,
  alignmentDimensions,
} from "@/lib/mock-data";

/* ───────────── Types ───────────── */

export type Lead = {
  id: string;
  parent: string;
  phone: string;
  email: string;
  city: string;
  source: string;
  sessionType: SessionType;
  babyAge: string;
  preferredDate: string;
  location: string;
  memoryGoal: string;
  package: string;
  budget: string;
  followUp: string;
  status: LeadStatus;
  convertedClientId?: string;
};

export type Client = {
  id: string;
  name: string;
  phone: string;
  email: string;
  city: string;
  family: string;
  childName: string;
  dob: string;
  pregnancy: string;
  notes: string;
  pastSessions: number;
  nextMilestone: string;
  fromLeadId?: string;
};

export type Booking = {
  id: string;
  clientId?: string;
  client: string;
  category: SessionType;
  package: string;
  date: string;
  city: string;
  locationType: string;
  locationDetails: string;
  photographer: string;
  assistant: string;
  styling: string;
  addOns: string;
  price: number;
  offer: number;
  advance: number;
  balance: number;
  payment: "Pending" | "Partial" | "Paid";
  privacy: string;
  safety: "Pending" | "Completed";
  deadline: string;
  status: BookingStatus;
  selectionConfirmed: boolean;
  albumSelectionConfirmed: boolean;
  journeyStage: JourneyStage;
  reviewRequested?: boolean;
  aftercareSkipReason?: string;
};

export type PrivacyRecord = {
  id: string;
  bookingId: string;
  client: string;
  consent: string;
  date: string;
  platforms: string;
  images: string;
  confirmed: boolean;
  recordedBy: string;
};

export type SafetySubmission = {
  bookingId: string;
  category: "Newborn" | "Maternity" | "Sitter / Baby / Child";
  items: Record<string, boolean>;
  submittedAt: string;
  submittedBy: string;
};

export type EditingJob = {
  id: string;
  bookingId: string;
  client: string;
  status: EditingStatus;
  editedCount: number;
  selectionDate: string;
  deadline: string;
  editor: string;
  qc: string;
  deliveryLink: string;
  deliveryDate: string;
};

export type HeirloomJob = {
  id: string;
  bookingId: string;
  client: string;
  albumSize: string;
  pages: number;
  cover: string;
  frame: string;
  selected: string;
  proofSent: boolean;
  approved: boolean;
  sentToProduction: boolean;
  produced: boolean;
  qc: "Pending" | "Passed" | "—";
  packed: boolean;
  ready: boolean;
  delivered: boolean;
};

/* Memory Profile — one per owner (lead/client/booking) */
export type MemoryProfileOwner = "lead" | "client" | "booking";
export type MemoryProfile = {
  ownerType: MemoryProfileOwner;
  ownerId: string;
  memoryGoal: string;
  familyStory: string;
  importantPeople: string;
  mustCaptureMoments: string;
  comfortNeeds: string;
  sensitivities: string;
  legacyInterest: LegacyInterest;
  emotionalPriority: EmotionalPriority;
  notesPhotographer: string;
  notesEditor: string;
  notesAlbumDesigner: string;
  updatedAt: string;
};

/* Pixieset */
export type PixiesetRecord = {
  id: string;
  bookingId: string;
  clientId?: string;
  client: string;
  pixiesetClientName: string;
  collectionName: string;
  galleryLink: string;
  password: string;
  galleryStatus: PixiesetGalleryStatus;
  watermark: "Applied" | "Not Needed";
  favoritesEnabled: boolean;
  favoritesStatus: "Pending" | "Received";
  downloadEnabled: boolean;
  downloadExpiry: string;
  storeEnabled: boolean;
  priceSheet: PixiesetPriceSheet;
  invoiceLink: string;
  contractLink: string;
  orderStatus: PixiesetOrderStatus;
  syncNotes: string;
  updatedAt: string;
};

/* WhatsApp follow-up */
export type FollowUp = {
  id: string;
  client: string;
  bookingId?: string;
  leadId?: string;
  messageType: WhatsappMessageType;
  message: string;
  scheduledDate: string;
  status: FollowUpStatus;
  sentBy: string;
  notes: string;
  createdAt: string;
};

/* Tasks */
export type Task = {
  id: string;
  title: string;
  relatedType?: "lead" | "client" | "booking";
  relatedId?: string;
  relatedLabel?: string;
  role: TeamRole;
  assignee: string;
  dueDate: string;
  priority: TaskPriority;
  status: TaskStatus;
  sop?: string;
  notes: string;
  createdAt: string;
};

/* Reviews */
export type Review = {
  id: string;
  bookingId: string;
  client: string;
  sessionType: SessionType;
  requestStatus: ReviewRequestStatus;
  platform?: ReviewPlatform;
  rating?: number;
  testimonial: string;
  permissionToUse: boolean;
  consentProof: string;
  issueRaised: boolean;
  issueCategory?: IssueCategory;
  issueStatus?: IssueStatus;
  resolutionNotes: string;
  repeatOpportunity: boolean;
  nextMilestoneDate: string;
  createdAt: string;
  updatedAt: string;
};

/* Philosophy Alignment Score */
export type AlignmentScore = {
  bookingId: string;
  scores: Partial<Record<AlignmentDimension, number>>;
  notes: string;
  updatedAt: string;
};

/* Governance run-log */
export type GovernanceRun = {
  id: string;
  cadence: GovernanceCadence;
  date: string;
  items: Record<string, boolean>;
  completedBy: string;
};

const profileKey = (ownerType: MemoryProfileOwner, ownerId: string) => `${ownerType}:${ownerId}`;

/* ───────────── Result helpers ───────────── */

type Result =
  | { ok: true; message: string }
  | { ok: false; message: string; warning?: boolean };

const ok = (message: string): Result => ({ ok: true, message });
const fail = (message: string, warning = true): Result => ({
  ok: false,
  message,
  warning,
});

/* ───────────── Store ───────────── */

export type StoreData = {
  leads: Lead[];
  clients: Client[];
  bookings: Booking[];
  privacy: PrivacyRecord[];
  safety: SafetySubmission[];
  editing: EditingJob[];
  heirloom: HeirloomJob[];
  memoryProfiles: MemoryProfile[];
  pixieset: PixiesetRecord[];
  followUps: FollowUp[];
  tasks: Task[];
  reviews: Review[];
  alignment: AlignmentScore[];
  governance: GovernanceRun[];
};

type Store = StoreData & {
  hydrateFromDb: (data: Partial<StoreData>) => void;

  // lead flow
  setLeadStatus: (leadId: string, status: LeadStatus) => Result;
  convertLeadToClient: (leadId: string) => Result & { clientId?: string };

  // booking flow
  createBookingForClient: (
    clientId: string,
    draft?: Partial<Booking>,
  ) => Result & { bookingId?: string };
  setBookingStatus: (bookingId: string, status: BookingStatus) => Result;
  markShootCompleted: (bookingId: string) => Result;
  confirmSelection: (bookingId: string) => Result;
  confirmAlbumSelection: (bookingId: string) => Result;
  markPaymentPaid: (bookingId: string) => Result;

  // privacy
  recordPrivacy: (rec: Omit<PrivacyRecord, "id">) => Result;

  // safety
  submitSafety: (s: Omit<SafetySubmission, "submittedAt"> & { submittedAt?: string }) => Result;

  // editing
  startEditing: (bookingId: string) => Result & { jobId?: string };
  advanceEditing: (jobId: string) => Result;

  // heirloom
  startHeirloom: (
    bookingId: string,
    draft: Pick<HeirloomJob, "albumSize" | "pages" | "cover" | "frame" | "selected">,
  ) => Result & { jobId?: string };
  advanceHeirloom: (jobId: string, step: keyof Pick<HeirloomJob, "proofSent" | "approved" | "sentToProduction" | "produced" | "packed" | "ready" | "delivered">) => Result;
  passHeirloomQC: (jobId: string) => Result;

  // memory profiles
  upsertMemoryProfile: (
    ownerType: MemoryProfileOwner,
    ownerId: string,
    patch: Partial<Omit<MemoryProfile, "ownerType" | "ownerId" | "updatedAt">>,
  ) => Result;
  getMemoryProfile: (ownerType: MemoryProfileOwner, ownerId: string) => MemoryProfile | undefined;

  // journey
  setJourneyStage: (bookingId: string, stage: JourneyStage) => Result;
  requestReview: (bookingId: string) => Result;
  skipAftercare: (bookingId: string, reason: string) => Result;

  // pixieset
  upsertPixieset: (
    bookingId: string,
    patch: Partial<Omit<PixiesetRecord, "id" | "bookingId" | "client" | "updatedAt">>,
  ) => Result;

  // followups
  createFollowUp: (
    data: Omit<FollowUp, "id" | "createdAt" | "message"> & { message?: string },
  ) => Result & { followUpId?: string };
  updateFollowUp: (id: string, patch: Partial<FollowUp>) => Result;

  // tasks
  createTask: (
    data: Omit<Task, "id" | "createdAt" | "status" | "priority" | "notes" | "assignee" | "dueDate"> &
      Partial<Pick<Task, "status" | "priority" | "notes" | "assignee" | "dueDate">>,
  ) => Result & { taskId?: string };
  updateTask: (id: string, patch: Partial<Task>) => Result;

  // reviews
  upsertReview: (bookingId: string, patch: Partial<Omit<Review, "id" | "bookingId" | "createdAt" | "updatedAt">>) => Result;
  // alignment
  setAlignmentScore: (bookingId: string, dimension: AlignmentDimension, score: number) => Result;
  setAlignmentNotes: (bookingId: string, notes: string) => Result;
  // governance
  saveGovernanceRun: (cadence: GovernanceCadence, items: Record<string, boolean>, completedBy?: string) => Result;
};

const nextId = (prefix: string, list: { id: string }[]) => {
  const max = list.reduce((m, x) => {
    const n = parseInt(x.id.split("-")[1] ?? "0", 10);
    return Number.isFinite(n) ? Math.max(m, n) : m;
  }, 0);
  return `${prefix}-${String(max + 1).padStart(prefix === "C" ? 3 : 4, "0")}`;
};

const today = () => new Date().toISOString().slice(0, 10);

const statusToJourney: Record<BookingStatus, JourneyStage> = {
  Tentative: "Quote Sent",
  "Advance Pending": "Follow-Up Pending",
  Confirmed: "Booking Confirmed",
  "Pre-Shoot Prep": "Pre-Shoot Preparation",
  "Shoot Completed": "Shoot Completed",
  "Selection Pending": "Selection Pending",
  Editing: "Editing in Progress",
  Delivered: "Delivered",
  "Album/Frame Pending": "Album / Frame Production",
  Completed: "Completed / Relationship Active",
};

const initialBookings: Booking[] = (seedBookings as unknown as (Omit<Booking, "selectionConfirmed" | "albumSelectionConfirmed" | "journeyStage"> & Partial<Pick<Booking, "selectionConfirmed" | "albumSelectionConfirmed" | "journeyStage">>)[]).map(
  (b) => ({
    ...b,
    selectionConfirmed: b.status === "Editing" || b.status === "Delivered" || b.status === "Completed",
    albumSelectionConfirmed: b.status === "Album/Frame Pending" || b.status === "Completed",
    journeyStage: b.journeyStage ?? statusToJourney[b.status] ?? "Booking Confirmed",
  }),
);

const initialPrivacy: PrivacyRecord[] = (seedPrivacy as unknown as (Omit<PrivacyRecord, "bookingId"> & { booking: string })[]).map(
  ({ booking, ...rest }) => ({ ...rest, bookingId: booking }),
);

const initialEditing: EditingJob[] = (seedEditing as unknown as (Omit<EditingJob, "bookingId"> & { booking: string })[]).map(
  ({ booking, ...rest }) => ({ ...rest, bookingId: booking }),
);

const initialHeirloom: HeirloomJob[] = (seedHeirloom as unknown as (Omit<HeirloomJob, "bookingId" | "proofSent"> & { booking: string; proof: string })[]).map(
  ({ booking, proof, ...rest }) => ({ ...rest, bookingId: booking, proofSent: proof !== "—" }),
);

export const useStore = create<Store>((set, get) => ({
  leads: seedLeads as Lead[],
  clients: seedClients as Client[],
  bookings: initialBookings,
  privacy: initialPrivacy,
  safety: [],
  editing: initialEditing,
  heirloom: initialHeirloom,
  memoryProfiles: [],
  pixieset: [],
  followUps: [],
  tasks: [],
  reviews: [],
  alignment: [],
  governance: [],

  hydrateFromDb: (data) => set(() => ({ ...data })),

  setLeadStatus: (leadId, status) => {
    set((s) => ({
      leads: s.leads.map((l) => (l.id === leadId ? { ...l, status } : l)),
    }));
    return ok(`Lead marked “${status}”.`);
  },

  convertLeadToClient: (leadId) => {
    const lead = get().leads.find((l) => l.id === leadId);
    if (!lead) return { ...fail("Lead not found.") };
    if (lead.convertedClientId)
      return { ...fail("This lead is already linked to a client.", false), clientId: lead.convertedClientId };

    const clientId = nextId("C", get().clients);
    const newClient: Client = {
      id: clientId,
      name: lead.parent,
      phone: lead.phone,
      email: lead.email,
      city: lead.city,
      family: lead.sessionType === "Family" ? "Family" : "—",
      childName: lead.sessionType === "Maternity" ? "—" : "—",
      dob: "—",
      pregnancy: lead.sessionType === "Maternity" ? lead.babyAge : "—",
      notes: `Memory goal: “${lead.memoryGoal}”. Source: ${lead.source}.`,
      pastSessions: 0,
      nextMilestone: `${lead.sessionType} session (preferred ${lead.preferredDate})`,
      fromLeadId: leadId,
    };
    set((s) => ({
      clients: [newClient, ...s.clients],
      leads: s.leads.map((l) =>
        l.id === leadId ? { ...l, status: "Booked", convertedClientId: clientId } : l,
      ),
    }));
    get().createTask({
      title: `Respond to new inquiry from ${lead.parent}`,
      role: "Client Coordinator",
      relatedType: "lead",
      relatedId: leadId,
      relatedLabel: lead.parent,
      priority: "High",
      sop: "SOP-01",
    });
    return { ...ok(`${lead.parent} added as a client. Their memory is now in our care.`), clientId };
  },

  createBookingForClient: (clientId, draft) => {
    const client = get().clients.find((c) => c.id === clientId);
    if (!client) return { ...fail("Client not found.") };
    const bookingId = nextId("B", get().bookings);
    const newBooking: Booking = {
      id: bookingId,
      clientId,
      client: client.name,
      category: (draft?.category ?? "Family") as SessionType,
      package: draft?.package ?? "Gold — Connection Story",
      date: draft?.date ?? `${today()} 10:00`,
      city: draft?.city ?? client.city,
      locationType: draft?.locationType ?? "Studio",
      locationDetails: draft?.locationDetails ?? "To be confirmed",
      photographer: draft?.photographer ?? "Hema",
      assistant: draft?.assistant ?? "—",
      styling: draft?.styling ?? "In-house",
      addOns: draft?.addOns ?? "—",
      price: draft?.price ?? 49500,
      offer: draft?.offer ?? 49500,
      advance: draft?.advance ?? 0,
      balance: draft?.balance ?? 49500,
      payment: "Pending",
      privacy: "Not recorded",
      safety: "Pending",
      deadline: draft?.deadline ?? "—",
      status: "Tentative",
      selectionConfirmed: false,
      albumSelectionConfirmed: false,
      journeyStage: "Quote Sent",
    };
    set((s) => ({ bookings: [newBooking, ...s.bookings] }));
    const session = newBooking.category;
    const ct = get().createTask;
    ct({ title: `Send booking confirmation to ${client.name}`, role: "Client Coordinator", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-03", priority: "High" });
    ct({ title: `Send pre-shoot guide`, role: "Client Coordinator", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-04" });
    ct({ title: `Review Memory Profile before shoot`, role: "Photographer", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-04" });
    ct({ title: `Verify advance payment`, role: "Accounts", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, priority: "High" });
    if (session === "Newborn") {
      ct({ title: `Complete newborn safety checklist`, role: "Photographer", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-05", priority: "Urgent" });
      ct({ title: `Prepare newborn props and wraps`, role: "Assistant / Baby Care Support", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-05" });
    }
    if (session === "Maternity") {
      ct({ title: `Confirm outfits and makeup`, role: "Stylist / Makeup Artist", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-06" });
      ct({ title: `Confirm maternity comfort notes`, role: "Photographer", relatedType: "booking", relatedId: bookingId, relatedLabel: client.name, sop: "SOP-06" });
    }
    return { ...ok(`Tentative booking created for ${client.name}.`), bookingId };
  },

  setBookingStatus: (bookingId, status) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    if (!b) return fail("Booking not found.");
    if (status === "Shoot Completed" && b.safety !== "Completed")
      return fail("Safety checklist must be submitted before a shoot can be marked complete.");
    set((s) => ({
      bookings: s.bookings.map((x) => (x.id === bookingId ? { ...x, status } : x)),
    }));
    if (status === "Shoot Completed") {
      const ct = get().createTask;
      ct({ title: `Prepare preview gallery for ${b.client}`, role: "Editor / Retoucher", relatedType: "booking", relatedId: bookingId, relatedLabel: b.client, sop: "SOP-08", priority: "High" });
      ct({ title: `Send selection reminder to ${b.client}`, role: "Client Coordinator", relatedType: "booking", relatedId: bookingId, relatedLabel: b.client, sop: "SOP-08" });
    }
    return ok(`Booking updated to “${status}”.`);
  },

  markShootCompleted: (bookingId) => get().setBookingStatus(bookingId, "Shoot Completed"),

  confirmSelection: (bookingId) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    set((s) => ({
      bookings: s.bookings.map((b) =>
        b.id === bookingId ? { ...b, selectionConfirmed: true } : b,
      ),
    }));
    if (b) {
      const ct = get().createTask;
      ct({ title: `Confirm full payment for ${b.client}`, role: "Accounts", relatedType: "booking", relatedId: bookingId, relatedLabel: b.client, priority: "High" });
      ct({ title: `Begin editing for ${b.client}`, role: "Editor / Retoucher", relatedType: "booking", relatedId: bookingId, relatedLabel: b.client, sop: "SOP-08" });
    }
    return ok("Image selection confirmed.");
  },

  confirmAlbumSelection: (bookingId) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    set((s) => ({
      bookings: s.bookings.map((b) =>
        b.id === bookingId ? { ...b, albumSelectionConfirmed: true } : b,
      ),
    }));
    if (b) {
      const ct = get().createTask;
      ct({ title: `Prepare album proof for ${b.client}`, role: "Album / Print Coordinator", relatedType: "booking", relatedId: bookingId, relatedLabel: b.client, sop: "SOP-09", priority: "High" });
      ct({ title: `Complete print QC for ${b.client}`, role: "Album / Print Coordinator", relatedType: "booking", relatedId: bookingId, relatedLabel: b.client, sop: "SOP-09" });
    }
    return ok("Album / frame selections confirmed.");
  },

  markPaymentPaid: (bookingId) => {
    set((s) => ({
      bookings: s.bookings.map((b) =>
        b.id === bookingId ? { ...b, payment: "Paid", balance: 0, advance: b.price } : b,
      ),
    }));
    return ok("Payment marked as fully paid.");
  },

  recordPrivacy: (rec) => {
    if (!rec.confirmed)
      return fail("Consent must be confirmed in writing by the parent before saving.");
    const id = nextId("P", get().privacy);
    set((s) => ({
      privacy: [{ ...rec, id }, ...s.privacy],
      bookings: s.bookings.map((b) =>
        b.id === rec.bookingId ? { ...b, privacy: rec.consent } : b,
      ),
    }));
    if (["Portfolio Release", "Social Media Approved", "Ads Approved"].some((k) => rec.consent.includes(k))) {
      get().createTask({
        title: `Review marketing-approved content for ${rec.client}`,
        role: "Marketing Team",
        relatedType: "booking",
        relatedId: rec.bookingId,
        relatedLabel: rec.client,
      });
    }
    return ok("Consent recorded. Marketing rules are now enforceable for this booking.");
  },

  submitSafety: (s) => {
    const required = Object.values(s.items).length;
    const completed = Object.values(s.items).filter(Boolean).length;
    if (completed < required)
      return fail(`${required - completed} item${required - completed === 1 ? "" : "s"} still unchecked. Comfort first — finish every check before submitting.`);
    const submission: SafetySubmission = {
      ...s,
      submittedAt: s.submittedAt ?? new Date().toISOString(),
    };
    set((st) => ({
      safety: [submission, ...st.safety.filter((x) => x.bookingId !== s.bookingId)],
      bookings: st.bookings.map((b) =>
        b.id === s.bookingId ? { ...b, safety: "Completed" } : b,
      ),
    }));
    return ok("Safety checklist submitted. The shoot may now be marked complete.");
  },

  startEditing: (bookingId) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    if (!b) return fail("Booking not found.");
    if (!b.selectionConfirmed)
      return fail("Image selection must be confirmed before editing can begin.");
    if (b.payment !== "Paid")
      return fail("Editing cannot begin until full payment is confirmed.");
    if (get().editing.find((e) => e.bookingId === bookingId))
      return fail("Editing job already exists for this booking.", false);
    const jobId = nextId("E", get().editing);
    const job: EditingJob = {
      id: jobId,
      bookingId,
      client: b.client,
      status: "Editing Started",
      editedCount: 0,
      selectionDate: today(),
      deadline: b.deadline,
      editor: "Unassigned",
      qc: "—",
      deliveryLink: "—",
      deliveryDate: "—",
    };
    set((s) => ({
      editing: [job, ...s.editing],
      bookings: s.bookings.map((x) => (x.id === bookingId ? { ...x, status: "Editing" } : x)),
    }));
    return { ...ok("Editing started. The story is being shaped."), jobId };
  },

  advanceEditing: (jobId) => {
    const order: EditingStatus[] = [
      "Shoot Uploaded",
      "Backup Completed",
      "Preview Gallery Sent",
      "Client Selection Pending",
      "Selection Received",
      "Full Payment Pending",
      "Editing Started",
      "Editing Completed",
      "Photographer QC",
      "Final Export",
      "Delivered",
    ];
    const job = get().editing.find((e) => e.id === jobId);
    if (!job) return fail("Editing job not found.");
    const i = order.indexOf(job.status);
    if (i === order.length - 1) return fail("Already delivered.", false);
    const next = order[i + 1];
    set((s) => ({
      editing: s.editing.map((e) =>
        e.id === jobId
          ? {
              ...e,
              status: next,
              deliveryDate: next === "Delivered" ? today() : e.deliveryDate,
            }
          : e,
      ),
      bookings:
        next === "Delivered"
          ? s.bookings.map((b) => (b.id === job.bookingId ? { ...b, status: "Delivered" } : b))
          : s.bookings,
    }));
    if (next === "Editing Completed") {
      get().createTask({
        title: `Final QC for ${job.client}`,
        role: "Founder / Studio Head",
        relatedType: "booking",
        relatedId: job.bookingId,
        relatedLabel: job.client,
        sop: "SOP-08",
        priority: "High",
      });
    }
    if (next === "Delivered") {
      get().createTask({
        title: `Send delivery message to ${job.client}`,
        role: "Client Coordinator",
        relatedType: "booking",
        relatedId: job.bookingId,
        relatedLabel: job.client,
        sop: "SOP-10",
      });
    }
    return ok(`Editing progressed to “${next}”.`);
  },

  startHeirloom: (bookingId, draft) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    if (!b) return fail("Booking not found.");
    if (!b.albumSelectionConfirmed)
      return fail("Album / frame selections must be confirmed before production starts.");
    if (get().heirloom.find((h) => h.bookingId === bookingId))
      return fail("Heirloom job already exists for this booking.", false);
    const jobId = nextId("H", get().heirloom);
    const job: HeirloomJob = {
      id: jobId,
      bookingId,
      client: b.client,
      ...draft,
      proofSent: false,
      approved: false,
      sentToProduction: false,
      produced: false,
      qc: "—",
      packed: false,
      ready: false,
      delivered: false,
    };
    set((s) => ({
      heirloom: [job, ...s.heirloom],
      bookings: s.bookings.map((x) =>
        x.id === bookingId ? { ...x, status: "Album/Frame Pending" } : x,
      ),
    }));
    return { ...ok("Heirloom production started."), jobId };
  },

  advanceHeirloom: (jobId, step) => {
    set((s) => ({
      heirloom: s.heirloom.map((h) => (h.id === jobId ? { ...h, [step]: true } : h)),
      bookings:
        step === "delivered"
          ? s.bookings.map((b) => {
              const j = get().heirloom.find((x) => x.id === jobId);
              return j && b.id === j.bookingId ? { ...b, status: "Completed" } : b;
            })
          : s.bookings,
    }));
    return ok(`Step “${step}” marked complete.`);
  },

  passHeirloomQC: (jobId) => {
    const h = get().heirloom.find((x) => x.id === jobId);
    if (!h) return fail("Heirloom job not found.");
    if (!h.produced) return fail("Production must be completed before QC.");
    set((s) => ({
      heirloom: s.heirloom.map((x) => (x.id === jobId ? { ...x, qc: "Passed" } : x)),
    }));
    return ok("QC passed. Ready for packing.");
  },

  getMemoryProfile: (ownerType, ownerId) =>
    get().memoryProfiles.find((p) => p.ownerType === ownerType && p.ownerId === ownerId),

  upsertMemoryProfile: (ownerType, ownerId, patch) => {
    const existing = get().memoryProfiles.find(
      (p) => p.ownerType === ownerType && p.ownerId === ownerId,
    );
    const base: MemoryProfile = existing ?? {
      ownerType,
      ownerId,
      memoryGoal: "",
      familyStory: "",
      importantPeople: "",
      mustCaptureMoments: "",
      comfortNeeds: "",
      sensitivities: "",
      legacyInterest: "None",
      emotionalPriority: "Simple Memory",
      notesPhotographer: "",
      notesEditor: "",
      notesAlbumDesigner: "",
      updatedAt: new Date().toISOString(),
    };
    const next: MemoryProfile = { ...base, ...patch, updatedAt: new Date().toISOString() };
    set((s) => ({
      memoryProfiles: existing
        ? s.memoryProfiles.map((p) => (p === existing ? next : p))
        : [next, ...s.memoryProfiles],
    }));
    return ok("Memory Profile saved. The story is on record.");
  },

  setJourneyStage: (bookingId, stage) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    if (!b) return fail("Booking not found.");
    // Guards
    if (stage === "Package Recommended") {
      const mp =
        get().memoryProfiles.find((p) => p.ownerType === "booking" && p.ownerId === bookingId) ||
        (b.clientId && get().memoryProfiles.find((p) => p.ownerType === "client" && p.ownerId === b.clientId!));
      if (!mp || !mp.memoryGoal.trim())
        return fail("Capture the family's Memory Goal before recommending a package.");
    }
    if (stage === "Booking Confirmed") {
      if (!b.package || b.package === "—")
        return fail("Record the chosen package before confirming the booking.");
      if (b.advance <= 0)
        return fail("Advance payment must be recorded before confirming the booking.");
    }
    if (stage === "Shoot Completed" && b.safety !== "Completed")
      return fail("Safety checklist must be submitted before marking the shoot complete.");
    if (stage === "Delivered") {
      const job = get().editing.find((e) => e.bookingId === bookingId);
      const pix = get().pixieset.find((p) => p.bookingId === bookingId);
      const editingDone = job?.status === "Delivered";
      const galleryDelivered = pix?.galleryStatus === "Delivered";
      if (!editingDone && !galleryDelivered)
        return fail("Editing or the Pixieset gallery must reach Delivered first.");
    }
    if (stage === "Completed / Relationship Active") {
      const job = get().editing.find((e) => e.bookingId === bookingId);
      const delivered = job?.status === "Delivered";
      const reviewed = !!b.reviewRequested;
      const aftercareDone = reviewed || !!b.aftercareSkipReason;
      if (!delivered) return fail("Delivery must be completed before closing the journey.");
      if (!aftercareDone)
        return fail("Request a review or record an aftercare skip reason before closing.");
    }
    set((s) => ({
      bookings: s.bookings.map((x) => (x.id === bookingId ? { ...x, journeyStage: stage } : x)),
    }));
    return ok(`Journey advanced to “${stage}”.`);
  },

  requestReview: (bookingId) => {
    set((s) => ({
      bookings: s.bookings.map((b) =>
        b.id === bookingId ? { ...b, reviewRequested: true } : b,
      ),
    }));
    return ok("Review request logged.");
  },

  skipAftercare: (bookingId, reason) => {
    if (!reason.trim()) return fail("A reason is needed to intentionally skip aftercare.");
    set((s) => ({
      bookings: s.bookings.map((b) =>
        b.id === bookingId ? { ...b, aftercareSkipReason: reason.trim() } : b,
      ),
    }));
    return ok("Aftercare intentionally skipped with reason recorded.");
  },

  upsertPixieset: (bookingId, patch) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    if (!b) return fail("Booking not found.");
    const existing = get().pixieset.find((p) => p.bookingId === bookingId);
    const base: PixiesetRecord = existing ?? {
      id: nextId("PX", get().pixieset),
      bookingId,
      clientId: b.clientId,
      client: b.client,
      pixiesetClientName: b.client,
      collectionName: `${b.client} — ${b.category}`,
      galleryLink: "",
      password: "",
      galleryStatus: "Not Created",
      watermark: "Not Needed",
      favoritesEnabled: true,
      favoritesStatus: "Pending",
      downloadEnabled: false,
      downloadExpiry: "",
      storeEnabled: false,
      priceSheet: "None",
      invoiceLink: "",
      contractLink: "",
      orderStatus: "No Order",
      syncNotes: "",
      updatedAt: new Date().toISOString(),
    };
    const next: PixiesetRecord = { ...base, ...patch, updatedAt: new Date().toISOString() };
    set((s) => ({
      pixieset: existing
        ? s.pixieset.map((p) => (p === existing ? next : p))
        : [next, ...s.pixieset],
    }));
    return ok("Pixieset record saved.");
  },

  createFollowUp: (data) => {
    const id = nextId("FU", get().followUps);
    const message =
      data.message ??
      renderTemplate(whatsappTemplates[data.messageType], buildPlaceholders(get(), data));
    const item: FollowUp = {
      id,
      client: data.client,
      bookingId: data.bookingId,
      leadId: data.leadId,
      messageType: data.messageType,
      message,
      scheduledDate: data.scheduledDate,
      status: data.status,
      sentBy: data.sentBy,
      notes: data.notes ?? "",
      createdAt: new Date().toISOString(),
    };
    set((s) => ({ followUps: [item, ...s.followUps] }));
    return { ...ok(`“${data.messageType}” follow-up saved.`), followUpId: id };
  },

  updateFollowUp: (id, patch) => {
    set((s) => ({
      followUps: s.followUps.map((f) => (f.id === id ? { ...f, ...patch } : f)),
    }));
    return ok("Follow-up updated.");
  },

  createTask: (data) => {
    const id = nextId("T", get().tasks);
    const item: Task = {
      id,
      title: data.title,
      relatedType: data.relatedType,
      relatedId: data.relatedId,
      relatedLabel: data.relatedLabel,
      role: data.role,
      assignee: data.assignee ?? "Unassigned",
      dueDate: data.dueDate ?? today(),
      priority: data.priority ?? "Medium",
      status: data.status ?? "Pending",
      sop: data.sop,
      notes: data.notes ?? "",
      createdAt: new Date().toISOString(),
    };
    set((s) => ({ tasks: [item, ...s.tasks] }));
    return { ...ok(`Task created: ${data.title}`), taskId: id };
  },

  updateTask: (id, patch) => {
    set((s) => ({
      tasks: s.tasks.map((t) => (t.id === id ? { ...t, ...patch } : t)),
    }));
    return ok("Task updated.");
  },

  upsertReview: (bookingId, patch) => {
    const b = get().bookings.find((x) => x.id === bookingId);
    if (!b) return fail("Booking not found.");
    const existing = get().reviews.find((r) => r.bookingId === bookingId);
    const base: Review = existing ?? {
      id: nextId("R", get().reviews),
      bookingId,
      client: b.client,
      sessionType: b.category,
      requestStatus: "Pending",
      testimonial: "",
      permissionToUse: false,
      consentProof: "",
      issueRaised: false,
      resolutionNotes: "",
      repeatOpportunity: false,
      nextMilestoneDate: "",
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    const next: Review = { ...base, ...patch, updatedAt: new Date().toISOString() };
    set((s) => ({
      reviews: existing
        ? s.reviews.map((r) => (r === existing ? next : r))
        : [next, ...s.reviews],
    }));
    if (patch.requestStatus === "Requested" && (!existing || existing.requestStatus !== "Requested")) {
      set((s) => ({
        bookings: s.bookings.map((x) => (x.id === bookingId ? { ...x, reviewRequested: true } : x)),
      }));
      get().createTask({
        title: `Follow up if review not received from ${b.client}`,
        role: "Client Coordinator",
        relatedType: "booking",
        relatedId: bookingId,
        relatedLabel: b.client,
        sop: "SOP-10",
      });
    }
    if (patch.permissionToUse && (!existing || !existing.permissionToUse)) {
      get().createTask({
        title: `Ask permission to use testimonial — ${b.client}`,
        role: "Marketing Team",
        relatedType: "booking",
        relatedId: bookingId,
        relatedLabel: b.client,
      });
    }
    if (patch.repeatOpportunity && next.nextMilestoneDate) {
      get().createTask({
        title: `Milestone follow-up — ${b.client} (${next.nextMilestoneDate})`,
        role: "Client Coordinator",
        relatedType: "booking",
        relatedId: bookingId,
        relatedLabel: b.client,
        dueDate: next.nextMilestoneDate,
      });
    }
    return ok("Review record saved.");
  },

  setAlignmentScore: (bookingId, dimension, score) => {
    if (score < 1 || score > 5) return fail("Score must be between 1 and 5.");
    const existing = get().alignment.find((a) => a.bookingId === bookingId);
    const base: AlignmentScore = existing ?? { bookingId, scores: {}, notes: "", updatedAt: new Date().toISOString() };
    const next: AlignmentScore = {
      ...base,
      scores: { ...base.scores, [dimension]: score },
      updatedAt: new Date().toISOString(),
    };
    set((s) => ({
      alignment: existing ? s.alignment.map((a) => (a === existing ? next : a)) : [next, ...s.alignment],
    }));
    return ok(`“${dimension}” scored ${score}/5.`);
  },

  setAlignmentNotes: (bookingId, notes) => {
    const existing = get().alignment.find((a) => a.bookingId === bookingId);
    const base: AlignmentScore = existing ?? { bookingId, scores: {}, notes: "", updatedAt: new Date().toISOString() };
    const next: AlignmentScore = { ...base, notes, updatedAt: new Date().toISOString() };
    set((s) => ({
      alignment: existing ? s.alignment.map((a) => (a === existing ? next : a)) : [next, ...s.alignment],
    }));
    return ok("Alignment notes saved.");
  },

  saveGovernanceRun: (cadence, items, completedBy = "Hema") => {
    const id = nextId("G", get().governance);
    const run: GovernanceRun = { id, cadence, date: today(), items, completedBy };
    set((s) => ({ governance: [run, ...s.governance] }));
    return ok(`${cadence[0].toUpperCase() + cadence.slice(1)} governance run saved.`);
  },
}));

/* ───────────── Derived helpers ───────────── */

export function bookingFlags(b: Booking) {
  const marketingAllowed = ["Portfolio Release", "Social Media Approved", "Ads Approved"].some((k) =>
    b.privacy.includes(k),
  );
  const consentRecorded = b.privacy !== "Not recorded";
  const canCompleteShoot = b.safety === "Completed";
  const canStartEditing = b.selectionConfirmed && b.payment === "Paid";
  const canStartHeirloom = b.albumSelectionConfirmed;
  return { marketingAllowed, consentRecorded, canCompleteShoot, canStartEditing, canStartHeirloom };
}

/* ───────────── Alignment helpers ───────────── */

export function alignmentAverage(scores: AlignmentScore["scores"]): number {
  const vals = Object.values(scores).filter((v): v is number => typeof v === "number");
  if (!vals.length) return 0;
  return Math.round((vals.reduce((a, b) => a + b, 0) / vals.length) * 10) / 10;
}

export function bookingAlignment(bookingId: string, alignment: AlignmentScore[]): number {
  const rec = alignment.find((a) => a.bookingId === bookingId);
  return rec ? alignmentAverage(rec.scores) : 0;
}

export { alignmentDimensions };

/* ───────────── Template helpers ───────────── */

export function renderTemplate(template: string, vars: Record<string, string>) {
  return Object.entries(vars).reduce(
    (acc, [k, v]) => acc.split(k).join(v || k),
    template,
  );
}

type StoreSnapshot = {
  bookings: Booking[];
  leads: Lead[];
  pixieset: PixiesetRecord[];
  memoryProfiles: MemoryProfile[];
};

export function buildPlaceholders(
  s: StoreSnapshot,
  ctx: { client: string; bookingId?: string; leadId?: string },
): Record<string, string> {
  const b = ctx.bookingId ? s.bookings.find((x) => x.id === ctx.bookingId) : undefined;
  const l = ctx.leadId ? s.leads.find((x) => x.id === ctx.leadId) : undefined;
  const pix = ctx.bookingId ? s.pixieset.find((p) => p.bookingId === ctx.bookingId) : undefined;
  const mp = b
    ? s.memoryProfiles.find((p) => p.ownerType === "booking" && p.ownerId === b.id)
    : undefined;
  return {
    "[Client Name]": ctx.client || b?.client || l?.parent || "",
    "[Session Type]": (b?.category as string) || (l?.sessionType as string) || "",
    "[Package Name]": b?.package || l?.package || "",
    "[Shoot Date]": b?.date || l?.preferredDate || "",
    "[Balance Amount]": b ? `₹${b.balance.toLocaleString("en-IN")}` : "",
    "[Gallery Link]": pix?.galleryLink || "—",
    "[Privacy Choice]": b?.privacy || "your privacy preferences",
    "[Delivery Timeline]": b?.deadline || "10–14 days",
    "[Review Link]": "https://g.page/littleshots/review",
    "[Memory Goal]": mp?.memoryGoal || l?.memoryGoal || "",
  };
}