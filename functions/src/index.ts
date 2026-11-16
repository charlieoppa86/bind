/**
 * BIND Cloud Functions
 *
 * searchPlaces: 카카오 로컬 "키워드로 장소 검색"을 대신 호출한다.
 *   카카오 REST API 키는 앱에 넣지 않고 Secret Manager에만 둔다.
 * sendRequest / respondRequest / expireRequests: 대화 요청(하루 횟수·중복·만료·채팅방 생성)은
 *   신뢰가 필요해서 서버만 쓴다.
 * onMessageCreated: 메시지가 오면 대화방의 마지막 메시지·상대 안 읽은 수·메시지 수를 갱신한다.
 * onReportCreated: 서로 다른 신고자 2명이 쌓이면 대상 계정을 정지하고 카드를 내린다.
 * onReviewCreated: "좋았어요"면 상대의 좋았어요 수를 올리고, 신뢰 표시 기준을 넘으면 카드에 붙인다.
 * onCheckinWritten: 체크인이 생기거나 내려가면 그 장소의 지금 인원(activeCount)을 다시 센다.
 * deleteAccount: 탈퇴. 닉네임 예약을 풀고 프로필을 "떠난 사용자"로 표시한 뒤
 *   Auth 계정을 지운다(클라이언트 규칙으로는 못 하는 일).
 *
 *   firebase functions:secrets:set KAKAO_REST_API_KEY
 *   firebase deploy --only functions
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";

initializeApp();

// 앱(lib/data/place/place_search.dart)의 region과 같아야 한다.
// invoker: "public" — 앱(Firebase SDK)이 호출할 수 있게 Cloud Run 호출 권한을 연다.
// 로그인 여부는 각 함수 안에서 request.auth로 확인한다.
setGlobalOptions({
  region: "asia-northeast3",
  maxInstances: 10,
  invoker: "public",
});

const kakaoKey = defineSecret("KAKAO_REST_API_KEY");

const KAKAO_URL = "https://dapi.kakao.com/v2/local/search/keyword.json";
const MIN_QUERY = 2; // AppLimits.placeSearchMinLength
const MAX_QUERY = 30; // AppLimits.placeSearchMaxLength
const PAGE_SIZE = 15; // AppLimits.placeSearchMaxResults (카카오 최대 15)

interface KakaoDocument {
  id: string;
  place_name: string;
  category_name: string;
  road_address_name: string;
  address_name: string;
  x: string; // 경도
  y: string; // 위도
}

export interface PlaceResult {
  id: string;
  name: string;
  address: string;
  category: string;
  lat: number | null;
  lng: number | null;
}

/** "음식점 > 카페 > 커피전문점" → "커피전문점" */
function shortCategory(categoryName: string): string {
  const parts = categoryName.split(">").map((p) => p.trim()).filter(Boolean);
  return parts.length ? parts[parts.length - 1] : "";
}

function toPlace(d: KakaoDocument): PlaceResult {
  const lat = Number(d.y);
  const lng = Number(d.x);
  return {
    id: d.id,
    name: d.place_name,
    address: d.road_address_name || d.address_name,
    category: shortCategory(d.category_name),
    lat: Number.isFinite(lat) ? lat : null,
    lng: Number.isFinite(lng) ? lng : null,
  };
}

export const searchPlaces = onCall(
  { secrets: [kakaoKey] /* TODO: App Check 연결 후 enforceAppCheck: true */ },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "로그인이 필요해요.");
    }
    const query = String(request.data?.query ?? "").trim();
    if (query.length < MIN_QUERY || query.length > MAX_QUERY) {
      throw new HttpsError(
        "invalid-argument",
        `검색어는 ${MIN_QUERY}~${MAX_QUERY}자여야 해요.`,
      );
    }

    const url = new URL(KAKAO_URL);
    url.searchParams.set("query", query);
    url.searchParams.set("size", String(PAGE_SIZE));

    const res = await fetch(url, {
      headers: { Authorization: `KakaoAK ${kakaoKey.value()}` },
    });
    if (!res.ok) {
      // 키·쿼터 문제는 로그로만 남기고 앱에는 일반 오류로 알린다.
      // 카카오 오류 응답에는 앱 키가 그대로 들어 있을 수 있어 본문은 남기지 않는다.
      let errorType = "unknown";
      try {
        errorType = String(((await res.json()) as { errorType?: string }).errorType);
      } catch {
        // 본문이 JSON이 아니면 무시
      }
      console.error("kakao search failed", res.status, errorType);
      throw new HttpsError("unavailable", "장소 검색이 잠시 안 돼요.");
    }
    const body = (await res.json()) as { documents?: KakaoDocument[] };
    return { places: (body.documents ?? []).map(toPlace) };
  },
);

