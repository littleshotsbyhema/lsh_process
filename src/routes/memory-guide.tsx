import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
  type RefObject,
} from "react";
import { createFileRoute } from "@tanstack/react-router";
import {
  ArrowLeft,
  ArrowRight,
  Check,
  Copy,
  Heart,
  Loader2,
  LockKeyhole,
  MessageCircleHeart,
  Save,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import {
  guideStages,
  maxSelections,
  optionLabel,
  questionsForStage,
  type GuideAnswers,
  type MemoryGuideQuestion,
} from "@/lib/memory-guide.definition";
import {
  createMemoryGuideResume,
  getMemoryGuideState,
  processMemoryGuideDecision,
  recordMemoryGuideNextAction,
  resumeMemoryGuide,
  saveMemoryGuideAnswers,
  saveMemoryGuideContact,
  startMemoryGuide,
  type MemoryGuideDecision,
  type MemoryGuideState,
} from "@/lib/memory-guide.functions";

const STORAGE_KEY = "lsh-memory-guide-access-v1";

export const Route = createFileRoute("/memory-guide")({
  head: () => ({
    meta: [
      { title: "Memory Guide · Little Shots by Hema" },
      { name: "referrer", content: "no-referrer" },
      {
        name: "description",
        content:
          "A calm, privacy-aware guide to the Little Shots experience that may fit your family story.",
      },
    ],
  }),
  component: MemoryGuidePage,
});

function isBlank(value: unknown) {
  if (value == null) return true;
  if (typeof value === "string") return value.trim() === "";
  if (Array.isArray(value)) return value.length === 0;
  return false;
}

function inr(value: number) {
  return new Intl.NumberFormat("en-IN", {
    style: "currency",
    currency: "INR",
    maximumFractionDigits: 0,
  }).format(value);
}

type NextAction =
  "book_consultation" | "request_quote" | "whatsapp" | "save_for_later" | "human_review";
type PreferredContact = "whatsapp" | "phone" | "email" | "no_preference";

function MemoryGuidePage() {
  const headingRef = useRef<HTMLHeadingElement>(null);
  const bootstrappedRef = useRef(false);

  const [accessToken, setAccessToken] = useState<string | null>(null);
  const [guideState, setGuideState] = useState<MemoryGuideState | null>(null);
  const [answers, setAnswers] = useState<GuideAnswers>({});
  const [stageIndex, setStageIndex] = useState(0);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [resumeLink, setResumeLink] = useState<string | null>(null);

  const [contactName, setContactName] = useState("");
  const [contactPhone, setContactPhone] = useState("");
  const [contactEmail, setContactEmail] = useState("");
  const [preferredContact, setPreferredContact] = useState<PreferredContact>("whatsapp");
  const [contactPermission, setContactPermission] = useState(false);

  const loadState = useCallback(async (token: string) => {
    const loaded = await getMemoryGuideState({ data: { accessToken: token } });
    setGuideState(loaded);
    setAnswers(loaded.answers ?? {});
    if (loaded.contact) {
      setContactName(loaded.contact.contact_name);
      setContactPhone(loaded.contact.contact_phone);
      setContactEmail(loaded.contact.contact_email ?? "");
      setPreferredContact(loaded.contact.preferred_contact as PreferredContact);
      setContactPermission(loaded.contact.contact_permission);
    }
    if (loaded.decision) {
      setStageIndex(guideStages.length);
    } else {
      const index = guideStages.findIndex((stage) => stage.id === loaded.session.current_stage);
      setStageIndex(index >= 0 ? index : 0);
    }
    return loaded;
  }, []);

  useEffect(() => {
    if (bootstrappedRef.current) return;
    bootstrappedRef.current = true;
    void (async () => {
      setBusy(true);
      setError(null);
      try {
        const hash = window.location.hash;
        const resumeToken = hash.startsWith("#resume=")
          ? decodeURIComponent(hash.slice("#resume=".length))
          : null;
        if (resumeToken) {
          // Remove the secret from the visible URL before any later navigation.
          // URL fragments are not sent to the server or in HTTP Referer headers.
          window.history.replaceState(null, "", "/memory-guide");
          const resumed = await resumeMemoryGuide({ data: { resumeToken } });
          localStorage.setItem(STORAGE_KEY, resumed.accessToken);
          setAccessToken(resumed.accessToken);
          await loadState(resumed.accessToken);
          setNotice(
            "Your saved guide is open on this device. The resume link has now been used and cannot be replayed.",
          );
          return;
        }
        const stored = localStorage.getItem(STORAGE_KEY);
        if (stored) {
          try {
            setAccessToken(stored);
            await loadState(stored);
          } catch {
            localStorage.removeItem(STORAGE_KEY);
            setAccessToken(null);
          }
        }
      } catch (cause) {
        setError(cause instanceof Error ? cause.message : "Unable to resume the Memory Guide.");
      } finally {
        setBusy(false);
      }
    })();
  }, [loadState]);

  useEffect(() => {
    headingRef.current?.focus();
  }, [stageIndex, guideState?.decision?.id]);

  const currentStage = stageIndex < guideStages.length ? guideStages[stageIndex] : null;
  const currentQuestions = useMemo(
    () => (currentStage ? questionsForStage(currentStage.id, answers) : []),
    [answers, currentStage],
  );
  const decision = guideState?.decision ?? null;

  function findNavigableStageIndex(fromIndex: number, direction: 1 | -1) {
    let index = fromIndex + direction;

    while (index >= 0 && index < guideStages.length) {
      const stage = guideStages[index];

      if (stage && (stage.id === "STG-14" || questionsForStage(stage.id, answers).length > 0)) {
        return index;
      }

      index += direction;
    }

    return fromIndex;
  }

  async function begin(jumpToContact = false) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      const started = await startMemoryGuide({ data: { sourcePage: "/memory-guide" } });
      localStorage.setItem(STORAGE_KEY, started.access_token);
      setAccessToken(started.access_token);
      await loadState(started.access_token);
      setStageIndex(jumpToContact ? guideStages.findIndex((stage) => stage.id === "STG-14") : 0);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to start the Memory Guide.");
    } finally {
      setBusy(false);
    }
  }

  function setAnswer(fieldKey: string, value: string | string[] | boolean) {
    setAnswers((previous) => ({ ...previous, [fieldKey]: value }));
    setError(null);
  }

  function toggleMulti(question: MemoryGuideQuestion, value: string) {
    const current = Array.isArray(answers[question.fieldKey])
      ? (answers[question.fieldKey] as string[])
      : [];
    const next = current.includes(value)
      ? current.filter((item) => item !== value)
      : [...current, value];
    const max = maxSelections(question);
    if (max && next.length > max) {
      setError(`Choose up to ${max} options for “${question.prompt}”.`);
      return;
    }
    setAnswer(question.fieldKey, next);
  }

  function validateStage() {
    for (const question of currentQuestions) {
      const required =
        question.requirement === "Required" || question.requirement === "Conditional";
      if (required && isBlank(answers[question.fieldKey])) {
        return `Please answer “${question.prompt}”.`;
      }
    }
    return null;
  }

  async function persistVisibleStage(targetStageId: string) {
    if (!accessToken || !guideState || !currentStage || currentStage.id === "STG-14")
      return guideState?.session.version ?? null;

    const payload: GuideAnswers = {};
    for (const question of currentQuestions) {
      const value = answers[question.fieldKey];
      if (!isBlank(value)) payload[question.fieldKey] = value;
    }

    const saved = await saveMemoryGuideAnswers({
      data: {
        accessToken,
        expectedVersion: guideState.session.version,
        stageId: targetStageId,
        answers: payload,
      },
    });
    setGuideState((previous) =>
      previous
        ? {
            ...previous,
            session: {
              ...previous.session,
              version: saved.session_version,
              current_stage: saved.current_stage,
              progress_percent: saved.progress_percent,
              status: "draft",
            },
            decision: null,
          }
        : previous,
    );
    return saved.session_version;
  }

  async function goToHumanSupport() {
    const contactIndex = guideStages.findIndex((stage) => stage.id === "STG-14");
    if (contactIndex < 0 || stageIndex === contactIndex) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      if (currentStage && currentStage.id !== "STG-14") {
        await persistVisibleStage("STG-14");
      }
      setStageIndex(contactIndex);
      setNotice(
        "Your answers so far are saved. You can choose whether you want the team to contact you.",
      );
    } catch (cause) {
      const message =
        cause instanceof Error ? cause.message : "Unable to save before opening human support.";
      setError(message);
      if (accessToken && message.toLowerCase().includes("another device"))
        await loadState(accessToken);
    } finally {
      setBusy(false);
    }
  }

  async function saveCurrentStage() {
    if (!accessToken || !guideState || !currentStage) return;
    setError(null);
    setNotice(null);

    if (currentStage.id === "STG-14") {
      await finishContactAndRecommend();
      return;
    }

    const validationError = validateStage();
    if (validationError) {
      setError(validationError);
      return;
    }

    setBusy(true);
    try {
      const nextIndex = findNavigableStageIndex(stageIndex, 1);
      const nextStage = guideStages[nextIndex];

      if (nextIndex === stageIndex || !nextStage) {
        throw new Error("No next Memory Guide stage is available.");
      }

      await persistVisibleStage(nextStage.id);
      setStageIndex(nextIndex);
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : "Unable to save this step.";
      setError(message);
      if (message.toLowerCase().includes("another device")) await loadState(accessToken);
    } finally {
      setBusy(false);
    }
  }

  async function finishContactAndRecommend() {
    if (!accessToken || !guideState) return;
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      if (contactPermission) {
        if (!contactName.trim())
          throw new Error("Please add the name we should use for your enquiry.");
        if (!/^\+[0-9]{8,15}$/.test(contactPhone))
          throw new Error("Use an international mobile number, for example +919876543210.");
      }
      await saveMemoryGuideContact({
        data: {
          accessToken,
          contactName: contactPermission ? contactName : "",
          contactPhone: contactPermission ? contactPhone : "",
          contactEmail: contactPermission ? contactEmail.trim() || null : null,
          contactPermission,
          preferredContact,
        },
      });
      const result = await processMemoryGuideDecision({
        data: { accessToken, expectedVersion: guideState.session.version },
      });
      const refreshed = await loadState(accessToken);
      setGuideState({ ...refreshed, decision: result });
      setStageIndex(guideStages.length);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to prepare your recommendation.");
    } finally {
      setBusy(false);
    }
  }

  async function saveForLater() {
    if (!accessToken || !guideState) return;
    setBusy(true);
    setError(null);
    try {
      if (currentStage && currentStage.id !== "STG-14") {
        await persistVisibleStage(currentStage.id);
      }
      const resume = await createMemoryGuideResume({ data: { accessToken } });
      const url = `${window.location.origin}/memory-guide#resume=${encodeURIComponent(resume.resume_token)}`;
      setResumeLink(url);
      setNotice(
        `Your answers so far are saved. This one-time resume link expires ${new Intl.DateTimeFormat("en-IN", { dateStyle: "medium", timeStyle: "short" }).format(new Date(resume.resume_expires_at))}.`,
      );
    } catch (cause) {
      const message = cause instanceof Error ? cause.message : "Unable to create a resume link.";
      setError(message);
      if (message.toLowerCase().includes("another device")) await loadState(accessToken);
    } finally {
      setBusy(false);
    }
  }

  async function chooseNextAction(nextAction: NextAction) {
    if (!accessToken) return;
    setBusy(true);
    setError(null);
    try {
      await recordMemoryGuideNextAction({ data: { accessToken, nextAction } });
      if (nextAction === "save_for_later") {
        setBusy(false);
        await saveForLater();
        return;
      }
      setGuideState((previous) =>
        previous
          ? { ...previous, session: { ...previous.session, next_action: nextAction } }
          : previous,
      );
      if (!guideState?.contact) {
        setNotice(
          "Your choice is saved. Add enquiry contact permission if you would like our team to respond.",
        );
        setStageIndex(guideStages.findIndex((stage) => stage.id === "STG-14"));
      } else {
        setNotice(
          "Your preferred next step is saved for the team. No provider delivery is being claimed here.",
        );
      }
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Unable to save the next step.");
    } finally {
      setBusy(false);
    }
  }

  if (!accessToken || !guideState) {
    return (
      <main className="min-h-screen bg-background text-foreground">
        <div className="mx-auto flex min-h-screen max-w-3xl items-center px-5 py-12 sm:px-8">
          <div className="w-full rounded-[32px] border border-border bg-card p-7 shadow-sm sm:p-10">
            <div className="inline-flex items-center gap-2 rounded-full border border-border bg-background px-3 py-1 text-xs text-muted-foreground">
              <Heart className="h-3.5 w-3.5" /> Little Shots Memory Guide
            </div>
            <h1
              ref={headingRef}
              tabIndex={-1}
              className="mt-6 font-serif text-4xl leading-tight text-primary outline-none sm:text-5xl"
            >
              Begin with the memory, not the package.
            </h1>
            <p className="mt-5 max-w-2xl text-base leading-7 text-muted-foreground">
              In a few calm steps, we’ll understand the chapter your family is living through and
              guide you toward a fitting Little Shots experience. You can ask for a person at any
              point.
            </p>
            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <TrustPoint
                icon={Sparkles}
                title="A few minutes"
                text="One clear question at a time."
              />
              <TrustPoint
                icon={ShieldCheck}
                title="Private by default"
                text="Privacy preference is never treated as image-use consent."
              />
              <TrustPoint
                icon={MessageCircleHeart}
                title="Human support"
                text="Uncertain or special needs go to a team review."
              />
            </div>
            {error && <ErrorBox message={error} />}
            <div className="mt-8 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => void begin(false)}
                disabled={busy}
                className="inline-flex items-center gap-2 rounded-xl bg-primary px-5 py-3 text-sm font-medium text-primary-foreground disabled:opacity-50"
              >
                {busy ? (
                  <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                  <ArrowRight className="h-4 w-4" />
                )}{" "}
                Begin
              </button>
              <button
                type="button"
                onClick={() => void begin(true)}
                disabled={busy}
                className="inline-flex items-center gap-2 rounded-xl border border-border px-5 py-3 text-sm text-primary disabled:opacity-50"
              >
                <MessageCircleHeart className="h-4 w-4" /> Talk to our team
              </button>
            </div>
            <p className="mt-5 text-xs leading-5 text-muted-foreground">
              The guide does not give medical advice, does not invent package pricing, and does not
              send WhatsApp/email messages by itself.
            </p>
          </div>
        </div>
      </main>
    );
  }

  if (decision && stageIndex >= guideStages.length) {
    return (
      <GuideLayout
        reference={guideState.session.reference}
        progress={100}
        onSave={() => void saveForLater()}
        onHuman={() => void chooseNextAction("human_review")}
        busy={busy}
      >
        <RecommendationResult
          decision={decision}
          selectedAction={guideState.session.next_action}
          onAction={(action) => void chooseNextAction(action)}
          busy={busy}
          headingRef={headingRef}
        />
        {notice && <NoticeBox message={notice} />}
        {resumeLink && <ResumeBox link={resumeLink} />}
        {error && <ErrorBox message={error} />}
      </GuideLayout>
    );
  }

  if (!currentStage) return null;

  const visibleProgress = Math.max(4, Math.round(((stageIndex + 1) / guideStages.length) * 92));

  return (
    <GuideLayout
      reference={guideState.session.reference}
      progress={visibleProgress}
      onSave={() => void saveForLater()}
      onHuman={() => void goToHumanSupport()}
      busy={busy}
    >
      <div className="rounded-[28px] border border-border bg-card p-5 sm:p-8">
        <div className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
          {currentStage.eyebrow}
        </div>
        <h1
          ref={headingRef}
          tabIndex={-1}
          className="mt-2 font-serif text-3xl text-primary outline-none sm:text-4xl"
        >
          {currentStage.title}
        </h1>
        <p className="mt-3 max-w-2xl text-sm leading-6 text-muted-foreground">
          {currentStage.description}
        </p>

        {currentStage.id === "STG-14" ? (
          <ContactStep
            name={contactName}
            phone={contactPhone}
            email={contactEmail}
            preferred={preferredContact}
            permission={contactPermission}
            onName={setContactName}
            onPhone={setContactPhone}
            onEmail={setContactEmail}
            onPreferred={setPreferredContact}
            onPermission={setContactPermission}
          />
        ) : (
          <div className="mt-7 space-y-7">
            {currentQuestions.map((question) => (
              <QuestionControl
                key={question.questionId}
                question={question}
                value={answers[question.fieldKey]}
                onSet={setAnswer}
                onToggle={toggleMulti}
              />
            ))}
          </div>
        )}

        {error && <ErrorBox message={error} />}
        {notice && <NoticeBox message={notice} />}
        {resumeLink && <ResumeBox link={resumeLink} />}

        <div className="mt-8 flex flex-wrap items-center justify-between gap-3 border-t border-border pt-5">
          <button
            type="button"
            disabled={busy || stageIndex === 0}
            onClick={() => setStageIndex(findNavigableStageIndex(stageIndex, -1))}
            className="inline-flex items-center gap-2 rounded-xl border border-border px-4 py-2.5 text-sm text-primary disabled:opacity-40"
          >
            <ArrowLeft className="h-4 w-4" /> Back
          </button>
          <button
            type="button"
            disabled={busy}
            onClick={() => void saveCurrentStage()}
            className="inline-flex items-center gap-2 rounded-xl bg-primary px-5 py-2.5 text-sm font-medium text-primary-foreground disabled:opacity-50"
          >
            {busy ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : currentStage.id === "STG-14" ? (
              <Sparkles className="h-4 w-4" />
            ) : (
              <ArrowRight className="h-4 w-4" />
            )}
            {currentStage.id === "STG-14" ? "See my guide" : "Save & continue"}
          </button>
        </div>
      </div>
    </GuideLayout>
  );
}

