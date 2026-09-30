import { Timestamp } from "firebase-admin/firestore";
import { PlanId } from "./plans";

export const SCHEMA_VERSION = 1;
export const HOUSEHOLD_RETENTION_DAYS = 30;

export type FamilyStatus = "active" | "frozen" | "deleting";
export type HouseholdRole = "admin" | "member";

export interface FamilyDoc {
  name: string;
  ownerId: string;
  status: FamilyStatus;
  plan: PlanId;
  memberCount: number;
  householdCount: number;
  pendingTransfer?: { toUid: string; createdAt: Timestamp; expiresAt: Timestamp } | null;
}

export interface MemberDoc {
  role: "owner" | "member";
  status: "active" | "removed";
  displayName?: string;
  photoUrl?: string | null;
}

export interface HouseholdDoc {
  name: string;
  access: Record<string, HouseholdRole>;
  accessUids: string[];
  deletedAccess?: Record<string, HouseholdRole>;
  createdBy: string;
  deletedAt: Timestamp | null;
}
