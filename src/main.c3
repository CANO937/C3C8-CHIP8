module chip8emu;
import std::io;
import std::math::random;
import std::io::file;
import raylib6::rl;
import raygui::rg;

const ushort GFX_H = 32;
const ushort GFX_W = 64;
const ushort SCALE = 10;
const ushort INSTRUCTIONS_PER_FRAME = 12;
const ushort SAMPLE_RATE = 44100;
const int FREQ = 440;
const int PERIOD = SAMPLE_RATE / FREQ;

struct Chip8Context {
    char[4096] memory;  // 4KB of memory
    ushort[16] stack;   // Stack 16W
    char[16] vx;        // V0-VE Registers

    ushort sp;          // Stack Pointer
    ushort si;          // Source index

    ushort pc;          // Program Counter
    ushort ir;          // Instruction Register

    char dt;            // Delay timer 
    char st;            // Sound timer (if st == 0 then sound)

    char[64 * 32]  gfx; // Grafix array
    char[16]  keyboard; // Keyboard

}

const RLKeyboardKey[16] KEYMAP_QWERTY = {
    RLKeyboardKey.X,     // 0x0
    RLKeyboardKey.ONE,   // 0x1
    RLKeyboardKey.TWO,   // 0x2
    RLKeyboardKey.THREE, // 0x3
    RLKeyboardKey.Q,     // 0x4
    RLKeyboardKey.W,     // 0x5
    RLKeyboardKey.E,     // 0x6
    RLKeyboardKey.A,     // 0x7
    RLKeyboardKey.S,     // 0x8
    RLKeyboardKey.D,     // 0x9
    RLKeyboardKey.Z,     // 0xA
    RLKeyboardKey.C,     // 0xB
    RLKeyboardKey.FOUR,  // 0xC
    RLKeyboardKey.R,     // 0xD
    RLKeyboardKey.F,     // 0xE
    RLKeyboardKey.V      // 0xF
};

const RLKeyboardKey[16] KEYMAP_NUMPAD = {
    RLKeyboardKey.KP_DECIMAL,  // 0x0
    RLKeyboardKey.KP_7,        // 0x1
    RLKeyboardKey.KP_8,        // 0x2
    RLKeyboardKey.KP_9,        // 0x3
    RLKeyboardKey.KP_4,        // 0x4
    RLKeyboardKey.KP_5,        // 0x5
    RLKeyboardKey.KP_6,        // 0x6
    RLKeyboardKey.KP_1,        // 0x7
    RLKeyboardKey.KP_2,        // 0x8
    RLKeyboardKey.KP_3,        // 0x9
    RLKeyboardKey.KP_0,        // 0xA
    RLKeyboardKey.KP_ENTER,    // 0xB
    RLKeyboardKey.KP_DIVIDE,   // 0xC
    RLKeyboardKey.KP_MULTIPLY, // 0xD
    RLKeyboardKey.KP_SUBTRACT, // 0xE
    RLKeyboardKey.KP_ADD       // 0xF
};


// 0x000-0x1FF - Chip 8 interpreter (contains font set in emu)
// 0x050-0x0A0 - Used for the built in 4x5 pixel font set (0-F)
// 0x200-0xFFF - Program ROM and work RAM
fn char    readmem(ushort index, Chip8Context* context) {
    return context.memory[index];
}
fn ushort readmeml(ushort index, Chip8Context* context) {
    ushort opcode = ((ushort)context.memory[index]) << 8;
    opcode |= (ushort)context.memory[index + 1];
    return opcode;
}
fn void       push(ushort payload, Chip8Context* context) {
	context.stack[context.sp] = payload;
	context.sp++;
}
fn ushort      pop(Chip8Context* context)                 {
	context.sp--;
	ushort rp = context.stack[context.sp];
	return rp;
}