function GuideLayout({
  reference,
  progress,
  onSave,
  onHuman,
  busy,
  children,
}: {
  reference: string;
  progress: number;
  onSave: () => void;
  onHuman: () => void;
  busy: boolean;
  children: ReactNode;
}) {
  return (
    <main className="min-h-screen bg-background text-foreground">
      <div className="mx-auto max-w-4xl px-4 py-5 sm:px-7 sm:py-8">
        <header className="mb-5 rounded-2xl border border-border bg-card px-4 py-4 sm:px-5">
          <div className="flex flex-wrap items-center justify-between gap-3">
            <div>
              <div className="font-serif text-lg text-primary">Little Shots Memory Guide</div>
              <div className="mt-0.5 text-[11px] text-muted-foreground">{reference}</div>
            </div>
            <div className="flex flex-wrap gap-2">
              <button
                type="button"
                disabled={busy}
                onClick={onSave}
                className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-50"
              >
                <Save className="h-3.5 w-3.5" /> Save for later
              </button>
              <button
                type="button"
                disabled={busy}
                onClick={onHuman}
                className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 py-2 text-xs text-primary disabled:opacity-50"
              >
                <MessageCircleHeart className="h-3.5 w-3.5" /> Human support
              </button>
            </div>
          </div>
          <div className="mt-4 flex items-center gap-3">
            <progress
              className="h-2 w-full overflow-hidden rounded-full"
              max={100}
              value={progress}
              aria-label="Memory Guide progress"
            />
            <span className="w-10 text-right text-xs tabular-nums text-muted-foreground">
              {progress}%
            </span>
          </div>
        </header>
        {children}
        <footer className="mx-auto mt-6 max-w-2xl text-center text-xs leading-5 text-muted-foreground">
          Because these little moments become everything. Your family memories are private by
          default, and you can choose human support whenever you prefer.
        </footer>
      </div>
    </main>
  );
}

