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
    }

    void del() {
        int index = buffer.index_of_pos(pos);
        buffer.del(index);
        move(Dir.Left);
    }

    void move(Dir dir) {
        final switch (dir) {
        case Dir.Left:
        case Dir.Right:
            movex(dir);
            break;
        case Dir.Up:
        case Dir.Down:
            movey(dir);
        }
    }

private:
    int want_column;

    void movex(Dir dir) {
        switch (dir) {
        case Dir.Left:
            if (pos.col > 0) {
                pos.col--;
            }
            break;
        case Dir.Right:
            if (pos.col < buffer.line_length(pos.row) - 1) {
                pos.col++;
            }
            break;
        default:
            assert(false);
        }
        want_column = pos.col;
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
        if (pos.col <= 0) {
            pos.col = 0;
        }
        if (pos.col > buffer.line_length(pos.row) - 1) {
            pos.col = buffer.line_length(pos.row) - 1;
        }
    }

}
