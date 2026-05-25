export type SessionType = "Maternity" | "Newborn" | "Sitter" | "Baby" | "Child" | "Family";

export const sessionTypes: SessionType[] = ["Maternity", "Newborn", "Sitter", "Baby", "Child", "Family"];

export const leadStatuses = [
  "New Inquiry",
  "Contacted",
  "Package Shared",
  "Consultation Done",
  "Follow-Up Needed",
  "Booked",
  "Lost",
  "Future Lead",
] as const;
export type LeadStatus = (typeof leadStatuses)[number];

export const bookingStatuses = [
  "Tentative",
  "Advance Pending",
  "Confirmed",
  "Pre-Shoot Prep",
  "Shoot Completed",
  "Selection Pending",
  "Editing",
  "Delivered",
  "Album/Frame Pending",
  "Completed",
] as const;
export type BookingStatus = (typeof bookingStatuses)[number];

export const editingStatuses = [
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
] as const;
export type EditingStatus = (typeof editingStatuses)[number];

export const journeyStages = [
  "New Inquiry",
  "Details Collected",
  "Memory Goal Captured",
  "Package Recommended",
  "Quote Sent",
  "Follow-Up Pending",
  "Booking Confirmed",
  "Pre-Shoot Preparation",
  "Shoot Scheduled",
  "Shoot Completed",
  "Selection Pending",
  "Editing Pending",
  "Editing in Progress",
  "QC Pending",
  "Pixieset Gallery Ready",
  "Delivered",
  "Album / Frame Production",
  "Review Requested",
  "Milestone Follow-Up",
  "Completed / Relationship Active",
] as const;
export type JourneyStage = (typeof journeyStages)[number];

export const legacyInterestOptions = [
  "Album",
  "Frame",
  "Prints",
  "Cinematic Reel",
  "None",
] as const;
export type LegacyInterest = (typeof legacyInterestOptions)[number];

export const emotionalPriorityOptions = [
  "Simple Memory",
  "Family Connection",
  "Heirloom Story",
  "Complete Legacy",
] as const;
export type EmotionalPriority = (typeof emotionalPriorityOptions)[number];

/* ───────── Pixieset ───────── */
export const pixiesetGalleryStatuses = [
  "Not Created",
  "Draft",
  "Sent",
  "Viewed",
  "Selection Done",
  "Delivered",
] as const;
export type PixiesetGalleryStatus = (typeof pixiesetGalleryStatuses)[number];

export const pixiesetOrderStatuses = ["No Order", "Ordered", "Paid", "Fulfilled"] as const;
export type PixiesetOrderStatus = (typeof pixiesetOrderStatuses)[number];

export const pixiesetPriceSheets = ["Album", "Frame", "Print", "Digital", "None"] as const;
export type PixiesetPriceSheet = (typeof pixiesetPriceSheets)[number];

/* ───────── WhatsApp templates ───────── */
export const whatsappMessageTypes = [
  "New Inquiry",
  "Package Recommendation",
  "Quote Sent",
  "Follow-Up 1",
  "Follow-Up 2",
  "Booking Confirmation",
  "Pre-Shoot Guide",
  "Payment Reminder",
  "Selection Reminder",
  "Editing Update",
  "Delivery Message",
  "Album Proof Approval",
  "Review Request",
  "Milestone Follow-Up",
] as const;
export type WhatsappMessageType = (typeof whatsappMessageTypes)[number];

