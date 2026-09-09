# libmempressure

`libmempressure` is the M3 building block of kutu OS: a small C library
that turns the kernel's
[Pressure Stall Information](https://docs.kernel.org/admin-guide/perf/psi.html)
into application-level memory-pressure events — a Linux answer to
Android's `onTrimMemory()`. Instead of being killed by the OOM killer
(or userspace oomd), your application learns that memory is getting tight
and sheds caches gracefully.

Source of truth: [kutuso/libmempressure](https://github.com/kutuso/libmempressure).

```
level       some avg10   what your app should do
----------- ------------ ------------------------------------
none        < 5%         business as usual
low         >= 5%        stop prefetching, trim opportunistically
moderate    >= 15%       drop object caches, shrink pools
critical    >= 40%       shed everything, survive
```

Events fire on level *changes* only, filtered by hysteresis (consecutive
readings), so callbacks don't flap. A monitor thread reads
`/proc/pressure/memory` (configurable) and dispatches to subscribers.

## Tour of the bindings

**C** (`include/mempressure.h`):

```c
static void on_pressure(mp_level_t level, void *ud) {
    if (level >= MP_LEVEL_MODERATE) cache_drop_all();
}
mp_init(NULL);                    /* defaults; zero fields fall back too */
mp_subscribe(on_pressure, my_app);
/* ... */
mp_shutdown();
```

**C++** (header-only RAII, `bindings/c++/mempressure.hpp`):

```cpp
mp::Monitor monitor;
monitor.subscribe([](mp::Level level) {
    if (level >= mp::Level::Moderate) cache.drop_all();
});
```

**JVM** (`bindings/jvm/`, `libmempressure_jni.so`):

```java
MemPressure.start(new MemPressure.Config());
int h = MemPressure.subscribe(level -> {
    if (level >= 2) cache.dropAll();      // 0 none 1 low 2 moderate 3 critical
});
```

**Python** (CPython extension):

```python
import mempressure as mp
mp.start()
mp.subscribe(lambda level: level >= 2 and cache.drop_all())
mp.psi()      # {'some_avg10': 0.12, ...}
```

## Configuration

`mp_config_t` (or the per-binding equivalents) tunes:

| Field | Default | Meaning |
|---|---|---|
| `low/moderate/critical_threshold` | 5 / 15 / 40 | "some avg10" percentages that select the level |
| `poll_interval_sec` | 0.5 | monitor tick |
| `hysteresis` | 2 | consecutive readings before a change fires |
| `psi_path` | `/proc/pressure/memory` | PSI source (fixtures in tests) |

Zero/absent fields fall back to defaults, so partial configs just work.

## Contract details worth knowing

- Callbacks run on the monitor thread: keep them fast, make them
  thread-safe, and never call `mp_shutdown` from one (subscribing and
  unsubscribing *are* safe from callbacks).
- The C library is process-global: one monitor, many subscribers. The C++
  `Monitor` refcounts this for you.
- Threading rules, error codes and the exact level semantics are documented
  in the [public header](https://github.com/kutuso/libmempressure/blob/master/include/mempressure.h).

## Building and testing

```sh
git clone https://github.com/kutuso/libmempressure
cd libmempressure
make test     # cmake build + ctest (C core, C++ binding, JVM binding)
              # + python binding tests
```

CI additionally runs everything under gcc and clang, and the native suites
under AddressSanitizer + UndefinedBehaviorSanitizer. The test suites drive
the monitor from fixture files (`psi_path`), so they never need real
memory pressure — the example binary runs against your real
`/proc/pressure/memory`.

## Relationship to kutu OS

On kutu OS the kernel side of this contract is already guaranteed:
`kutu-check-kernel` (and `kutu-doctor check`) assert PSI is present on
every supported kernel. The M3 `mempressured` policy daemon will be built
on this library, and applications shipped by kutu (and anything else) can
link it — it has no dependencies beyond libc/pthreads, so it can be
vendored into any package (`pkg-config mempressure` once installed).
