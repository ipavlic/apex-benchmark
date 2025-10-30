/**
 * Unit tests for Harness micro-benchmarking framework
 */
@IsTest
private class HarnessTest {

    /**
     * Mock SystemProvider that returns controlled values for testing
     */
    private class MockSystemProvider extends Harness.SystemProvider {
        private Integer callCount = 0;
        private Integer baseTime = 1000;
        private Integer baseCpu = 100;
        private Integer baseHeap = 10000;
        private Integer baseDml = 0;
        private Integer baseSoql = 0;

        // Increment values on each call to simulate time passing
        public override Long getCurrentTimeMillis() {
            return baseTime + (callCount++);
        }

        public override Integer getCpuTime() {
            return baseCpu + callCount;
        }

        public override Integer getHeapSize() {
            return baseHeap + (callCount * 100);
        }

        public override Integer getDmlStatements() {
            return baseDml;
        }

        public override Integer getQueries() {
            return baseSoql;
        }
    }

    /**
     * Simple test benchmark that does nothing
     */
    private class SimpleBenchmark extends Benchmark {
        public Integer runCount = 0;
        public Boolean setupCalled = false;
        public Boolean teardownCalled = false;

        public override void setup() {
            setupCalled = true;
        }

        public override void run() {
            runCount++;
        }

        public override void teardown() {
            teardownCalled = true;
        }
    }

    @IsTest
    static void testRunWithDefaults() {
        // Setup mock
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        // Execute
        Harness.Result result = Harness.run('Test', bench);

        // Verify lifecycle
        System.assert(bench.setupCalled, 'setup() should be called');
        System.assert(bench.teardownCalled, 'teardown() should be called');
        System.assertEquals(110, bench.runCount, 'run() should be called 110 times (10 warmup + 100 iterations)');

        // Verify result
        System.assertEquals('Test', result.name);
        System.assertEquals(100, result.iterations);
        System.assertNotEquals(null, result.avgWallMs);
        System.assertNotEquals(null, result.avgCpuMs);
        System.assertNotEquals(null, result.minWallMs);
        System.assertNotEquals(null, result.maxWallMs);
        System.assertNotEquals(null, result.minCpuMs);
        System.assertNotEquals(null, result.maxCpuMs);
    }

    @IsTest
    static void testRunWithCustomIterations() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        // Execute with custom warmup and iterations
        Harness.Result result = Harness.run('Test', bench, 5, 20);

