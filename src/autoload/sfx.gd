extends Node
## 절차적으로 합성한 임시 효과음. 정식 사운드 에셋이 준비되면 같은 id로 교체한다.
## 무기군마다 다른 발사음, 판정마다(일반·약점·장갑·파괴·처치) 다른 소리를 낸다(기획서 §8.7, §26.1).
## 3D 소리는 거리로 감쇠하고, 벽에 가려지면 먹먹하게 들린다(§23.3).
##
## 레이어 형식: {"t": 파형(noise/sine/square/saw/tri), "dur": 길이, "start": 시작 지연,
##   "f0"/"f1": 시작·끝 주파수(지수 곡선), "a": 어택, "d": 지수 감쇠율, "g": 크기,
##   "lp": 노이즈 저역 통과 계수(0~1, 작을수록 어두움), "vib"/"vd": 비브라토 속도·깊이}

const MIX_RATE := 22050
const MAX_VOICES := 48
const OCCLUDED_CUTOFF_HZ := 1400.0
const OCCLUDED_DB := -7.0

const RECIPES := {
	&"shot_pistol": [
		{"t": "noise", "dur": 0.14, "d": 30.0, "g": 1.0, "lp": 0.55},
		{"t": "sine", "dur": 0.12, "f0": 190.0, "f1": 70.0, "d": 22.0, "g": 0.9},
		{"t": "noise", "dur": 0.012, "g": 0.6, "lp": 1.0},
	],
	&"shot_rifle": [
		{"t": "noise", "dur": 0.2, "d": 20.0, "g": 1.0, "lp": 0.42},
		{"t": "sine", "dur": 0.16, "f0": 150.0, "f1": 48.0, "d": 16.0, "g": 1.1},
		{"t": "noise", "dur": 0.015, "g": 0.5, "lp": 1.0},
	],
	&"shot_shotgun": [
		{"t": "noise", "dur": 0.45, "d": 8.0, "g": 1.1, "lp": 0.28},
		{"t": "sine", "dur": 0.35, "f0": 95.0, "f1": 32.0, "d": 9.0, "g": 1.2},
		{"t": "noise", "dur": 0.02, "g": 0.5, "lp": 0.9},
	],
	&"shot_sniper": [
		{"t": "noise", "dur": 0.03, "g": 0.9, "lp": 1.0},
		{"t": "noise", "dur": 0.7, "d": 6.0, "g": 0.9, "lp": 0.35},
		{"t": "sine", "dur": 0.5, "f0": 125.0, "f1": 38.0, "d": 7.0, "g": 1.1},
	],
	&"shot_energy": [
		{"t": "square", "dur": 0.18, "f0": 1500.0, "f1": 260.0, "d": 14.0, "g": 0.35},
		{"t": "sine", "dur": 0.2, "f0": 820.0, "f1": 180.0, "d": 12.0, "g": 0.7},
		{"t": "noise", "dur": 0.08, "d": 30.0, "g": 0.3, "lp": 0.8},
	],
	&"reload_out": [
		{"t": "noise", "dur": 0.03, "d": 60.0, "g": 0.8, "lp": 0.9},
		{"t": "sine", "dur": 0.04, "f0": 1900.0, "f1": 1400.0, "d": 50.0, "g": 0.4},
	],
	&"reload_in": [
		{"t": "noise", "dur": 0.04, "d": 50.0, "g": 0.9, "lp": 0.6},
		{"t": "sine", "dur": 0.06, "f0": 900.0, "f1": 500.0, "d": 40.0, "g": 0.5},
		{"t": "noise", "start": 0.12, "dur": 0.03, "d": 60.0, "g": 0.7, "lp": 0.9},
	],
	&"dry_fire": [
		{"t": "sine", "dur": 0.025, "f0": 2400.0, "f1": 2000.0, "d": 80.0, "g": 0.5},
		{"t": "noise", "dur": 0.015, "d": 90.0, "g": 0.4, "lp": 1.0},
	],
	&"overheat": [
		{"t": "noise", "dur": 0.9, "a": 0.02, "d": 3.0, "g": 0.55, "lp": 0.85},
		{"t": "sine", "dur": 0.6, "f0": 1100.0, "f1": 400.0, "d": 4.0, "g": 0.25},
	],
	&"hit_normal": [
		{"t": "sine", "dur": 0.07, "f0": 340.0, "f1": 170.0, "d": 35.0, "g": 0.9},
		{"t": "noise", "dur": 0.05, "d": 45.0, "g": 0.5, "lp": 0.3},
	],
	&"hit_weak": [
		{"t": "sine", "dur": 0.16, "f0": 1568.0, "f1": 1568.0, "d": 18.0, "g": 0.8},
		{"t": "sine", "dur": 0.12, "f0": 2350.0, "f1": 2350.0, "d": 22.0, "g": 0.4},
		{"t": "noise", "dur": 0.03, "d": 60.0, "g": 0.3, "lp": 0.5},
	],
	&"hit_armor": [
		{"t": "sine", "dur": 0.22, "f0": 523.0, "f1": 510.0, "d": 14.0, "g": 0.5},
		{"t": "sine", "dur": 0.2, "f0": 1377.0, "f1": 1350.0, "d": 16.0, "g": 0.35},
		{"t": "sine", "dur": 0.18, "f0": 2213.0, "f1": 2180.0, "d": 18.0, "g": 0.25},
		{"t": "noise", "dur": 0.025, "d": 70.0, "g": 0.6, "lp": 0.9},
	],
	&"armor_break": [
		{"t": "noise", "dur": 0.6, "d": 6.0, "g": 1.0, "lp": 0.55},
		{"t": "sine", "dur": 0.5, "f0": 310.0, "f1": 250.0, "d": 6.0, "g": 0.5},
		{"t": "sine", "dur": 0.45, "f0": 833.0, "f1": 780.0, "d": 7.0, "g": 0.35},
		{"t": "sine", "dur": 0.4, "f0": 1510.0, "f1": 1450.0, "d": 8.0, "g": 0.25},
	],
	&"kill": [
		{"t": "sine", "dur": 0.2, "f0": 240.0, "f1": 110.0, "d": 14.0, "g": 0.8},
		{"t": "sine", "start": 0.03, "dur": 0.3, "f0": 1046.0, "f1": 1046.0, "d": 9.0, "g": 0.35},
	],
	&"melee_swing": [
		{"t": "noise", "dur": 0.22, "a": 0.06, "d": 9.0, "g": 0.8, "lp": 0.22},
	],
	&"melee_hit": [
		{"t": "noise", "dur": 0.1, "d": 35.0, "g": 1.0, "lp": 0.45},
		{"t": "sine", "dur": 0.12, "f0": 170.0, "f1": 80.0, "d": 25.0, "g": 0.9},
	],
	&"parry": [
		{"t": "sine", "dur": 0.5, "f0": 2093.0, "f1": 2093.0, "d": 6.0, "g": 0.6},
		{"t": "sine", "dur": 0.4, "f0": 3136.0, "f1": 3136.0, "d": 8.0, "g": 0.35},
		{"t": "noise", "dur": 0.04, "d": 50.0, "g": 0.6, "lp": 0.9},
	],
	&"block": [
		{"t": "sine", "dur": 0.16, "f0": 420.0, "f1": 300.0, "d": 18.0, "g": 0.7},
		{"t": "noise", "dur": 0.07, "d": 40.0, "g": 0.6, "lp": 0.5},
	],
	## 패링 가능 공격 전조: 짧게 올라가는 두 음
	&"tele_parry": [
		{"t": "sine", "dur": 0.09, "f0": 988.0, "f1": 988.0, "d": 20.0, "g": 0.6},
		{"t": "sine", "start": 0.1, "dur": 0.12, "f0": 1480.0, "f1": 1480.0, "d": 16.0, "g": 0.6},
	],
	## 패링 불가 공격 전조: 낮게 떨리는 으르렁거림
	&"tele_heavy": [
		{"t": "saw", "dur": 0.55, "a": 0.06, "f0": 92.0, "f1": 78.0, "d": 3.0, "g": 0.55, "vib": 11.0, "vd": 0.06},
		{"t": "noise", "dur": 0.5, "a": 0.1, "d": 4.0, "g": 0.3, "lp": 0.15},
	],
	&"player_hurt": [
		{"t": "sine", "dur": 0.2, "f0": 130.0, "f1": 65.0, "d": 14.0, "g": 0.9},
		{"t": "noise", "dur": 0.12, "d": 28.0, "g": 0.5, "lp": 0.3},
	],
	&"dodge": [
		{"t": "noise", "dur": 0.2, "a": 0.03, "d": 10.0, "g": 0.7, "lp": 0.3},
	],
	&"land": [
		{"t": "noise", "dur": 0.08, "d": 40.0, "g": 0.5, "lp": 0.15},
		{"t": "sine", "dur": 0.08, "f0": 90.0, "f1": 55.0, "d": 30.0, "g": 0.5},
	],
	&"footstep": [
		{"t": "noise", "dur": 0.06, "d": 50.0, "g": 0.35, "lp": 0.18},
	],
	&"skill_frost": [
		{"t": "sine", "dur": 0.7, "f0": 1175.0, "f1": 1175.0, "d": 4.5, "g": 0.3},
		{"t": "sine", "dur": 0.65, "f0": 1760.0, "f1": 1760.0, "d": 5.0, "g": 0.25},
		{"t": "sine", "dur": 0.6, "f0": 2637.0, "f1": 2637.0, "d": 6.0, "g": 0.2},
		{"t": "noise", "dur": 0.5, "d": 6.0, "g": 0.35, "lp": 0.9},
	],
	&"skill_leap": [
		{"t": "noise", "dur": 0.28, "a": 0.02, "d": 8.0, "g": 0.8, "lp": 0.4},
		{"t": "sine", "dur": 0.2, "f0": 260.0, "f1": 640.0, "d": 10.0, "g": 0.4},
	],
	&"skill_shield": [
		{"t": "sine", "dur": 0.7, "a": 0.08, "f0": 220.0, "f1": 230.0, "d": 3.0, "g": 0.5},
		{"t": "sine", "dur": 0.7, "a": 0.08, "f0": 330.0, "f1": 345.0, "d": 3.0, "g": 0.35},
		{"t": "noise", "dur": 0.2, "d": 15.0, "g": 0.3, "lp": 0.6},
	],
	&"skill_launch": [
		{"t": "sine", "dur": 0.16, "f0": 420.0, "f1": 150.0, "d": 15.0, "g": 0.7},
		{"t": "noise", "dur": 0.15, "d": 20.0, "g": 0.5, "lp": 0.5},
	],
	&"explosion": [
		{"t": "noise", "dur": 0.9, "d": 4.5, "g": 1.2, "lp": 0.22},
		{"t": "sine", "dur": 0.7, "f0": 75.0, "f1": 28.0, "d": 5.0, "g": 1.1},
		{"t": "noise", "dur": 0.04, "g": 0.6, "lp": 1.0},
	],
	&"ignite": [
		{"t": "noise", "dur": 0.35, "a": 0.03, "d": 7.0, "g": 0.6, "lp": 0.6},
	],
	&"freeze": [
		{"t": "noise", "dur": 0.25, "d": 14.0, "g": 0.5, "lp": 0.95},
		{"t": "sine", "dur": 0.3, "f0": 2800.0, "f1": 3400.0, "d": 10.0, "g": 0.25},
	],
	&"shock": [
		{"t": "square", "dur": 0.14, "f0": 1700.0, "f1": 1200.0, "d": 18.0, "g": 0.3, "vib": 60.0, "vd": 0.2},
		{"t": "noise", "dur": 0.12, "d": 22.0, "g": 0.5, "lp": 1.0},
	],
	&"bleed": [
		{"t": "noise", "dur": 0.12, "d": 25.0, "g": 0.5, "lp": 0.35},
		{"t": "sine", "dur": 0.1, "f0": 300.0, "f1": 180.0, "d": 25.0, "g": 0.3},
	],
	## 살인토끼 무리 경고 울음
	&"rabbit_squeal": [
		{"t": "tri", "dur": 0.3, "f0": 1800.0, "f1": 2700.0, "d": 6.0, "g": 0.6, "vib": 28.0, "vd": 0.05},
		{"t": "tri", "start": 0.12, "dur": 0.2, "f0": 2400.0, "f1": 1900.0, "d": 9.0, "g": 0.4},
	],
	## 풀숲 매복의 단서가 되는 바스락거림
	&"rustle": [
		{"t": "noise", "dur": 0.4, "a": 0.12, "d": 6.0, "g": 0.45, "lp": 0.6},
	],
	&"charger_roar": [
		{"t": "saw", "dur": 0.9, "a": 0.1, "f0": 68.0, "f1": 55.0, "d": 2.5, "g": 0.6, "vib": 7.0, "vd": 0.08},
		{"t": "noise", "dur": 0.8, "a": 0.15, "d": 3.0, "g": 0.4, "lp": 0.12},
	],
	&"wall_crash": [
		{"t": "noise", "dur": 0.5, "d": 7.0, "g": 1.1, "lp": 0.2},
		{"t": "sine", "dur": 0.4, "f0": 64.0, "f1": 30.0, "d": 8.0, "g": 1.0},
	],
	&"spit_charge": [
		{"t": "noise", "dur": 0.8, "a": 0.7, "d": 0.5, "g": 0.4, "lp": 0.5},
		{"t": "sine", "dur": 0.8, "a": 0.6, "f0": 300.0, "f1": 600.0, "d": 0.5, "g": 0.15},
	],
	&"sac_burst": [
		{"t": "noise", "dur": 0.4, "d": 10.0, "g": 0.9, "lp": 0.5},
		{"t": "sine", "dur": 0.2, "f0": 200.0, "f1": 80.0, "d": 16.0, "g": 0.6},
	],
	&"pickup": [
		{"t": "sine", "dur": 0.1, "f0": 880.0, "f1": 1320.0, "d": 14.0, "g": 0.5},
	],
	&"consume": [
		{"t": "sine", "dur": 0.2, "f0": 600.0, "f1": 820.0, "d": 8.0, "g": 0.5},
		{"t": "noise", "dur": 0.1, "d": 25.0, "g": 0.2, "lp": 0.7},
	],
	&"ui_click": [
		{"t": "sine", "dur": 0.035, "f0": 1250.0, "f1": 1150.0, "d": 60.0, "g": 0.5},
	],
	&"ui_confirm": [
		{"t": "sine", "dur": 0.07, "f0": 880.0, "f1": 880.0, "d": 25.0, "g": 0.45},
		{"t": "sine", "start": 0.07, "dur": 0.1, "f0": 1320.0, "f1": 1320.0, "d": 18.0, "g": 0.45},
	],
	&"notice": [
		{"t": "sine", "dur": 0.1, "f0": 1046.0, "f1": 1046.0, "d": 16.0, "g": 0.4},
		{"t": "sine", "start": 0.08, "dur": 0.14, "f0": 1568.0, "f1": 1568.0, "d": 14.0, "g": 0.35},
	],
	&"unlock": [
		{"t": "sine", "dur": 0.14, "f0": 523.0, "f1": 523.0, "d": 10.0, "g": 0.4},
		{"t": "sine", "start": 0.09, "dur": 0.14, "f0": 659.0, "f1": 659.0, "d": 10.0, "g": 0.4},
		{"t": "sine", "start": 0.18, "dur": 0.14, "f0": 784.0, "f1": 784.0, "d": 10.0, "g": 0.4},
		{"t": "sine", "start": 0.27, "dur": 0.35, "f0": 1046.0, "f1": 1046.0, "d": 6.0, "g": 0.45},
	],
	&"death": [
		{"t": "sine", "dur": 1.2, "f0": 220.0, "f1": 55.0, "d": 2.0, "g": 0.7},
		{"t": "noise", "dur": 0.6, "d": 5.0, "g": 0.3, "lp": 0.15},
	],
	&"respawn": [
		{"t": "sine", "dur": 0.15, "f0": 392.0, "f1": 392.0, "d": 8.0, "g": 0.4},
		{"t": "sine", "start": 0.12, "dur": 0.15, "f0": 523.0, "f1": 523.0, "d": 8.0, "g": 0.4},
		{"t": "sine", "start": 0.24, "dur": 0.4, "f0": 659.0, "f1": 659.0, "d": 5.0, "g": 0.4},
	],
	# --- 기동과 근접 기술 ---
	&"air_step": [
		{"t": "noise", "dur": 0.22, "a": 0.02, "d": 10.0, "g": 0.6, "lp": 0.5},
		{"t": "sine", "dur": 0.15, "f0": 520.0, "f1": 980.0, "d": 12.0, "g": 0.25},
	],
	&"wall_kick": [
		{"t": "noise", "dur": 0.06, "d": 40.0, "g": 0.8, "lp": 0.35},
		{"t": "sine", "dur": 0.1, "f0": 160.0, "f1": 90.0, "d": 25.0, "g": 0.6},
		{"t": "noise", "start": 0.04, "dur": 0.2, "a": 0.02, "d": 10.0, "g": 0.4, "lp": 0.6},
	],
	&"slide": [
		{"t": "noise", "dur": 0.55, "a": 0.03, "d": 4.0, "g": 0.6, "lp": 0.25},
		{"t": "noise", "dur": 0.4, "a": 0.02, "d": 6.0, "g": 0.25, "lp": 0.8},
	],
	&"perfect_evade": [
		{"t": "sine", "dur": 0.5, "a": 0.01, "f0": 1760.0, "f1": 880.0, "d": 5.0, "g": 0.35},
		{"t": "sine", "dur": 0.6, "a": 0.01, "f0": 2640.0, "f1": 1320.0, "d": 4.0, "g": 0.2},
		{"t": "noise", "dur": 0.35, "a": 0.01, "d": 8.0, "g": 0.35, "lp": 0.9},
	],
	&"technique": [
		{"t": "sine", "dur": 0.12, "f0": 660.0, "f1": 990.0, "d": 14.0, "g": 0.3},
		{"t": "noise", "dur": 0.18, "a": 0.02, "d": 12.0, "g": 0.35, "lp": 0.7},
	],
	&"spin_slash": [
		{"t": "noise", "dur": 0.35, "a": 0.03, "d": 7.0, "g": 0.7, "lp": 0.55},
		{"t": "sine", "dur": 0.3, "f0": 400.0, "f1": 1200.0, "d": 8.0, "g": 0.2},
	],
	&"plunge_impact": [
		{"t": "noise", "dur": 0.5, "d": 7.0, "g": 1.0, "lp": 0.2},
		{"t": "sine", "dur": 0.45, "f0": 110.0, "f1": 40.0, "d": 7.0, "g": 1.0},
		{"t": "noise", "dur": 0.03, "g": 0.6, "lp": 1.0},
	],
	# --- 공명 장치 알림 ---
	&"level_up": [
		{"t": "sine", "dur": 0.12, "f0": 523.0, "f1": 523.0, "d": 9.0, "g": 0.35},
		{"t": "sine", "start": 0.08, "dur": 0.12, "f0": 659.0, "f1": 659.0, "d": 9.0, "g": 0.35},
		{"t": "sine", "start": 0.16, "dur": 0.12, "f0": 784.0, "f1": 784.0, "d": 9.0, "g": 0.35},
		{"t": "sine", "start": 0.24, "dur": 0.7, "f0": 1046.0, "f1": 1046.0, "d": 3.5, "g": 0.42, "vib": 6.0, "vd": 0.004},
		{"t": "sine", "start": 0.24, "dur": 0.7, "f0": 1568.0, "f1": 1568.0, "d": 4.0, "g": 0.18},
		{"t": "noise", "start": 0.24, "dur": 0.6, "a": 0.05, "d": 5.0, "g": 0.12, "lp": 0.95},
	],
	&"discover": [
		{"t": "sine", "dur": 0.5, "a": 0.02, "f0": 880.0, "f1": 880.0, "d": 4.0, "g": 0.3},
		{"t": "sine", "start": 0.14, "dur": 0.6, "a": 0.02, "f0": 1318.0, "f1": 1318.0, "d": 3.5, "g": 0.3},
		{"t": "tri", "start": 0.0, "dur": 0.8, "a": 0.2, "f0": 440.0, "f1": 440.0, "d": 2.5, "g": 0.15},
	],
	&"unique_sting": [
		{"t": "sine", "dur": 2.2, "a": 0.3, "f0": 55.0, "f1": 49.0, "d": 1.2, "g": 0.8},
		{"t": "sine", "dur": 2.2, "a": 0.3, "f0": 58.3, "f1": 51.0, "d": 1.2, "g": 0.6},
		{"t": "saw", "start": 0.1, "dur": 1.6, "a": 0.4, "f0": 110.0, "f1": 98.0, "d": 1.8, "g": 0.15},
		{"t": "noise", "dur": 1.8, "a": 0.6, "d": 1.5, "g": 0.25, "lp": 0.05},
	],
	# --- 환경음(필드) ---
	&"bird_chirp_a": [
		{"t": "sine", "dur": 0.07, "f0": 3100.0, "f1": 4300.0, "d": 20.0, "g": 0.5},
		{"t": "sine", "start": 0.11, "dur": 0.07, "f0": 3200.0, "f1": 4500.0, "d": 20.0, "g": 0.5},
		{"t": "sine", "start": 0.22, "dur": 0.12, "f0": 4400.0, "f1": 3000.0, "d": 12.0, "g": 0.45},
	],
	&"bird_chirp_b": [
		{"t": "sine", "dur": 0.26, "f0": 4600.0, "f1": 2700.0, "d": 6.0, "g": 0.45, "vib": 32.0, "vd": 0.06},
		{"t": "sine", "start": 0.34, "dur": 0.18, "f0": 3900.0, "f1": 3300.0, "d": 9.0, "g": 0.35, "vib": 28.0, "vd": 0.05},
	],
	&"bird_trill": [
		{"t": "sine", "dur": 0.03, "f0": 3800.0, "f1": 4000.0, "d": 40.0, "g": 0.4},
		{"t": "sine", "start": 0.05, "dur": 0.03, "f0": 3850.0, "f1": 4050.0, "d": 40.0, "g": 0.4},
		{"t": "sine", "start": 0.1, "dur": 0.03, "f0": 3900.0, "f1": 4100.0, "d": 40.0, "g": 0.4},
		{"t": "sine", "start": 0.15, "dur": 0.03, "f0": 3950.0, "f1": 4150.0, "d": 40.0, "g": 0.4},
		{"t": "sine", "start": 0.2, "dur": 0.03, "f0": 4000.0, "f1": 4200.0, "d": 40.0, "g": 0.38},
		{"t": "sine", "start": 0.25, "dur": 0.03, "f0": 4050.0, "f1": 4250.0, "d": 40.0, "g": 0.36},
		{"t": "sine", "start": 0.3, "dur": 0.05, "f0": 4100.0, "f1": 3600.0, "d": 25.0, "g": 0.34},
	],
	&"owl_hoot": [
		{"t": "sine", "dur": 0.32, "a": 0.05, "f0": 430.0, "f1": 390.0, "d": 3.0, "g": 0.5},
		{"t": "sine", "start": 0.55, "dur": 0.55, "a": 0.08, "f0": 410.0, "f1": 350.0, "d": 2.5, "g": 0.5, "vib": 5.0, "vd": 0.02},
	],
	&"anvil_strike": [
		{"t": "noise", "dur": 0.03, "d": 60.0, "g": 0.7, "lp": 0.9},
		{"t": "sine", "dur": 0.5, "f0": 1760.0, "f1": 1745.0, "d": 9.0, "g": 0.5},
		{"t": "sine", "dur": 0.4, "f0": 2640.0, "f1": 2630.0, "d": 12.0, "g": 0.3},
	],
	## 밤의 포식자: 멀리서 들리는 긴 울음, 낮게 긁는 으르렁거림, 어둠 속으로 사라지는 소리
	&"predator_howl": [
		{"t": "saw", "dur": 2.6, "a": 0.45, "f0": 150.0, "f1": 92.0, "d": 0.8, "g": 0.42, "vib": 4.5, "vd": 0.04},
		{"t": "sine", "dur": 2.6, "a": 0.5, "f0": 300.0, "f1": 186.0, "d": 0.8, "g": 0.5, "vib": 4.5, "vd": 0.03},
		{"t": "noise", "dur": 2.2, "a": 0.7, "d": 1.2, "g": 0.22, "lp": 0.08},
	],
	&"predator_growl": [
		{"t": "saw", "dur": 1.3, "a": 0.15, "f0": 56.0, "f1": 48.0, "d": 1.6, "g": 0.6, "vib": 11.0, "vd": 0.14},
		{"t": "noise", "dur": 1.2, "a": 0.2, "d": 1.8, "g": 0.45, "lp": 0.09},
	],
	&"predator_vanish": [
		{"t": "noise", "dur": 1.0, "a": 0.35, "d": 2.8, "g": 0.5, "lp": 0.22},
		{"t": "sine", "dur": 0.9, "a": 0.25, "f0": 240.0, "f1": 70.0, "d": 3.2, "g": 0.35},
	],
	&"clue_found": [
		{"t": "sine", "dur": 0.3, "f0": 660.0, "f1": 660.0, "d": 6.0, "g": 0.4},
		{"t": "sine", "start": 0.13, "dur": 0.45, "f0": 990.0, "f1": 990.0, "d": 5.0, "g": 0.35},
		{"t": "tri", "start": 0.13, "dur": 0.45, "f0": 1980.0, "f1": 1980.0, "d": 7.0, "g": 0.08},
	],
	&"water_step": [
		{"t": "noise", "dur": 0.16, "a": 0.01, "d": 14.0, "g": 0.7, "lp": 0.45},
		{"t": "sine", "start": 0.02, "dur": 0.08, "f0": 700.0, "f1": 350.0, "d": 30.0, "g": 0.25},
	],
	## 늑대: 무리를 부르는 긴 울음, 낮은 으르렁거림
	&"wolf_howl": [
		{"t": "sine", "dur": 2.0, "a": 0.35, "f0": 420.0, "f1": 610.0, "d": 0.9, "g": 0.5, "vib": 5.5, "vd": 0.02},
		{"t": "tri", "dur": 2.0, "a": 0.4, "f0": 840.0, "f1": 1220.0, "d": 1.1, "g": 0.12, "vib": 5.5, "vd": 0.02},
		{"t": "sine", "start": 1.3, "dur": 1.2, "a": 0.1, "f0": 610.0, "f1": 380.0, "d": 1.6, "g": 0.35},
	],
	&"wolf_growl": [
		{"t": "saw", "dur": 0.9, "a": 0.08, "f0": 88.0, "f1": 76.0, "d": 2.5, "g": 0.45, "vib": 14.0, "vd": 0.12},
		{"t": "noise", "dur": 0.8, "a": 0.1, "d": 3.0, "g": 0.35, "lp": 0.14},
	],
	## 고블린: 날카로운 휘파람, 짧은 고함, 주술 읊조림, 두목의 함성
	&"goblin_whistle": [
		{"t": "sine", "dur": 0.35, "a": 0.02, "f0": 2100.0, "f1": 2900.0, "d": 3.0, "g": 0.55, "vib": 9.0, "vd": 0.01},
		{"t": "sine", "start": 0.4, "dur": 0.5, "a": 0.02, "f0": 2900.0, "f1": 1800.0, "d": 2.5, "g": 0.5},
	],
	&"goblin_shout": [
		{"t": "saw", "dur": 0.45, "a": 0.03, "f0": 330.0, "f1": 250.0, "d": 4.0, "g": 0.4, "vib": 18.0, "vd": 0.06},
		{"t": "noise", "dur": 0.4, "a": 0.02, "d": 5.0, "g": 0.25, "lp": 0.35},
	],
	&"goblin_chant": [
		{"t": "tri", "dur": 1.5, "a": 0.2, "f0": 196.0, "f1": 220.0, "d": 0.8, "g": 0.35, "vib": 6.0, "vd": 0.03},
		{"t": "sine", "dur": 1.5, "a": 0.4, "f0": 392.0, "f1": 440.0, "d": 0.8, "g": 0.2, "vib": 3.0, "vd": 0.02},
	],
	&"goblin_warcry": [
		{"t": "saw", "dur": 1.1, "a": 0.05, "f0": 150.0, "f1": 110.0, "d": 1.6, "g": 0.55, "vib": 9.0, "vd": 0.08},
		{"t": "noise", "dur": 1.0, "a": 0.05, "d": 2.0, "g": 0.35, "lp": 0.2},
	],
	&"heal_chime": [
		{"t": "sine", "dur": 0.6, "f0": 880.0, "f1": 880.0, "d": 4.0, "g": 0.3},
		{"t": "sine", "start": 0.1, "dur": 0.7, "f0": 1320.0, "f1": 1320.0, "d": 4.0, "g": 0.25},
	],
	## 고블린 총: 거칠고 덜컹거리는 발사음
	&"shot_crude": [
		{"t": "noise", "dur": 0.3, "d": 9.0, "g": 1.0, "lp": 0.45},
		{"t": "square", "dur": 0.12, "f0": 140.0, "f1": 60.0, "d": 22.0, "g": 0.35},
		{"t": "noise", "start": 0.08, "dur": 0.15, "d": 20.0, "g": 0.3, "lp": 0.8},
	],
	&"spear_whoosh": [
		{"t": "noise", "dur": 0.35, "a": 0.1, "d": 8.0, "g": 0.5, "lp": 0.3},
	],
	&"smoke_pop": [
		{"t": "noise", "dur": 0.7, "a": 0.01, "d": 4.0, "g": 0.7, "lp": 0.25},
		{"t": "sine", "dur": 0.15, "f0": 180.0, "f1": 90.0, "d": 20.0, "g": 0.4},
	],
	&"frost_mist": [
		{"t": "noise", "dur": 1.0, "a": 0.25, "d": 2.5, "g": 0.4, "lp": 0.5},
		{"t": "sine", "dur": 0.9, "a": 0.2, "f0": 1400.0, "f1": 900.0, "d": 3.0, "g": 0.12},
	],
	## 늪턱 구렁(보스): 늪을 울리는 낮은 포효, 진흙을 뚫고 솟구치는 소리, 진흙 뱉기, 잠수, 거품
	&"maw_roar": [
		{"t": "saw", "dur": 2.2, "a": 0.25, "f0": 46.0, "f1": 38.0, "d": 1.1, "g": 0.75, "vib": 6.0, "vd": 0.1},
		{"t": "saw", "dur": 2.0, "a": 0.3, "f0": 92.0, "f1": 70.0, "d": 1.3, "g": 0.3, "vib": 9.0, "vd": 0.08},
		{"t": "noise", "dur": 2.0, "a": 0.3, "d": 1.2, "g": 0.5, "lp": 0.1},
	],
	&"mud_burst": [
		{"t": "noise", "dur": 0.9, "a": 0.01, "d": 4.0, "g": 1.1, "lp": 0.16},
		{"t": "sine", "dur": 0.6, "f0": 58.0, "f1": 26.0, "d": 5.0, "g": 1.1},
		{"t": "noise", "start": 0.05, "dur": 0.5, "d": 7.0, "g": 0.5, "lp": 0.5},
	],
	&"mud_spit": [
		{"t": "noise", "dur": 0.35, "a": 0.02, "d": 9.0, "g": 0.8, "lp": 0.25},
		{"t": "sine", "dur": 0.2, "f0": 160.0, "f1": 60.0, "d": 14.0, "g": 0.5},
	],
	&"mud_dive": [
		{"t": "noise", "dur": 1.2, "a": 0.08, "d": 2.2, "g": 0.7, "lp": 0.14},
		{"t": "sine", "dur": 0.8, "a": 0.05, "f0": 90.0, "f1": 40.0, "d": 3.0, "g": 0.5},
	],
	&"mud_bubbles": [
		{"t": "sine", "dur": 0.08, "f0": 260.0, "f1": 520.0, "d": 30.0, "g": 0.35},
		{"t": "sine", "start": 0.14, "dur": 0.07, "f0": 300.0, "f1": 620.0, "d": 30.0, "g": 0.3},
		{"t": "sine", "start": 0.3, "dur": 0.09, "f0": 220.0, "f1": 470.0, "d": 30.0, "g": 0.3},
		{"t": "noise", "dur": 0.4, "a": 0.05, "d": 6.0, "g": 0.15, "lp": 0.2},
	],
	&"boss_sting": [
		{"t": "sine", "dur": 2.4, "a": 0.05, "f0": 41.0, "f1": 41.0, "d": 1.0, "g": 0.8},
		{"t": "saw", "dur": 1.8, "a": 0.02, "f0": 82.0, "f1": 78.0, "d": 1.6, "g": 0.25},
		{"t": "noise", "dur": 0.6, "a": 0.005, "d": 5.0, "g": 0.6, "lp": 0.2},
		{"t": "sine", "start": 0.5, "dur": 1.8, "a": 0.05, "f0": 61.7, "f1": 61.7, "d": 1.3, "g": 0.4},
	],
}

