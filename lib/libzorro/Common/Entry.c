#include "../System/Thread.h"

extern int main();

void __entry() {
    Exit(main());
}