export const whatsappTemplates: Record<WhatsappMessageType, string> = {
  "New Inquiry":
    "Hello [Client Name], this is Hema from Little Shots. Thank you for reaching out about your [Session Type] session. We'd love to hear the moment you most want to preserve — there is no rush. When you're ready, we'll gently guide you through how we work.",
  "Package Recommendation":
    "Hi [Client Name], based on what you shared, the [Package Name] feels like a beautiful fit for your [Session Type]. It's designed for families who want their story to truly live on. Would you like me to share the full inclusions and a few sample stories?",
  "Quote Sent":
    "Hi [Client Name], I've shared the gentle quote for your [Package Name] · [Session Type] session. Take your time looking through it. If anything feels unclear, I'm one message away — no pressure at all.",
  "Follow-Up 1":
    "Hi [Client Name], just a soft check-in on your [Session Type] session. We're holding the date warmly for you and would love to know if you'd like to move forward.",
  "Follow-Up 2":
    "Hi [Client Name], thinking of you and your family. If the timing isn't right, that's completely okay — we'll be here whenever you feel ready to preserve this chapter.",
  "Booking Confirmation":
    "Welcome to the Little Shots family, [Client Name]. Your [Session Type] session on [Shoot Date] is confirmed. We'll send you a gentle pre-shoot guide soon so the day feels calm and prepared.",
  "Pre-Shoot Guide":
    "Hi [Client Name], here is your warm pre-shoot guide for [Shoot Date]. It covers comfort, outfits, timings, and what to expect. Please read it slowly — and tell us anything that would help you feel at ease.",
  "Payment Reminder":
    "Hi [Client Name], a soft reminder that the balance of [Balance Amount] is due before we begin editing. Whenever it's convenient for you — we're here to help with any payment option.",
  "Selection Reminder":
    "Hi [Client Name], your preview gallery is ready. When you're ready, please mark your favourites at [Gallery Link]. Take all the time you need — these are your memories.",
  "Editing Update":
    "Hi [Client Name], editing for your [Session Type] story has begun. We're shaping it with care and will share the final gallery within [Delivery Timeline].",
  "Delivery Message":
    "[Client Name], your final gallery is here ❤ — [Gallery Link]. We've handled it with [Privacy Choice] in mind. We hope it feels like the moment you wanted to keep forever.",
  "Album Proof Approval":
    "Hi [Client Name], your album proof is ready for a gentle review. Please look through and let us know any small change you'd love — we won't send it to production until it feels exactly right.",
  "Review Request":
    "[Client Name], if your story felt meaningful, we'd be quietly grateful for a few words: [Review Link]. Your voice helps other families trust us with their little moments.",
  "Milestone Follow-Up":
    "Hi [Client Name], thinking of you and your family. The next little milestone is on the horizon — whenever you're ready, we'd be honoured to keep telling your story.",
};

export const whatsappPlaceholders = [
  "[Client Name]",
  "[Session Type]",
  "[Package Name]",
  "[Shoot Date]",
  "[Balance Amount]",
  "[Gallery Link]",
  "[Privacy Choice]",
  "[Delivery Timeline]",
  "[Review Link]",
] as const;

export const followUpStatuses = ["Draft", "Scheduled", "Sent", "Skipped"] as const;
export type FollowUpStatus = (typeof followUpStatuses)[number];

/* ───────── Team & Tasks ───────── */
export const teamRoles = [
  "Founder / Studio Head",
  "Client Coordinator",
  "Sales Lead",
  "Photographer",
  "Assistant / Baby Care Support",
  "Stylist / Makeup Artist",
  "Editor / Retoucher",
  "Album / Print Coordinator",
  "Marketing Team",
  "Accounts",
] as const;
export type TeamRole = (typeof teamRoles)[number];

export const taskPriorities = ["Low", "Medium", "High", "Urgent"] as const;
export type TaskPriority = (typeof taskPriorities)[number];

export const taskStatuses = ["Pending", "In Progress", "Blocked", "Done", "Skipped"] as const;
export type TaskStatus = (typeof taskStatuses)[number];

