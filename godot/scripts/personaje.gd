extends CharacterBody3D
## Esqueleto mínimo de personaje jugable — cápsula placeholder, sin arte.
## Se llega a esta escena haciendo zoom a la zona "ciudad" desde Mapa.tscn.

const VELOCIDAD := 4.0
const GRAVEDAD := 9.8

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVEDAD * delta

	var mover := _vector_movimiento()
	velocity.x = mover.x * VELOCIDAD
	velocity.z = mover.y * VELOCIDAD

	if mover != Vector2.ZERO:
		look_at(global_position + Vector3(mover.x, 0, mover.y), Vector3.UP)

	move_and_slide()

func _vector_movimiento() -> Vector2:
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if v == Vector2.ZERO:
		v.x = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
		v.y = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
	return v