var _streams: Dictionary = {}
var _voices: int = 0


func _ready() -> void:
	# 메뉴가 열려 게임이 멈춰 있어도 인터페이스 소리는 나야 한다.
	process_mode = Node.PROCESS_MODE_ALWAYS
	for id in RECIPES:
		_streams[id] = synthesize(RECIPES[id])


func _exit_tree() -> void:
	# 종료할 때 재생 중인 소리를 멈춰 재생 객체가 남지 않게 한다.
	for child in get_children():
		if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
			child.stop()


func has_sound(id: StringName) -> bool:
	return _streams.has(id)


func get_stream(id: StringName) -> AudioStream:
	return _streams.get(id)


## 2D 재생(플레이어 자신의 소리, UI 등)
func play(id: StringName, volume_db: float = 0.0, pitch: float = 1.0, bus: StringName = &"SFX") -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		push_warning("알 수 없는 효과음: %s" % id)
		return
	if _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.bus = bus
	_start(p)


func play_ui(id: StringName, volume_db: float = 0.0) -> void:
	play(id, volume_db, 1.0, &"UI")


## 3D 재생. 가까운 카메라와 사이에 벽이 있으면 먹먹하게 줄인다.
func play_at(id: StringName, position: Vector3, volume_db: float = 0.0, pitch: float = 1.0,
		max_distance: float = 80.0) -> void:
	var stream: AudioStream = _streams.get(id)
	if stream == null:
		push_warning("알 수 없는 효과음: %s" % id)
		return
	if _voices >= MAX_VOICES:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.bus = &"SFX"
	p.unit_size = 8.0
	p.max_distance = max_distance
	p.attenuation_filter_cutoff_hz = 9000.0
	p.attenuation_filter_db = -12.0
	if _is_occluded(position):
		p.volume_db += OCCLUDED_DB
		p.attenuation_filter_cutoff_hz = OCCLUDED_CUTOFF_HZ
	p.position = position
	_start(p)


