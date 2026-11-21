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
 * onRequestWritten / (onMessageCreated·onCheckinWritten 안) : 푸시 알림(개별 토큰 발송)
 * sendTopicPush: 운영자 토픽 발송(관리자 권한), sendTestPush: 내 기기로 테스트 발송
 * deleteAccount: 탈퇴. 닉네임 예약을 풀고 프로필·카드·요청·차단·푸시 토큰을 지운 뒤
 *   "떠난 사용자" 표시만 남기고 Auth 계정을 지운다(클라이언트 규칙으로는 못 하는 일).
 * aggregateDailyMetrics: 매일 0시 30분(KST) 전날 지표(성사 대화·요청·체크인·장소 동시 인원·
 *   7일 재체크인·신고)를 metrics/{YYYY-MM-DD}에 숫자로 저장한다. 성사 시각은 onMessageCreated가 남긴다.
 * 보관 기간(TTL, firestore.indexes.json): 대화방·메시지·평가 7일, 신고 1년.
 *
 *   firebase functions:secrets:set KAKAO_REST_API_KEY
 *   firebase deploy --only functions
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { FieldValue, Timestamp, getFirestore } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
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
      // 프로필(닉네임·하는 일·동의 시각 등)은 모두 지우고, 대화 상대에게
      // "떠난 사용자"로 보이게 하는 표시만 남긴다(US-012, 개인정보처리방침 "탈퇴 시 파기").
      tx.set(userRef, { deleted: true, deletedAt: FieldValue.serverTimestamp() });
    }
  });

  // 문서가 많을 수 있어 배치(500건 제한) 대신 BulkWriter로 쓴다.
  const writer = db.bulkWriter();
  // 열려 있던 대화방에는 떠났다고 표시한다(상대 입력창이 닫힌다).
  // 대화방·메시지·평가는 7일 보관 기간이 끝나면 TTL로 지워진다.
  const chats = await db.collection("chats").where("memberUids", "array-contains", uid).get();
  chats.docs.forEach((d) => writer.update(d.ref, { leftUids: FieldValue.arrayUnion(uid) }));
  // 푸시 토큰·차단 목록을 지운다.
  for (const sub of ["fcmTokens", "blocks"]) {
    (await userRef.collection(sub).get()).docs.forEach((d) => writer.delete(d.ref));
  }
  // 체크인 카드(지난 카드 포함)를 지운다. 장소 인원은 onCheckinWritten이 다시 센다.
  (await db.collection("checkins").where("uid", "==", uid).get()).docs.forEach((d) =>
    writer.delete(d.ref),
  );
  // 보내고 받은 대화 요청(닉네임·한 마디가 담김)을 지운다.
  for (const field of ["fromUid", "toUid"]) {
    (await db.collection("chatRequests").where(field, "==", uid).get()).docs.forEach((d) =>
      writer.delete(d.ref),
    );
  }
  // 처음 만든 장소에 남은 내 uid를 지운다(장소 자체는 다른 사람도 쓰므로 남긴다).
  (await db.collection("spots").where("creatorUid", "==", uid).get()).docs.forEach((d) =>
    writer.update(d.ref, { creatorUid: null }),
  );
  await writer.close();
  // 신고 기록(reports)은 분쟁 대응·부정 이용 방지를 위해 접수 1년 뒤 TTL로 지워질 때까지 남긴다.
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

    // US-015: 새로 체크인하면 "누가 오면 알려줘"를 켜 둔 같은 장소 사람에게 한 번 알린다.
    if (!before && after && after.checkedOutAt == null) {
      await notifyArrival(after.spotId as string, after.uid as string, after);
    }
  },
);

// ── 푸시 알림(FCM) ─────────────────────────────────────

const PUSH_CHANNEL = "bind_default"; // 앱의 Android 알림 채널(FirebasePushPlatform.channelId)

interface PushPayload {
  title: string;
  body: string;
  type: string; // request · accepted · rejected · expired · message · arrival · notice · test
  route?: string; // 앱 안 화면 경로(앱은 허용된 경로만 연다)
  collapseKey?: string; // 같은 대화방 알림은 하나로 묶는다
}

function messageFor(p: PushPayload) {
  const data: Record<string, string> = { type: p.type };
  if (p.route) data.route = p.route;
  return {
    notification: { title: p.title, body: p.body },
    data,
    android: {
      priority: "high" as const,
      collapseKey: p.collapseKey,
      notification: {
        channelId: PUSH_CHANNEL,
        icon: "ic_stat_bind",
        color: "#2F80FF",
        tag: p.collapseKey,
      },
    },
    apns: {
      payload: { aps: { sound: "default", threadId: p.collapseKey } },
    },
  };
}