        // Verify
        System.assertEquals(25, bench.runCount, 'run() should be called 25 times (5 warmup + 20 iterations)');
        System.assertEquals(20, result.iterations);
    }

    @IsTest
    static void testRunWithHeapTracking() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        // Execute with heap tracking
        Harness.Result result = Harness.run('Test', bench, 5, 10, Harness.TRACK_HEAP);

        // Verify heap metrics are populated
        System.assertNotEquals(null, result.avgHeapKb);
        System.assertNotEquals(null, result.minHeapKb);
        System.assertNotEquals(null, result.maxHeapKb);
    }

    @IsTest
    static void testRunWithoutHeapTracking() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        // Execute without heap tracking (default)
        Harness.Result result = Harness.run('Test', bench, 5, 10, 0);

        // Verify heap metrics are NOT populated
        System.assertEquals(null, result.avgHeapKb);
        System.assertEquals(null, result.minHeapKb);
        System.assertEquals(null, result.maxHeapKb);
    }

    @IsTest
    static void testRunWithDBTracking() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        // Execute with DB tracking
        Harness.Result result = Harness.run('Test', bench, 5, 10, Harness.TRACK_DB);

        // Verify DB metrics are populated
        System.assertNotEquals(null, result.dmlStatements);
        System.assertNotEquals(null, result.soqlQueries);
        System.assertNotEquals(null, result.minDmlStatements);
        System.assertNotEquals(null, result.maxDmlStatements);
        System.assertNotEquals(null, result.minSoqlQueries);
        System.assertNotEquals(null, result.maxSoqlQueries);
    }

    @IsTest
    static void testResultToString() {
        Harness.Result result = new Harness.Result('Test Benchmark', 1.234, 0.987);
        result.iterations = 100;
        result.minWallMs = 1.0;
        result.maxWallMs = 2.0;
        result.minCpuMs = 0.8;
        result.maxCpuMs = 1.2;

        String output = result.toString();

        System.assert(output.contains('Test Benchmark'), 'Should contain name');
        System.assert(output.contains('wall: 1.234'), 'Should contain wall time');
        System.assert(output.contains('cpu: 0.987'), 'Should contain CPU time');
        System.assert(output.contains('min/max wall'), 'Should contain min/max wall');
        System.assert(output.contains('min/max cpu'), 'Should contain min/max CPU');
    }

    @IsTest
    static void testResultToStringWithHeap() {
        Harness.Result result = new Harness.Result('Test', 1.0, 1.0);
        result.avgHeapKb = 512.5;
        result.minHeapKb = 500.0;
        result.maxHeapKb = 550.0;
        result.minWallMs = 1.0;
        result.maxWallMs = 2.0;
        result.minCpuMs = 1.0;
        result.maxCpuMs = 2.0;

        String output = result.toString();

        System.assert(output.contains('heap: 512.50 KB'), 'Should contain heap');
        System.assert(output.contains('min/max: 500.00/550.00'), 'Should contain heap min/max');
    }

    @IsTest
    static void testCompare() {
        Harness.Result r1 = new Harness.Result('Fast', 1.0, 1.0);
        r1.minWallMs = 1.0;
        r1.maxWallMs = 1.0;
        r1.minCpuMs = 1.0;
        r1.maxCpuMs = 1.0;

        Harness.Result r2 = new Harness.Result('Slow', 2.0, 2.0);
        r2.minWallMs = 2.0;
        r2.maxWallMs = 2.0;
        r2.minCpuMs = 2.0;
        r2.maxCpuMs = 2.0;

        // This will output to debug log
        Harness.compare(new List<Harness.Result>{ r2, r1 });

        // No assertion - just verify no exception
        System.assert(true, 'compare() should complete without error');
    }

    @IsTest
    static void testSuiteBasic() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench1 = new SimpleBenchmark();
        SimpleBenchmark bench2 = new SimpleBenchmark();

        // Execute
        List<Harness.Result> results = new Harness.Suite()
            .add('Benchmark 1', bench1)
            .add('Benchmark 2', bench2)
            .warmup(5)
            .iterations(10)
            .runAll();

        // Verify
        System.assertEquals(2, results.size(), 'Should return 2 results');
        System.assertEquals('Benchmark 1', results[0].name);
        System.assertEquals('Benchmark 2', results[1].name);
        System.assertEquals(15, bench1.runCount, '5 warmup + 10 iterations');
        System.assertEquals(15, bench2.runCount, '5 warmup + 10 iterations');
    }

    @IsTest
    static void testSuiteWithTrackHeap() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        List<Harness.Result> results = new Harness.Suite()
            .add('Test', bench)
            .trackHeap()
            .warmup(5)
            .iterations(10)
            .runAll();

        // Verify heap tracking enabled
        System.assertNotEquals(null, results[0].avgHeapKb);
    }

    @IsTest
    static void testSuiteWithTrackDB() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        List<Harness.Result> results = new Harness.Suite()
            .add('Test', bench)
            .trackDB()
            .warmup(5)
            .iterations(10)
            .runAll();

        // Verify DB tracking enabled
        System.assertNotEquals(null, results[0].dmlStatements);
        System.assertNotEquals(null, results[0].soqlQueries);
    }

    @IsTest
    static void testSuiteWithBothTracking() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench = new SimpleBenchmark();

        List<Harness.Result> results = new Harness.Suite()
            .add('Test', bench)
            .trackHeap()
            .trackDB()
            .warmup(5)
            .iterations(10)
            .runAll();

        // Verify both tracking enabled
        System.assertNotEquals(null, results[0].avgHeapKb);
        System.assertNotEquals(null, results[0].dmlStatements);
    }

    @IsTest
    static void testSuiteRunAndCompare() {
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        SimpleBenchmark bench1 = new SimpleBenchmark();
        SimpleBenchmark bench2 = new SimpleBenchmark();

        // Execute - this will output to debug log
        List<Harness.Result> results = new Harness.Suite()
            .add('Method 1', bench1)
            .add('Method 2', bench2)
            .warmup(5)
            .iterations(10)
            .runAndCompare();

        // Verify
        System.assertEquals(2, results.size());
        System.assert(true, 'runAndCompare() should complete without error');
    }

    @IsTest
    static void testTrackingFlags() {
        // Test bitwise flag combinations
        System.assertEquals(1, Harness.TRACK_HEAP);
        System.assertEquals(2, Harness.TRACK_DB);
        System.assertEquals(3, Harness.TRACK_ALL);
        System.assertEquals(3, Harness.TRACK_HEAP | Harness.TRACK_DB);
    }

    @IsTest
    static void testMinimalBenchmark() {
        // Test benchmark with only run() method (no setup/teardown)
        MockSystemProvider mock = new MockSystemProvider();
        Harness.systemProvider = mock;

        Benchmark minimalBench = new MinimalBenchmark();
        Harness.Result result = Harness.run('Minimal', minimalBench, 2, 5);

        System.assertEquals(5, result.iterations);
    }

    /**
     * Minimal benchmark implementation
     */
    private class MinimalBenchmark extends Benchmark {
        public override void run() {
            // Do nothing
        }
    }
}