func _start(p: Node) -> void:
	add_child(p)
	_voices += 1
	p.finished.connect(_on_voice_finished.bind(p))
	p.play()


func _on_voice_finished(p: Node) -> void:
	_voices -= 1
	p.queue_free()


func _is_occluded(position: Vector3) -> bool:
	var vp := get_viewport()
	var cam: Camera3D = vp.get_camera_3d() if vp else null
	if cam == null or not cam.is_inside_tree():
		return false
	var space := cam.get_world_3d().direct_space_state
	var from := cam.global_position
	if from.distance_squared_to(position) < 1.0:
		return false
	var q := PhysicsRayQueryParameters3D.create(from, position, CombatLayers.WORLD)
	return not space.intersect_ray(q).is_empty()


## 레이어 목록을 16비트 모노 WAV로 합성한다.
static func synthesize(layers: Array) -> AudioStreamWAV:
	var total := 0.0
	for l in layers:
		total = maxf(total, float(l.get("start", 0.0)) + float(l.dur))
	var n := int(total * MIX_RATE) + 1
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919
	for l in layers:
		var kind: String = l.t
		var start := int(float(l.get("start", 0.0)) * MIX_RATE)
		var length := int(float(l.dur) * MIX_RATE)
		var attack := maxf(float(l.get("a", 0.002)), 0.0005)
		var decay_mul := exp(-float(l.get("d", 0.0)) / MIX_RATE)
		var gain := float(l.get("g", 1.0))
		var lp := float(l.get("lp", 1.0))
		var f0 := float(l.get("f0", 440.0))
		var f1 := float(l.get("f1", f0))
		var freq_mul := pow(f1 / f0, 1.0 / maxf(length, 1)) if f0 > 0.0 and f1 > 0.0 else 1.0
		var vib := float(l.get("vib", 0.0))
		var vd := float(l.get("vd", 0.0))
		var fade := mini(int(0.004 * MIX_RATE), length)
		var env_decay := 1.0
		var freq := f0
		var phase := 0.0
		var lp_state := 0.0
		for i in length:
			var idx := start + i
			if idx >= n:
				break
			var t := float(i) / MIX_RATE
			var env := env_decay * minf(t / attack, 1.0)
			if i > length - fade:
				env *= float(length - i) / float(fade)
			env_decay *= decay_mul
			var s := 0.0
			if kind == "noise":
				lp_state += (rng.randf_range(-1.0, 1.0) - lp_state) * lp
				s = lp_state
			else:
				var f := freq
				if vib > 0.0:
					f *= 1.0 + vd * sin(TAU * vib * t)
				freq *= freq_mul
				phase = fmod(phase + f / MIX_RATE, 1.0)
				match kind:
					"sine":
						s = sin(TAU * phase)
					"square":
						s = 0.6 if phase < 0.5 else -0.6
					"saw":
						s = 2.0 * phase - 1.0
					"tri":
						s = 4.0 * absf(phase - 0.5) - 1.0
			buf[idx] += s * env * gain
	var peak := 0.0
	for v in buf:
		peak = maxf(peak, absf(v))
	var norm := 0.85 / peak if peak > 0.0001 else 1.0
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		bytes.encode_s16(i * 2, int(clampf(buf[i] * norm, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