/** 한 사람의 모든 기기로 보낸다. 만료된 토큰은 지운다. */
async function pushToUser(uid: string, p: PushPayload): Promise<void> {
  const db = getFirestore();
  const snap = await db.collection("users").doc(uid).collection("fcmTokens").get();
  if (snap.empty) return;
  const tokens = snap.docs.map((d) => d.id);
  const res = await getMessaging().sendEachForMulticast({ tokens, ...messageFor(p) });
  const stale: Promise<unknown>[] = [];
  res.responses.forEach((r, i) => {
    const code = r.error?.code;
    if (
      code === "messaging/registration-token-not-registered" ||
      code === "messaging/invalid-registration-token" ||
      code === "messaging/invalid-argument"
    ) {
      stale.push(snap.docs[i].ref.delete());
    }
  });
  await Promise.all(stale);
}

/** 토픽을 구독한 모든 기기로 보낸다. */
async function pushToTopic(topic: string, p: PushPayload): Promise<string> {
  return getMessaging().send({ topic, ...messageFor(p) });
}

/** [to]가 [from]을 차단했으면 알림을 보내지 않는다. */
async function blocked(to: string, from: string): Promise<boolean> {
  const doc = await getFirestore()
    .collection("users").doc(to).collection("blocks").doc(from).get();
  return doc.exists;
}

async function nicknameOf(uid: string): Promise<string> {
  const user = await getFirestore().collection("users").doc(uid).get();
  return (user.get("nickname") as string | undefined) ?? "상대";
}

/** 요청이 생기거나 상태가 바뀌면 알린다(sendRequest·respondRequest·expireRequests 모두 여기로). */
export const onRequestWritten = onDocumentWritten(
  "chatRequests/{requestId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!after) return;
    const id = event.params.requestId;
    const from = after.fromUid as string;
    const to = after.toUid as string;

    // 새 요청 → 받는 사람
    if (!before) {
      if (await blocked(to, from)) return;
      await pushToUser(to, {
        type: "request",
        title: "새 대화 요청",
        body: `${after.fromNickname ?? "누군가"}님: "${after.message}"`,
        route: `/requests/received/${id}`,
      });
      return;
    }
    if (before.status === after.status || before.status !== "pending") return;

    // 수락·거절·만료 → 보낸 사람
    const name = await nicknameOf(to);
    switch (after.status) {
      case "accepted":
        await pushToUser(from, {
          type: "accepted",
          title: "대화 요청이 수락됐어요",
          body: `${name}님과 대화를 시작해 보세요`,
          route: after.chatId ? `/chats/${after.chatId}` : "/requests/sent",
        });
        break;
      case "rejected":
        await pushToUser(from, {
          type: "rejected",
          title: "대화 요청 결과",
          body: `${name}님은 이번엔 어렵대요`,
          route: "/requests/sent",
        });
        break;
      case "expired":
        await pushToUser(from, {
          type: "expired",
          title: "요청이 끝났어요",
          body: `${name}님이 30분 안에 답하지 않아 요청이 끝났어요`,
          route: "/requests/sent",
        });
        break;
    }
  },
);

/** 운영자: 토픽으로 한 번에 보내기(관리자 커스텀 클레임 admin=true만) */
export const sendTopicPush = onCall(async (request) => {
  if (request.auth?.token.admin !== true) {
    throw new HttpsError("permission-denied", "관리자만 보낼 수 있어요.");
  }
  const topic = String(request.data?.topic ?? "");
  const title = String(request.data?.title ?? "").trim();
  const body = String(request.data?.body ?? "").trim();
  if (!/^[a-zA-Z0-9_-]{1,64}$/.test(topic) || !title) {
    throw new HttpsError("invalid-argument", "토픽과 제목을 확인해 주세요.");
  }
  const route = typeof request.data?.route === "string" ? request.data.route : undefined;
  const id = await pushToTopic(topic, { type: "notice", title, body, route });
  return { messageId: id };
});

