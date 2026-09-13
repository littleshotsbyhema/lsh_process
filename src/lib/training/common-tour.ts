export type CommonOrientationStepKey =
  | "welcome"
  | "role-scope"
  | "navigation"
  | "evidence-before-status"
  | "privacy"
  | "escalation"
  | "help";

export type CommonOrientationStep = {
  key: CommonOrientationStepKey;
  eyebrow: string;
  title: string;
  body: string;
};

export const commonOrientationSteps: readonly CommonOrientationStep[] = [
  {
    key: "welcome",
    eyebrow: "Welcome",
    title: "LittleShots by Hema OS is our system of record",
    body: "Important studio work belongs in the OS. A phone call or WhatsApp message may carry a conversation, but the operational truth must still be reflected in the system.",
  },
  {
    key: "role-scope",
    eyebrow: "Your access",
    title: "Your role and studio scope are intentional",
    body: "The rooms, records, and studios you can access come from your real role and branch grants. If something is outside your role or branch, do not work around the restriction.",
  },
  {
    key: "navigation",
    eyebrow: "Navigation",
    title: "Start from the rooms assigned to your role",
    body: "Use the LittleShots by Hema OS navigation to move between the operating rooms available to you. Role-specific training will later guide the exact workflow inside each room.",
  },
  {
    key: "evidence-before-status",
    eyebrow: "Operational truth",
    title: "Evidence comes before status",
    body: "Never move work forward only because someone says it is complete. Required evidence must exist before a controlled status or journey stage is changed.",
  },
  {
    key: "privacy",
    eyebrow: "Trust",
    title: "Access does not mean permission to share",
    body: "Only use family information for the work your role requires. Do not copy private information into personal notes, personal cloud storage, or casual messaging, and never assume marketing consent.",
  },
  {
    key: "escalation",
    eyebrow: "Exceptions",
    title: "Stop and ask instead of improvising",
    body: "If a workflow looks wrong, required evidence is missing, a family raises a sensitive concern, or you are unsure about your authority, stop and escalate to the Studio Manager or Founder.",
  },
  {
    key: "help",
    eyebrow: "Help",
    title: "Training and help stay available",
    body: "You can return to Help & Training at any time. Role-specific guided practice will be added here without using real client records as training material.",
  },
];
