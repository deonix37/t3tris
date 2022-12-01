extends Node2D

signal lines_completed

const PIECE_SPAWN_CELL = Vector2i(3, 0)
const PIECE_VARIATIONS = [
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(2, 1)],
    [Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
    [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(2, 1)],
]

const CELL_SIZE = Vector2i(28, 28)
const FIELD_SIZE = Vector2i(10, 20)
const FIELD_RECT = Rect2i(Vector2i.ZERO, FIELD_SIZE)

var score := 0

@onready var grid := $Grid as Node2D

@onready var step_timer := $StepTimer as Timer
@onready var default_step_time := step_timer.wait_time
@onready var accelerated_step_time := default_step_time / 10

func _ready() -> void:
    randomize()
    spawn_piece()

func _input(event: InputEvent) -> void:
    if event.is_action_pressed('move_left', true):
        if can_move_piece(Vector2i(-1, 0)):
            move_piece(Vector2i(-1, 0))

    if event.is_action_pressed('move_right', true):
        if can_move_piece(Vector2i(1, 0)):
            move_piece(Vector2i(1, 0))

    if event.is_action_pressed('move_down'):
        accelerate_step_timer()

    if event.is_action_pressed('move_up'):
        rotate_piece()

    if event.is_action_pressed('reload'):
        get_tree().reload_current_scene()

func on_piece_placed() -> void:
    complete_lines()
    reset_step_timer()
    spawn_piece()

func on_game_over() -> void:
    step_timer.stop()
    shuffle_blocks()

func complete_lines() -> void:
    var blocks_by_cells := {}
    var all_blocks_to_remove: Array[PieceBlock] = []

    for block in get_all_blocks():
        blocks_by_cells[block.field_cell] = block

    for y in range(FIELD_SIZE.y):
        var blocks_to_remove: Array[PieceBlock] = []

        for x in range(FIELD_SIZE.x):
            var block = blocks_by_cells.get(Vector2i(x, y))

            if block:
                blocks_to_remove.append(block)

        if blocks_to_remove.size() != FIELD_SIZE.x:
            continue

        for cell in blocks_by_cells:
            if cell.y < y:
                move_block(blocks_by_cells[cell], Vector2i(0, 1))

        all_blocks_to_remove.append_array(blocks_to_remove)

    for block in all_blocks_to_remove:
        block.queue_free()

    if all_blocks_to_remove:
        score += all_blocks_to_remove.size()
        emit_signal('lines_completed', score)

func spawn_piece() -> void:
    for block in get_piece_blocks():
        block.remove_from_group('piece_blocks')

    for cell in PIECE_VARIATIONS.pick_random():
        spawn_piece_block(cell)

func spawn_piece_block(cell: Vector2i) -> void:
    var block := PieceBlock.new()

    block.piece_cell = cell
    block.field_cell = PIECE_SPAWN_CELL + cell

    block.size = CELL_SIZE
    block.position = block.field_cell * CELL_SIZE

    block.add_to_group('blocks')
    block.add_to_group('piece_blocks')

    add_child(block)

func rotate_piece() -> void:
    var piece_size := get_piece_size()
    var blocks_by_cells := {}
    var blocks_offsets := {}

    for block in get_piece_blocks():
        blocks_by_cells[block.piece_cell] = block

    for y in range(piece_size.y):
        for x in range(piece_size.x):
            var block = blocks_by_cells.get(Vector2i(x, y))

            if not block:
                continue

            var new_cell := Vector2i(y, piece_size.x - 1 - x)
            var offset = new_cell - block.piece_cell

            if not can_move_block(block, offset):
                return

            blocks_offsets[block] = offset

    for block in blocks_offsets:
        block.piece_cell += blocks_offsets[block]
        move_block(block, blocks_offsets[block])

func move_piece(offset: Vector2i) -> void:
    for block in get_piece_blocks():
        move_block(block, offset)

func move_block(block: PieceBlock, offset: Vector2i) -> void:
    block.field_cell += offset
    block.position += Vector2(offset * CELL_SIZE)

func shuffle_blocks() -> void:
    for block in get_all_blocks():
        block.position = Vector2(
            randi() % FIELD_SIZE.x * CELL_SIZE.x,
            randi() % FIELD_SIZE.y * CELL_SIZE.y,
        )

func can_move_piece(offset: Vector2i) -> bool:
    for block in get_piece_blocks():
        if not can_move_block(block, offset):
            return false

    return true

func can_move_block(block: PieceBlock, offset: Vector2i) -> bool:
    var new_cell := block.field_cell + offset

    if not Rect2i(new_cell, Vector2i.ONE).intersects(FIELD_RECT):
        return false

    for external_block in get_all_blocks():
        if not external_block.is_in_group('piece_blocks'):
            if new_cell == external_block.field_cell:
                return false

    return true

func get_piece_size() -> Vector2i:
    var result := Vector2i.ZERO

    for block in get_piece_blocks():
        result.x = max(result.x, block.piece_cell.x)
        result.y = max(result.y, block.piece_cell.y)

    return result + Vector2i.ONE

func get_all_blocks() -> Array[Node]:
    return get_tree().get_nodes_in_group('blocks')

func get_piece_blocks() -> Array[Node]:
    return get_tree().get_nodes_in_group('piece_blocks')

func accelerate_step_timer() -> void:
    step_timer.wait_time = accelerated_step_time
    step_timer.start()

func reset_step_timer() -> void:
    step_timer.wait_time = default_step_time
    step_timer.start()

func _on_step_timer_timeout() -> void:
    if can_move_piece(Vector2i(0, 1)):
        move_piece(Vector2i(0, 1))
    elif not can_move_piece(Vector2i(0, 0)):
        on_game_over()
    else:
        on_piece_placed()

func _on_grid_draw() -> void:
    for x in range(FIELD_SIZE.x):
        for y in range(FIELD_SIZE.y):
            var origin := Vector2i(CELL_SIZE.x * x, CELL_SIZE.y * y)

            grid.draw_polyline([
                origin,
                origin + Vector2i(CELL_SIZE.x, 0),
                origin + Vector2i(CELL_SIZE.x, CELL_SIZE.y),
                origin + Vector2i(0, CELL_SIZE.y),
                origin,
            ], Color(0.5, 0.5, 0.5), 3)