/** 개발용: 내 기기로 테스트 알림(token: 내 토큰들, topic: 내 개인 토픽 u_{uid}) */
export const sendTestPush = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요해요.");
  const viaTopic = request.data?.mode === "topic";
  // 백그라운드·종료 상태를 시험하려고 몇 초 뒤에 보낼 수 있다(최대 15초).
  const delay = Math.min(Math.max(Number(request.data?.delaySeconds ?? 0), 0), 15);
  if (delay > 0) await new Promise((r) => setTimeout(r, delay * 1000));
  const payload: PushPayload = {
    type: "test",
    title: viaTopic ? "토픽 테스트 알림" : "토큰 테스트 알림",
    body: "누르면 요청 화면으로 이동해요",
    route: "/requests/received",
  };
  if (viaTopic) {
    await pushToTopic(`u_${uid}`, payload);
  } else {
    await pushToUser(uid, payload);
  }
  return { ok: true };
});

// ── 2-2. 대화 요청 ─────────────────────────────────────

// lib/core/constants/app_limits.dart 와 같은 값
const REQUEST_MESSAGE_MAX = 40;
const REQUEST_EXPIRY_MS = 30 * 60 * 1000;
const FREE_DAILY_REQUESTS = 5;
const CHAT_RETENTION_MS = 7 * 24 * 60 * 60 * 1000;
/** 성사 대화 기준: 양쪽이 각각 이 수 이상 메시지를 보낸 대화방(BIND_blueprint 7장 NSM) */
const SUCCESS_MESSAGES = 3;
/** 신고 기록 보관 기간(개인정보처리방침): 접수 1년 뒤 TTL로 삭제 */
const REPORT_RETENTION_MS = 365 * 24 * 60 * 60 * 1000;

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
      // 성사 대화(NSM): 양쪽이 각각 SUCCESS_MESSAGES개 이상 보낸 첫 순간을 남긴다.
      // 대화방은 7일 뒤 지워지므로, 매일 집계(aggregateDailyMetrics)가 이 시각으로 센다.
      if (!chat.succeededAt) {
        const counts = { ...((chat.messageCounts as Record<string, number>) ?? {}) };
        counts[sender] = (counts[sender] ?? 0) + 1;
        const members = chat.memberUids as string[];
        if (members.every((u) => (counts[u] ?? 0) >= SUCCESS_MESSAGES)) {
          update.succeededAt = FieldValue.serverTimestamp();
        }
      }
      tx.update(chatRef, update);
    });

    // 새 메시지 → 상대(떠났거나 나를 차단했으면 보내지 않는다)
    const chat = (await chatRef.get()).data();
    if (!chat) return;
    const left = (chat.leftUids as string[] | undefined) ?? [];
    const others = (chat.memberUids as string[]).filter(
      (u) => u !== sender && !left.includes(u),
    );
    const name = await nicknameOf(sender);
    const text = String(msg.text ?? "");
    await Promise.all(
      others.map(async (o) => {
        if (await blocked(o, sender)) return;
        await pushToUser(o, {
          type: "message",
          title: name,
          body: text.length > 100 ? `${text.slice(0, 100)}…` : text,
          route: `/chats/${event.params.chatId}`,
          collapseKey: `chat_${event.params.chatId}`,
        });
      }),
    );
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
  // 보관 기간이 끝나면 TTL로 지워지게 한다(클라이언트는 이 필드를 쓸 수 없다).
  await event.data?.ref.update({
    expiresAt: Timestamp.fromMillis(Date.now() + REPORT_RETENTION_MS),
  });
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
    const db = getFirestore();
    // 평가도 대화방과 함께 7일 뒤 TTL로 지워지게 방의 만료 시각을 붙인다.
    // (TTL은 상위 문서가 지워져도 하위 컬렉션을 지우지 않는다)
    const chat = await db.collection("chats").doc(event.params.chatId).get();
    const chatExpiresAt = chat.get("expiresAt") as Timestamp | undefined;
    await event.data?.ref.update({
      expiresAt: chatExpiresAt ?? Timestamp.fromMillis(Date.now() + CHAT_RETENTION_MS),
    });
    if (event.data?.get("rating") !== "good") return;
    const targetUid = event.data?.get("targetUid") as string;
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

