import std.stdio;
import std.algorithm : map;
import std.array;
import std.exception : enforce;
import std.file;
import std.typecons;
static import std.string;
static import core.exception;

class Buffer {
    static Buffer of_file(string filename) {
        Buffer buffer = new Buffer();
        buffer.filename = filename;
        buffer.contents = readText(filename);
        return buffer;
    }

    static Buffer of_string(string contents) {
        Buffer buffer = new Buffer();
        buffer.filename = null;
        buffer.contents = contents;
        return buffer;
    }

    char get(int i) {
        return contents[i];
    }

    void insert(char c, int i) {
        string s = [c];
        contents = contents[0 .. i] ~ s ~ contents[i .. $];
    }

    void del(int i) {
        contents = contents[0 .. i - 1] ~ contents[i .. $];
    }

    void save() {
        toFile(contents, filename.get);
    }

    ulong length() {
        return contents.length;
    }

    int index_of_pos(int row, int col) {
        int r = 0;
        int c = 0;
        for (int i = 0; i < length() && r <= row; i++) {
            if (row == r && col == c) {
                return i;
            }
            if (get(i) == '\n') {
                r++;
                c = 0;
            } else {
                c++;
            }
        }
        return -1;
    }

    int num_lines() {
        int lines = 1;
        for (int i = 0; i < length(); i++) {
            if (get(i) == '\n') {
                lines += 1;
            }
        }
        return lines;
    }

    int line_length(int row) {
        int start = index_of_pos(row, 0);
        assert(start != -1);
        for (int i = start; i < length(); i++) {
            if (get(i) == '\n') {
                return i - start;
            }
        }
        return cast(int) length() - start;

    }

private:
    string contents;
    Nullable!string filename;
}

void assertEqual(T)(T value, T expected) {
    if (value != expected) {
        string error = std.string.format("expected %s, got %s", expected, value);
        throw new core.exception.AssertError(error);
    }
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
    assertEqual(b.index_of_pos(0, 1), 1);
}
