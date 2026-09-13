export const TRAINING_NAVIGATION_EVENT = "lsh:training-navigation";

export type GuidedInterfaceTourStep = {
  key: string;
  target: string;
  eyebrow: string;
  title: string;
  body: string;
  openNavigation: boolean;
};

export const guidedInterfaceTourSteps: readonly GuidedInterfaceTourStep[] = [
  {
    key: "operating-rooms",
    target: "main-navigation",
    eyebrow: "Your operating rooms",
    title: "Use the navigation that belongs to your role",
    body: "These are the LittleShots by Hema OS rooms currently available to your live role. A room that is absent or restricted should never be worked around manually.",
    openNavigation: true,
  },
  {
    key: "signed-in-role",
    target: "signed-in-role",
    eyebrow: "Your authority",
    title: "Always know which role you are working as",
    body: "Your signed-in role is part of the authorization boundary. Training can explain your scope, but it cannot add a role or widen access.",
    openNavigation: true,
  },
  {
    key: "help-and-training",
    target: "training-help",
    eyebrow: "Help stays available",
    title: "Return to Help & Training whenever you need guidance",
    body: "Help & Training is a permanent way back to onboarding and future role guidance. It does not change client records or operational authority.",
    openNavigation: true,
  },
];
