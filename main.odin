package main

import "core:fmt"

WINDOW_WIDTH :: 45
WINDOW_HEIGHT :: 20
TARGET_FPS :: 60

draw_border :: proc() {
    for i := 0; i < WINDOW_HEIGHT; i += 1 {
        for j := 0; j < WINDOW_WIDTH; j += 1 {
            if i == 0 || i == WINDOW_HEIGHT - 1 || j == 0 || j == WINDOW_WIDTH - 1 {
                fmt.print("#")
            } else {
                fmt.print(" ")
            }
        }
        fmt.println()
    }
}

main :: proc() {
    draw_border()
}