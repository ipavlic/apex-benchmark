/**
 * Unit tests for Benchmark abstract base class
 */
@IsTest
private class BenchmarkTest {

    /**
     * Test implementation with all methods overridden
     */
    private class FullBenchmark extends Benchmark {
        public Boolean setupCalled = false;
        public Integer runCount = 0;
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

    /**
     * Minimal implementation with only run() method
     */
    private class MinimalBenchmark extends Benchmark {
        public Integer runCount = 0;

        public override void run() {
            runCount++;
        }
    }

    @IsTest
    static void testFullBenchmarkLifecycle() {
        FullBenchmark bench = new FullBenchmark();

        // Execute lifecycle
        bench.setup();
        bench.run();
        bench.run();
        bench.teardown();

        // Verify
        System.assert(bench.setupCalled, 'setup() should be called');
        System.assertEquals(2, bench.runCount, 'run() should be called twice');
        System.assert(bench.teardownCalled, 'teardown() should be called');
    }

    @IsTest
    static void testMinimalBenchmark() {
        MinimalBenchmark bench = new MinimalBenchmark();

        // Call methods (setup/teardown are no-ops)
        bench.setup();
        bench.run();
        bench.teardown();

        // Verify run was called
        System.assertEquals(1, bench.runCount, 'run() should be called once');
    }

    @IsTest
    static void testSetupIsOptional() {
        MinimalBenchmark bench = new MinimalBenchmark();

        // setup() should not throw even without override
        bench.setup();

        System.assert(true, 'setup() should have default implementation');
    }

    @IsTest
    static void testTeardownIsOptional() {
        MinimalBenchmark bench = new MinimalBenchmark();

        // teardown() should not throw even without override
        bench.teardown();

        System.assert(true, 'teardown() should have default implementation');
    }

    @IsTest
    static void testRunIsRequired() {
        // This test verifies that run() must be implemented
        // If run() is not abstract, this would fail to compile
        MinimalBenchmark bench = new MinimalBenchmark();
        bench.run();

        System.assertEquals(1, bench.runCount, 'run() must be implemented');
    }
}
