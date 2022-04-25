import std.string;
import core.exception;

void assertEqual(T)(T value, T expected) {
    if (value != expected) {
        string error = .format("expected %s, got %s", expected, value);
        throw new AssertError(error);
    }
}
