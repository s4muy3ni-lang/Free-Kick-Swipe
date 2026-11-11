extends TestCase
## Estilo arcade liviano (pedido del usuario): publico 2D con una hoja de sprites PNG que se mueve y festeja, tribunas y
## torres estilo caja en pocas mallas, y en Boton de caida una torre de hierro bajo cada plataforma que se pierde en el
## vacio.

## Mallas (draw calls) que agrega el estadio de noche completo: tribunas, luces, publico, torres y banderas.
const ARENA_MESH_BUDGET := 40

func _meshes(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		if n is MeshInstance3D or n is MultiMeshInstance3D:
			out.append(n)
	return out

func _arena() -> Node3D:
	var root := Node3D.new()
	spawn(root)
	ArcadeLook.night_arena(root, Vector3(10, 0, 0), 30.0, 18.0, true)
	return root

func test_crowd_is_2d_sprites_in_one_draw_call() -> void:
	var root := _arena()
	var crowds: Array = root.find_children("Publico", "MultiMeshInstance3D", true, false)
	check(crowds.size() == 1, "el publico es una sola MultiMesh")
	var mmi: MultiMeshInstance3D = crowds[0]
	var mm: MultiMesh = mmi.multimesh
	note("hinchas: %d, triangulos del publico: %d" % [mm.instance_count, mm.instance_count * 2])
	check(mm.mesh is QuadMesh, "cada hincha es un cuadrado (2 triangulos), no un cubo")
	check(mm.instance_count > 300, "tribunas llenas")
	var sm: ShaderMaterial = mmi.material_override
	var tex: Texture2D = sm.get_shader_parameter("atlas")
	check(tex != null and tex.get_width() == 256 and tex.get_height() == 1152, "usa la hoja de sprites PNG (4 cuadros x 12 variantes)")
	var all: Array = _meshes(root)
	note("mallas del estadio: %d (presupuesto %d)" % [all.size(), ARENA_MESH_BUDGET])
	check(all.size() <= ARENA_MESH_BUDGET, "el estadio entra en el presupuesto de mallas")
	check(root.find_children("*", "CollisionObject3D", true, false).is_empty(), "la decoracion no tiene colision")
	cleanup()

func test_crowd_cheers_and_calms_down() -> void:
	var root := _arena()
	check(is_zero_approx(ArcadeLook.cheer_level(root)), "en calma al empezar")
	ArcadeLook.cheer(root, 1.0, 0.5)
	await wait_seconds(0.5)
	note("festejo a los 0,5 s: %.2f" % ArcadeLook.cheer_level(root))
	check(ArcadeLook.cheer_level(root) > 0.95, "festeja")
	await wait_seconds(2.0)
	check(ArcadeLook.cheer_level(root) < 0.01, "y vuelve a la calma")
	cleanup()

func test_good_shot_makes_the_crowd_cheer() -> void:
	var d: Dictionary = MinigameCatalog.level("dianas", 1)
	d["seed"] = 3
	d["practice"] = true
	Minigame.next_def = d
	var g: Minigame = (load(String(d["scene"])) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	check(is_equal_approx(g.crowd_cheer("todas", ["¡TODAS ABAJO!", Color(0.35, 1.0, 0.45)]), 1.0), "un buen tiro (verde) festejan todos")
	check(is_zero_approx(g.crowd_cheer("x", ["Afuera", Color(1.0, 0.6, 0.4)])), "un error no")
	check(is_zero_approx(g.crowd_cheer("x", ["0 de 3 dianas", Color(1.0, 0.85, 0.35)])), "un tiro que no suma, tampoco")
	g.state = Minigame.State.FLIGHT
	g._resolve("todas")
	await wait_seconds(0.4)
	note("tras «todas»: festejo %.2f" % ArcadeLook.cheer_level(g))
	check(ArcadeLook.cheer_level(g) > 0.95, "y el publico del modo festeja de verdad")
	cleanup()

func test_boton_iron_tower_goes_down_into_the_void() -> void:
	var d: Dictionary = MinigameCatalog.level("boton_caida", 1)
	d["seed"] = 5
	d["practice"] = true
	Minigame.next_def = d
	var g: BotonCaida = (load(BotonCaida.SCENE) as PackedScene).instantiate()
	g.fast = true
	spawn(g)
	await physics_frames(5)
	for s in 2:
		var t: MeshInstance3D = g.get_node_or_null("TorreHierro%d" % s)
		check(t != null, "plataforma %d: tiene torre de hierro" % s)
		if t == null:
			continue
		var bb: AABB = t.mesh.get_aabb()
		note("torre %d: de y = %.1f a %.1f, %d vertices" % [s, bb.position.y, bb.end.y, t.mesh.surface_get_array_len(0)])
		check(bb.end.y < -0.85 and bb.end.y > -1.6, "arranca debajo de la cubierta (la losa va de 0 a -1 m)")
		check(bb.position.y < -25.0, "baja hasta perderse en el vacio")
		# El que cae pasa por adentro: ninguna viga cruza la columna del hueco de la trampilla.
		var verts: PackedVector3Array = t.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var h: Vector3 = g._hole_local[s]
		var inside: int = 0
		for v in verts:
			var p: Vector3 = g.frames[s].affine_inverse() * v
			if p.y > -14.0 and absf(p.x - h.x) < BotonCaida.HOLE * 0.5 and absf(p.z - h.z) < BotonCaida.HOLE * 0.5:
				inside += 1
		check(inside == 0, "plataforma %d: la torre no tapa la caida (%d vertices en el hueco)" % [s, inside])
	var env: Environment = null
	for c in g.get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
	check(env != null and env.fog_enabled and env.fog_height_density > 0.0 and is_zero_approx(env.fog_density), "niebla solo por debajo: el vacio se oscurece, arriba se ve igual")
	cleanup()
