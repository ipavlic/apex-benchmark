# Harness - Micro-benchmarking for Salesforce Apex

A lightweight micro-benchmarking framework for measuring Apex code performance in Salesforce.

**Architecture:**
- `Benchmark` - Abstract base class you extend to define benchmarks
- `Harness` - Runner that executes benchmarks and collects metrics

## Features

- **Time tracking** - Wall time and CPU time with min/max/average (always tracked)
- **Heap tracking** - Memory consumption per iteration (opt-in via `trackHeap()`)
- **Database tracking** - DML/SOQL operations with per-iteration min/max (opt-in via `trackDB()`)
- **Warmup iterations** - Avoid JIT cold-start effects
- **Comparison mode** - Compare multiple benchmarks with relative performance ratios
- **Builder pattern** - Fluent API for configuring benchmark suites

## Installation

Deploy both classes to your Salesforce org:

```bash
sfdx force:source:deploy -p force-app/main/default/classes/
```

**Files:**
- `Benchmark.cls` - Abstract base class
- `Harness.cls` - Execution harness

## Quick Start

### 1. Run Your First Benchmark

```apex
public class StringConcatTest extends Benchmark {
    public override void run() {
        String result = 'Hello' + ' ' + 'World';
    }
}

Harness.Result result = Harness.run('String Concat', new StringConcatTest());
System.debug(result);
```

### 2. Compare Multiple Approaches

```apex
public class PlusOperator extends Benchmark {
    public override void run() {
        String s = 'a' + 'b' + 'c';
    }
}

public class FormatMethod extends Benchmark {
    public override void run() {
        String s = String.format('{0}{1}{2}', new List<String>{'a', 'b', 'c'});
    }
}

new Harness.Suite()
    .add('Plus', new PlusOperator())
    .add('Format', new FormatMethod())
    .warmup(50)
    .iterations(200)
    .runAndCompare();
```

**Output:**
```
=== Benchmark Results (sorted by CPU time) ===
1. Plus | wall: 0.250 ms | cpu: 0.180 ms | min/max wall: 0.200/0.300 ms | min/max cpu: 0.170/0.190 ms
2. Format | wall: 0.420 ms | cpu: 0.350 ms | min/max wall: 0.380/0.480 ms | min/max cpu: 0.340/0.360 ms (1.94x)
```

**Key metrics:**
- **cpu** - CPU time (most stable, use for comparisons)
- **wall** - Real-world time (varies with platform load)
- **min/max** - Range of measurements
- **(1.94x)** - Relative slowness compared to fastest

## When to Use run() vs Suite

### Use `Harness.run()` when:
- Running a single benchmark
- Each benchmark needs different configuration (different warmup/iterations)

```apex
// Different configs per benchmark
Harness.Result r1 = Harness.run('Fast op', new FastOp(), 100, 1000);
Harness.Result r2 = Harness.run('DB op', new DBOp(), 10, 50, Harness.TRACK_DB);
```

### Use `Harness.Suite` when:
- Comparing multiple benchmarks (most common)
- Ensures fair comparison (same config for all)

```apex
// Same config for all = fair comparison
new Harness.Suite()
    .add('Method A', new MethodA())
    .add('Method B', new MethodB())
    .warmup(50)
    .iterations(200)
    .runAndCompare();
```

**Recommendation:** Use **Suite** for comparisons. It's simpler and ensures fairness.

## API Reference

### Benchmark Abstract Class

```apex
public abstract class Benchmark {
    public virtual void setup() {}     // Called once before iterations (optional)
    public abstract void run();        // Called per iteration (required)
    public virtual void teardown() {}  // Called once after iterations (optional)
}
```

**Example with setup/teardown:**
```apex
public class ListBenchmark extends Benchmark {
    private List<Integer> data;

    public override void setup() {
        data = new List<Integer>();
        for (Integer i = 0; i < 100; i++) {
            data.add(i);
        }
    }

    public override void run() {
        List<Integer> copy = data.clone();
    }

    public override void teardown() {
        data.clear();
    }
}
```

### Harness.run()

```apex
// With defaults (10 warmup, 100 iterations, time-only tracking)
Harness.Result run(String name, Benchmark bench)

// Custom warmup and iterations
Harness.Result run(String name, Benchmark bench, Integer warmup, Integer iterations)

// With tracking flags
Harness.Result run(String name, Benchmark bench, Integer warmup, Integer iterations, Integer flags)
```

**Tracking flags:**
```apex
Harness.TRACK_HEAP  // Track heap usage (1)
Harness.TRACK_DB    // Track DML/SOQL (2)
Harness.TRACK_ALL   // Track both (3)
```

**Default:** Only time metrics are tracked (`flags = 0`). Use flags to opt-in to heap/DB tracking.

**Examples:**
```apex
// Default: time only (fastest)
Harness.run('Test', new MyBench(), 10, 100, 0);

// Track heap
Harness.run('Test', new MyBench(), 10, 100, Harness.TRACK_HEAP);

// Track DB operations
Harness.run('Test', new MyBench(), 10, 100, Harness.TRACK_DB);

// Track everything
Harness.run('Test', new MyBench(), 10, 100, Harness.TRACK_ALL);
```

### Harness.Suite

Builder for running multiple benchmarks:

