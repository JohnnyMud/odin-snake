package main

import "core:fmt"
import "core:time"
import "core:os"
import "core:sys/posix"

WINDOW_WIDTH :: 45
WINDOW_HEIGHT :: 20
TARGET_FPS :: 60

SNAKE_Y :: 10
SNAKE_X :: 22

Point :: struct {
    x: int,
    y: int,
}

Direction :: enum {
    UP,
    DOWN,
    RIGHT,
    LEFT,
}

draw_game :: proc(snake_pos: Point) {
    // Move cursor to top-left and redraw over the previous frame.
    fmt.print("\e[H")
    for y := 0; y < WINDOW_HEIGHT; y += 1 {
        for x := 0; x < WINDOW_WIDTH; x += 1 {
            if y == 0 || y == WINDOW_HEIGHT - 1 || x == 0 || x == WINDOW_WIDTH - 1 {
                fmt.print("#")
            } else if y == snake_pos.y && x == snake_pos.x {
                draw_snake()
            } else {
                fmt.print(" ")
            }
        }
        fmt.println()
    }
}

main :: proc() {
    stdin_fd, original := termios_config_setup()
    defer posix.tcsetattr(stdin_fd, .TCSANOW, &original)


    buffer: [256]byte
    direction: Direction

    snake_head_position := Point {
        x = SNAKE_X,
        y = SNAKE_Y,
    }

    draw_game(snake_head_position)

    for snake_head_position.x < WINDOW_WIDTH - 1 {
        if poll_input(stdin_fd) {
            n, err := os.read(os.stdin, buffer[:])
            if err != nil || n <= 0 {
                break
            }
            key := string(buffer[:n])
            switch key {
                case "w":
                    direction = .UP
                case "s":
                    direction = .DOWN
                case "a":
                    direction = .LEFT
                case "d":
                    direction = .RIGHT
            }
        }
        move_snake(&snake_head_position, direction)
        draw_game(snake_head_position)
        time.sleep(100 * time.Millisecond)
    }

}

draw_snake :: proc() {
    fmt.print("@")
}

move_snake :: proc(pos: ^Point, dir: Direction) {
    switch dir {
        case .UP:
            pos.y -= 1
        case .DOWN:
            pos.y += 1
        case .LEFT:
            pos.x -= 2
        case .RIGHT:
            pos.x += 2
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