class_name TestCase
extends RefCounted
## 작은 테스트 기반 클래스. test_ 로 시작하는 메서드가 하나의 테스트다.
## 통합 테스트는 runner(장면 트리 안의 노드)를 이용해 장면을 붙이고 프레임을 기다린다.

var runner: Node
## 이 테스트에서 의도적으로 발생시키는 엔진 에러 수
var expected_errors: int = 0
var _failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func tree() -> SceneTree:
	return runner.get_tree()


func add_to_tree(node: Node) -> Node:
	runner.add_child(node)
	return node


func wait_frames(count: int = 1) -> void:
	for i in count:
		await runner.get_tree().process_frame


func wait_physics_frames(count: int = 1) -> void:
	for i in count:
		await runner.get_tree().physics_frame


## 고정 60fps로 실행하므로 초 단위를 물리 프레임 수로 바꿔 기다린다.
func wait_seconds(seconds: float) -> void:
	await wait_physics_frames(int(ceil(seconds * Engine.physics_ticks_per_second)))


func expect_error(count: int = 1) -> void:
	expected_errors += count


func fail(message: String) -> void:
	_failures.append(message)


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		fail("참이어야 함. %s" % message)


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		fail("거짓이어야 함. %s" % message)


func assert_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if typeof(actual) != typeof(expected) or actual != expected:
		fail("기대값 %s, 실제값 %s. %s" % [var_to_str(expected), var_to_str(actual), message])


func assert_ne(actual: Variant, unexpected: Variant, message: String = "") -> void:
	if typeof(actual) == typeof(unexpected) and actual == unexpected:
		fail("%s 이(가) 아니어야 함. %s" % [var_to_str(unexpected), message])


func assert_near(actual: float, expected: float, epsilon: float = 0.001, message: String = "") -> void:
	if absf(actual - expected) > epsilon:
		fail("기대값 %.4f±%.4f, 실제값 %.4f. %s" % [expected, epsilon, actual, message])


func assert_gt(actual: float, bound: float, message: String = "") -> void:
	if not actual > bound:
		fail("%.4f > %.4f 이어야 함. %s" % [actual, bound, message])


func assert_ge(actual: float, bound: float, message: String = "") -> void:
	if not actual >= bound:
		fail("%.4f >= %.4f 이어야 함. %s" % [actual, bound, message])


func assert_lt(actual: float, bound: float, message: String = "") -> void:
	if not actual < bound:
		fail("%.4f < %.4f 이어야 함. %s" % [actual, bound, message])


func assert_le(actual: float, bound: float, message: String = "") -> void:
	if not actual <= bound:
		fail("%.4f <= %.4f 이어야 함. %s" % [actual, bound, message])


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		fail("null이어야 함. %s" % message)


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		fail("null이 아니어야 함. %s" % message)
