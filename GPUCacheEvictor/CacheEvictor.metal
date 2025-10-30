#include <metal_stdlib>
using namespace metal;

kernel void in_shader_pump_probe_linear(
    // Input Buffers
    device const uint *probeBuffer [[buffer(0)]],
    device const uint *pumpBuffer [[buffer(1)]],
    
    // Output Buffer
    device uint *result_data [[buffer(2)]],

    // Configuration
    constant uint &pump_element_count [[buffer(3)]],
    
    threadgroup atomic_uint *timer [[threadgroup(0)]],
    threadgroup atomic_uint *stop_flag [[threadgroup(1)]],

    uint tid [[thread_index_in_threadgroup]]
) {
    // Shared variables for the worker's results
    threadgroup uint prime_result;
    //threadgroup uint pump_sum_result;
    threadgroup uint probe_result;

    // Thread 0 initializes the shared variables
    if (tid == 0) {
        atomic_store_explicit(timer, 0, memory_order_relaxed);
        atomic_store_explicit(stop_flag, 0, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // --- WORKER THREAD ---
    if (tid == 64) {
        // 1. Prime and Pump
        
        
        prime_result = probeBuffer[0];

        uint temp_pump_sum = 0;
        const uint stride_in_elements = 16;
        for (uint i = 0; i < 10; i++){
            for (uint j = 0; j < pump_element_count; j += stride_in_elements) {
                temp_pump_sum += pumpBuffer[j];
            }
        }
        
        simdgroup_barrier(mem_flags::mem_threadgroup);
        
        // 2. TIMED SECTION: Take before/after snapshots of the timer
        uint startTime = atomic_load_explicit(timer, memory_order_relaxed);
        probe_result = probeBuffer[0];
        uint endTime = atomic_load_explicit(timer, memory_order_relaxed);
        
        // 3. Signal all timer threads to stop
        atomic_store_explicit(stop_flag, 1, memory_order_relaxed);
        
        // 4. Calculate duration and write results
        uint duration = endTime - startTime;
        
        result_data[1] = prime_result;
        result_data[2] = duration;
        result_data[3] = temp_pump_sum + probe_result;
    }
    // --- TIMER THREADS ---
    else if (tid == 0){
        // All other threads act as the timer, incrementing the shared value
        // until the worker thread sets the stop_flag.
        uint counter = 0;
        while (atomic_load_explicit(stop_flag, memory_order_relaxed) == 0) {
            counter++;
            atomic_store_explicit(timer, counter, memory_order_relaxed);
            //atomic_fetch_add_explicit(timer, 1, memory_order_relaxed);
        }
        
        result_data[0] = atomic_load_explicit(timer, memory_order_relaxed);
//         result_data[0] = counter;
    }
}


// Helper function for pseudo-random number generation
uint lcg(thread uint &seed) {
    seed = (1664543 * seed + 1013904223);
    return seed;
}

kernel void in_shader_pump_probe_random(
    // Input Buffers
    device const uint *probeBuffer [[buffer(0)]],
    device const uint *pumpBuffer [[buffer(1)]],
    
    // Output Buffer
    device uint *result_data [[buffer(2)]],

    // Configuration
    constant uint &pump_element_count [[buffer(3)]],
    
    // Threadgroup memory for communication
    threadgroup atomic_uint *timer [[threadgroup(0)]],
    threadgroup atomic_uint *stop_flag [[threadgroup(1)]],

    uint tid [[thread_index_in_threadgroup]]
) {
    // Shared variables for the worker's results
    threadgroup uint prime_result;
    threadgroup uint probe_result;

    // Thread 0 initializes the shared variables
    if (tid == 0) {
        atomic_store_explicit(timer, 0, memory_order_relaxed);
        atomic_store_explicit(stop_flag, 0, memory_order_relaxed);
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // --- WORKER THREAD ---
    if (tid == 64) {
        // 1. Prime the cache
        prime_result = probeBuffer[0];

        uint temp_pump_sum = 0;
        //uint random_seed = tid * 2654435761; // Seed the PRNG
        
        
        
        for (uint i = 0; i < pump_element_count/16; i ++) {
            uint random_index = lcg(i) % (pump_element_count/16);
            temp_pump_sum += pumpBuffer[random_index * 16];
        }
        
        simdgroup_barrier(mem_flags::mem_threadgroup);
        
        // 2. TIMED SECTION: Take before/after snapshots of the timer
        uint startTime = atomic_load_explicit(timer, memory_order_relaxed);
        probe_result = probeBuffer[0];
        uint endTime = atomic_load_explicit(timer, memory_order_relaxed);
        
        // 3. Signal all timer threads to stop
        atomic_store_explicit(stop_flag, 1, memory_order_relaxed);
        
        // 4. Calculate duration and write results
        uint duration = endTime - startTime;
        
        result_data[1] = prime_result;
        result_data[2] = duration; // Keep sum to prevent optimization
        result_data[3] = temp_pump_sum + probe_result;
    }
    // --- TIMER THREAD ---
    else if (tid == 0){
        // All other threads act as the timer, incrementing the shared value
        // until the worker thread sets the stop_flag.
        uint counter = 0;
        while (atomic_load_explicit(stop_flag, memory_order_relaxed) == 0) {
            counter++;
            atomic_store_explicit(timer, counter, memory_order_relaxed);
            // (timer, 1, memory_order_relaxed);
        }
        
        result_data[0] = atomic_load_explicit(timer, memory_order_relaxed);
//         result_data[0] = counter;
    }
}