/* ───────── SOPs (read-only) ───────── */
export const sops = [
  {
    id: "SOP-01",
    title: "Inquiry Handling",
    summary: "Respond to every family with warmth, within 60 minutes.",
    steps: [
      "Acknowledge the inquiry within 60 minutes — never silent.",
      "Listen first. Ask what moment they most want to preserve.",
      "Capture details into the Memory Profile.",
      "Mark lead status and follow-up date.",
      "Hand over to Sales Lead for package recommendation.",
    ],
  },
  {
    id: "SOP-02",
    title: "Consultation & Package Recommendation",
    summary: "Recommend the package that protects the right memory, not the largest invoice.",
    steps: [
      "Review the Memory Profile and emotional priority.",
      "Match to Bronze / Gold / Diamond / Emerald with reasoning.",
      "Share inclusions warmly — never pressure.",
      "Send quote via WhatsApp using the approved template.",
    ],
  },
  {
    id: "SOP-03",
    title: "Booking Confirmation",
    summary: "Confirm only after advance payment and written details are on file.",
    steps: [
      "Verify advance payment with Accounts.",
      "Send Booking Confirmation message.",
      "Schedule pre-shoot guide and reminders.",
      "Share Memory Profile with photographer + editor.",
    ],
  },
  {
    id: "SOP-04",
    title: "Pre-Shoot Preparation",
    summary: "Every shoot begins calm. Comfort is the first frame.",
    steps: [
      "Confirm location, timings, props, stylist 48h before.",
      "Confirm comfort needs and sensitivities with family.",
      "Photographer reviews Memory Profile aloud with team.",
      "Print safety checklist for the category.",
    ],
  },
  {
    id: "SOP-05",
    title: "Newborn Safety",
    summary: "Baby-led pacing. Spotter mandatory. Never compromise.",
    steps: [
      "Parent present at all times.",
      "Spotter for any elevated or composite pose.",
      "Sanitised wraps, stable props.",
      "Stop immediately if baby shows discomfort.",
      "Submit checklist before marking shoot complete.",
    ],
  },
  {
    id: "SOP-06",
    title: "Maternity Comfort",
    summary: "Comfort over composition, always.",
    steps: [
      "Comfortable poses only — no physically stressful posture.",
      "Rest breaks every 15 minutes.",
      "Private changing space provided.",
      "Confirm makeup sensitivities in advance.",
    ],
  },
  {
    id: "SOP-07",
    title: "Sitter / Baby / Child Safety",
    summary: "Stable props, parent nearby, no forced posing.",
    steps: [
      "Allergy check completed.",
      "Breaks offered freely.",
      "Never force a pose or a smile.",
      "Confirm child comfort before each frame.",
    ],
  },
  {
    id: "SOP-08",
    title: "Image Selection & Editing",
    summary: "Edit only after selection is confirmed and balance is paid.",
    steps: [
      "Send preview gallery via Pixieset.",
      "Wait for client selection — do not chase.",
      "Verify full payment with Accounts.",
      "Editor begins; Founder QC before delivery.",
    ],
  },
  {
    id: "SOP-09",
    title: "Album, Frame & Print Production",
    summary: "An heirloom must be worth keeping for generations.",
    steps: [
      "Confirm album/frame selections in writing.",
      "Share proof and wait for approval.",
      "Send to production only after approval.",
      "QC every piece before packing.",
    ],
  },
  {
    id: "SOP-10",
    title: "Delivery & Aftercare",
    summary: "Delivery is not the end. Relationship is.",
    steps: [
      "Deliver gallery with a warm, personal note.",
      "Request a review only when the family feels ready.",
      "Schedule the next milestone follow-up.",
      "Mark journey as Completed / Relationship Active.",
    ],
  },
] as const;