/** 같은 장소에서 "누가 오면 알려줘"를 켠 사람에게 알리고 설정을 끈다(한 번만). */
async function notifyArrival(
  spotId: string,
  newcomer: string,
  card: FirebaseFirestore.DocumentData,
): Promise<void> {
  const db = getFirestore();
  const waiting = await db
    .collection("checkins")
    .where("spotId", "==", spotId)
    .where("notifyWhenSomeoneArrives", "==", true)
    .where("checkedOutAt", "==", null)
    .get();
  const owners = new Set<string>();
  const batch = db.batch();
  for (const d of waiting.docs) {
    const owner = d.get("uid") as string;
    if (owner === newcomer) continue;
    owners.add(owner);
    batch.update(d.ref, { notifyWhenSomeoneArrives: false });
  }
  if (owners.size === 0) return;
  await batch.commit();
  await Promise.all(
    [...owners].map(async (owner) => {
      if (await blocked(owner, newcomer)) return;
      await pushToUser(owner, {
        type: "arrival",
        title: "누가 왔어요",
        body: `${card.nickname ?? "누군가"}님이 체크인했어요: "${card.topic ?? ""}"`,
        route: "/spot",
      });
    }),
  );
}

// ── 3. 지표 집계 ──────────────────────────────────────
//
// 매일 0시 30분(KST)에 전날 지표를 metrics/{YYYY-MM-DD}에 저장한다(숫자만, 개인 식별 정보 없음).
// 대화방·메시지는 7일 뒤 TTL로 지워지므로 그 전에 세어 둔다. 클라이언트는 읽을 수 없다(firestore.rules).
// 지표 정의: BIND_blueprint 7장(NSM·보조 1~3·가드레일).

const DAY_MS = 24 * 60 * 60 * 1000;
const KST_MS = 9 * 60 * 60 * 1000;

/** 시각 → KST 날짜 문자열(YYYY-MM-DD) */
function kstDay(ms: number): string {
  return new Date(ms + KST_MS).toISOString().slice(0, 10);
}

/** KST 날짜 문자열 → 그날 0시(ms) */
function kstDayStartMs(day: string): number {
  return Date.parse(`${day}T00:00:00+09:00`);
}

