#!/usr/bin/env python3
"""몬스터 데이터 생성기.

몬스터 수가 많아지므로(목표: 일반 250 · 희귀 50 · 보스 12 · 유니크 8) 능력치와 공격 패턴을 이 표 한 곳에서 관리하고
data/enemies/<id>.tres를 만든다. 표를 고친 뒤 다시 실행한다:

    python3 tools/gen_enemy_data.py

손으로 만든 예전 데이터(살인토끼, 바위등 돌격수, 포자 사수, 밤의 포식자, 훈련용 표적)는 건드리지 않는다.
"""
from __future__ import annotations

import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "data", "enemies")

# 위협 등급(EnemyData.ThreatTier)
NORMAL, ENHANCED, RARE, ELITE, BOSS, UNIQUE = range(6)
# 공격 종류(EnemyAttackData.Kind)
STRIKE, LUNGE, CHARGE, PROJECTILE, SHOT, SPECIAL = range(6)
# 공격권 그룹(EnemyAttackData.TokenGroup)
TOKEN_NONE, TOKEN_MELEE, TOKEN_RANGED = range(3)


def atk(aid: str, name: str, kind: int, **kw) -> dict:
    d = {"id": aid, "display_name": name, "kind": kind}
    d.update(kw)
    return d


SPECIES: list[dict] = [
    # --- 토끼류 ---
    dict(
        id="horn_rabbit", display_name="뿔토끼", family="토끼 계열", threat_tier=ENHANCED, combat_role="돌격",
        description="이마에 짧은 뿔이 난 토끼. 숨지 않고 둘씩 다니며, 뒷발을 구르다 곧게 들이받는다. "
        "들이받기는 막을 수 없지만 옆으로 비키면 나무나 바위에 부딪혀 잠시 정신을 잃는다.",
        level=3, max_hp=65, walk_speed=2.5, run_speed=7.2, turn_speed_deg=480, poise=24, stagger_duration=0.8, mass_kg=8,
        sight_range=24, sight_fov_deg=130, proximity_sense=3.0, hearing_mult=1.1, leash_radius=32, pack_alert_radius=14,
        attacks=[
            atk("horn_charge", "뿔 들이받기", CHARGE, parryable=False, min_range=3.5, max_range=11.0, windup=0.85,
                active_time=0.8, recovery=0.9, cooldown=3.2, damage=15, reach=1.1, hit_angle_deg=60, move_speed=12,
                knockback=6, wall_stun=1.4),
            atk("horn_jab", "뿔 찌르기", STRIKE, max_range=1.9, windup=0.45, active_time=0.15, recovery=0.6, cooldown=1.6,
                damage=10, reach=1.5, hit_angle_deg=80, knockback=3, weight=1.2, bleed_buildup=20),
        ],
        burn_mult=1.2, xp_reward=24, resonance_on_kill=5, ammo_drop_chance=0.35, heal_drop_chance=0.05,
        model_id="horn_rabbit",
    ),
    dict(
        id="serial_rabbit", display_name="연쇄살인범토끼", family="토끼 계열", threat_tier=RARE, combat_role="매복·돌격",
        description="밤이면 토끼 무리에 섞여 다니는 검은 토끼. 한 번 뛰어들면 숨 돌릴 틈 없이 세 번까지 이어 덮친다. "
        "이어 뛰기 사이의 짧은 착지가 반격할 틈이다.",
        level=6, max_hp=150, defense=0.05, walk_speed=3.0, run_speed=8.5, turn_speed_deg=600, poise=40,
        stagger_duration=0.7, mass_kg=12, sight_range=26, sight_fov_deg=150, proximity_sense=3.5, hearing_mult=1.3,
        leash_radius=40, pack_alert_radius=20,
        attacks=[
            atk("chain_leap", "이어 덮치기", LUNGE, min_range=2.2, max_range=7.0, windup=0.55, active_time=0.42,
                recovery=0.35, cooldown=2.2, damage=12, reach=1.3, hit_angle_deg=70, move_speed=13, knockback=3,
                bleed_buildup=28),
            atk("rend", "할퀴기", STRIKE, max_range=1.7, windup=0.4, active_time=0.12, recovery=0.5, cooldown=1.4,
                damage=9, reach=1.5, hit_angle_deg=80, knockback=2, bleed_buildup=18),
        ],
        bleed_mult=0.8, xp_reward=110, resonance_on_kill=14, ammo_drop_chance=0.6, heal_drop_chance=0.2,
        model_id="serial_rabbit", appears="night",
    ),
    # --- 늑대류 ---
    dict(
        id="ash_wolf", display_name="잿빛 늑대", family="늑대 계열", threat_tier=NORMAL, combat_role="포위",
        description="잿빛 털의 늑대. 서너 마리가 함께 사냥하며, 한 마리가 앞에서 시선을 끄는 동안 나머지가 옆과 뒤로 돌아 문다. "
        "무리 한가운데로 뛰어들기보다 벽을 등지면 한쪽으로만 싸울 수 있다.",
        level=4, max_hp=95, walk_speed=2.6, run_speed=8.2, turn_speed_deg=420, poise=30, stagger_duration=0.9, mass_kg=45,
        sight_range=30, sight_fov_deg=150, proximity_sense=3.5, hearing_mult=1.2, leash_radius=45, pack_alert_radius=25,
        attacks=[
            atk("lunge_bite", "뛰어들어 물기", LUNGE, min_range=2.5, max_range=6.5, windup=0.55, active_time=0.44,
                recovery=0.7, cooldown=2.2, damage=13, reach=1.4, hit_angle_deg=70, move_speed=11, knockback=3.5,
                bleed_buildup=22),
            atk("snap", "물어뜯기", STRIKE, max_range=2.0, windup=0.4, active_time=0.15, recovery=0.55, cooldown=1.5,
                damage=9, reach=1.6, hit_angle_deg=80, knockback=2),
        ],
        burn_mult=1.1, chill_mult=0.9, xp_reward=34, resonance_on_kill=6, ammo_drop_chance=0.35, heal_drop_chance=0.06,
        model_id="ash_wolf",
    ),
    dict(
        id="wolf_alpha", display_name="늑대 우두머리", family="늑대 계열", threat_tier=ELITE, combat_role="지휘·돌격",
        description="무리를 이끄는 검은 늑대. 긴 울음으로 무리를 몰아세우면 늑대들이 더 빠르고 사나워진다. "
        "크게 몸을 낮춘 뒤의 덮치기는 막을 수 없다. 울기 시작할 때 경직시키면 울음이 끊긴다.",
        level=6, max_hp=360, defense=0.08, walk_speed=2.8, run_speed=8.6, turn_speed_deg=380, poise=80,
        stagger_duration=1.2, mass_kg=70, sight_range=34, sight_fov_deg=150, proximity_sense=4.0, hearing_mult=1.2,
        leash_radius=50, pack_alert_radius=30,
        attacks=[
            atk("howl", "울부짖기", SPECIAL, min_range=0.0, max_range=30.0, windup=0.9, active_time=0.8, recovery=0.4,
                cooldown=16.0, weight=0.6, token_group=TOKEN_NONE),
            atk("crushing_pounce", "짓누르는 덮치기", LUNGE, parryable=False, min_range=3.0, max_range=9.0, windup=0.95,
                active_time=0.54, recovery=1.0, cooldown=4.5, damage=24, reach=1.7, hit_angle_deg=70, move_speed=13,
                knockback=7),
            atk("savage_bite", "사나운 물기", STRIKE, max_range=2.3, windup=0.5, active_time=0.18, recovery=0.7,
                cooldown=1.8, damage=16, reach=1.9, hit_angle_deg=90, knockback=3, bleed_buildup=25),
        ],
        xp_reward=140, resonance_on_kill=12, ammo_drop_chance=0.8, heal_drop_chance=0.25,
        model_id="wolf_alpha",
    ),
    dict(
        id="silvermane", display_name="은갈기 늑대", family="늑대 계열", threat_tier=RARE, combat_role="기습",
        description="안개 낀 밤에만 모습을 드러내는 은빛 갈기의 늑대. 물린 자리가 얼어붙는다. "
        "안개 속으로 몸을 감췄다가 전혀 다른 쪽에서 덮친다. 발밑의 서리 자국이 다음 자리를 알려 준다.",
        level=7, max_hp=420, defense=0.1, walk_speed=3.0, run_speed=9.0, turn_speed_deg=420, poise=70,
        stagger_duration=1.0, mass_kg=60, sight_range=36, sight_fov_deg=160, proximity_sense=4.0, hearing_mult=1.3,
        leash_radius=55,
        attacks=[
            atk("frost_bite", "서리 물기", LUNGE, min_range=2.5, max_range=7.0, windup=0.6, active_time=0.43,
                recovery=0.6, cooldown=2.4, damage=16, reach=1.5, hit_angle_deg=70, move_speed=12, knockback=3,
                chill_buildup=45),
            atk("mist_step", "안개 걸음", SPECIAL, min_range=4.0, max_range=20.0, windup=0.4, active_time=0.6,
                recovery=0.2, cooldown=9.0, weight=0.5, token_group=TOKEN_NONE),
        ],
        chill_mult=0.3, burn_mult=1.3, xp_reward=180, resonance_on_kill=16, ammo_drop_chance=0.8, heal_drop_chance=0.3,
        model_id="silvermane", appears="night",
    ),
    # --- 고블린 ---
    dict(
        id="goblin_scout", display_name="고블린 척후병", family="고블린", threat_tier=NORMAL, combat_role="정찰",
        description="무리 앞에서 길을 살피는 작은 고블린. 사람을 보면 먼저 덤비지 않고 날카로운 휘파람을 불며 동료에게 달려간다. "
        "달아나는 척후병을 놓치면 곧 무리가 몰려온다. 들고 있던 식칼을 떨어뜨리기도 한다.",
        level=2, max_hp=55, walk_speed=2.4, run_speed=5.4, turn_speed_deg=480, poise=22, stagger_duration=0.9,
        mass_kg=30, sight_range=30, sight_fov_deg=140, proximity_sense=3.0, hearing_mult=1.3, leash_radius=50,
        pack_alert_radius=30,
        attacks=[
            atk("knife_slash", "식칼 베기", STRIKE, max_range=1.8, windup=0.45, active_time=0.15, recovery=0.55,
                cooldown=1.3, damage=9, reach=1.6, hit_angle_deg=90, knockback=2, bleed_buildup=15),
            atk("knife_lunge", "뛰어들어 찌르기", LUNGE, min_range=2.0, max_range=4.5, windup=0.5, active_time=0.33,
                recovery=0.7, cooldown=3.0, damage=11, reach=1.3, hit_angle_deg=70, move_speed=9, knockback=2),
        ],
        xp_reward=18, resonance_on_kill=4, ammo_drop_chance=0.4, heal_drop_chance=0.08,
        model_id="goblin_scout",
    ),
    dict(
        id="goblin_brute", display_name="고블린 도끼잡이", family="고블린", threat_tier=NORMAL, combat_role="방어·근접",
        description="나무 방패를 앞세우고 다가오는 고블린. 정면에서 쏜 탄은 방패에 박힌다. 방패는 부술 수 있고, "
        "도끼를 크게 치켜드는 순간 다리와 옆구리가 빈다. 쓰던 손도끼를 떨어뜨리기도 한다.",
        level=3, max_hp=120, defense=0.05, walk_speed=2.2, run_speed=4.6, turn_speed_deg=300, poise=45,
        stagger_duration=1.0, mass_kg=45, sight_range=26, sight_fov_deg=120, proximity_sense=3.0, leash_radius=45,
        pack_alert_radius=25,
        attacks=[
            atk("axe_chop", "도끼 내려찍기", STRIKE, max_range=2.2, windup=0.65, active_time=0.18, recovery=0.8,
                cooldown=1.8, damage=15, reach=2.0, hit_angle_deg=90, knockback=3),
            atk("shield_bash", "방패 밀치기", STRIKE, parryable=False, max_range=1.8, windup=0.8, active_time=0.15,
                recovery=0.7, cooldown=3.5, damage=8, reach=1.6, hit_angle_deg=70, knockback=7),
        ],
        xp_reward=28, resonance_on_kill=5, ammo_drop_chance=0.45, heal_drop_chance=0.1,
        model_id="goblin_brute",
    ),
    dict(
        id="goblin_gunner", display_name="고블린 사수", family="고블린", threat_tier=NORMAL, combat_role="사격",
        description="조잡한 총을 든 고블린. 조준하는 동안 총구에서 붉은 빛줄기가 뻗어 나온다. 빛줄기가 멈추는 순간 "
        "방아쇠를 당기니, 그때 옆으로 비켜라. 쓰던 총을 떨어뜨리기도 한다.",
        level=4, max_hp=65, walk_speed=2.3, run_speed=4.8, turn_speed_deg=360, poise=25, stagger_duration=1.0,
        mass_kg=32, sight_range=40, sight_fov_deg=130, proximity_sense=3.0, leash_radius=50, pack_alert_radius=25,
        attacks=[
            atk("crude_shot", "조잡한 사격", SHOT, parryable=False, min_range=3.5, max_range=32.0, windup=1.0,
                active_time=0.1, recovery=0.8, cooldown=2.8, damage=14, knockback=2, token_group=TOKEN_RANGED),
            atk("butt_strike", "개머리 치기", STRIKE, max_range=1.8, windup=0.45, active_time=0.15, recovery=0.6,
                cooldown=1.6, damage=8, reach=1.6, hit_angle_deg=80, knockback=4),
        ],
        xp_reward=26, resonance_on_kill=5, ammo_drop_chance=0.7, heal_drop_chance=0.08,
        model_id="goblin_gunner",
    ),
    dict(
        id="goblin_thrower", display_name="고블린 투척병", family="고블린", threat_tier=NORMAL, combat_role="사격",
        description="등에 뼈창 묶음을 멘 고블린. 멀리서 창을 던지고, 가까이 오면 연기 폭탄으로 시야를 가린 채 물러난다. "
        "뼈창을 떨어뜨리기도 한다.",
        level=4, max_hp=60, walk_speed=2.3, run_speed=5.0, turn_speed_deg=380, poise=22, stagger_duration=1.0,
        mass_kg=30, sight_range=34, sight_fov_deg=140, proximity_sense=3.0, leash_radius=50, pack_alert_radius=25,
        attacks=[
            atk("spear_throw", "뼈창 던지기", PROJECTILE, parryable=False, min_range=5.0, max_range=26.0, windup=0.8,
                active_time=0.1, recovery=0.8, cooldown=2.6, damage=13, projectile_speed=22, projectile_gravity=9,
                projectile_blast_radius=1.2, bleed_buildup=20, token_group=TOKEN_RANGED),
            atk("smoke_bomb", "연기 폭탄", PROJECTILE, parryable=False, min_range=3.0, max_range=16.0, windup=0.8,
                active_time=0.1, recovery=0.6, cooldown=12.0, damage=2, projectile_speed=14, projectile_gravity=9,
                projectile_blast_radius=4.0, weight=0.5, token_group=TOKEN_RANGED),
        ],
        xp_reward=24, resonance_on_kill=5, ammo_drop_chance=0.45, heal_drop_chance=0.08,
        model_id="goblin_thrower",
    ),
    dict(
        id="goblin_shaman", display_name="고블린 주술사", family="고블린", threat_tier=ENHANCED, combat_role="지원",
        description="짐승 두개골 가면을 쓴 고블린. 동료가 다치면 주문을 외워 상처를 아물게 한다. "
        "주문을 외는 동안 경직시키면 끊긴다. 가장 먼저 쓰러뜨려야 할 상대.",
        level=5, max_hp=90, walk_speed=2.1, run_speed=4.4, turn_speed_deg=360, poise=30, stagger_duration=1.1,
        mass_kg=30, sight_range=34, sight_fov_deg=150, proximity_sense=3.0, leash_radius=45, pack_alert_radius=25,
        attacks=[
            atk("heal_chant", "치유 주문", SPECIAL, min_range=0.0, max_range=30.0, windup=1.6, active_time=0.5,
                recovery=0.6, cooldown=7.0, weight=2.0, token_group=TOKEN_NONE),
            atk("hex_bolt", "저주 구슬", PROJECTILE, parryable=False, min_range=4.0, max_range=28.0, windup=0.9,
                active_time=0.1, recovery=0.7, cooldown=3.0, damage=12, projectile_speed=14, projectile_gravity=2,
                projectile_blast_radius=1.6, shock_buildup=30, token_group=TOKEN_RANGED),
        ],
        xp_reward=45, resonance_on_kill=9, ammo_drop_chance=0.5, heal_drop_chance=0.25,
        model_id="goblin_shaman",
    ),
    dict(
        id="goblin_chief", display_name="고블린 두목", family="고블린", threat_tier=ELITE, combat_role="근접·지휘",
        description="고블린 무리를 거느리는 덩치 큰 고블린. 양손 대도를 머리 위로 치켜드는 내려찍기는 막을 수 없지만, "
        "옆으로 휘두르는 베기는 흘려 낼 수 있다. 크게 다치면 함성을 질러 무리를 몰아세운다. 쓰러뜨리면 쓰던 대도를 반드시 떨어뜨린다.",
        level=7, max_hp=520, defense=0.12, walk_speed=2.4, run_speed=5.0, turn_speed_deg=260, poise=110,
        stagger_duration=1.4, mass_kg=110, sight_range=30, sight_fov_deg=130, proximity_sense=4.0, leash_radius=45,
        pack_alert_radius=35,
        attacks=[
            atk("overhead_cleave", "대도 내려찍기", STRIKE, parryable=False, max_range=3.2, windup=1.1, active_time=0.22,
                recovery=1.1, cooldown=3.2, damage=30, reach=3.0, hit_angle_deg=60, knockback=8),
            atk("sweep", "휩쓸기", STRIKE, max_range=3.0, windup=0.7, active_time=0.2, recovery=0.9, cooldown=2.2,
                damage=20, reach=2.9, hit_angle_deg=150, knockback=5),
            atk("war_cry", "함성", SPECIAL, min_range=0.0, max_range=30.0, windup=1.0, active_time=0.6, recovery=0.4,
                cooldown=20.0, weight=0.5, token_group=TOKEN_NONE),
        ],
        xp_reward=180, resonance_on_kill=16, ammo_drop_chance=0.9, heal_drop_chance=0.4,
        model_id="goblin_chief",
    ),
    dict(
        id="oneeye_sniper", display_name="외눈 고블린 저격수", family="고블린", threat_tier=RARE, combat_role="저격",
        description="한쪽 눈을 가린 고블린 저격수. 먼 곳에서 조준경을 번뜩이며 노리고, 한 발 쏠 때마다 자리를 옮긴다. "
        "번뜩임이 멎는 순간 방아쇠를 당긴다. 쓰러뜨리면 희귀 이상의 저격 무기를 반드시 떨어뜨린다.",
        level=8, max_hp=200, defense=0.05, walk_speed=2.6, run_speed=5.6, turn_speed_deg=360, poise=40,
        stagger_duration=1.1, mass_kg=35, sight_range=70, sight_fov_deg=140, proximity_sense=4.0, hearing_mult=1.4,
        leash_radius=70, pack_alert_radius=40,
        attacks=[
            atk("aimed_shot", "조준 사격", SHOT, parryable=False, min_range=6.0, max_range=65.0, windup=1.8,
                active_time=0.1, recovery=1.0, cooldown=3.5, damage=28, knockback=4, token_group=TOKEN_RANGED),
            atk("stock_bash", "개머리 치기", STRIKE, max_range=1.8, windup=0.45, active_time=0.15, recovery=0.6,
                cooldown=1.6, damage=10, reach=1.6, hit_angle_deg=80, knockback=4),
        ],
        xp_reward=220, resonance_on_kill=18, ammo_drop_chance=1.0, heal_drop_chance=0.4,
        model_id="oneeye_sniper",
    ),
]