```apex
Suite add(String name, Benchmark bench)  // Add benchmark
Suite warmup(Integer count)              // Set warmup iterations (default: 10)
Suite iterations(Integer count)          // Set measurement iterations (default: 100)
Suite trackHeap()                        // Enable heap tracking
Suite trackDB()                          // Enable DB tracking
List<Result> runAll()                    // Run all, return results
List<Result> runAndCompare()             // Run all, display comparison
```

**Examples:**

```apex
// Default: time only
new Harness.Suite()
    .add('Method A', new MethodA())
    .add('Method B', new MethodB())
    .warmup(50)
    .iterations(200)
    .runAndCompare();

// With heap tracking
new Harness.Suite()
    .add('Method A', new MethodA())
    .add('Method B', new MethodB())
    .trackHeap()
    .runAndCompare();

// With both heap and DB tracking
new Harness.Suite()
    .add('Method A', new MethodA())
    .add('Method B', new MethodB())
    .trackHeap()
    .trackDB()
    .runAndCompare();
```

### Harness.Result

```apex
public class Result {
    public String name;
    public Decimal avgWallMs;        // Average wall time (always tracked)
    public Decimal avgCpuMs;         // Average CPU time (always tracked)
    public Decimal minWallMs;        // Min wall time (always tracked)
    public Decimal maxWallMs;        // Max wall time (always tracked)
    public Decimal minCpuMs;         // Min CPU time (always tracked)
    public Decimal maxCpuMs;         // Max CPU time (always tracked)
    public Decimal avgHeapKb;        // Average heap (TRACK_HEAP)
    public Decimal minHeapKb;        // Min heap (TRACK_HEAP)
    public Decimal maxHeapKb;        // Max heap (TRACK_HEAP)
    public Integer iterations;       // Number of iterations
    public Integer dmlStatements;    // Total DML (TRACK_DB)
    public Integer soqlQueries;      // Total SOQL (TRACK_DB)
    public Integer minDmlStatements; // Min DML per iteration (TRACK_DB)
    public Integer maxDmlStatements; // Max DML per iteration (TRACK_DB)
    public Integer minSoqlQueries;   // Min SOQL per iteration (TRACK_DB)
    public Integer maxSoqlQueries;   // Max SOQL per iteration (TRACK_DB)

    public String toString();        // One-line output with all metrics
}
```

### Harness.compare()

```apex
Harness.compare(List<Result> results)  // Display sorted comparison
```

## Best Practices

### Use CPU Time for Comparisons
CPU time is more stable than wall time. Focus on `avgCpuMs` when comparing.

### Use Adequate Warmup
Apex JIT compiles code on first execution. Use 50-100 warmup iterations for stable results.

### Run Enough Iterations
More iterations = more accurate averages. Use 100-1000 for fast operations, 10-50 for DB operations.

### Isolate What You're Measuring
Only include code to measure in `run()`. Put setup in `setup()`, cleanup in `teardown()`.

### Compare Fairly
Ensure benchmarks do equivalent work when comparing.

### Watch Governor Limits
Benchmarks consume CPU time and heap. Check `Limits.getCpuTime()` before running large suites.

### Track Only What You Need
Default (time-only) is fastest. Only enable heap/DB tracking when needed.

## Examples

### Database Operations

```apex
public class SOQLBenchmark extends Benchmark {
    public override void run() {
        List<Account> accts = [SELECT Id, Name FROM Account LIMIT 10];
    }
}

// Use fewer iterations and enable DB tracking
Harness.Result result = Harness.run('SOQL Query', new SOQLBenchmark(), 5, 20, Harness.TRACK_DB);
System.debug('SOQL Queries: ' + result.soqlQueries);
```

### Custom Result Processing

```apex
List<Harness.Result> results = new Harness.Suite()
    .add('Method 1', new Method1())
    .add('Method 2', new Method2())
    .runAll();

for (Harness.Result r : results) {
    if (r.avgCpuMs > 5.0) {
        System.debug('SLOW: ' + r.toString());
    }
}
```

## Limitations

- **Governor limits apply** - 10,000ms CPU synchronous / 60,000ms asynchronous
- **Single transaction** - All benchmarks run in one transaction
- **No multi-threading** - Apex is single-threaded
- **Measurement overhead** - Tracking consumes resources (use flags to minimize)

## Tips

- Use **CPU time** for comparisons (more stable than wall time)
- Run in **consistent environment** (sandbox performance varies)
- **Repeat experiments** to verify consistency
- **Clear debug logs** before benchmarking (logging has overhead)
- **Minimize System.debug()** in benchmark code

## Testing

The framework includes comprehensive unit tests with 100% code coverage:

- **BenchmarkTest.cls** - Tests for the Benchmark abstract class
- **HarnessTest.cls** - Tests for the Harness execution engine

### Testability

Harness uses a dependency injection pattern for system calls:

```apex
@TestVisible
private static SystemProvider systemProvider = new SystemProvider();
```

In tests, replace `systemProvider` with a mock to control time/limit values:

```apex
// Mock that returns controlled values
private class MockSystemProvider extends Harness.SystemProvider {
    public override Long getCurrentTimeMillis() {
        return 1000; // Controlled value
    }
    // ... other methods
}

// Use in tests
Harness.systemProvider = new MockSystemProvider();
```

This allows testing without relying on actual system timing or governor limits.

## License

MIT License - Use freely in your projects.

---

**Happy benchmarking!**