export const deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요해요.");
  }
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);

  await db.runTransaction(async (tx) => {
    const user = await tx.get(userRef);
    const key = user.get("nicknameKey") as string | undefined;
    if (key) {
      const nickRef = db.collection("nicknames").doc(key);
      const nick = await tx.get(nickRef);
      if (nick.get("uid") === uid) tx.delete(nickRef);
    }
    if (user.exists) {
      // 대화 상대에게 "떠난 사용자"로 보이도록 문서는 남기고 표시만 한다(US-012).
      tx.update(userRef, { deleted: true, jobCustom: null });
    }
  });
  // 열려 있던 대화방에는 떠났다고 표시한다(상대 입력창이 닫힌다).
  const chats = await db.collection("chats").where("memberUids", "array-contains", uid).get();
  const batch = db.batch();
  chats.docs.forEach((d) => batch.update(d.ref, { leftUids: FieldValue.arrayUnion(uid) }));
  // 체크인 카드도 내린다(장소 인원은 onCheckinWritten이 다시 센다).
  const cards = await db
    .collection("checkins")
    .where("uid", "==", uid)
    .where("checkedOutAt", "==", null)
    .get();
  cards.docs.forEach((d) => batch.update(d.ref, { checkedOutAt: FieldValue.serverTimestamp() }));
  await batch.commit();
  await getAuth().deleteUser(uid);
  return { ok: true };
});

/** 장소의 체크아웃 전 카드를 낸 사람 수(한 사람이 주제를 여러 개 올려도 1명) */
async function recountSpot(spotId: string): Promise<void> {
  const db = getFirestore();
  const snap = await db
    .collection("checkins")
    .where("spotId", "==", spotId)
    .where("checkedOutAt", "==", null)
    .select("uid")
    .get();
  const people = new Set(snap.docs.map((d) => d.get("uid") as string)).size;
  await db.collection("spots").doc(spotId).set(
    { activeCount: people },
    { merge: true },
  );
}

export const onCheckinWritten = onDocumentWritten(
  "checkins/{checkinId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    // 주제 글자만 바뀐 경우처럼 인원과 상관없으면 건너뛴다.
    const sameSpot = before?.spotId === after?.spotId;
    const sameState =
      (before?.checkedOutAt == null) === (after?.checkedOutAt == null);
    if (before && after && sameSpot && sameState) return;

    const spotIds = new Set<string>();
    if (before?.spotId) spotIds.add(before.spotId as string);
    if (after?.spotId) spotIds.add(after.spotId as string);
    await Promise.all([...spotIds].map(recountSpot));
  },
);

// ── 2-2. 대화 요청 ─────────────────────────────────────

// lib/core/constants/app_limits.dart 와 같은 값
const REQUEST_MESSAGE_MAX = 40;
const REQUEST_EXPIRY_MS = 30 * 60 * 1000;
const FREE_DAILY_REQUESTS = 5;
const CHAT_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;

/** 한국 시간 기준 오늘 0시 */
function startOfTodayKst(now: Date): Date {
  const kst = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  kst.setUTCHours(0, 0, 0, 0);
  return new Date(kst.getTime() - 9 * 60 * 60 * 1000);
}

function isPlusActive(user: FirebaseFirestore.DocumentData | undefined): boolean {
  const until = user?.plusExpiresAt as Timestamp | undefined;
  return user?.isPlus === true && !!until && until.toMillis() > Date.now();
}

type SendResult = "sent" | "duplicate" | "dailyLimit" | "notCheckedIn" | "gone";

