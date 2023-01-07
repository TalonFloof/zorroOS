# Filesystem Server

The zorroOS filesystem server uses a modified version of the 9p2000 protocol optimized for the Owl Kernel's IPC mechanisms.
The protocol for zorroOS is known as 9p2000.z. It's basically 9p2000 but with 64-bit nanosecond precision timestamps (to prevent the Y2K38 bug from occurring in zorroOS).
However, since zorroOS used 9p as its file protocol, zorroOS makes no distinction between local and remote filesystem instances.
zorroOS communicates with them the exact same way.