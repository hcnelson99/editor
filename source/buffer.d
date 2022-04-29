import std.stdio;
import std.algorithm : map;
import std.array;
import std.exception : enforce;
import std.file;
import std.typecons;
import asserts;

struct Pos {
    int row, col;
}

class Buffer {
    bool dirty = false;

    static Buffer of_file(string filename) {
        Buffer buffer = new Buffer();
        buffer.filename = filename;
        buffer.contents = readText(filename);
        buffer.recompute_newlines();
        return buffer;
    }

    static Buffer of_string(string contents) {
        Buffer buffer = new Buffer();
        buffer.filename = null;
        buffer.contents = contents;
        buffer.recompute_newlines();
        return buffer;
    }

    char get(int i) const {
        return contents[i];
    }

    void insert(char c, int i) {
        assert(0 <= i && i <= length());
        dirty = true;
        string s = [c];
        contents = contents[0 .. i] ~ s ~ contents[i .. $];
        recompute_newlines();
    }

    void del(int i) {
        assert(0 < i && i <= length());
        dirty = true;
        contents = contents[0 .. i - 1] ~ contents[i .. $];
        recompute_newlines();
    }

    void save() {
        dirty = false;
        toFile(contents, filename.get);
    }

    ulong length() const {
        return contents.length;
    }

    int index_of_pos(Pos pos) const {
        if (pos.row < 0 || pos.row >= num_lines()) {
            return -1;
        }

        ulong i = get_beginning_of_line(pos.row);
        ulong j = get_beginning_of_line(pos.row + 1);

        if (i + pos.col >= j) {
            return -1;
        }

        return cast(int)(i + pos.col);
    }

    Pos pos_of_index(int target) const {
        assert(0 <= target && target <= length());
        Pos p = Pos(0, 0);
        for (int i = 0; i < target; i++) {
            if (get(i) == '\n') {
                p.row++;
                p.col = 0;
            } else {
                p.col++;
            }
        }
        return p;
    }

    int num_lines() const {
        return cast(int)(newlines.length + 1);
    }

    int line_length(int row) {
        return get_beginning_of_line(row + 1) - get_beginning_of_line(row) - 1;
    }

private:
    int get_beginning_of_line(int row) const {
        assert(0 <= row && row <= num_lines());
        if (row == 0) {
            return 0;
        }
        if (row - 1 == newlines.length) {
            return cast(int)(contents.length) + 1;
        }
        return newlines[row - 1] + 1;
    }

    string contents;
    int[] newlines;

    void recompute_newlines() {
        newlines = [];
        foreach (i; 0 .. contents.length) {
            if (contents[i] == '\n') {
                newlines ~= cast(int)(i);
            }
        }
    }

    Nullable!string filename;
}

unittest {
    Buffer b = Buffer.of_string("abc");
    assertEqual(b.get(1), 'b');
    assertEqual(b.num_lines(), 1);
    assertEqual(b.line_length(0), 3);

    b.insert('\n', 0);
    assertEqual(b.get(1), 'a');
    assertEqual(b.num_lines(), 2);
    assertEqual(b.line_length(0), 0);
    assertEqual(b.line_length(1), 3);
    b.insert('a', 0);
    assertEqual(b.index_of_pos(Pos(0, 1)), 1);
    assertEqual(b.pos_of_index(1), Pos(0, 1));
    assertEqual(b.pos_of_index(2), Pos(1, 0));
}

unittest {
    Buffer b = Buffer.of_string("abc");
    b.insert('d', 3);
    assertEqual(b.get(3), 'd');
}

unittest {
    Buffer b = Buffer.of_string("abc");
    assertEqual(b.pos_of_index(3), Pos(0, 3));
    assertEqual(b.index_of_pos(Pos(0, 3)), 3);

    b = Buffer.of_string("abc\n123");
    // actually is this correct?
    assertEqual(b.pos_of_index(3), Pos(0, 3));
    assertEqual(b.index_of_pos(Pos(0, 3)), 3);
}
