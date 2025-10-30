/**
 * Abstract base class that benchmark implementations must extend
 *
 * Lifecycle:
 *   1. setup() - Called once before warmup iterations (optional)
 *   2. run() - Called for each warmup and measurement iteration (required)
 *   3. teardown() - Called once after all iterations complete (optional)
 */
public abstract class Benchmark {
    /**
     * Optional setup method called once before any iterations
     * Override this to initialize test data or resources
     */
    public virtual void setup() {}

    /**
     * Required benchmark method called for each iteration
     * Only code in this method is measured
     */
    public abstract void run();

    /**
     * Optional teardown method called once after all iterations
     * Override this to clean up resources
     */
    public virtual void teardown() {}
}
