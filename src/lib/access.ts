import {
  Home,
  Heart,
  Users,
  CalendarHeart,
  Sparkles,
  ShieldCheck,
  ClipboardCheck,
  Image as ImageIcon,
  Frame,
  LineChart,
  BookHeart,
  Camera,
  MessageSquareHeart,
  ListChecks,
  GitBranch,
  FileText,
  Clipboard,
  Star,
  Megaphone,
  Gauge,
  UsersRound,
  BookOpen,
  Settings as SettingsIcon,
  BrainCircuit,
} from "lucide-react";
import type { AppRole } from "@/lib/session";

export type NavItem = {
  to: string;
  label: string;
  icon: typeof Home;
  /** `null` = every studio role. `[]` = Founder only. */
  roles: AppRole[] | null;
};

export const nav: NavItem[] = [
  { to: "/", label: "Dashboard", icon: Home, roles: null },
  {
    to: "/leads",
    label: "Leads",
    icon: Heart,
    roles: ["studio_manager", "client_coordinator", "sales_head", "sales"],
  },
  {
    to: "/guide-reviews",
    label: "Memory Guide Reviews",
    icon: BrainCircuit,
    roles: ["client_coordinator", "sales"],
  },
  {
    to: "/clients",
    label: "Clients",
    icon: Users,
    roles: ["studio_manager", "client_coordinator", "sales", "accounts"],
  },
  {
    to: "/memory",
    label: "Memory Profiles",
    icon: BookHeart,
    roles: [
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
  },
  { to: "/bookings", label: "Bookings", icon: CalendarHeart, roles: null },
  { to: "/pipeline", label: "Pipeline", icon: GitBranch, roles: null },
  {
    to: "/packages",
    label: "Packages",
    icon: Sparkles,
    roles: ["studio_manager", "client_coordinator", "sales_head", "sales", "accounts"],
  },
  {
    to: "/quote",
    label: "Quote Builder",
    icon: FileText,
    roles: ["studio_manager", "client_coordinator", "sales_head", "sales", "accounts"],
  },
  {
    to: "/whatsapp",
    label: "WhatsApp Follow-Ups",
    icon: MessageSquareHeart,
    roles: ["studio_manager", "client_coordinator", "sales_head", "sales"],
  },
  {
    to: "/prep",
    label: "Shoot Prep",
    icon: Clipboard,
    roles: ["client_coordinator", "photographer", "assistant", "stylist"],
  },
  {
    to: "/safety",
    label: "Safety & Comfort",
    icon: ClipboardCheck,
    roles: ["client_coordinator", "photographer", "assistant"],
  },
  {
    to: "/privacy",
    label: "Privacy & Consent",
    icon: ShieldCheck,
    roles: ["client_coordinator", "marketing"],
  },
  {
    to: "/editing",
    label: "Editing & QC",
    icon: ImageIcon,
    roles: ["studio_manager", "editor", "client_coordinator"],
  },
  {
    to: "/pixieset",
    label: "Gallery & Delivery",
    icon: Camera,
    roles: ["studio_manager", "editor", "client_coordinator"],
  },
  {
    to: "/heirloom",
    label: "Heirloom Production",
    icon: Frame,
    roles: ["studio_manager", "album_coordinator", "client_coordinator"],
  },
  { to: "/tasks", label: "Team Tasks", icon: ListChecks, roles: null },
  { to: "/sops", label: "SOP Center", icon: BookOpen, roles: null },
  { to: "/marketing", label: "Marketing Approvals", icon: Megaphone, roles: ["marketing"] },
  {
    to: "/reviews",
    label: "Reviews & Aftercare",
    icon: Star,
    roles: ["studio_manager", "client_coordinator", "marketing"],
  },
  { to: "/governance", label: "Governance", icon: Gauge, roles: [] },
  { to: "/reports", label: "Reports / KPIs", icon: LineChart, roles: ["accounts"] },
  { to: "/kpi", label: "KPI Detail", icon: LineChart, roles: ["accounts"] },
  {
    to: "/team",
    label: "Team",
    icon: UsersRound,
    roles: ["studio_manager", "client_coordinator"],
  },
  { to: "/settings", label: "Settings", icon: SettingsIcon, roles: null },
];

function normalise(pathname: string) {
  if (pathname !== "/" && pathname.endsWith("/")) return pathname.slice(0, -1);
  return pathname;
}

/**
 * Rooms that still depend on the legacy seeded booking store.
 *
 * Keep their source available for deliberate migration, but do not expose
 * them as operational studio systems until they are connected to canonical
 * booking and journey records.
 *
 * Editing, Gallery & Delivery, Heirloom Production and Reviews & Aftercare
 * were migrated onto the canonical Stage 13-21 journey and are live.
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

export function visibleNav(roles: AppRole[]) {
  const available = nav.filter((item) => !temporarilyUnavailablePaths.has(item.to));

  if (roles.includes("founder")) return available;

  return available.filter(
    (item) => item.roles === null || item.roles.some((r) => roles.includes(r)),
  );
}

/** Can this person open this module at all (typed URL included)? */
export function canView(pathname: string, roles: AppRole[]) {
  const path = normalise(pathname);

  if (temporarilyUnavailablePaths.has(path)) return false;
  if (roles.includes("founder")) return true;

  const item = nav.find((n) => n.to === path);
  if (!item) return true; // unknown path — let the router's not-found handle it
  if (item.roles === null) return true;
  return item.roles.some((r) => roles.includes(r));
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
