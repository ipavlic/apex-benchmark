/**
 * Harness - A micro-benchmarking tool for Salesforce Apex
 *
 * Usage:
 *   Harness.Result result = Harness.run('My Benchmark', new MyBenchmark(), 100, 1000);
 *   System.debug(result);
 *
 * Or use the builder for more control:
 *   Harness.Suite suite = new Harness.Suite()
 *       .add('Test 1', new Benchmark1())
 *       .add('Test 2', new Benchmark2())
 *       .warmup(50)
 *       .iterations(500);
 *
 *   List<Harness.Result> results = suite.runAll();
 *   Harness.compare(results);
 */
public class Harness {

    // Tracking flags (can be combined with | operator)
    public static final Integer TRACK_HEAP = 1;  // Track heap usage per iteration
    public static final Integer TRACK_DB = 2;    // Track DML/SOQL operations
    public static final Integer TRACK_ALL = TRACK_HEAP | TRACK_DB;  // Track everything

    // Default configuration
    private static final Integer DEFAULT_WARMUP = 10;
    private static final Integer DEFAULT_ITERATIONS = 100;
    private static final Integer DEFAULT_FLAGS = 0;  // By default, only track time metrics

    // System provider for dependency injection (testable)
    @TestVisible
    private static SystemProvider systemProvider = new SystemProvider();

    /**
     * Provider for system-level operations (time, limits)
     * Can be mocked in tests by replacing systemProvider instance
     */
    public virtual class SystemProvider {
        public virtual Long getCurrentTimeMillis() {
            return System.now().getTime();
        }

        public virtual Integer getCpuTime() {
            return Limits.getCpuTime();
        }

        public virtual Integer getHeapSize() {
            return Limits.getHeapSize();
        }

        public virtual Integer getDmlStatements() {
            return Limits.getDmlStatements();
        }

        public virtual Integer getQueries() {
            return Limits.getQueries();
        }
    }

    /**
     * Result of a benchmark run with detailed statistics
     */
    public class Result {
        public String name;
        public Decimal avgWallMs;
        public Decimal avgCpuMs;
        public Decimal avgHeapKb;
        public Decimal minWallMs;
        public Decimal maxWallMs;
        public Decimal minCpuMs;
        public Decimal maxCpuMs;
        public Decimal minHeapKb;
        public Decimal maxHeapKb;
        public Integer iterations;
        public Integer dmlStatements;
        public Integer soqlQueries;
        public Integer minDmlStatements;
        public Integer maxDmlStatements;
        public Integer minSoqlQueries;
        public Integer maxSoqlQueries;

        public Result(String name, Decimal wall, Decimal cpu) {
            this.name = name;
            this.avgWallMs = wall;
            this.avgCpuMs = cpu;
        }

        public override String toString() {
            String base = name + ' | wall: ' + avgWallMs.setScale(3) + ' ms | cpu: ' + avgCpuMs.setScale(3) + ' ms';
            base += ' | min/max wall: ' + minWallMs.setScale(3) + '/' + maxWallMs.setScale(3) + ' ms';
            base += ' | min/max cpu: ' + minCpuMs.setScale(3) + '/' + maxCpuMs.setScale(3) + ' ms';
            if (avgHeapKb != null) {
                base += ' | heap: ' + avgHeapKb.setScale(2) + ' KB';
                if (minHeapKb != null) {
                    base += ' (min/max: ' + minHeapKb.setScale(2) + '/' + maxHeapKb.setScale(2) + ')';
                }
            }
            if (dmlStatements != null && dmlStatements > 0) {
                base += ' | DML: ' + dmlStatements;
                if (minDmlStatements != null) {
                    base += ' (min/max: ' + minDmlStatements + '/' + maxDmlStatements + ')';
                }
            }
            if (soqlQueries != null && soqlQueries > 0) {
                base += ' | SOQL: ' + soqlQueries;
                if (minSoqlQueries != null) {
                    base += ' (min/max: ' + minSoqlQueries + '/' + maxSoqlQueries + ')';
                }
            }
            return base;
        }

    }

