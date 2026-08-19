package main

import "core:fmt"
import "core:time"
import "core:os"
import "core:sys/posix"
import "core:math/rand"


WINDOW_WIDTH :: 45
WINDOW_HEIGHT :: 20

SNAKE_Y :: 10
SNAKE_X :: 22

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

draw_game :: proc(snake: []Point, food: Point) {
    // Move cursor to top-left and redraw over the previous frame.
    fmt.print("\e[H")
    for y := 0; y < WINDOW_HEIGHT; y += 1 {
        for x := 0; x < WINDOW_WIDTH; x += 1 {
            if y == 0 || y == WINDOW_HEIGHT - 1 || x == 0 || x == WINDOW_WIDTH - 1 {
                fmt.print("#")
            } else if point_in_snake(snake, x, y) {
                draw_snake()
            } else if food.x == x && food.y == y {
                add_food()
            } else {
                fmt.print(" ")
            }
        }
        fmt.println()
    }
}

main :: proc() {
    game_running := true
    snake: [dynamic]Point
    food: Point
    stdin_fd, original := termios_config_setup()
    defer posix.tcsetattr(stdin_fd, .TCSANOW, &original)


    buffer: [8]byte
    direction: Direction

    initialize_game_board(&snake, &food)

    for game_running {
        if poll_input(stdin_fd) {
            n, err := os.read(os.stdin, buffer[:])
            if err != nil || n <= 0 {
                break
            }
            key := string(buffer[:n])
            new_dir := direction_from_key(key)
            direction = try_set_direction(direction, new_dir)
        }
        if direction != .NONE {
            check_collision(snake[:], &game_running)
            should_grow: bool = check_food_collision(snake[:], &food)
            move_snake(&snake, direction, should_grow)
        }
        draw_game(snake[:], food)
        time.sleep(100 * time.Millisecond)
    }

    fmt.println("Game over!")
}

initialize_game_board :: proc(snake: ^[dynamic]Point, food: ^Point) {
    snake_head_position := Point {
        x = SNAKE_X,
        y = SNAKE_Y,
    }
    body_1 := Point {
        x = SNAKE_X - 1,
        y = SNAKE_Y,
    }
    body_2 := Point {
        x = SNAKE_X - 2,
        y = SNAKE_Y,
    }

    append(snake, snake_head_position, body_1, body_2)
    food^ = generate_food_pos(snake[:])
    draw_game(snake[:], food^)
}

add_food :: proc() {
    fmt.print("*")
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

check_food_collision :: proc(snake: []Point, food: ^Point) -> bool {
    status := snake[0].x == food^.x && snake[0].y == food^.y
    if status {
        food^ = generate_food_pos(snake)
    }
    return status
}

draw_snake :: proc() {
    fmt.print("@")
}

point_in_snake :: proc(snake: []Point, x, y: int) -> bool {
    for p in snake {
        if p.x == x && p.y == y {
            return true
        }
    }
    return false
}

move_snake :: proc(snake: ^[dynamic]Point, dir: Direction, should_grow: bool) {
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
    for i in 1..<n {
        current_pos := snake^[i]
        snake^[i] = old_pos
        old_pos = current_pos
        if i == n - 1 && should_grow {
            append(snake, old_pos)
        }
    }
}

direction_from_key :: proc(key: string) -> Direction {
    switch key {
        case "w": return .UP
        case "s": return .DOWN
        case "a": return .LEFT
        case "d": return .RIGHT
        case:      return .NONE
    }
}

try_set_direction :: proc(current, new: Direction) -> Direction {
    if new == .NONE do return current
    if current == .NONE do return new
    if is_opposite(current, new) do return current
    return new
}

is_opposite :: proc(a, b: Direction) -> bool {
    return (a == .UP && b == .DOWN) ||
           (a == .DOWN && b == .UP) ||
           (a == .LEFT && b == .RIGHT) ||
           (a == .RIGHT && b == .LEFT)
}

check_collision :: proc(snake: []Point, game_running: ^bool) {
    // Check if the snake has collided with the game border
    snake_head := snake[0]
    if snake_head.x < 1 || snake_head.x >= WINDOW_WIDTH - 1 || snake_head.y < 1 || snake_head.y >= WINDOW_HEIGHT - 1 {
        game_running^ = false
    }
    // Check if the snake has collided with itself
    n := len(snake)
    for i in 1..<n {
        if snake[i].x == snake_head.x && snake[i].y == snake_head.y {
            game_running^ = false
        }
    }
}

poll_input :: proc(stdin_fd: posix.FD) -> bool {
	pfd := posix.pollfd{
		fd = stdin_fd,
		events = {.IN},
	}
	// timeout 0 = don't block; just check if input is ready
	result := posix.poll(&pfd, 1, 0)
	return result > 0
}

termios_config_setup :: proc() -> (posix.FD, posix.termios) {
	// Save the terminal's original settings.
	original := posix.termios{}
	stdin_fd := posix.FD(os.fd(os.stdin))
	posix.tcgetattr(stdin_fd, &original)

	// Make a copy that we'll modify.
	raw := original

	// Don't wait for Enter (ICANON).
	// Don't echo keys to the terminal (ECHO).
	raw.c_lflag -= {.ICANON, .ECHO}

	// Apply the new settings.
	posix.tcsetattr(stdin_fd, .TCSANOW, &raw)
	return stdin_fd, original
}