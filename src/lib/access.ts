import {
  Home,
  Handshake,
  Camera,
  Wand2,
  PackageCheck,
  HeartHandshake,
  Settings as SettingsIcon,
} from "lucide-react";
import type { AppRole } from "@/lib/session";

export type NavItem = {
  to: string;
  label: string;
  icon: typeof Home;
  /** `null` = every studio role. `[]` = Founder only. */
  roles: AppRole[] | null;
  /** One line describing what the module is for. */
  blurb?: string;
};

/**
 * The studio has six modules and a dashboard.
 *
 * Everything a person does lives inside one of them, and each one owns a
 * contiguous run of the booking journey. The older single-purpose screens
 * still exist and still work; they are reached from inside the module that
 * owns them rather than from a flat list of twenty-six links.
 */
export const nav: NavItem[] = [
  { to: "/", label: "Dashboard", icon: Home, roles: null },
  {
    to: "/sales",
    label: "Sales",
    icon: Handshake,
    roles: ["studio_manager", "client_coordinator", "sales_head", "sales", "accounts"],
    blurb: "Enquiry through to a confirmed booking",
  },
  {
    to: "/production",
    label: "Production",
    icon: Camera,
    roles: ["studio_manager", "client_coordinator", "photographer", "assistant", "stylist"],
    blurb: "Booked through to the shoot and selection",
  },
  {
    to: "/post-production",
    label: "Post Production",
    icon: Wand2,
    roles: ["studio_manager", "editor", "videographer", "client_coordinator"],
    blurb: "Editing, video and QC through to the gallery",
  },
  {
    to: "/delivery",
    label: "Delivery",
    icon: PackageCheck,
    roles: ["studio_manager", "client_coordinator", "album_coordinator"],
    blurb: "Gallery, balance and album or frame production",
  },
  {
    to: "/marketing-hub",
    label: "Marketing",
    icon: HeartHandshake,
    roles: ["studio_manager", "client_coordinator", "marketing"],
    blurb: "Reviews, next-session plans and closing the file",
  },
  {
    to: "/admin",
    label: "Admin",
    icon: SettingsIcon,
    roles: ["studio_manager"],
    blurb: "Who can do what, stage targets, team and catalogue",
  },
];

/* ───────────── Module contents ───────────── */

export type ModuleLink = {
  to: string;
  label: string;
  description: string;
};

/**
 * The existing single-purpose screens, filed under the module that owns
 * them. A link whose path is temporarily unavailable is hidden.
 */
export const moduleLinks: Record<string, ModuleLink[]> = {
  "/sales": [
    { to: "/leads", label: "Leads", description: "Every enquiry and where it stands" },
    { to: "/quote", label: "Quote Builder", description: "Build and send a quotation" },
    { to: "/clients", label: "Families", description: "Family records and contact history" },
    { to: "/packages", label: "Packages", description: "What the studio sells, and for how much" },
    { to: "/whatsapp", label: "Follow-Ups", description: "WhatsApp follow-up prompts" },
    { to: "/memory", label: "Memory Profiles", description: "What matters to each family" },
    {
      to: "/guide-reviews",
      label: "Memory Guide Reviews",
      description: "Review the guide before it is sent",
    },
  ],
  "/production": [
    { to: "/bookings", label: "Bookings", description: "Every confirmed booking" },
    { to: "/pipeline", label: "Pipeline", description: "The whole journey at a glance" },
    { to: "/prep", label: "Shoot Prep", description: "Prepare for the session" },
    { to: "/safety", label: "Safety & Comfort", description: "Newborn safety checklist" },
  ],
  "/post-production": [],
  "/delivery": [{ to: "/privacy", label: "Privacy & Consent", description: "Consent to publish" }],
  "/marketing-hub": [
    { to: "/marketing", label: "Marketing Approvals", description: "Approve images for use" },
  ],
  "/admin": [
    { to: "/team", label: "Team", description: "People, roles and invitations" },
    { to: "/settings", label: "Settings", description: "Studio profile and preferences" },
    { to: "/tasks", label: "Team Tasks", description: "Everything assigned to someone" },
    { to: "/sops", label: "SOP Center", description: "How the studio does things" },
    { to: "/governance", label: "Governance", description: "Philosophy alignment scoring" },
    { to: "/reports", label: "Reports", description: "Numbers on the studio" },
    { to: "/kpi", label: "KPI Detail", description: "The detail behind the numbers" },
  ],
};

function normalise(pathname: string) {
  if (pathname !== "/" && pathname.endsWith("/")) return pathname.slice(0, -1);
  return pathname;
}

/**
 * Screens that still depend on the legacy seeded booking store.
 *
 * Their source is kept for deliberate migration, but they are not exposed
 * as operational studio systems until they read canonical booking and
 * journey records.
 */
export const temporarilyUnavailablePaths = new Set([
  "/prep",
  "/safety",
  "/privacy",
  "/marketing",
  "/governance",
  "/reports",
  "/kpi",
]);

export function isTemporarilyUnavailable(pathname: string) {
  return temporarilyUnavailablePaths.has(normalise(pathname));
}

/** The links inside a module that are actually usable right now. */
export function availableModuleLinks(modulePath: string): ModuleLink[] {
  return (moduleLinks[normalise(modulePath)] ?? []).filter(
    (link) => !temporarilyUnavailablePaths.has(link.to),
  );
}

