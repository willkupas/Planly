import { logJob } from "./jobLog";

export type JobNotificationType =
  | "expiry_d7"
  | "frozen_d0"
  | "delete_d60"
  | "delete_d30"
  | "delete_d7"
  | "delete_d1";

/** Payload só com ids e tipo (cloud-functions §5); o texto é montado no app (i18n). */
export interface JobNotification {
  type: JobNotificationType;
  familyId: string;
  recipientUids: string[];
}

export type Notifier = (n: JobNotification) => Promise<void>;

/**
 * Gancho de avisos. Hoje só registra (sem FCM): a flag in-app (`notifiedAt` na família) é
 * gravada pelo job antes de chamar o gancho. O envio FCM (T-023) substitui este notifier
 * sem mudar a lógica dos jobs.
 */
export const defaultNotify: Notifier = async (n) => {
  logJob({
    function: "lifecycleJob",
    operation: `notify:${n.type}`,
    result: "ok",
    familyId: n.familyId,
    counts: { recipients: n.recipientUids.length },
  });
};