export const sendRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
  const toCheckinId = String(request.data?.toCheckinId ?? "");
  const message = String(request.data?.message ?? "").trim();
  if (!toCheckinId || message.length < 1 || message.length > REQUEST_MESSAGE_MAX) {
    throw new HttpsError("invalid-argument", "요청 내용을 확인해 주세요.");
  }

  const db = getFirestore();
  const [meSnap, targetSnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("checkins").doc(toCheckinId).get(),
  ]);
  const me = meSnap.data();
  if (!me || me.suspended === true) {
    throw new HttpsError("permission-denied", "요청을 보낼 수 없어요.");
  }
  const target = targetSnap.data();
  if (!target || target.checkedOutAt != null || target.uid === uid) {
    return { result: "gone" satisfies SendResult };
  }
  const toUid = target.uid as string;
  const spotId = target.spotId as string;
  // 어느 한쪽이 차단했으면 보내지 않는다(차단 사실은 알리지 않고 "볼 수 없는 카드"로).
  const [iBlocked, theyBlocked] = await Promise.all([
    db.collection("users").doc(uid).collection("blocks").doc(toUid).get(),
    db.collection("users").doc(toUid).collection("blocks").doc(uid).get(),
  ]);
  if (iBlocked.exists || theyBlocked.exists) {
    return { result: "gone" satisfies SendResult };
  }

  // 나도 같은 장소에 체크인해 있어야 한다.
  const myCard = await db
    .collection("checkins")
    .where("uid", "==", uid)
    .where("spotId", "==", spotId)
    .where("checkedOutAt", "==", null)
    .limit(1)
    .get();
  if (myCard.empty) return { result: "notCheckedIn" satisfies SendResult };

  const now = new Date();
  // 같은 사람에게는 답을 기다리는 요청 1개만
  const pending = await db
    .collection("chatRequests")
    .where("fromUid", "==", uid)
    .where("toUid", "==", toUid)
    .where("status", "==", "pending")
    .get();
  if (pending.docs.some((d) => (d.get("expiresAt") as Timestamp).toMillis() > now.getTime())) {
    return { result: "duplicate" satisfies SendResult };
  }

  // 무료는 하루 5번(한국 시간 기준)
  if (!isPlusActive(me)) {
    const today = await db
      .collection("chatRequests")
      .where("fromUid", "==", uid)
      .where("createdAt", ">=", Timestamp.fromDate(startOfTodayKst(now)))
      .count()
      .get();
    if (today.data().count >= FREE_DAILY_REQUESTS) {
      return { result: "dailyLimit" satisfies SendResult };
    }
  }

  const ref = await db.collection("chatRequests").add({
    fromUid: uid,
    toUid,
    spotId,
    toCheckinId,
    message,
    status: "pending",
    createdAt: Timestamp.fromDate(now),
    expiresAt: Timestamp.fromMillis(now.getTime() + REQUEST_EXPIRY_MS),
    fromNickname: me.nickname ?? "",
    fromJobTag: me.jobTag ?? "other",
    fromJobCustom: me.jobCustom ?? null,
    chatId: null,
  });
  // TODO(fcm): 받는 사람에게 푸시
  return { result: "sent" satisfies SendResult, requestId: ref.id };
});

export const respondRequest = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
  const requestId = String(request.data?.requestId ?? "");
  const accept = request.data?.accept === true;
  if (!requestId) throw new HttpsError("invalid-argument", "요청이 없어요.");

  const db = getFirestore();
  const reqRef = db.collection("chatRequests").doc(requestId);
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(reqRef);
    const req = snap.data();
    if (!req || req.toUid !== uid) {
      throw new HttpsError("not-found", "볼 수 없는 요청이에요.");
    }
    if (req.status !== "pending") {
      return { result: req.status as string, chatId: req.chatId ?? null };
    }
    const now = Date.now();
    if ((req.expiresAt as Timestamp).toMillis() <= now) {
      tx.update(reqRef, { status: "expired" });
      return { result: "expired", chatId: null };
    }
    if (!accept) {
      tx.update(reqRef, { status: "rejected", respondedAt: FieldValue.serverTimestamp() });
      return { result: "rejected", chatId: null };
    }

    // 수락: 채팅방을 만들고 요청 한 마디를 첫 메시지로 넣는다.
    const chatRef = db.collection("chats").doc();
    const fromUid = req.fromUid as string;
    tx.set(chatRef, {
      memberUids: [fromUid, uid],
      requestId,
      spotId: req.spotId ?? null,
      createdAt: Timestamp.fromMillis(now),
      expiresAt: Timestamp.fromMillis(now + CHAT_RETENTION_MS),
      lastMessage: req.message,
      lastMessageAt: Timestamp.fromMillis(now),
      leftUids: [],
      unread: { [fromUid]: 0, [uid]: 0 },
    });
    tx.set(chatRef.collection("messages").doc(), {
      senderUid: fromUid,
      text: req.message,
      sentAt: Timestamp.fromMillis(now),
      // 대화방과 함께 TTL로 지워지도록
      expiresAt: Timestamp.fromMillis(now + CHAT_RETENTION_MS),
    });
    tx.update(reqRef, {
      status: "accepted",
      chatId: chatRef.id,
      respondedAt: FieldValue.serverTimestamp(),
    });
    // TODO(fcm): 요청한 사람에게 "수락했어요" 푸시
    return { result: "accepted", chatId: chatRef.id };
  });
});