// Fetch - Decode - Execute
fn void          fetch(Chip8Context* context) {
    context.ir = readmeml(context.pc, context);
    context.pc += 2;
}
fn void decodeExecute(Chip8Context* context) {
    // CLS
	if (context.ir == 0x00E0) {
		for (int i = 0; i < context.gfx.len; i++) {
			context.gfx[i] = 0;
		}
	}
	// RET
	else if (context.ir == 0x00EE) {
		context.pc = pop(context);
	}
    // JP addr
    else if ((context.ir >> (16 - 4)) == 1) {
        ushort payload = context.ir & 0x0FFF;
		context.pc = payload;
    }
    // Call addr
    else if ((context.ir >> (16 - 4)) == 2) {
        ushort payload = context.ir & 0x0FFF;
		push(context.pc, context);
		context.pc = payload;
    }
    // SE Vx, byte
    else  if ((context.ir >> (16 - 4)) == 3) {
        char register = (char)((context.ir & 0x0F00) >> 8);
        char payload = (char)(context.ir & 0x00FF);
		if (context.vx[register] == payload) {
			context.pc += 2;
		}
    }
    // SNE Vx, byte
    else if ((context.ir >> (16 - 4)) == 4) {
        char register = (char)((context.ir & 0x0F00) >> 8);
        char payload = (char)(context.ir & 0x00FF);
		if (context.vx[register] != payload) {
			context.pc += 2;
		}
    }
	// SE Vx, Vy
	else if ((context.ir >> (16 - 4)) == 5) {
		char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		if (context.vx[register1] == context.vx[register2]) {
			context.pc += 2;
		}
	}
	// LD Vx, byte
    else if ((context.ir >> (16 - 4)) == 6) {
        char register = (char)((context.ir & 0x0F00) >> 8);
        char payload = (char)(context.ir & 0x00FF);
		context.vx[register] = payload;
    }
	// ADD Vx, byte
	else if ((context.ir >> (16 - 4)) == 7) {
        char register = (char)((context.ir & 0x0F00) >> 8);
        char payload = (char)(context.ir & 0x00FF);
		context.vx[register] = context.vx[register] + payload;
    }
	// LD Vx, Vy 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F)== 0)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[register1] = context.vx[register2];

    }
	// OR Vx, Vy 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F)== 1)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[register1] |= context.vx[register2];
    }
	// AND Vx, Vy 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 2)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[register1] &= context.vx[register2];
    }
	// XOR Vx, Vy 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 3)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[register1] ^= context.vx[register2];
    }
	// ADD Vx, Vy 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 4)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		ushort r = context.vx[register1] + context.vx[register2];
		if (r > 255) {
			context.vx[0xF] = 1;
		}
		else {
			context.vx[0xF] = 0;
		}
		context.vx[register1] = (char)(r);
    }
	// SUB Vx, Vy
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 5)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		if (context.vx[register1] >= context.vx[register2]) {
			context.vx[0xF] = 1;
		}
		else {
			context.vx[0xF] = 0;
		}
		context.vx[register1] = context.vx[register1] - context.vx[register2];
    }
	// SHR Vx {, Vy} 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 6)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[0xF] = context.vx[register1] & 0x01;
		context.vx[register1] >>= 1;
    }
	// SUBN Vx, Vy 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 7)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[0xF] = (context.vx[register2] >= context.vx[register1]) ? 1 : 0;
		context.vx[register1] = context.vx[register2] - context.vx[register1];

    }
	// SHL Vx {, Vy} 
	else if (((context.ir >> (16 - 4)) == 8) && ((context.ir & 0x000F) == 0xE)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		context.vx[0xF] =  (context.vx[register1] & 0x80) >> 7;
		context.vx[register1] <<= 1;
    }
	// SNE Vx, Vy
	else if (((context.ir >> (16 - 4)) == 9)) {
        char register1 = (char)((context.ir & 0x0F00) >> 8);
		char register2 = (char)((context.ir & 0x00F0) >> 4);
		if (context.vx[register1] != context.vx[register2]) {
			context.pc += 2;
		}
    }
	// LD I, addr
	else if (((context.ir >> (16 - 4)) == 0xA)) {
		ushort payload = context.ir & 0x0FFF;
		context.si = payload;
	}
	// JP V0, addr
	else if (((context.ir >> (16 - 4)) == 0xB)) {
		ushort payload = context.ir & 0x0FFF;
		context.pc = context.vx[0] + payload;
	}
	// RND Vx, byte
	else if (((context.ir >> (16 - 4)) == 0xC)) {
        char register = (char)((context.ir & 0x0F00) >> 8);
        char payload = (char)(context.ir & 0x00FF);
		context.vx[register] = (char)(rand(256) & payload);
	}
	// DRW Vx, Vy, nibble DXYN
	else if (((context.ir >> (16 - 4)) == 0xD)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		char register2 =  (char)((context.ir & 0x00F0) >> 4);
		char nibble    =  (char)(context.ir & 0x000F);

		char sx = context.vx[register1] % 64;
    	char sy = context.vx[register2] % 32;

		context.vx[0xF] = 0;
		
		for (char row = 0; row < nibble; row++) {
        	if (sy + row >= 32) break;
        	char spriteb = context.memory[context.si + row];
        	for (char col = 0; col < 8; col++) {
            	if (sx + col >= 64) break;
            	char spritep = spriteb & (0x80 >> col);

            	if (spritep != 0) {
            	    ushort screeni = (sy + row) * 64 + (sx + col);
            	    if (context.gfx[screeni] == 1) {
           	         	context.vx[0xF] = 1;
            	    }
            	    context.gfx[screeni] ^= 1;
				}
			}
		}
	}
	// SKP Vx
	else if (((context.ir >> (16 - 4)) == 0xE) && ((context.ir & 0x00FF) == 0x9E)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		char key = context.vx[register1] & 0x0F;

		if (context.keyboard[key] != 0) {
			context.pc += 2;
		}

	}
	// SKNP Vx
	else if (((context.ir >> (16 - 4)) == 0xE) && ((context.ir & 0x00FF) == 0xA1)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		char key = context.vx[register1] & 0x0F;

		if (context.keyboard[key] == 0) {
			context.pc += 2;
		}
	}
	// LD Vx, DT
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x07)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		context.vx[register1] = context.dt;
	}
	//  LD Vx, K 
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x0A)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		char key = context.vx[register1] & 0x0F;
		bool keyP = false;

		for (char i = 0; i < 16; i++) {
			if (context.keyboard[i] != 0) {
				context.vx[register1] = i;
				keyP = true;
				break;
			}
		}

		if (!keyP) {
			context.pc -= 2;
		}
	}
	// LD DT, Vx
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x15)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		context.dt = context.vx[register1];
	}
	// LD ST, Vx  
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x18)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		context.st = context.vx[register1];
	}
	// ADD I, Vx 
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x1E)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		context.si += context.vx[register1];
	}
	// LD F, Vx
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x29)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);

    	char digit = context.vx[register1] & 0x0F;
    	context.si = 0x50 + (digit * 5);
	}
	// LD B, Vx
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x33)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);

		char value = context.vx[register1];
		context.memory[context.si]     = value / 100;
		context.memory[context.si + 1] = (value / 10) % 10;
		context.memory[context.si + 2] = value % 10;
		context.si += 3;
	}
	// LD [I], Vx
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x55)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		for (int i = 0; i < (register1 + 1); i++) {
			context.memory[context.si + i] = context.vx[i];
		}
	}
	// LD Vx, [I]
	else if (((context.ir >> (16 - 4)) == 0xF) && ((context.ir & 0x00FF) == 0x65)) {
        char register1 =  (char)((context.ir & 0x0F00) >> 8);
		for (int i = 0; i < (register1 + 1); i++) {
			context.vx[i] = context.memory[context.si + i];
		}
	}
}

