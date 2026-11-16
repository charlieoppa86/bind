/**
 * BIND Cloud Functions
 *
 * searchPlaces: 카카오 로컬 "키워드로 장소 검색"을 대신 호출한다.
 *   카카오 REST API 키는 앱에 넣지 않고 Secret Manager에만 둔다.
 * deleteAccount: 탈퇴. 닉네임 예약을 풀고 프로필을 "떠난 사용자"로 표시한 뒤
 *   Auth 계정을 지운다(클라이언트 규칙으로는 못 하는 일).
 *
 *   firebase functions:secrets:set KAKAO_REST_API_KEY
 *   firebase deploy --only functions
 */
import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { setGlobalOptions } from "firebase-functions/v2";
import { HttpsError, onCall } from "firebase-functions/v2/https";
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
  // TODO(2단계): 내 체크인 체크아웃 처리, 대기 중 요청 정리
  await getAuth().deleteUser(uid);
  return { ok: true };
});