export const leads = [
  {
    id: "L-001",
    parent: "Aanya Mehta",
    phone: "+91 98200 11122",
    email: "aanya.mehta@gmail.com",
    city: "Mumbai",
    source: "Instagram",
    sessionType: "Newborn" as SessionType,
    babyAge: "12 days",
    preferredDate: "2026-06-04",
    location: "Studio",
    memoryGoal: "Capture his tiny fingers wrapped around mine",
    package: "Diamond — Heirloom",
    budget: "₹45–60k",
    followUp: "2026-05-27",
    status: "Package Shared",
  },
  {
    id: "L-002",
    parent: "Ritika & Arjun Shah",
    phone: "+91 98765 22112",
    email: "ritika.shah@outlook.com",
    city: "Pune",
    source: "Referral",
    sessionType: "Maternity" as SessionType,
    babyAge: "32 weeks",
    preferredDate: "2026-06-12",
    location: "Outdoor",
    memoryGoal: "Feeling held by my husband before she arrives",
    package: "Gold — Connection Story",
    budget: "₹30–40k",
    followUp: "2026-05-26",
    status: "Consultation Done",
  },
  {
    id: "L-003",
    parent: "Pooja Iyer",
    phone: "+91 99021 88765",
    email: "pooja.iyer@gmail.com",
    city: "Bengaluru",
    source: "Google",
    sessionType: "Sitter" as SessionType,
    babyAge: "7 months",
    preferredDate: "2026-06-20",
    location: "Home",
    memoryGoal: "Her giggles when she sees her dad",
    package: "Bronze — Essential",
    budget: "₹15–25k",
    followUp: "2026-05-28",
    status: "New Inquiry",
  },
  {
    id: "L-004",
    parent: "Neha Kapoor",
    phone: "+91 98111 55009",
    email: "neha.kapoor@gmail.com",
    city: "Delhi",
    source: "Instagram",
    sessionType: "Family" as SessionType,
    babyAge: "—",
    preferredDate: "2026-07-02",
    location: "Outdoor",
    memoryGoal: "All four of us, before our eldest leaves for college",
    package: "Emerald — Complete Legacy",
    budget: "₹80k+",
    followUp: "2026-05-30",
    status: "Follow-Up Needed",
  },
];

export const clients = [
  {
    id: "C-014",
    name: "Sneha & Karan Bhatia",
    phone: "+91 98200 33445",
    email: "sneha.b@gmail.com",
    city: "Mumbai",
    family: "Parents + 1 (Vihaan, 2y)",
    childName: "Vihaan",
    dob: "2024-03-11",
    pregnancy: "—",
    notes: "Loves outdoor golden-hour. Vihaan shy around new people — give warm-up time.",
    pastSessions: 3,
    nextMilestone: "First-birthday cake smash (Mar 2026)",
  },
  {
    id: "C-021",
    name: "Aanya Mehta",
    phone: "+91 98200 11122",
    email: "aanya.mehta@gmail.com",
    city: "Mumbai",
    family: "Parents + newborn",
    childName: "Kabir",
    dob: "2026-05-13",
    pregnancy: "Delivered",
    notes: "Maternity done with us at 30w. Now newborn within 14 days.",
    pastSessions: 1,
    nextMilestone: "Sitter (Dec 2026)",
  },
  {
    id: "C-027",
    name: "Ritika & Arjun Shah",
    phone: "+91 98765 22112",
    email: "ritika.shah@outlook.com",
    city: "Pune",
    family: "Couple, expecting first",
    childName: "—",
    dob: "—",
    pregnancy: "32 weeks",
    notes: "Sensitive skin — avoid heavy makeup. Prefers natural florals.",
    pastSessions: 0,
    nextMilestone: "Newborn (Aug 2026)",
  },
];