    /**
     * Run a single benchmark with custom warmup and iteration counts
     *
     * @param name Name of the benchmark
     * @param bench Benchmark implementation
     * @param warmup Number of warmup iterations (not measured)
     * @param iterations Number of measured iterations
     * @return Result with statistics
     */
    public static Result run(String name, Benchmark bench, Integer warmup, Integer iterations) {
        return run(name, bench, warmup, iterations, DEFAULT_FLAGS);
    }

    /**
     * Run a single benchmark with custom tracking flags
     *
     * @param name Name of the benchmark
     * @param bench Benchmark implementation
     * @param warmup Number of warmup iterations
     * @param iterations Number of measured iterations
     * @param flags Tracking flags (TRACK_HEAP, TRACK_DB, or combine with |)
     * @return Result with statistics
     */
    public static Result run(String name, Benchmark bench, Integer warmup, Integer iterations, Integer flags) {
        // Setup phase (not measured)
        bench.setup();

        // Warm-up phase (not measured)
        for (Integer i = 0; i < warmup; i++) {
            bench.run();
        }

        Boolean trackHeap = (flags & TRACK_HEAP) != 0;
        Boolean trackDb = (flags & TRACK_DB) != 0;

        Long totalWall = 0;
        Long totalCpu = 0;
        Long totalHeap = 0;
        Long minWall = null;
        Long maxWall = null;
        Long minCpu = null;
        Long maxCpu = null;
        Long minHeap = null;
        Long maxHeap = null;

        Integer totalDml = 0;
        Integer totalSoql = 0;
        Integer minDml = null;
        Integer maxDml = null;
        Integer minSoql = null;
        Integer maxSoql = null;

        Integer dmlBefore = trackDb ? systemProvider.getDmlStatements() : 0;
        Integer soqlBefore = trackDb ? systemProvider.getQueries() : 0;

        for (Integer i = 0; i < iterations; i++) {
            // Measure wall time, CPU time, and heap usage per iteration
            Long wallStart = systemProvider.getCurrentTimeMillis();
            Integer cpuStart = systemProvider.getCpuTime();
            Integer heapStart = trackHeap ? systemProvider.getHeapSize() : 0;
            Integer dmlStart = trackDb ? systemProvider.getDmlStatements() : 0;
            Integer soqlStart = trackDb ? systemProvider.getQueries() : 0;

            bench.run();

            Long wallDelta = systemProvider.getCurrentTimeMillis() - wallStart;
            Integer cpuDelta = systemProvider.getCpuTime() - cpuStart;
            Integer heapDelta = trackHeap ? (systemProvider.getHeapSize() - heapStart) : 0;
            Integer dmlDelta = trackDb ? (systemProvider.getDmlStatements() - dmlStart) : 0;
            Integer soqlDelta = trackDb ? (systemProvider.getQueries() - soqlStart) : 0;

            totalWall += wallDelta;
            totalCpu += cpuDelta;
            totalHeap += heapDelta;
            totalDml += dmlDelta;
            totalSoql += soqlDelta;

            // Always track min/max for wall and CPU time
            if (minWall == null || wallDelta < minWall) minWall = wallDelta;
            if (maxWall == null || wallDelta > maxWall) maxWall = wallDelta;
            if (minCpu == null || cpuDelta < minCpu) minCpu = cpuDelta;
            if (maxCpu == null || cpuDelta > maxCpu) maxCpu = cpuDelta;

            // Track min/max heap when tracking heap
            if (trackHeap) {
                if (minHeap == null || heapDelta < minHeap) minHeap = heapDelta;
                if (maxHeap == null || heapDelta > maxHeap) maxHeap = heapDelta;
            }

            // Track min/max DB operations when tracking DB
            if (trackDb) {
                if (minDml == null || dmlDelta < minDml) minDml = dmlDelta;
                if (maxDml == null || dmlDelta > maxDml) maxDml = dmlDelta;
                if (minSoql == null || soqlDelta < minSoql) minSoql = soqlDelta;
                if (maxSoql == null || soqlDelta > maxSoql) maxSoql = soqlDelta;
            }
        }

        Result result = new Result(
            name,
            ((Decimal) totalWall) / iterations,
            ((Decimal) totalCpu) / iterations
        );

        result.iterations = iterations;

        // Always populate min/max wall and CPU times
        result.minWallMs = minWall;
        result.maxWallMs = maxWall;
        result.minCpuMs = minCpu;
        result.maxCpuMs = maxCpu;

        if (trackHeap) {
            result.avgHeapKb = ((Decimal) totalHeap) / iterations / 1024;
            result.minHeapKb = ((Decimal) minHeap) / 1024;
            result.maxHeapKb = ((Decimal) maxHeap) / 1024;
        }

        if (trackDb) {
            result.dmlStatements = totalDml;
            result.soqlQueries = totalSoql;
            result.minDmlStatements = minDml;
            result.maxDmlStatements = maxDml;
            result.minSoqlQueries = minSoql;
            result.maxSoqlQueries = maxSoql;
        }

        // Teardown phase (not measured)
        bench.teardown();

        return result;
    }