/** 30분 안에 답이 없는 요청을 끝낸다(5분마다). */
export const expireRequests = onSchedule(
  { schedule: "every 5 minutes", timeZone: "Asia/Seoul" },
  async () => {
    const db = getFirestore();
    const due = await db
      .collection("chatRequests")
      .where("status", "==", "pending")
      .where("expiresAt", "<=", Timestamp.now())
      .limit(400)
      .get();
    if (due.empty) return;
    const batch = db.batch();
    due.docs.forEach((d) => batch.update(d.ref, { status: "expired" }));
    await batch.commit();
  },
);

// ── 2-3. 채팅 ─────────────────────────────────────────

export const onMessageCreated = onDocumentCreated(
  "chats/{chatId}/messages/{messageId}",
  async (event) => {
    const msg = event.data?.data();
    if (!msg) return;
    const sender = msg.senderUid as string;
    const db = getFirestore();
    const chatRef = db.collection("chats").doc(event.params.chatId);
    await db.runTransaction(async (tx) => {
      const chat = (await tx.get(chatRef)).data();
      if (!chat) return;
      const others = (chat.memberUids as string[]).filter((u) => u !== sender);
      const update: Record<string, unknown> = {
        lastMessage: msg.text,
        lastMessageAt: msg.sentAt ?? FieldValue.serverTimestamp(),
        [`messageCounts.${sender}`]: FieldValue.increment(1),
      };
      for (const o of others) update[`unread.${o}`] = FieldValue.increment(1);
      tx.update(chatRef, update);
    });
    // TODO(fcm): 상대에게 새 메시지 푸시
  },
);

// ── 2-4. 신고·평가 ────────────────────────────────────

const REPORTS_UNTIL_SUSPENSION = 2; // AppLimits.reportsUntilSuspension
const TRUST_BADGE_THRESHOLD = 5; // AppLimits.trustBadgeThreshold

/** 사용자의 체크아웃 전 카드 */
function activeCards(uid: string) {
  return getFirestore()
    .collection("checkins")
    .where("uid", "==", uid)
    .where("checkedOutAt", "==", null)
    .get();
}

export const onReportCreated = onDocumentCreated("reports/{reportId}", async (event) => {
  const targetUid = event.data?.get("targetUid") as string | undefined;
  if (!targetUid) return;
  const db = getFirestore();
  // 문서 id가 신고자_대상이라 문서 수 = 서로 다른 신고자 수
  const count = await db
    .collection("reports")
    .where("targetUid", "==", targetUid)
    .count()
    .get();
  if (count.data().count < REPORTS_UNTIL_SUSPENSION) return;

  const userRef = db.collection("users").doc(targetUid);
  const user = await userRef.get();
  if (!user.exists || user.get("suspended") === true) return;
  const batch = db.batch();
  batch.update(userRef, { suspended: true, suspendedAt: FieldValue.serverTimestamp() });
  (await activeCards(targetUid)).docs.forEach((d) =>
    batch.update(d.ref, { checkedOutAt: FieldValue.serverTimestamp() }),
  );
  await batch.commit();
  // TODO: 운영자 알림(이의 제기 검토용)
});

export const onReviewCreated = onDocumentCreated(
  "chats/{chatId}/reviews/{reviewerUid}",
  async (event) => {
    if (event.data?.get("rating") !== "good") return;
    const targetUid = event.data?.get("targetUid") as string;
    const db = getFirestore();
    const userRef = db.collection("users").doc(targetUid);
    const after = await db.runTransaction(async (tx) => {
      const user = await tx.get(userRef);
      if (!user.exists) return 0;
      const next = ((user.get("goodReviewCount") as number | undefined) ?? 0) + 1;
      tx.update(userRef, { goodReviewCount: next });
      return next;
    });
    // 기준을 막 넘었으면 올려 둔 카드에도 신뢰 표시를 붙인다.
    if (after === TRUST_BADGE_THRESHOLD) {
      const batch = db.batch();
      (await activeCards(targetUid)).docs.forEach((d) =>
        batch.update(d.ref, { hasTrustBadge: true }),
      );
      await batch.commit();
    }
  },
);
