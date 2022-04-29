import std.stdio;
import buffer;
import asserts;

enum Dir {
    Left,
    Right,
    Up,
    Down
}

class Cursor {
    Buffer buffer;

    Pos pos;

    this(Buffer buffer) {
        this.buffer = buffer;
    }

    void insert(char c) {
        int index = buffer.index_of_pos(pos);
        buffer.insert(c, index);
        index++;
        pos = buffer.pos_of_index(index);
        want_column = pos.col;
    }

    void del() {
        int index = buffer.index_of_pos(pos);
        buffer.del(index);
        index -= 1;
        if (index < 0) {
            index = 0;
        }
        pos = buffer.pos_of_index(index);
        want_column = pos.col;
    }

    void move(Dir dir, bool allow_movement_to_end_of_line) {
        final switch (dir) {
        case Dir.Left:
        case Dir.Right:
            movex(dir, allow_movement_to_end_of_line);
            break;
        case Dir.Up:
        case Dir.Down:
            movey(dir);
        }
    }

    void keep_within_line() {
        if (pos.col >= buffer.line_length(pos.row)) {
            pos.col = buffer.line_length(pos.row) - 1;
            want_column = pos.col;
        }

    }

private:
    int want_column;

    void movex(Dir dir, bool allow_movement_to_end_of_line) {
        bool moved = false;
        switch (dir) {
        case Dir.Left:
            if (pos.col > 0) {
                pos.col--;
                moved = true;
            }
            break;
        case Dir.Right:
            int adjust = allow_movement_to_end_of_line ? 0 : 1;
            if (pos.col < buffer.line_length(pos.row) - adjust) {
                pos.col++;
                moved = true;
            }
            break;
        default:
            assert(false);
        }
        if (moved) {
            want_column = pos.col;
        }
    }

    void movey(Dir dir) {
        switch (dir) {
        case Dir.Up:
            if (pos.row > 0) {
                pos.row--;
            }
            break;
        case Dir.Down:
            if (pos.row < buffer.num_lines() - 1) {
                pos.row++;
            }
            break;
        default:
            assert(false);
        }

        pos.col = want_column;
        if (pos.col > buffer.line_length(pos.row) - 1) {
            pos.col = buffer.line_length(pos.row) - 1;
        }
        if (pos.col <= 0) {
            pos.col = 0;
        }
    }

}
