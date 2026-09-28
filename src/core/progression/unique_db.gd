class_name UniqueDB
extends RefCounted
## 유니크 사건의 단서·각인·칭호(기획서 §13.2 단서 단계, §15 유니크 몬스터, §22.3 탐사 단서판).
## 단서는 본 사실(fact)과 그 단서가 가리키는 방향(존재·위치·조건)을 나눠 적는다.
## 정답(출현 조건)은 단서를 충분히 모았을 때만 추정(deduction)으로 정리해 보여 준다.

enum ClueKind { EXISTENCE, LOCATION, CONDITION }

const CLUE_KIND_NAMES := ["존재", "위치", "조건"]

const CLUES := {
	&"claw_marks": {
		"unique": &"night_predator", "kind": ClueKind.EXISTENCE, "title": "거대한 발톱 자국",
		"where": "그늘 숲 동쪽 가장자리",
		"fact": "나무껍질이 사람 키의 두 배 높이까지 깊게 파였다. 곰보다 훨씬 큰 무언가의 발톱이다.",
	},
	&"night_tracks": {
		"unique": &"night_predator", "kind": ClueKind.LOCATION, "title": "숲 한가운데로 이어진 발자국",
		"where": "그늘 숲 안쪽",
		"fact": "사람 몸통만 한 발자국이 그늘 숲 한가운데로 이어진다. 흙이 아직 축축하다. 밤사이 찍힌 것이다.",
	},
	&"explorer_journal": {
		"unique": &"night_predator", "kind": ClueKind.CONDITION, "title": "찢긴 탐사 일지",
		"where": "북쪽 야영지",
		"fact": "「셋째 밤. 풀벌레 소리가 한꺼번에 멎었다. 그늘 숲 깊은 곳, 달빛도 들지 않는 데서 푸른 눈 두 개가…」 뒷장은 찢겨 나갔다.",
	},
	&"night_glimpse": {
		"unique": &"night_predator", "kind": ClueKind.EXISTENCE, "title": "어둠 속의 푸른 눈",
		"where": "밤의 그늘 숲",
		"fact": "밤의 그늘 숲에서 풀벌레 소리가 멎더니, 나무 사이로 푸른 눈 두 개가 이쪽을 보고 있었다. 눈 깜짝할 사이에 사라졌다.",
	},
}

## 유니크별 정보. 단서가 need개 이상 모이면 탐사 기록에 추정이 정리된다(기획서 §13.3).
const UNIQUES := {
	&"night_predator": {
		"name": "밤의 포식자",
		"hidden_name": "???",
		"clues_needed": 2,
		"deduction": "밤에만, 그늘 숲 깊은 곳(숲 한가운데)에 나타난다. 나타나기 전에 풀벌레 소리가 멎는다.",
		"hint_before": "그늘 숲 쪽에 무언가 있다는 소문이 돈다. 흔적을 더 찾아보자.",
	},
}

const MARKS := {
	&"predator_mark": {
		"name": "밤의 포식자의 각인",
		"desc": "밤의 포식자에게서 살아남은 자에게 남은 표식. 지워지지 않는다.",
		"effects": [
			"약한 야생 몬스터(일반·강화 등급, 레벨이 비슷하거나 낮은 개체)는 먼저 덤비지 않고 달아난다",
			"밤눈이 밝아진다(밤과 그늘 숲이 덜 어둡다)",
			"대신 나보다 강한 몬스터는 표식을 알아보고 더 멀리서 알아챈다",
		],
	},
}

const TITLES := {
	&"night_survivor": "밤을 넘긴 자",
	&"maw_hunter": "늪턱을 꺾은 자",
}


static func has_clue(id: StringName) -> bool:
	return CLUES.has(id)


static func clue(id: StringName) -> Dictionary:
	return CLUES.get(id, {})


static func clue_title(id: StringName) -> String:
	return String(CLUES[id].title) if CLUES.has(id) else String(id)


static func clue_kind_name(id: StringName) -> String:
	return CLUE_KIND_NAMES[int(CLUES[id].kind)] if CLUES.has(id) else ""


static func clues_for(unique_id: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in CLUES:
		if CLUES[id].unique == unique_id:
			out.append(id)
	return out


static func unique_name(unique_id: StringName, revealed: bool) -> String:
	var u: Dictionary = UNIQUES.get(unique_id, {})
	if u.is_empty():
		return String(unique_id)
	return String(u.name) if revealed else String(u.hidden_name)


static func mark_name(id: StringName) -> String:
	return String(MARKS[id].name) if MARKS.has(id) else String(id)


static func title_name(id: StringName) -> String:
	return String(TITLES.get(id, String(id)))