export function visibleNav(roles: AppRole[]) {
  const available = nav.filter((item) => !temporarilyUnavailablePaths.has(item.to));

  if (roles.includes("founder")) return available;

  return available.filter(
    (item) => item.roles === null || item.roles.some((r) => roles.includes(r)),
  );
}

/**
 * Roles allowed into each legacy screen, kept so a typed URL is still
 * checked even though these no longer appear in the sidebar.
 */
const legacyRoles: Record<string, AppRole[] | null> = {
  "/leads": ["studio_manager", "client_coordinator", "sales_head", "sales"],
  "/guide-reviews": ["client_coordinator", "sales"],
  "/clients": ["studio_manager", "client_coordinator", "sales", "accounts"],
  "/memory": [
    "studio_manager",
    "client_coordinator",
    "sales",
    "photographer",
    "assistant",
    "stylist",
    "videographer",
    "editor",
    "album_coordinator",
    "marketing",
    "accounts",
  ],
  "/bookings": null,
  "/pipeline": null,
  "/packages": ["studio_manager", "client_coordinator", "sales_head", "sales", "accounts"],
  "/quote": ["studio_manager", "client_coordinator", "sales_head", "sales", "accounts"],
  "/whatsapp": ["studio_manager", "client_coordinator", "sales_head", "sales"],
  "/tasks": null,
  "/sops": null,
  "/team": ["studio_manager", "client_coordinator"],
  "/settings": null,
  "/training": null,
  // Superseded by the six modules, still reachable by URL.
  "/editing": ["studio_manager", "editor", "client_coordinator"],
  "/pixieset": ["studio_manager", "editor", "client_coordinator"],
  "/heirloom": ["studio_manager", "album_coordinator", "client_coordinator"],
  "/reviews": ["studio_manager", "client_coordinator", "marketing"],
};

/** Can this person open this screen at all (typed URL included)? */
export function canView(pathname: string, roles: AppRole[]) {
  const path = normalise(pathname);

  if (temporarilyUnavailablePaths.has(path)) return false;
  if (roles.includes("founder")) return true;

  const item = nav.find((n) => n.to === path);
  if (item) {
    if (item.roles === null) return true;
    return item.roles.some((r) => roles.includes(r));
  }

  if (path in legacyRoles) {
    const allowed = legacyRoles[path];
    if (allowed === null) return true;
    return allowed.some((r) => roles.includes(r));
  }

  return true; // unknown path — let the router's not-found handle it
}

/* ───────────── Action permissions ───────────── */

export type Action =
  | "leads.write"
  | "clients.write"
  | "bookings.write"
  | "bookings.finance"
  | "pipeline.advance"
  | "memory.write"
  | "safety.write"
  | "privacy.write"
  | "editing.write"
  | "pixieset.write"
  | "heirloom.write"
  | "tasks.write"
  | "marketing.approve"
  | "reviews.write"
  | "governance.write"
  | "links.share";

/** Founder always passes. Everyone else needs one of the listed roles. */
export const permissions: Record<Action, { label: string; roles: AppRole[] }> = {
  "leads.write": {
    label: "Add and update inquiries",
    roles: ["studio_manager", "client_coordinator", "sales_head", "sales"],
  },
  "clients.write": {
    label: "Edit family records",
    roles: ["studio_manager", "client_coordinator", "sales"],
  },
  "bookings.write": {
    label: "Create and edit bookings",
    roles: ["client_coordinator", "sales"],
  },
  "bookings.finance": {
    label: "Change money fields (price, advance, payment)",
    roles: ["accounts", "sales"],
  },
  "pipeline.advance": { label: "Advance a family's journey stage", roles: ["client_coordinator"] },
  "memory.write": {
    label: "Write memory profiles",
    roles: ["studio_manager", "client_coordinator", "sales", "photographer"],
  },
  "safety.write": {
    label: "Complete safety & comfort checklists",
    roles: ["client_coordinator", "photographer", "assistant"],
  },
  "privacy.write": {
    label: "Record privacy & consent",
    roles: ["client_coordinator", "marketing"],
  },
  "editing.write": {
    label: "Move editing & delivery status",
    roles: ["editor", "client_coordinator"],
  },
  "pixieset.write": { label: "Manage Pixieset galleries", roles: ["editor", "client_coordinator"] },
  "heirloom.write": {
    label: "Run heirloom production",
    roles: ["album_coordinator", "client_coordinator"],
  },
  "tasks.write": {
    label: "Create and close team tasks",
    roles: [
      "client_coordinator",
      "sales_head",
      "sales",
      "photographer",
      "assistant",
      "stylist",
      "editor",
      "album_coordinator",
      "marketing",
      "accounts",
    ],
  },
  "marketing.approve": { label: "Approve images for marketing", roles: ["marketing"] },
  "reviews.write": {
    label: "Request reviews and log aftercare",
    roles: ["client_coordinator", "marketing"],
  },
  "governance.write": { label: "Score philosophy alignment", roles: ["client_coordinator"] },
  "links.share": {
    label: "Create family share links",
    roles: ["client_coordinator", "sales_head", "sales"],
  },
};

export function can(action: Action, roles: AppRole[]) {
  if (roles.includes("founder")) return true;
  return permissions[action].roles.some((r) => roles.includes(r));
}
