import std.stdio;
static import std.ascii;
import std.algorithm : min;
import std.array;
import std.exception : enforce;
import std.string;
import core.time;
import bindbc.sdl;
import bindbc.sdl.ttf;

import buffer;
import cursor;

class Window {
    SDL_Window* window;
    SDL_Renderer* renderer;
    int width = 1080;
    int height = 720;

    this() {
        window = SDL_CreateWindow("editor", SDL_WINDOWPOS_UNDEFINED,
                SDL_WINDOWPOS_UNDEFINED, width, height, SDL_WINDOW_RESIZABLE);
        enforce(window);
        renderer = SDL_CreateRenderer(window, -1, 0);
        enforce(renderer);
    }

    void resize(int width, int height) {
        this.width = width;
        this.height = height;
    }

    void set_color(SDL_Color color) {
        SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255);

    }

    void clear(SDL_Color color) {
        set_color(color);
        SDL_RenderClear(renderer);
    }

    void blit(SDL_Texture* texture, int x, int y) {
        int w, h;
        SDL_QueryTexture(texture, null, null, &w, &h);
        SDL_Rect dst = SDL_Rect(x, y, w, h);
        enforce(SDL_RenderCopy(renderer, texture, null, &dst) == 0);
    }

    void rect(SDL_Color color, SDL_Rect rect) {
        set_color(color);
        SDL_RenderFillRect(renderer, &rect);
    }

    void redraw() {
        SDL_RenderPresent(renderer);
    }
}

SDL_Color grey = {38, 50, 56};
SDL_Color white = {205, 211, 222};

class Font {
    SDL_Renderer* renderer;
    TTF_Font* font;
    int width, height;

    struct ColoredGlyph {
        char c;
        SDL_Color fg, bg;
    }

    SDL_Texture*[ColoredGlyph] glyph_cache;

    this(SDL_Renderer* renderer, string font_contents, int size) {
        this.renderer = renderer;

        SDL_RWops* rw = SDL_RWFromConstMem(cast(void*) font_contents.ptr,
                cast(int) font_contents.length);
        font = TTF_OpenFontRW(rw, 0, size);
        enforce(font);

        enforce(TTF_SizeText(font, " ", &width, &height) == 0);
    }

    SDL_Texture* render(char c, SDL_Color fg, SDL_Color bg) {
        ColoredGlyph colored_glyph = {c, fg, bg};
        if (colored_glyph in glyph_cache) {
            return glyph_cache[colored_glyph];
        }

        SDL_Surface* surface = TTF_RenderText_Shaded(font, toStringz([c]), fg, bg);
        enforce(surface);
        SDL_Texture* texture = SDL_CreateTextureFromSurface(renderer, surface);
        enforce(texture);
        SDL_FreeSurface(surface);

        glyph_cache[colored_glyph] = texture;

        return texture;
    }
}

enum EditMode {
    Insert,
    Normal
};

class BufferView {
    Buffer buffer;
    Font font;

    int rows;
    int columns;

    int scroll_line = 0;

    Cursor cursor;

    EditMode mode = EditMode.Normal;
    bool last_key_j = false;
    MonoTime j_time;

    bool last_key_space = false;

    this(Buffer buffer, Font font, int width, int height) {
        this.buffer = buffer;
        this.font = font;
        this.cursor = new Cursor(buffer);
        resize(width, height);
    }

    bool k_will_exit() {
        return last_key_j && (MonoTime.currTime - j_time) <= dur!"msecs"(200);
    }

    void resize(int width, int height) {
        rows = height / font.height;
        columns = width / font.width;
        /* scroll(); */
    }

    void draw_cursor(Window window) {
        int screen_x = cursor.pos.col;
        if (mode == EditMode.Insert && k_will_exit) {
            screen_x--;
        }
        int screen_y = cursor.pos.row - scroll_line;
        int pixel_x = screen_x * font.width;
        int pixel_y = screen_y * font.height;
        final switch (mode) {
        case EditMode.Normal:
            char c = cursor.index == -1 ? ' ' : buffer.get(cursor.index);
            auto text = font.render(c, grey, white);
            window.blit(text, pixel_x, pixel_y);
            break;
        case EditMode.Insert:
            window.rect(white, SDL_Rect(pixel_x, pixel_y,
                    font.width / 5, font.height));
            break;
        }
    }

    void render(Window window) {
        foreach (screen_y; 0 .. rows) {
            foreach (screen_x; 0 .. columns) {
                int buffer_col = screen_x;
                int buffer_row = scroll_line + screen_y;
                int i = buffer.index_of_pos(Pos(buffer_row, buffer_col));
                char c = i == -1 ? ' ' : buffer.get(i);
                auto text = font.render(c, white, grey);
                window.blit(text, screen_x * font.width, screen_y * font.height);
            }
        }

        draw_cursor(window);
    }

    /* void movehalfpage(int dir) { */
    /*     int amount = dir * rows / 2; */
    /*     scroll_line += amount; */
    /*     movey(amount); */
    /* } */

