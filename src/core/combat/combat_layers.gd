class_name CombatLayers
extends RefCounted
## 물리 레이어 비트 마스크. project.godot의 [layer_names] 순서와 맞춘다.

const WORLD := 1 << 0
const PLAYER := 1 << 1
const ENEMY := 1 << 2
const HURTBOX := 1 << 3
const INTERACTABLE := 1 << 4
const PICKUP := 1 << 5

## 플레이어의 사격·근접·스킬이 맞힐 수 있는 대상: 지형과 적 피격 부위
const PLAYER_ATTACK_MASK := WORLD | HURTBOX
## 적의 투사체가 맞힐 수 있는 대상: 지형과 플레이어
const ENEMY_ATTACK_MASK := WORLD | PLAYER
