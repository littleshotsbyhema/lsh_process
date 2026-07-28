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
  { to: "/leads", label: "Leads", icon: Heart, roles: ["coordinator", "sales"] },
  { to: "/clients", label: "Clients", icon: Users, roles: ["coordinator", "sales", "accounts"] },
  { to: "/memory", label: "Memory Profiles", icon: BookHeart, roles: null },
  { to: "/bookings", label: "Bookings", icon: CalendarHeart, roles: null },
  { to: "/pipeline", label: "Pipeline", icon: GitBranch, roles: null },
  {
    to: "/packages",
    label: "Packages",
    icon: Sparkles,
    roles: ["coordinator", "sales", "accounts"],
  },
  {
    to: "/quote",
    label: "Quote Builder",
    icon: FileText,
    roles: ["coordinator", "sales", "accounts"],
  },
  {
    to: "/whatsapp",
    label: "WhatsApp Follow-Ups",
    icon: MessageSquareHeart,
    roles: ["coordinator", "sales"],
  },
  {
    to: "/prep",
    label: "Shoot Prep",
    icon: Clipboard,
    roles: ["coordinator", "photographer", "assistant", "stylist"],
  },
  {
    to: "/safety",
    label: "Safety & Comfort",
    icon: ClipboardCheck,
    roles: ["coordinator", "photographer", "assistant"],
  },
  {
    to: "/privacy",
    label: "Privacy & Consent",
    icon: ShieldCheck,
    roles: ["coordinator", "marketing"],
  },
  {
    to: "/editing",
    label: "Editing & Delivery",
    icon: ImageIcon,
    roles: ["editor", "coordinator"],
  },
  { to: "/pixieset", label: "Pixieset Control", icon: Camera, roles: ["editor", "coordinator"] },
  { to: "/heirloom", label: "Heirloom Production", icon: Frame, roles: ["album", "coordinator"] },
  { to: "/tasks", label: "Team Tasks", icon: ListChecks, roles: null },
  { to: "/sops", label: "SOP Center", icon: BookOpen, roles: null },
  { to: "/marketing", label: "Marketing Approvals", icon: Megaphone, roles: ["marketing"] },
  { to: "/reviews", label: "Reviews & Aftercare", icon: Star, roles: ["coordinator", "marketing"] },
  { to: "/governance", label: "Governance", icon: Gauge, roles: [] },
  { to: "/reports", label: "Reports / KPIs", icon: LineChart, roles: ["accounts"] },
  { to: "/kpi", label: "KPI Detail", icon: LineChart, roles: ["accounts"] },
  { to: "/team", label: "Team", icon: UsersRound, roles: [] },
  { to: "/settings", label: "Settings", icon: SettingsIcon, roles: null },
];

export function visibleNav(roles: AppRole[]) {
  if (roles.includes("founder")) return nav;
  return nav.filter((item) => item.roles === null || item.roles.some((r) => roles.includes(r)));
}

function normalise(pathname: string) {
  if (pathname !== "/" && pathname.endsWith("/")) return pathname.slice(0, -1);
  return pathname;
}

/** Can this person open this module at all (typed URL included)? */
export function canView(pathname: string, roles: AppRole[]) {
  if (roles.includes("founder")) return true;
  const path = normalise(pathname);
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
  | "links.share"
  | "team.manage";

/** Founder always passes. Everyone else needs one of the listed roles. */
export const permissions: Record<Action, { label: string; roles: AppRole[] }> = {
  "leads.write": { label: "Add and update inquiries", roles: ["coordinator", "sales"] },
  "clients.write": { label: "Edit family records", roles: ["coordinator", "sales"] },
  "bookings.write": { label: "Create and edit bookings", roles: ["coordinator", "sales"] },
  "bookings.finance": {
    label: "Change money fields (price, advance, payment)",
    roles: ["accounts", "sales"],
  },
  "pipeline.advance": { label: "Advance a family's journey stage", roles: ["coordinator"] },
  "memory.write": {
    label: "Write memory profiles",
    roles: ["coordinator", "sales", "photographer"],
  },
  "safety.write": {
    label: "Complete safety & comfort checklists",
    roles: ["coordinator", "photographer", "assistant"],
  },
  "privacy.write": { label: "Record privacy & consent", roles: ["coordinator", "marketing"] },
  "editing.write": { label: "Move editing & delivery status", roles: ["editor", "coordinator"] },
  "pixieset.write": { label: "Manage Pixieset galleries", roles: ["editor", "coordinator"] },
  "heirloom.write": { label: "Run heirloom production", roles: ["album", "coordinator"] },
  "tasks.write": {
    label: "Create and close team tasks",
    roles: [
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
  "marketing.approve": { label: "Approve images for marketing", roles: ["marketing"] },
  "reviews.write": {
    label: "Request reviews and log aftercare",
    roles: ["coordinator", "marketing"],
  },
  "governance.write": { label: "Score philosophy alignment", roles: ["coordinator"] },
  "links.share": { label: "Create family share links", roles: ["coordinator", "sales"] },
  "team.manage": { label: "Invite teammates and assign roles", roles: [] },
};

export function can(action: Action, roles: AppRole[]) {
  if (roles.includes("founder")) return true;
  return permissions[action].roles.some((r) => roles.includes(r));
}