DATA_FIELDS = [
    "id", "display_name", "family", "threat_tier", "combat_role", "description", "model_id", "appears",
    "max_hp", "defense", "walk_speed", "run_speed", "turn_speed_deg", "poise", "stagger_duration", "mass_kg",
    "sight_range", "sight_fov_deg", "proximity_sense", "hearing_mult", "leash_radius", "pack_alert_radius",
    "burn_mult", "chill_mult", "shock_mult", "bleed_mult", "boss_status_rules",
    "level", "xp_reward", "resonance_on_kill", "ammo_drop_chance", "heal_drop_chance",
    "analysis_skill", "core_drop_chance",
]
ATTACK_FIELDS = [
    "id", "display_name", "kind", "parryable", "min_range", "max_range", "windup", "active_time", "recovery", "cooldown",
    "damage", "reach", "hit_angle_deg", "move_speed", "knockback", "weight", "token_group", "wall_stun",
    "projectile_speed", "projectile_gravity", "projectile_blast_radius",
    "burn_buildup", "chill_buildup", "shock_buildup", "bleed_buildup",
]
STRING_NAMES = {"id", "model_id", "analysis_skill"}


def fmt(key: str, value) -> str:
    if isinstance(value, bool):
        return "true" if value else "false"
    if key in STRING_NAMES:
        return '&"%s"' % value
    if isinstance(value, str):
        return '"%s"' % value.replace('"', '\\"')
    if isinstance(value, float):
        return repr(value)
    return str(value)


