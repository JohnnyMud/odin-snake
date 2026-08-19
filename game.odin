package main

import "core:math/rand"
import "core:strconv"

WINDOW_WIDTH :: 45
WINDOW_HEIGHT :: 20

SNAKE_Y :: 10
SNAKE_X :: 22

// Score line + board rows (each with newline), with headroom for game-over text.
BOARD_BUF_SIZE :: 2048

Point :: struct {
	x: int,
	y: int,
}

Direction :: enum {
	NONE,
	UP,
	DOWN,
	RIGHT,
	LEFT,
}

Game :: struct {
	snake:     [dynamic]Point,
	food:      Point,
	direction: Direction,
	running:   bool,
	score:     int,
}

game_reset :: proc(g: ^Game) {
	clear(&g.snake)
	g.score = 0
	g.direction = .NONE
	g.running = true

	append(
		&g.snake,
		Point{x = SNAKE_X, y = SNAKE_Y},
		Point{x = SNAKE_X - 1, y = SNAKE_Y},
		Point{x = SNAKE_X - 2, y = SNAKE_Y},
	)
	g.food = generate_food_pos(g.snake[:])
}

game_apply_key :: proc(g: ^Game, key: string) {
	if !g.running && (key == "r" || key == "R") {
		game_reset(g)
		return
	}
	g.direction = try_set_direction(g.direction, direction_from_key(key))
}

game_step :: proc(g: ^Game) {
	if !g.running || g.direction == .NONE {
		return
	}

	old_tail := g.snake[len(g.snake) - 1]
	move_snake(&g.snake, g.direction)
	check_collision(g)

	if g.running && g.snake[0].x == g.food.x && g.snake[0].y == g.food.y {
		append(&g.snake, old_tail)
		g.score += 1
		g.food = generate_food_pos(g.snake[:])
	}
}

game_write_board :: proc(g: ^Game, buf: []byte) -> int {
	n := 0
	if g.running {
		write_playing_board(g, buf, &n)
	} else {
		write_game_over_board(g, buf, &n)
	}
	return n
}

write_playing_board :: proc(g: ^Game, buf: []byte, n: ^int) {
	write_str(buf, n, "Score: ")
	write_int(buf, n, g.score)
	write_byte(buf, n, '\n')

	for y := 0; y < WINDOW_HEIGHT; y += 1 {
		for x := 0; x < WINDOW_WIDTH; x += 1 {
			ch: byte
			if y == 0 || y == WINDOW_HEIGHT - 1 || x == 0 || x == WINDOW_WIDTH - 1 {
				ch = '#'
			} else if point_in_snake(g.snake[:], x, y) {
				ch = '@'
			} else if g.food.x == x && g.food.y == y {
				ch = '*'
			} else {
				ch = ' '
			}
			write_byte(buf, n, ch)
		}
		write_byte(buf, n, '\n')
	}
}

write_game_over_board :: proc(g: ^Game, buf: []byte, n: ^int) {
	score_tmp: [32]byte
	score_n := 0
	write_str(score_tmp[:], &score_n, "Score: ")
	write_int(score_tmp[:], &score_n, g.score)
	score_line := string(score_tmp[:score_n])

	// Blank line where the live score sat, so a full redraw covers it.
	write_byte(buf, n, '\n')
	write_border_row(buf, n)
	for y in 1 ..< WINDOW_HEIGHT - 1 {
		switch y {
		case WINDOW_HEIGHT / 2 - 2:
			write_centered_row(buf, n, "GAME OVER")
		case WINDOW_HEIGHT / 2:
			write_centered_row(buf, n, score_line)
		case WINDOW_HEIGHT / 2 + 2:
			write_centered_row(buf, n, "Press R to replay")
		case:
			write_centered_row(buf, n, "")
		}
	}
	write_border_row(buf, n)
}

