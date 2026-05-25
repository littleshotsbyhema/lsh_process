import { toast } from "sonner";

export function handle(result: { ok: boolean; message: string; warning?: boolean }) {
  if (result.ok) toast.success(result.message);
  else if (result.warning === false) toast(result.message);
  else toast.error(result.message);
  return result.ok;
}