export const bookings = [
  {
    id: "B-2041",
    client: "Sneha & Karan Bhatia",
    category: "Family" as SessionType,
    package: "Gold — Connection Story",
    date: "2026-05-25 16:30",
    city: "Mumbai",
    locationType: "Outdoor",
    locationDetails: "Bandstand, Bandra — meet at lower deck",
    photographer: "Hema",
    assistant: "Riya",
    styling: "Self-styled",
    addOns: "20-page album, 1 wall frame 16x24",
    price: 55000,
    offer: 49500,
    advance: 25000,
    balance: 24500,
    payment: "Partial",
    privacy: "Selective Sharing",
    safety: "Pending",
    deadline: "2026-06-15",
    status: "Pre-Shoot Prep",
  },
  {
    id: "B-2042",
    client: "Aanya Mehta",
    category: "Newborn" as SessionType,
    package: "Diamond — Heirloom",
    date: "2026-05-25 10:00",
    city: "Mumbai",
    locationType: "Studio",
    locationDetails: "Studio A, Khar West",
    photographer: "Hema",
    assistant: "Spotter: Meera",
    styling: "In-house",
    addOns: "30-page heirloom album",
    price: 78000,
    offer: 72000,
    advance: 36000,
    balance: 36000,
    payment: "Partial",
    privacy: "Full Privacy",
    safety: "Pending",
    deadline: "2026-06-20",
    status: "Pre-Shoot Prep",
  },
  {
    id: "B-2038",
    client: "Tara Sundaram",
    category: "Maternity" as SessionType,
    package: "Gold — Connection Story",
    date: "2026-05-18 17:00",
    city: "Bengaluru",
    locationType: "Outdoor",
    locationDetails: "Cubbon Park — east gate",
    photographer: "Hema",
    assistant: "Riya",
    styling: "In-house",
    addOns: "Reel + 12x18 frame",
    price: 42000,
    offer: 42000,
    advance: 42000,
    balance: 0,
    payment: "Paid",
    privacy: "Portfolio Release",
    safety: "Completed",
    deadline: "2026-06-08",
    status: "Editing",
  },
];

export const todayShoots = bookings.filter((b) => b.date.startsWith("2026-05-25"));

export const philosophyScore = 92;

export const kpis = [
  { label: "First response time", value: "42 min", target: "< 60 min", good: true },
  { label: "Inquiry → booking conversion", value: "38%", target: "> 30%", good: true },
  { label: "Quotes with full details", value: "96%", target: "100%", good: false },
  { label: "Bookings with privacy recorded", value: "100%", target: "100%", good: true },
  { label: "Safety checklist completion", value: "98%", target: "100%", good: false },
  { label: "On-time editing delivery", value: "91%", target: "> 95%", good: false },
  { label: "On-time album/frame delivery", value: "88%", target: "> 90%", good: false },
  { label: "Album/frame defect rate", value: "1.2%", target: "< 2%", good: true },
  { label: "Public posts with written consent", value: "100%", target: "100%", good: true },
  { label: "Client satisfaction score", value: "4.9 / 5", target: "> 4.7", good: true },
  { label: "Repeat milestone booking rate", value: "64%", target: "> 50%", good: true },
];

export const packageTiers = [
  {
    tier: "Bronze",
    name: "The Essential Memory",
    blurb: "A gentle, intimate session focused on the moment itself.",
    fitFor: "A simple, treasured memory.",
    includes: ["60-min session", "20 edited images", "Online gallery"],
  },
  {
    tier: "Gold",
    name: "The Connection Story",
    blurb: "Mother–baby and family connection, captured in light and touch.",
    fitFor: "Baby + mother + family bonds.",
    includes: ["90-min session", "40 edited images", "Reel (60s)", "Premium gallery"],
  },
  {
    tier: "Diamond",
    name: "The Heirloom Story",
    blurb: "A fuller narrative arc, ready to live on a shelf, not a phone.",
    fitFor: "Album-led storytelling.",
    includes: ["2-hour session", "60 edited images", "20-page heirloom album", "Reel (90s)"],
  },
  {
    tier: "Emerald",
    name: "The Complete Legacy",
    blurb: "Cinematic reel, heirloom album, framed centerpiece — a legacy set.",
    fitFor: "Premium legacy.",
    includes: ["Half-day session", "100+ edited images", "30-page album", "Wall frame", "Cinematic reel"],
  },
] as const;

export const privacyOptions = [
  "Full Privacy — Do Not Share",
  "Selective Sharing — Only Approved Images",
  "Anonymous Sharing — No Names / No Identifying Details",
  "Portfolio Release — Approved Images May Be Used",
  "Social Media Approved",
  "Ads Approved",
] as const;

