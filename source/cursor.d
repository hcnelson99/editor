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

    void move(Dir dir, int count, bool allow_movement_to_end_of_line) {
        assert(count >= 1);
        final switch (dir) {
        case Dir.Left:
        case Dir.Right:
            movex(dir, count, allow_movement_to_end_of_line);
            break;
        case Dir.Up:
        case Dir.Down:
            movey(dir, count);
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

    void movex(Dir dir, int count, bool allow_movement_to_end_of_line) {
        Pos prev_pos = pos;

        switch (dir) {
        case Dir.Left:
            pos.col -= count;
            if (pos.col < 0) {
                pos.col = 0;
            }
            break;
        case Dir.Right:
            int adjust = allow_movement_to_end_of_line ? 0 : 1;
            pos.col += count;
            int line_length = buffer.line_length(pos.row);
            if (pos.col >= line_length - adjust) {
                pos.col = line_length - adjust;
            }
            break;
        default:
            assert(false);
        }
        if (pos != prev_pos) {
            want_column = pos.col;
        }
    }

    void movey(Dir dir, int count) {
        switch (dir) {
        case Dir.Up:
            pos.row -= count;
            if (pos.row < 0) {
                pos.row = 0;
            }
            break;
        case Dir.Down:
            pos.row += count;
            int num_lines = buffer.num_lines();
            if (pos.row >= num_lines - 1) {
                pos.row = num_lines - 1;
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
