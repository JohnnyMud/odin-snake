#+build !js
package main

import "core:fmt"
import "core:os"
import "core:sys/posix"
import "core:time"

main :: proc() {
	g: Game
	stdin_fd, original := termios_config_setup()
	defer posix.tcsetattr(stdin_fd, .TCSANOW, &original)

	input: [8]byte
	board: [BOARD_BUF_SIZE]byte

	for {
		game_reset(&g)
		draw_frame(&g, board[:])

		for g.running {
			if poll_input(stdin_fd) {
				n, err := os.read(os.stdin, input[:])
				if err != nil || n <= 0 {
					return
				}
				game_apply_key(&g, string(input[:n]))
			}
			game_step(&g)
			draw_frame(&g, board[:])
			time.sleep(100 * time.Millisecond)
		}

		draw_frame(&g, board[:])
		if !wait_for_replay(&g, stdin_fd, input[:]) {
			return
		}
	}
}

draw_frame :: proc(g: ^Game, board: []byte) {
	fmt.print("\e[H\e[J")
	n := game_write_board(g, board)
	fmt.print(string(board[:n]))
}

wait_for_replay :: proc(g: ^Game, stdin_fd: posix.FD, buffer: []byte) -> bool {
	for {
		if poll_input(stdin_fd) {
			n, err := os.read(os.stdin, buffer)
			if err != nil || n <= 0 {
				return false
			}
			game_apply_key(g, string(buffer[:n]))
			if g.running {
				return true
			}
		}
		time.sleep(50 * time.Millisecond)
	}
}

poll_input :: proc(stdin_fd: posix.FD) -> bool {
	pfd := posix.pollfd {
		fd     = stdin_fd,
		events = {.IN},
	}
	result := posix.poll(&pfd, 1, 0)
	return result > 0
}

termios_config_setup :: proc() -> (posix.FD, posix.termios) {
	original := posix.termios{}
	stdin_fd := posix.FD(os.fd(os.stdin))
	posix.tcgetattr(stdin_fd, &original)

	raw := original
	raw.c_lflag -= {.ICANON, .ECHO}

	posix.tcsetattr(stdin_fd, .TCSANOW, &raw)
	return stdin_fd, original
}
