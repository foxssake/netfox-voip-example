extends MultiplayerSpawner

@export var player_scene: PackedScene

func _ready():
	set_multiplayer_authority(1)
	NetworkEvents.on_server_start.connect(_handle_server_start)
	NetworkEvents.on_client_start.connect(_handle_client_start)
	NetworkEvents.on_peer_join.connect(_handle_peer_join)

func _handle_server_start():
	spawn_avatar(multiplayer.get_unique_id())

func _handle_client_start(peer_id: int):
	spawn_avatar(peer_id)

func _handle_peer_join(peer_id: int):
	spawn_avatar(peer_id)

func spawn_avatar(peer_id: int):
	var avatar = player_scene.instantiate() as Node3D
	avatar.name += " #%s" % peer_id
	avatar.position = Vector3.UP
	
	get_node(spawn_path).add_child(avatar, true)
	avatar.set_multiplayer_authority(peer_id)
	
	if peer_id == multiplayer.get_unique_id():
		var listener = AudioListener3D.new()
		avatar.add_child(listener)