// Load ROM
fn bool loadRom(String filename, Chip8Context* context) {
	File? fl = file::open(filename, "rb");
	if (catch error = fl) {
		io::printfn("Errore apertura file '%s': %s", filename, error);
		return false;
	}
	defer (void)fl.close();

	sz? fileRead = fl.read(context.memory[0x200..]);
	if (catch error = fileRead) {
        io::printfn("Errore lettura ROM: %s", error);
        return false;
	}

    io::printfn("ROM caricata con successo (%d byte).", fileRead);
    return true;	
}

// Init Graphics
fn void init() {
	rl::set_trace_log_level((RLTraceLogLevel)7);
	rl::init_window(640, 320, "c3chip8");
	rl::begin_drawing();
	rl::clear_background(rl::BLACK);
	rl::end_drawing();
	rl::set_target_fps(60);
}

// Update Keypad
fn void updateKeypad(Chip8Context* context) {
    for (int i = 0; i < 16; i++) {
        bool pressed = rl::is_key_down(KEYMAP_QWERTY[i]) || rl::is_key_down(KEYMAP_NUMPAD[i]);
        context.keyboard[i] = pressed ? 1 : 0;
    }
}

fn void main() {
    Chip8Context context;
	context.pc = 0x200;

	init();
	rl::init_audio_device();
	short[PERIOD] samples;
	for (int i = 0; i < PERIOD; i++) {
		samples[i] = (i < PERIOD / 2) ? 4000 : -4000;
	}
	RLWave wave = {
		.frameCount  = PERIOD,
		.sample_rate = SAMPLE_RATE,
		.sample_size = 16,
		.channels    = 1,
		.data        = &samples
	};
	RLSound beep = rl::load_sound_from_wave(wave);
	
	io::printfn("input file");
	String? filename = io::treadline();
	if (catch error = filename)  {
		io::printfn("Internal Error %s", error);
		return;
	}
	if (!loadRom(filename, &context)) {
		return;
	}
	
	while (!rl::window_should_close()) {
		updateKeypad(&context);
		for (char i = 0; i < INSTRUCTIONS_PER_FRAME; i++) {
			fetch(&context);
			decodeExecute(&context);
		}
		rl::begin_drawing();
		rl::clear_background(rl::BLACK);
		for (ushort y = 0; y < GFX_H; y++) {
			for (ushort x = 0; x < GFX_W; x++) {
				if (context.gfx[y * 64 + x] != 0) {
					rl::draw_rectangle(x * SCALE, y * SCALE, SCALE, SCALE, rl::GREEN);
				}
			}
		}
		rl::end_drawing();


		if (context.dt > 0) {
        	context.dt--;
    	}
		if (context.st > 0) {
			if (!rl::is_sound_playing(beep)) {
				rl::play_sound(beep);
			}
			context.st--;
		} else {
			if (rl::is_sound_playing(beep)) {
				rl::stop_sound(beep);
			}
		}
		

	}

	rl::unload_sound(beep);
	rl::close_audio_device();
	rl::close_window();
	
	io::print("\e[2J\e[H");
	for (int i = 0; i < 16; i++) {
		io::printfn("V%d\t = %d", i, context.vx[i]);
	}
	io::printfn("SP\t = %d", context.sp);
	io::printfn("SI\t = %d", context.si);
	io::printfn("PC\t = %d", context.pc);
	io::printfn("IR\t = %d", context.ir);
	io::printfn("DT\t = %d", context.dt);
	io::printfn("ST\t = %d", context.st);

}