    /* const int scrolloff = 2; */
    /* void scroll() { */
    /*     if (cursor_line - scroll_line > rows - scrolloff) { */
    /*         scroll_line = cursor_line - rows + scrolloff; */
    /*     } */
    /*     if (cursor_line - scroll_line < scrolloff) { */
    /*         scroll_line = cursor_line - scrolloff; */
    /*     } */
    /*     if (scroll_line + rows > buffer.num_lines()) { */
    /*         scroll_line = buffer.num_lines() - rows; */
    /*     } */
    /*     if (scroll_line < 0) { */
    /*         scroll_line = 0; */
    /*     } */
    /* } */

    void insert_mode_key(char c) {
        if (c == 'k' && k_will_exit()) {
            mode = EditMode.Normal;
            cursor.del();
        } else {
            cursor.insert(c);
        }
        if (c == 'j') {
            last_key_j = true;
            j_time = MonoTime.currTime;
        } else {
            last_key_j = false;
        }

    }

    bool onshortcut(SDL_Keysym keysym) {
        switch (keysym.sym) {
        case SDLK_LEFT:
            cursor.move(Dir.Left);
            break;
        case SDLK_RIGHT:
            cursor.move(Dir.Right);
            break;
        case SDLK_UP:
            cursor.move(Dir.Up);
            break;
        case SDLK_DOWN:
            cursor.move(Dir.Down);
            break;
        default:
            break;
        }

        final switch (mode) {
        case EditMode.Insert:
            switch (keysym.sym) {
            case SDLK_BACKSPACE:
                cursor.del();
                break;
            case SDLK_ESCAPE:
                mode = EditMode.Normal;
                break;
            case SDLK_RETURN:
                cursor.insert('\n');
                break;
            default:
                break;
            }
            break;
        case EditMode.Normal:
            if (last_key_space) {
                last_key_space = false;
                switch (keysym.sym) {
                case SDLK_q:
                    if (!buffer.dirty) {
                        return true;
                    }
                    break;
                case SDLK_w:
                    buffer.save();
                    break;
                default:
                    break;
                }
            } else {
                last_key_space = false;
                switch (keysym.sym) {
                case SDLK_SPACE:
                    last_key_space = true;
                    break;
                case SDLK_f:
                    if (keysym.mod & KMOD_CTRL) {
                        /* movehalfpage(2); */
                    }
                    break;
                case SDLK_b:
                    if (keysym.mod & KMOD_CTRL) {
                        /* movehalfpage(-2); */
                    } else {
                        /* word(-1); */
                    }
                    break;
                case SDLK_d:
                    if (keysym.mod & KMOD_CTRL) {
                        /* movehalfpage(1); */
                    }
                    break;
                case SDLK_u:
                    if (keysym.mod & KMOD_CTRL) {
                        /* movehalfpage(-1); */
                    }
                    break;
                case SDLK_w:
                    /* word(1); */
                    break;
                default:
                    break;
                }
            }
        }

        return false;
    }

    void onkey(char c) {
        final switch (mode) {
        case EditMode.Insert:
            insert_mode_key(c);
            break;
        case EditMode.Normal:
            switch (c) {
            case 'h':
                cursor.move(Dir.Left);
                break;
            case 'j':
                cursor.move(Dir.Down);
                break;
            case 'k':
                cursor.move(Dir.Up);
                break;
            case 'l':
                cursor.move(Dir.Right);
                break;
            case 'i':
                mode = EditMode.Insert;
                break;
            default:
                break;
            }
        }

    }

}

void init_sdl() {
    // enforce(loadSDL() == sdlSupport);
    // enforce(loadSDLTTF() == sdlTTFSupport);

    enforce(SDL_Init(SDL_INIT_VIDEO) == 0);
    enforce(TTF_Init() == 0);
}

string pragmata_pro_regular = import("PragmataPro Mono Regular.ttf");

int main(string[] args) {
    if (args.length != 2) {
        writeln("usage: editor FILENAME");
        return 1;
    }

    init_sdl();
    Window window = new Window();
    Buffer buffer = Buffer.of_string(args[1]);
    Font font = new Font(window.renderer, pragmata_pro_regular, 16);
    BufferView buffer_view = new BufferView(buffer, font, window.width, window.height);

    SDL_StartTextInput();
    bool running = true;
    while (running) {
        SDL_Event event;
        while (SDL_PollEvent(&event)) {
            switch (event.type) {
            case SDL_QUIT:
                running = false;
                break;
            case SDL_WINDOWEVENT:
                switch (event.window.event) {
                case SDL_WINDOWEVENT_RESIZED:
                    int w = event.window.data1;
                    int h = event.window.data2;
                    window.resize(w, h);
                    buffer_view.resize(w, h);
                    break;
                default:
                    break;
                }
                break;
            case SDL_KEYDOWN:
                bool exit = buffer_view.onshortcut(event.key.keysym);
                if (exit) {
                    running = false;
                }
                break;

            case SDL_TEXTINPUT:
                foreach (char c; fromStringz(event.text.text.ptr)) {
                    buffer_view.onkey(c);
                }
                break;
            default:
                break;
            }

        }
        window.clear(grey);
        buffer_view.render(window);

        window.redraw();
    }
    return 0;
}
