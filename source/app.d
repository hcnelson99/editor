import std.stdio;
import std.array;
import std.algorithm;
import std.exception : enforce;
import std.typecons : Nullable, nullable;
import std.string;
import bindbc.sdl;
import bindbc.sdl.ttf;

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

    void clear(SDL_Color color) {
        SDL_SetRenderDrawColor(renderer, color.r, color.g, color.b, 255);
        SDL_RenderClear(renderer);
    }

    void blit(SDL_Texture* texture, int x, int y) {
        int w, h;
        SDL_QueryTexture(texture, null, null, &w, &h);
        SDL_Rect dst = SDL_Rect(x, y, w, h);
        enforce(SDL_RenderCopy(renderer, texture, null, &dst) == 0);
    }

    void redraw() {
        SDL_RenderPresent(renderer);
    }
}

class Buffer {
    string[] lines;

    this(string filename) {
        auto file = File(filename);
        lines = file.byLine().map!(x => x.idup).array;
    }

    Nullable!(char) get(int x, int y) {
        Nullable!char result;

        enforce(x >= 0 && y >= 0);
        if (y >= lines.length) {
            return result;
        }

        string line = lines[y];
        if (x >= line.length) {
            return result;
        }
        result = line[x];
        return result;
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

    this(SDL_Renderer* renderer, string font_path, int size) {
        this.renderer = renderer;
        font = TTF_OpenFont(toStringz(font_path), size);
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

class BufferView {
    Buffer buffer;
    int scroll_line;

    int cursor_line;
    int cursor_column;

    this(Buffer buffer) {
        this.buffer = buffer;
        scroll_line = 0;
        cursor_line = 0;
        cursor_column = 0;
    }

    void render(Window window, Font font) {
        int display_rows = window.height / font.height + 1;
        int display_columns = window.width / font.width + 1;

        foreach (y; 0 .. display_rows) {
            foreach (x; 0 .. display_columns) {
                Nullable!char c = buffer.get(x, y);

                bool is_cursor = x == cursor_column && y == cursor_line;

                if (c.isNull && is_cursor) {
                    auto text = font.render(' ', grey, white);
                    window.blit(text, x * font.width, y * font.height);
                } else if (!c.isNull) {
                    SDL_Color fg, bg;
                    if (is_cursor) {
                        fg = grey;
                        bg = white;
                    } else {
                        fg = white;
                        bg = grey;
                    }
                    auto text = font.render(c.get, fg, bg);
                    window.blit(text, x * font.width, y * font.height);
                }
            }
        }
    }

    void move(int dx, int dy) {
        cursor_line += dy;
        cursor_column += dx;
    }

}

void init_sdl() {
    enforce(loadSDL() == sdlSupport);
    enforce(loadSDLTTF() == sdlTTFSupport);

    enforce(SDL_Init(SDL_INIT_VIDEO) == 0);
    enforce(TTF_Init() == 0);

}

void main() {
    init_sdl();

    Window window = new Window();
    Buffer buffer = new Buffer("source/app.d");
    BufferView buffer_view = new BufferView(buffer);
    Font font = new Font(window.renderer, "fonts/PragmataPro Mono Regular.ttf", 24);
    window.clear(grey);

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
                    window.resize(event.window.data1, event.window.data2);
                    break;

                default:
                    break;
                }
                break;

            case SDL_KEYDOWN:
                switch (event.key.keysym.sym) {
                case SDLK_h:
                    buffer_view.move(-1, 0);
                    break;
                case SDLK_j:
                    buffer_view.move(0, 1);
                    break;
                case SDLK_k:
                    buffer_view.move(0, -1);
                    break;
                case SDLK_l:
                    buffer_view.move(1, 0);
                    break;
                default:
                    break;
                }
                break;

            default:
                break;
            }

        }
        window.clear(grey);

        buffer_view.render(window, font);

        window.redraw();
    }
}