write_border_row :: proc(buf: []byte, n: ^int) {
	for _ in 0 ..< WINDOW_WIDTH {
		write_byte(buf, n, '#')
	}
	write_byte(buf, n, '\n')
}

write_centered_row :: proc(buf: []byte, n: ^int, text: string) {
	inner := WINDOW_WIDTH - 2
	text_len := len(text)
	pad_left := (inner - text_len) / 2
	pad_right := inner - text_len - pad_left

	write_byte(buf, n, '#')
	for _ in 0 ..< pad_left {
		write_byte(buf, n, ' ')
	}
	write_str(buf, n, text)
	for _ in 0 ..< pad_right {
		write_byte(buf, n, ' ')
	}
	write_byte(buf, n, '#')
	write_byte(buf, n, '\n')
}

write_str :: proc(buf: []byte, n: ^int, s: string) {
	remaining := len(buf) - n^
	to_copy := min(len(s), remaining)
	if to_copy > 0 {
		copy(buf[n^:], s[:to_copy])
		n^ += to_copy
	}
}

write_byte :: proc(buf: []byte, n: ^int, b: byte) {
	if n^ < len(buf) {
		buf[n^] = b
		n^ += 1
	}
}

write_int :: proc(buf: []byte, n: ^int, v: int) {
	tmp: [20]byte
	s := strconv.write_int(tmp[:], i64(v), 10)
	write_str(buf, n, s)
}

generate_food_pos :: proc(snake: []Point) -> Point {
	// Horizontal moves use ±2, and the snake starts on an even X, so the head
	// only ever occupies even columns. Food must use that same grid or it can
	// spawn on an odd X the snake can never reach.
	food := Point {
		x = rand.int_range(1, (WINDOW_WIDTH - 1) / 2) * 2,
		y = rand.int_range(1, WINDOW_HEIGHT - 1),
	}
	if point_in_snake(snake, food.x, food.y) {
		return generate_food_pos(snake)
	}
	return food
}

point_in_snake :: proc(snake: []Point, x, y: int) -> bool {
	for p in snake {
		if p.x == x && p.y == y {
			return true
		}
	}
	return false
}

move_snake :: proc(snake: ^[dynamic]Point, dir: Direction) {
	old_pos := snake^[0]
	n := len(snake)
	switch dir {
	case .NONE:
		return
	case .UP:
		snake^[0].y -= 1
	case .DOWN:
		snake^[0].y += 1
	case .LEFT:
		snake^[0].x -= 2
	case .RIGHT:
		snake^[0].x += 2
	}
	for i in 1 ..< n {
		current_pos := snake^[i]
		snake^[i] = old_pos
		old_pos = current_pos
	}
}

direction_from_key :: proc(key: string) -> Direction {
	switch key {
	case "w", "W":
		return .UP
	case "s", "S":
		return .DOWN
	case "a", "A":
		return .LEFT
	case "d", "D":
		return .RIGHT
	case:
		return .NONE
	}
}

try_set_direction :: proc(current, new: Direction) -> Direction {
	if new == .NONE do return current
	if current == .NONE do return new
	if is_opposite(current, new) do return current
	return new
}

is_opposite :: proc(a, b: Direction) -> bool {
	return(
		(a == .UP && b == .DOWN) ||
		(a == .DOWN && b == .UP) ||
		(a == .LEFT && b == .RIGHT) ||
		(a == .RIGHT && b == .LEFT) \
	)
}

check_collision :: proc(g: ^Game) {
	snake_head := g.snake[0]
	if snake_head.x < 1 ||
	   snake_head.x >= WINDOW_WIDTH - 1 ||
	   snake_head.y < 1 ||
	   snake_head.y >= WINDOW_HEIGHT - 1 {
		g.running = false
	}
	n := len(g.snake)
	for i in 1 ..< n {
		if g.snake[i].x == snake_head.x && g.snake[i].y == snake_head.y {
			g.running = false
		}
	}
}