function QuestionControl({
  question,
  value,
  onSet,
  onToggle,
}: {
  question: MemoryGuideQuestion;
  value: string | string[] | boolean | undefined;
  onSet: (fieldKey: string, value: string | string[] | boolean) => void;
  onToggle: (question: MemoryGuideQuestion, value: string) => void;
}) {
  const privateField = ["Sensitive", "Restricted"].includes(question.classification);
  return (
    <fieldset className="rounded-2xl border border-border p-4 sm:p-5">
      <legend className="px-1 text-sm font-medium text-primary">{question.prompt}</legend>
      <div className="mt-1 flex flex-wrap items-center gap-2 text-[11px] text-muted-foreground">
        {question.requirement === "Required" && <span>Required</span>}
        {question.requirement === "Conditional" && <span>Required for this path</span>}
        {privateField && (
          <span className="inline-flex items-center gap-1 rounded-full border border-border px-2 py-0.5">
            <LockKeyhole className="h-3 w-3" /> Restricted
          </span>
        )}
      </div>

      {(question.control === "single_select" || question.control === "multi_select") && (
        <div className="mt-4 grid gap-2 sm:grid-cols-2">
          {question.options.map((option) => {
            const checked =
              question.control === "multi_select"
                ? Array.isArray(value) && value.includes(option)
                : value === option;
            return (
              <label
                key={option}
                className={`flex cursor-pointer items-start gap-3 rounded-xl border p-3 text-sm transition ${checked ? "border-primary bg-accent" : "border-border bg-background"}`}
              >
                <input
                  type={question.control === "multi_select" ? "checkbox" : "radio"}
                  name={question.fieldKey}
                  value={option}
                  checked={checked}
                  onChange={() =>
                    question.control === "multi_select"
                      ? onToggle(question, option)
                      : onSet(question.fieldKey, option)
                  }
                  className="mt-0.5"
                />
                <span>{optionLabel(option, question.fieldKey)}</span>
              </label>
            );
          })}
        </div>
      )}

      {question.control === "boolean" && (
        <div className="mt-4 flex gap-2">
          {[true, false].map((choice) => (
            <label
              key={String(choice)}
              className={`flex cursor-pointer items-center gap-2 rounded-xl border px-4 py-2 text-sm ${value === choice ? "border-primary bg-accent" : "border-border"}`}
            >
              <input
                type="radio"
                name={question.fieldKey}
                checked={value === choice}
                onChange={() => onSet(question.fieldKey, choice)}
              />
              {choice ? "Yes" : "No"}
            </label>
          ))}
        </div>
      )}

      {question.control === "short_text" && (
        <textarea
          value={typeof value === "string" ? value : ""}
          onChange={(event) => onSet(question.fieldKey, event.target.value)}
          maxLength={
            question.fieldKey === "safety_note"
              ? 300
              : question.fieldKey === "story_note"
                ? 240
                : 80
          }
          rows={question.fieldKey === "travel_area" ? 2 : 4}
          className="mt-4 w-full rounded-xl border border-border bg-background px-3 py-2.5 text-sm text-primary outline-none focus:border-primary"
          placeholder={
            question.fieldKey === "travel_area"
              ? "Broad area only — not an exact address"
              : "Optional — share only what feels useful"
          }
        />
      )}
    </fieldset>
  );
}

