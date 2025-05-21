int main() {
    int a, b, c;
    a = 5;
    b = 10;
    c = a + b * 2;
    if (a < b) {
        c = c + 1;
    } else {
        c = c - 1;
    }
    while (c < 20) {
        c = c + 2;
    }
    return c;
}