function median(xs: number[]): number | null {
  if (xs.length === 0) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

function ratio(n: number, d: number): number | null {
  return d === 0 ? null : Math.round((n / d) * 1000) / 1000;
}

function millisOf(v: unknown): number | null {
  return v instanceof Timestamp ? v.toMillis() : null;
}

/** 사람별 체크인 시작 시각 목록(오름차순). 지난 카드도 남아 있어 첫 체크인을 알 수 있다. */
async function checkinTimesOf(uids: Iterable<string>): Promise<Map<string, number[]>> {
  const db = getFirestore();
  const out = new Map<string, number[]>();
  await Promise.all(
    [...uids].map(async (uid) => {
      const snap = await db.collection("checkins").where("uid", "==", uid).select("startedAt").get();
      const times = snap.docs
        .map((d) => millisOf(d.get("startedAt")))
        .filter((t): t is number => t !== null)
        .sort((a, b) => a - b);
      out.set(uid, times);
    }),
  );
  return out;
}

/** 장소별로 그날 가장 많이 겹친 체크인 인원(같은 사람의 카드 여러 장은 1명) */
function spotPeaks(
  cards: { uid: string; spotId: string; start: number; end: number }[],
): number[] {
  const bySpot = new Map<string, typeof cards>();
  for (const c of cards) bySpot.set(c.spotId, [...(bySpot.get(c.spotId) ?? []), c]);
  const peaks: number[] = [];
  for (const list of bySpot.values()) {
    const events = list.flatMap((c) => [
      { t: c.start, d: 1, uid: c.uid },
      { t: c.end, d: -1, uid: c.uid },
    ]);
    // 같은 시각이면 나간 사람을 먼저 뺀다.
    events.sort((a, b) => a.t - b.t || a.d - b.d);
    const open = new Map<string, number>();
    let peak = 0;
    for (const e of events) {
      const n = (open.get(e.uid) ?? 0) + e.d;
      if (n <= 0) open.delete(e.uid);
      else open.set(e.uid, n);
      peak = Math.max(peak, open.size);
    }
    peaks.push(peak);
  }
  return peaks;
}

/** [day]의 지표를 계산해 metrics/{day}에 저장한다. */
async function computeDailyMetrics(day: string): Promise<Record<string, unknown>> {
  const db = getFirestore();
  const start = kstDayStartMs(day);
  const end = start + DAY_MS;
  const inDay = (field: string, col: string) =>
    db
      .collection(col)
      .where(field, ">=", Timestamp.fromMillis(start))
      .where(field, "<", Timestamp.fromMillis(end));

  // NSM: 그날 성사된 대화방(succeededAt 기준)
  const succeeded = await inDay("succeededAt", "chats").count().get();

  // 대화 요청
  const reqs = await inDay("createdAt", "chatRequests").select("fromUid", "toUid", "status").get();
  const accepted = reqs.docs.filter((d) => d.get("status") === "accepted");
  const chattedUids = new Set(accepted.flatMap((d) => [d.get("fromUid"), d.get("toUid")] as string[]));

  // 체크인: 그날 시작한 카드
  const started = await inDay("startedAt", "checkins").select("uid").get();
  const checkinUids = new Set(started.docs.map((d) => d.get("uid") as string));

  // 장소 동시 인원: 그날과 겹친 카드(그날 이후 체크아웃했거나 아직 체크인 중인 카드 중 그날 끝 전에 시작한 것)
  const [closed, open] = await Promise.all([
    db.collection("checkins").where("checkedOutAt", ">=", Timestamp.fromMillis(start))
      .select("uid", "spotId", "startedAt", "checkedOutAt").get(),
    db.collection("checkins").where("checkedOutAt", "==", null)
      .select("uid", "spotId", "startedAt").get(),
  ]);
  const cards = [...closed.docs, ...open.docs]
    .map((d) => ({
      uid: d.get("uid") as string,
      spotId: d.get("spotId") as string,
      start: Math.max(millisOf(d.get("startedAt")) ?? end, start),
      end: Math.min(millisOf(d.get("checkedOutAt")) ?? end, end),
    }))
    .filter((c) => c.start < end && c.end > c.start);
  const peaks = spotPeaks(cards);

  // 7일 재체크인율: 7일 전에 처음 체크인한 사람 중, 그 뒤 7일 안(다른 날)에 다시 체크인한 비율
  const cohortDay = kstDay(start - 7 * DAY_MS);
  const cohortStart = kstDayStartMs(cohortDay);
  const cohortCards = await db.collection("checkins")
    .where("startedAt", ">=", Timestamp.fromMillis(cohortStart))
    .where("startedAt", "<", Timestamp.fromMillis(cohortStart + DAY_MS))
    .select("uid").get();
  const times = await checkinTimesOf(
    new Set([...checkinUids, ...cohortCards.docs.map((d) => d.get("uid") as string)]),
  );
  let cohort = 0;
  let returned = 0;
  for (const uid of new Set(cohortCards.docs.map((d) => d.get("uid") as string))) {
    const t = times.get(uid) ?? [];
    if (t.length === 0 || kstDay(t[0]) !== cohortDay) continue; // 첫 체크인이 그날인 사람만
    cohort++;
    if (t.some((x) => kstDay(x) !== cohortDay && x <= t[0] + 7 * DAY_MS)) returned++;
  }
  const newCheckinUsers = [...checkinUids].filter((u) => kstDay((times.get(u) ?? [0])[0]) === day).length;

  // 가드레일: 신고
  const reports = await inDay("createdAt", "reports").count().get();
  const reportCount = reports.data().count;

  const metrics = {
    date: day,
    computedAt: FieldValue.serverTimestamp(),
    // NSM
    succeededChats: succeeded.data().count,
    // 요청
    requests: reqs.size,
    acceptedRequests: accepted.length,
    acceptRate: ratio(accepted.length, reqs.size),
    // 체크인
    checkins: started.size,
    checkinUsers: checkinUids.size,
    newCheckinUsers,
    // 보조 1: 그날 체크인한 사람 중 그날 수락된 대화가 있는 비율
    checkinToChatRate: ratio([...checkinUids].filter((u) => chattedUids.has(u)).length, checkinUids.size),
    // 보조 2: 장소별 그날 최대 동시 인원
    activeSpots: peaks.length,
    spotPeakMedian: median(peaks),
    spotPeakMax: peaks.length ? Math.max(...peaks) : null,
    // 보조 3: 7일 재체크인(cohortDate에 첫 체크인한 사람 기준)
    retention7d: { cohortDate: cohortDay, cohortSize: cohort, returned, rate: ratio(returned, cohort) },
    // 가드레일: 수락된 대화 100건당 신고
    reports: reportCount,
    reportsPer100Chats: accepted.length === 0 ? null : Math.round((reportCount / accepted.length) * 10000) / 100,
  };
  await db.collection("metrics").doc(day).set(metrics);
  return metrics;
}

/** 매일 0시 30분(KST)에 전날 지표를 저장한다. */
export const aggregateDailyMetrics = onSchedule(
  { schedule: "30 0 * * *", timeZone: "Asia/Seoul" },
  async () => {
    await computeDailyMetrics(kstDay(Date.now() - DAY_MS));
  },
);
