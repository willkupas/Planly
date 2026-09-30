import "../config";
import { getFirestore } from "firebase-admin/firestore";

export const db = () => getFirestore();

export const paths = {
  user: (uid: string) => db().doc(`users/${uid}`),
  membership: (uid: string, familyId: string) => db().doc(`users/${uid}/memberships/${familyId}`),
  families: () => db().collection("families"),
  family: (familyId: string) => db().doc(`families/${familyId}`),
  member: (familyId: string, uid: string) => db().doc(`families/${familyId}/members/${uid}`),
  entitlement: (familyId: string) => db().doc(`families/${familyId}/billing/entitlement`),
  households: (familyId: string) => db().collection(`families/${familyId}/households`),
  household: (familyId: string, householdId: string) =>
    db().doc(`families/${familyId}/households/${householdId}`),
  activity: (familyId: string, householdId: string) =>
    db().collection(`families/${familyId}/households/${householdId}/activity`),
  rateLimit: (uid: string, fn: string) => db().doc(`_rateLimits/${uid}_${fn}`),
};