function ContactStep({
  name,
  phone,
  email,
  preferred,
  permission,
  onName,
  onPhone,
  onEmail,
  onPreferred,
  onPermission,
}: {
  name: string;
  phone: string;
  email: string;
  preferred: PreferredContact;
  permission: boolean;
  onName: (value: string) => void;
  onPhone: (value: string) => void;
  onEmail: (value: string) => void;
  onPreferred: (value: PreferredContact) => void;
  onPermission: (value: boolean) => void;
}) {
  return (
    <div className="mt-7 space-y-4">
      <div className="rounded-2xl border border-border bg-background p-4 text-sm leading-6 text-muted-foreground">
        You can receive the recommendation without giving us contact permission. If you want a
        quote, consultation or personal follow-up, tick the permission below. This is enquiry
        contact permission only —{" "}
        <strong className="font-medium text-primary">
          not marketing consent and not image-use consent.
        </strong>
      </div>
      <label className="block text-sm text-primary">
        What should we call you?
        <input
          value={name}
          onChange={(event) => onName(event.target.value)}
          maxLength={80}
          autoComplete="name"
          className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5"
        />
      </label>
      <label className="block text-sm text-primary">
        Best mobile number
        <input
          value={phone}
          onChange={(event) => onPhone(event.target.value)}
          placeholder="+919876543210"
          autoComplete="tel"
          inputMode="tel"
          className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5"
        />
      </label>
      <label className="block text-sm text-primary">
        Email <span className="text-muted-foreground">(optional)</span>
        <input
          value={email}
          onChange={(event) => onEmail(event.target.value)}
          autoComplete="email"
          inputMode="email"
          className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5"
        />
      </label>
      <label className="block text-sm text-primary">
        Preferred reply
        <select
          value={preferred}
          onChange={(event) => onPreferred(event.target.value as typeof preferred)}
          className="mt-1.5 w-full rounded-xl border border-border bg-background px-3 py-2.5"
        >
          <option value="whatsapp">WhatsApp</option>
          <option value="phone">Phone</option>
          <option value="email">Email</option>
          <option value="no_preference">No preference</option>
        </select>
      </label>
      <label className="flex items-start gap-3 rounded-2xl border border-border p-4 text-sm leading-6 text-primary">
        <input
          type="checkbox"
          checked={permission}
          onChange={(event) => onPermission(event.target.checked)}
          className="mt-1"
        />
        <span>
          Yes, Little Shots by Hema may contact me about this enquiry and the next step I choose.
        </span>
      </label>
      {!permission && (
        <p className="text-xs text-muted-foreground">
          Leave this unticked to continue privately without creating a CRM handoff.
        </p>
      )}
    </div>
  );
}

