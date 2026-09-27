extends Node
## 전역 신호 버스. 전투 시스템과 HUD·효과음 사이의 직접 참조를 줄인다.

enum NoticeKind { INFO, ANALYSIS, UNLOCK, PICKUP, WARNING }
## 화면 가운데 위에 크게 뜨는 공명 장치 알림의 종류
enum AnnounceKind { LEVEL_UP, DISCOVERY, SKILL, QUEST, UNIQUE, SYSTEM }

## 플레이어의 공격이 명중했다(히트마커, 효과음, 피해 수치).
signal hit_confirmed(result: HitResult)
## 플레이어가 공격받았다. source_position은 피격 방향 표시에 쓴다.
signal player_damaged(amount: float, source_position: Vector3, blocked: bool)
## 패링 성공
signal parry_succeeded(enemy: Node)
## 회피 무적으로 공격을 피했다
signal attack_evaded(enemy: Node)
## 공격이 닿기 직전에 피했다(간발의 회피)
signal perfect_evaded(enemy: Node)
signal notice(text: String, kind: int)
signal enemy_killed(enemy: Node)
signal player_died
signal player_respawned
## 공명 장치 알림(레벨업, 지역 발견, 스킬 습득, 유니크 시나리오 등)
signal announcement(title: String, subtitle: String, kind: int)
## 경험치를 얻었다
signal xp_gained(amount: int, reason: String)
## 재료·의뢰 물품을 얻었다
signal item_collected(item_id: StringName, count: int)
## 주민과 이야기했다(의뢰 진행용)
signal npc_talked(npc_id: StringName)
## 의뢰 보상 등으로 소모품을 받는다(플레이어가 받아 넣는다)
signal consumable_granted(consumable_id: StringName, count: int)


func notify(text: String, kind: int = NoticeKind.INFO) -> void:
	notice.emit(text, kind)


func announce(title: String, subtitle: String = "", kind: int = AnnounceKind.SYSTEM) -> void:
	announcement.emit(title, subtitle, kind)
