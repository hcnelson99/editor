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
        switch (dir) {
        case Dir.Left:
        case Dir.Right:
            movex(dir);
            break;
        default:
            assert(false);
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

}