function RecommendationResult({
  decision,
  selectedAction,
  onAction,
  busy,
  headingRef,
}: {
  decision: MemoryGuideDecision;
  selectedAction: string | null;
  onAction: (action: NextAction) => void;
  busy: boolean;
  headingRef: RefObject<HTMLHeadingElement | null>;
}) {
  return (
    <div className="space-y-5">
      <section className="rounded-[28px] border border-border bg-card p-6 sm:p-8">
        <div className="flex flex-wrap items-center justify-between gap-2">
          <div className="text-xs uppercase tracking-[0.18em] text-muted-foreground">
            Your Memory Guide
          </div>
          <span
            className={`rounded-full border px-3 py-1 text-xs ${decision.confidence === "high" ? "border-border" : "border-amber-300"}`}
          >
            {decision.confidence.replaceAll("_", " ")}
          </span>
        </div>
        <h1
          ref={headingRef}
          tabIndex={-1}
          className="mt-3 font-serif text-3xl text-primary outline-none sm:text-4xl"
        >
          {decision.primary_package
            ? `${decision.primary_package.public_name} may fit this chapter`
            : decision.future_milestone
              ? "A future milestone may fit better"
              : "A human guide is the right next step"}
        </h1>
        <p className="mt-4 text-sm leading-7 text-muted-foreground">{decision.explanation}</p>

        {decision.primary_package && (
          <div className="mt-6 grid gap-4 md:grid-cols-2">
            <PackageCard label="Primary fit" pkg={decision.primary_package} />
            {decision.alternative_package && (
              <PackageCard label="Nearby alternative" pkg={decision.alternative_package} />
            )}
          </div>
        )}
        {decision.future_milestone && (
          <div className="mt-5 rounded-2xl border border-border bg-background p-4 text-sm text-primary">
            {decision.future_milestone}
          </div>
        )}

        {decision.reasons.length > 0 && (
          <div className="mt-6">
            <h2 className="text-sm font-medium text-primary">Why this fit appeared</h2>
            <ul className="mt-3 space-y-2">
              {decision.reasons.map((reason) => (
                <li key={reason} className="flex gap-2 text-sm text-muted-foreground">
                  <Check className="mt-0.5 h-4 w-4 shrink-0 text-primary" /> {reason}
                </li>
              ))}
            </ul>
          </div>
        )}

        <div className="mt-6 rounded-2xl border border-border bg-background p-4">
          <div className="flex items-start gap-3">
            <ShieldCheck className="mt-0.5 h-5 w-5 shrink-0 text-primary" />
            <p className="text-sm leading-6 text-muted-foreground">{decision.privacy_note}</p>
          </div>
        </div>
        {decision.review_required && (
          <div className="mt-4 rounded-2xl border border-amber-300 bg-background p-4 text-sm leading-6 text-primary">
            A team review is required before this recommendation is treated as final. The guide has
            not guessed through the uncertainty.
          </div>
        )}
        <p className="mt-4 text-xs leading-5 text-muted-foreground">
          Prices shown are current standard catalogue prices from the approved client package
          documents. Promotional/offer pricing is intentionally not inferred from privacy choices;
          the team confirms any current offer separately.
        </p>
      </section>

      <section className="rounded-[28px] border border-border bg-card p-6 sm:p-8">
        <h2 className="font-serif text-2xl text-primary">What would feel helpful next?</h2>
        <p className="mt-2 text-sm leading-6 text-muted-foreground">
          No urgency. Choose a next step, save this guide, or ask for a person.
        </p>
        <div className="mt-5 grid gap-2 sm:grid-cols-2">
          <ActionButton
            label="Request a clear quote"
            value="request_quote"
            selected={selectedAction}
            onAction={onAction}
            busy={busy}
          />
          <ActionButton
            label="Arrange a consultation"
            value="book_consultation"
            selected={selectedAction}
            onAction={onAction}
            busy={busy}
          />
          <ActionButton
            label="Prefer WhatsApp / human help"
            value="whatsapp"
            selected={selectedAction}
            onAction={onAction}
            busy={busy}
          />
          <ActionButton
            label="Save for later"
            value="save_for_later"
            selected={selectedAction}
            onAction={onAction}
            busy={busy}
          />
        </div>
      </section>
    </div>
  );
}