export const privacyRecords = [
  {
    id: "P-2041",
    booking: "B-2041",
    client: "Sneha & Karan Bhatia",
    consent: "Selective Sharing — Only Approved Images",
    date: "2026-05-20",
    platforms: "Instagram (approved frames only)",
    images: "To be tagged post-selection",
    confirmed: true,
    recordedBy: "Riya (Client Coordinator)",
  },
  {
    id: "P-2042",
    booking: "B-2042",
    client: "Aanya Mehta",
    consent: "Full Privacy — Do Not Share",
    date: "2026-05-22",
    platforms: "None — internal use only",
    images: "All images private",
    confirmed: true,
    recordedBy: "Hema",
  },
  {
    id: "P-2038",
    booking: "B-2038",
    client: "Tara Sundaram",
    consent: "Portfolio Release — Approved Images May Be Used",
    date: "2026-05-15",
    platforms: "Portfolio, Instagram, Website",
    images: "12 approved frames (list attached)",
    confirmed: true,
    recordedBy: "Hema",
  },
];

export const safetyChecklists = {
  Newborn: [
    "Parent present at all times",
    "Baby-led pacing followed",
    "Feeding breaks allowed",
    "Wraps sanitized",
    "Props stable",
    "Assistant / spotter used where needed",
    "No unsupported risky pose",
    "Composite pose marked if used",
    "Baby discomfort stop-rule followed",
  ],
  Maternity: [
    "Comfortable poses only",
    "Rest breaks offered",
    "Changing privacy provided",
    "Makeup sensitivity checked",
    "No physically stressful pose",
  ],
  "Sitter / Baby / Child": [
    "Stable props",
    "Parent nearby",
    "Allergy check completed",
    "Breaks offered",
    "No forced posing",
    "Child comfort confirmed",
  ],
} as const;

export const editingJobs = [
  {
    id: "E-2038",
    booking: "B-2038",
    client: "Tara Sundaram",
    status: "Editing Started",
    editedCount: 18,
    selectionDate: "2026-05-21",
    deadline: "2026-06-08",
    editor: "Aman",
    qc: "Pending",
    deliveryLink: "—",
    deliveryDate: "—",
  },
  {
    id: "E-2035",
    booking: "B-2035",
    client: "Meher Kaur",
    status: "Photographer QC",
    editedCount: 42,
    selectionDate: "2026-05-12",
    deadline: "2026-05-30",
    editor: "Priya",
    qc: "In review",
    deliveryLink: "pixieset.com/meher",
    deliveryDate: "—",
  },
  {
    id: "E-2031",
    booking: "B-2031",
    client: "Ananya Rao",
    status: "Delivered",
    editedCount: 36,
    selectionDate: "2026-04-28",
    deadline: "2026-05-18",
    editor: "Aman",
    qc: "Passed",
    deliveryLink: "pixieset.com/ananya",
    deliveryDate: "2026-05-17",
  },
];

export const heirloomJobs = [
  {
    id: "H-1108",
    client: "Ananya Rao",
    booking: "B-2031",
    albumSize: "12×12",
    pages: 30,
    cover: "Linen, ivory",
    frame: "16×24 — oak",
    selected: "32 images",
    proof: "Approved",
    approved: true,
    sentToProduction: true,
    produced: false,
    qc: "Pending",
    packed: false,
    ready: false,
    delivered: false,
  },
  {
    id: "H-1102",
    client: "Meher Kaur",
    booking: "B-2025",
    albumSize: "10×10",
    pages: 20,
    cover: "Velvet, blush",
    frame: "—",
    selected: "24 images",
    proof: "Sent",
    approved: false,
    sentToProduction: false,
    produced: false,
    qc: "—",
    packed: false,
    ready: false,
    delivered: false,
  },
  {
    id: "H-1099",
    client: "Diya Suresh",
    booking: "B-2018",
    albumSize: "12×12",
    pages: 40,
    cover: "Leather, walnut",
    frame: "20×30 — walnut",
    selected: "48 images",
    proof: "Approved",
    approved: true,
    sentToProduction: true,
    produced: true,
    qc: "Passed",
    packed: true,
    ready: true,
    delivered: false,
  },
];