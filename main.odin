package main

import "core:fmt"
import "core:time"

WINDOW_WIDTH :: 45
WINDOW_HEIGHT :: 20
TARGET_FPS :: 60

SNAKE_Y :: 10
SNAKE_X :: 22

point :: struct {
    x: int,
    y: int,
}

draw_game :: proc(snake_pos: point) {
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
    snake_head_position := point {
        x = SNAKE_X,
        y = SNAKE_Y,
    }

    draw_game(snake_head_position)

    for snake_head_position.x < WINDOW_WIDTH - 1 {
        snake_head_position.x += 1
        draw_game(snake_head_position)
        time.sleep(100 * time.Millisecond)
    }

}

draw_snake :: proc() {
    fmt.print("@")
}