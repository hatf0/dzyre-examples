import std.stdio;
import zyre.node;
import zyre.logger;
import core.thread, core.time;

__gshared bool run = true;
void runListener() {
    // Since we don't use the regular allocator for this object,
    // we'll need to be sure to dispose it manually. Tedious, yes,
    // but it removes a lot of room for error.
    ZyreNode ourNode = ZyreNode.withUUID();  
    // When we exit this scope (the main thread), make sure we dispose of our object.
    scope(exit) theAllocator.dispose(ourNode);

    // Start it (so we can broadcast)
    ourNode.start();
    ourNode.joinGroup("GLOBAL");
    // Wait for all nodes to connect (and for us to join)
    Thread.sleep(100.msecs);

    while (run) {
        try { 
            auto evt = ourNode.recvEvent();
            scope(exit) theAllocator.dispose(evt);
            import zyre.event : EventType;
            DEBUG!"got event (type: %s, node id: %s)"(evt.type, ourNode.name);
            if (evt.type == EventType.ENTER) {
                INFO!"[%s] node entered [%s]"(ourNode.name, evt.peerName);
                ourNode.whisper(evt.peerId, "Hello");
            } else if (evt.type == EventType.EXIT) {
                INFO!"[%s] node exited [%s]"(ourNode.name, evt.peerName);
            } else if (evt.type == EventType.WHISPER) {
                INFO!"[%s] received ping (WHISPER) [%s]"(ourNode.name, evt.peerName);
                ourNode.shout("GLOBAL", "Hello");
            } else if (evt.type == EventType.SHOUT) {
                INFO!"[%s] received ping (SHOUT) [%s]"(ourNode.name, evt.peerName);
            } else if (evt.type == EventType.INVALID) {
                ERROR!"hit invalid event?";
                evt.print();
            }
        } catch(Exception e) {
            DEBUG!"caught exception (%s)"(e.msg);
        }
    }
}

import std.parallelism;
void main()
{
    debug _zyreLogger.minVerbosity = Verbosity.Debug;
    enum instances = 10;
    TaskPool t = new TaskPool(instances);
    t.isDaemon = false;
    for (int i = 0; i < instances; i++) {
        t.put(task!runListener());
    }

    stdin.readln();
    run = false;
    t.finish(true);
}