    /**
     * Run a benchmark with default settings (10 warmup, 100 iterations)
     */
    public static Result run(String name, Benchmark bench) {
        return run(name, bench, DEFAULT_WARMUP, DEFAULT_ITERATIONS);
    }

    /**
     * Compare multiple benchmark results and display sorted by CPU time
     *
     * @param results List of benchmark results
     */
    public static void compare(List<Result> results) {
        if (results == null || results.isEmpty()) {
            System.debug('No results to compare');
            return;
        }

        // Sort by CPU time (ascending)
        results.sort(new CpuComparator());

        System.debug('\n=== Benchmark Results (sorted by CPU time) ===');

        Result baseline = results[0];
        for (Integer i = 0; i < results.size(); i++) {
            Result r = results[i];
            String line = String.valueOf(i + 1) + '. ' + r.toString();

            // Show relative performance compared to baseline
            if (i > 0) {
                Decimal ratio = r.avgCpuMs / baseline.avgCpuMs;
                line += ' (' + ratio.setScale(2) + 'x)';
            }

            System.debug(line);
        }
    }


    /**
     * Comparator for sorting results by CPU time
     */
    private class CpuComparator implements System.Comparator<Result> {
        public Integer compare(Result a, Result b) {
            if (a.avgCpuMs < b.avgCpuMs) return -1;
            if (a.avgCpuMs > b.avgCpuMs) return 1;
            return 0;
        }
    }

    /**
     * Entry in a benchmark suite (package for Suite)
     */
    private class BenchmarkEntry {
        String name;
        Benchmark benchmark;

        BenchmarkEntry(String name, Benchmark benchmark) {
            this.name = name;
            this.benchmark = benchmark;
        }
    }

    /**
     * Suite builder for running multiple benchmarks with consistent configuration
     */
    public class Suite {
        private List<BenchmarkEntry> benchmarks = new List<BenchmarkEntry>();
        private Integer warmupCount = DEFAULT_WARMUP;
        private Integer iterationCount = DEFAULT_ITERATIONS;
        private Integer trackingFlags = 0;  // By default, only track time metrics

        /**
         * Add a benchmark to the suite
         */
        public Suite add(String name, Benchmark benchmark) {
            benchmarks.add(new BenchmarkEntry(name, benchmark));
            return this;
        }

        /**
         * Set warmup iterations for all benchmarks
         */
        public Suite warmup(Integer count) {
            this.warmupCount = count;
            return this;
        }

        /**
         * Set measurement iterations for all benchmarks
         */
        public Suite iterations(Integer count) {
            this.iterationCount = count;
            return this;
        }

        /**
         * Enable heap usage tracking (min/max/average per iteration)
         */
        public Suite trackHeap() {
            this.trackingFlags |= TRACK_HEAP;
            return this;
        }

        /**
         * Enable database operation tracking (DML/SOQL with min/max per iteration)
         */
        public Suite trackDB() {
            this.trackingFlags |= TRACK_DB;
            return this;
        }

        /**
         * Run all benchmarks in the suite
         */
        public List<Result> runAll() {
            List<Result> results = new List<Result>();
            for (BenchmarkEntry entry : benchmarks) {
                results.add(Harness.run(
                    entry.name,
                    entry.benchmark,
                    warmupCount,
                    iterationCount,
                    trackingFlags
                ));
            }
            return results;
        }

        /**
         * Run all benchmarks and automatically compare results
         */
        public List<Result> runAndCompare() {
            List<Result> results = runAll();
            Harness.compare(results);
            return results;
        }
    }
}
