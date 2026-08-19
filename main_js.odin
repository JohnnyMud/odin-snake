package main

import "base:runtime"

g: Game
board_buf: [BOARD_BUF_SIZE]byte
board_len: u32

refresh_board :: proc() {
	board_len = u32(game_write_board(&g, board_buf[:]))
}

@(export)
game_init :: proc "c" () {
	context = runtime.default_context()
	game_reset(&g)
	refresh_board()
}

@(export)
game_keydown :: proc "c" (key: u32) {
	context = runtime.default_context()
	k := key
	if k >= 'A' && k <= 'Z' {
		k += 32
	}
	ch: [1]byte = {u8(k)}
	game_apply_key(&g, string(ch[:]))
	refresh_board()
}

@(export)
game_tick :: proc "c" () {
	context = runtime.default_context()
	game_step(&g)
	refresh_board()
}

@(export)
game_board_ptr :: proc "c" () -> rawptr {
	return raw_data(board_buf[:])
}

@(export)
game_board_len :: proc "c" () -> u32 {
	return board_len
}
