#include "../System/Thread.h"

extern int main(int argc, char* argv[]);

void __entry(int argc, char* argv[]) {
    Exit(main(argc,argv));
}