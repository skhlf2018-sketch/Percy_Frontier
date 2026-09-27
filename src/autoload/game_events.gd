extends Node
## 전역 신호 버스. 전투 시스템과 HUD·효과음 사이의 직접 참조를 줄인다.

enum NoticeKind { INFO, ANALYSIS, UNLOCK, PICKUP, WARNING }

## 플레이어의 공격이 명중했다(히트마커, 효과음, 피해 수치).
signal hit_confirmed(result: HitResult)
## 플레이어가 공격받았다. source_position은 피격 방향 표시에 쓴다.
signal player_damaged(amount: float, source_position: Vector3, blocked: bool)
## 패링 성공
signal parry_succeeded(enemy: Node)
## 회피 무적으로 공격을 피했다
signal attack_evaded(enemy: Node)
signal notice(text: String, kind: int)
signal enemy_killed(enemy: Node)
signal player_died
signal player_respawned


func notify(text: String, kind: int = NoticeKind.INFO) -> void:
	notice.emit(text, kind)