function PackageCard({
  label,
  pkg,
}: {
  label: string;
  pkg: NonNullable<MemoryGuideDecision["primary_package"]>;
}) {
  return (
    <div className="rounded-2xl border border-border bg-background p-5">
      <div className="text-[11px] uppercase tracking-wider text-muted-foreground">
        {label} · {pkg.tier}
      </div>
      <div className="mt-1 font-serif text-2xl text-primary">{pkg.public_name}</div>
      <div className="mt-1 text-sm font-medium text-primary">{inr(pkg.list_price_inr)}</div>
      <p className="mt-3 text-sm leading-6 text-muted-foreground">{pkg.summary}</p>
      <ul className="mt-3 space-y-1.5 text-xs text-muted-foreground">
        {pkg.inclusions.slice(0, 5).map((item) => (
          <li key={item}>• {item}</li>
        ))}
      </ul>
    </div>
  );
}

function ActionButton({
  label,
  value,
  selected,
  onAction,
  busy,
}: {
  label: string;
  value: Exclude<NextAction, "human_review">;
  selected: string | null;
  onAction: (value: NextAction) => void;
  busy: boolean;
}) {
  const active = selected === value;
  return (
    <button
      type="button"
      disabled={busy}
      onClick={() => onAction(value)}
      className={`rounded-xl border px-4 py-3 text-left text-sm ${active ? "border-primary bg-accent text-primary" : "border-border text-primary"} disabled:opacity-50`}
    >
      {active && <Check className="mr-2 inline h-4 w-4" />}
      {label}
    </button>
  );
}