def write(sp: dict) -> str:
    attacks = sp.get("attacks", [])
    lines = [
        '[gd_resource type="Resource" script_class="EnemyData" load_steps=%d format=3]' % (len(attacks) + 3),
        "",
        '[ext_resource type="Script" path="res://src/core/data/enemy_attack_data.gd" id="1_atk"]',
        '[ext_resource type="Script" path="res://src/core/data/enemy_data.gd" id="2_data"]',
        "",
    ]
    for i, a in enumerate(attacks):
        lines.append('[sub_resource type="Resource" id="Atk_%d"]' % i)
        lines.append('script = ExtResource("1_atk")')
        for k in ATTACK_FIELDS:
            if k in a:
                lines.append("%s = %s" % (k, fmt(k, a[k])))
        lines.append("")
    lines.append("[resource]")
    lines.append('script = ExtResource("2_data")')
    for k in DATA_FIELDS:
        if k in sp:
            lines.append("%s = %s" % (k, fmt(k, sp[k])))
    if attacks:
        refs = ", ".join('SubResource("Atk_%d")' % i for i in range(len(attacks)))
        lines.append('attacks = Array[ExtResource("1_atk")]([%s])' % refs)
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for sp in SPECIES:
        path = os.path.join(OUT, sp["id"] + ".tres")
        with open(path, "w", encoding="utf-8") as f:
            f.write(write(sp))
        print("생성:", os.path.relpath(path, ROOT))


if __name__ == "__main__":
    main()
