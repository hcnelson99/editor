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
    int index;

    this(Buffer buffer) {
        this.buffer = buffer;
    }

    void insert(char c) {
        buffer.insert(c, index);
        index += 1;
        pos = buffer.pos_of_index(index);
    }

    void del() {
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

    invariant () {
        assertEqual(buffer.index_of_pos(pos), index);
        assert(0 <= index && index <= buffer.length());
    }

private:
    int want_column;

    void movex(Dir dir) {
        switch (dir) {
        case Dir.Left:
            if (pos.col > 0) {
                pos.col--;
                index--;
            }
            break;
        case Dir.Right:
            if (pos.col < buffer.line_length(pos.row) - 1) {
                pos.col++;
                index++;
            }
            break;
        default:
            assert(false);
        }
        want_column = pos.col;
    }

}