function ResumeBox({ link }: { link: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <div className="mt-4 rounded-2xl border border-border bg-background p-4" aria-live="polite">
      <div className="flex items-center gap-2 text-sm font-medium text-primary">
        <LockKeyhole className="h-4 w-4" /> One-time resume link
      </div>
      <p className="mt-1 text-xs leading-5 text-muted-foreground">
        Keep this link private. It expires and becomes unusable after a successful resume.
      </p>
      <div className="mt-3 flex gap-2">
        <input
          readOnly
          value={link}
          aria-label="One-time resume link"
          className="min-w-0 flex-1 rounded-lg border border-border bg-card px-3 py-2 text-xs"
        />
        <button
          type="button"
          onClick={() => void navigator.clipboard.writeText(link).then(() => setCopied(true))}
          className="inline-flex items-center gap-1.5 rounded-lg border border-border px-3 text-xs"
        >
          <Copy className="h-3.5 w-3.5" />
          {copied ? "Copied" : "Copy"}
        </button>
      </div>
    </div>
  );
}

function ErrorBox({ message }: { message: string }) {
  return (
    <div
      role="alert"
      className="mt-5 rounded-2xl border border-red-300 bg-background p-4 text-sm leading-6 text-primary"
    >
      {message}
    </div>
  );
}
function NoticeBox({ message }: { message: string }) {
  return (
    <div
      role="status"
      className="mt-5 rounded-2xl border border-border bg-background p-4 text-sm leading-6 text-muted-foreground"
    >
      {message}
    </div>
  );
}
function TrustPoint({
  icon: Icon,
  title,
  text,
}: {
  icon: typeof Sparkles;
  title: string;
  text: string;
}) {
  return (
    <div className="rounded-2xl border border-border bg-background p-4">
      <Icon className="h-5 w-5 text-primary" />
      <div className="mt-3 text-sm font-medium text-primary">{title}</div>
      <p className="mt-1 text-xs leading-5 text-muted-foreground">{text}</p>
    </div>
  );
}
