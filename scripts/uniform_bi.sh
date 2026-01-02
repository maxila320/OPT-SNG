#!/bin/bash

BUILD_DIR="build"
DATATYPE="float"
A_BUILD=1.00
QUERY_FILE="data/uniform/uniform_query.fbin"
GT_FILE="data/uniform/uniform_query_learn_gt100"
DATA_PATH="data/uniform/uniform_learn.fbin"
B_BUILD=0.025
M_BUILD=40.0
K_SEARCH=10
RESULT_PATH="data/uniform/res"
L_BUILD=300
L_SEARCH=300


MIN_R=100
MAX_R=300
MAX_ITER=15
TARGET_SCORE=-999999


RESULT_LOG="r_tuning_results_uniform.csv"
DEBUG_LOG="diskann_debug_uniform.log"


echo "R,BuildTime(sec),Recall(%),Latency(ms),Score,TotalTime(sec)" > $RESULT_LOG

START_TIME=$(date +%s)


parse_diskann_output() {
    local output="$1"
    

    echo "===== DiskANN Output =====" > $DEBUG_LOG
    echo "$output" >> $DEBUG_LOG
    echo "========================" >> $DEBUG_LOG


    local table_output=$(echo "$output" | sed -n '/^[[:space:]]*L[[:space:]]\+Beamwidth/,$p')


    local target_line=$(echo "$table_output" | awk -v l_search="$L_SEARCH" 'NR>2 && $1==l_search')

    echo "Target line: $target_line" >> $DEBUG_LOG


    local recall=$(echo "$target_line" | awk '{print $9}')  
    local latency=$(echo "$target_line" | awk '{print $4}')  



    latency_ms=$(echo "scale=4; $latency / 1000" | bc)

    echo "$recall $latency_ms"
    return 0
}


test_r_value() {
    local R=$1
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Testing R=$R..."
    

    INDEX_PATH_PREFIX="data/uniform/disk_index_uniform_learn_R${R}_L${L_BUILD}_A${A_BUILD}"
    rm -rf ${INDEX_PATH_PREFIX}*
    

    BUILD_START=$(date +%s.%N)
    ${BUILD_DIR}/apps/build_disk_index --data_type ${DATATYPE} --dist_fn l2 \
        --data_path ${DATA_PATH} --index_path_prefix ${INDEX_PATH_PREFIX} \
        -R ${R} -L ${L_BUILD} -B ${B_BUILD} -M ${M_BUILD} -A ${A_BUILD} \
        2>&1 | tee build_R${R}.log
    BUILD_END=$(date +%s.%N)
    BUILD_TIME=$(echo "$BUILD_END - $BUILD_START" | bc)
    

    SEARCH_START=$(date +%s.%N)
    SEARCH_OUTPUT=$(${BUILD_DIR}/apps/search_disk_index --data_type ${DATATYPE} --dist_fn l2 \
        --index_path_prefix ${INDEX_PATH_PREFIX} --query_file ${QUERY_FILE} \
        --gt_file ${GT_FILE} -K ${K_SEARCH} -L ${L_SEARCH} \
        --result_path ${RESULT_PATH} --num_nodes_to_cache 10000 2>&1)
    SEARCH_END=$(date +%s.%N)
    SEARCH_TIME=$(echo "$SEARCH_END - $SEARCH_START" | bc)
    

    if ! METRICS=$(parse_diskann_output "$SEARCH_OUTPUT"); then
        echo "ERROR: Failed to parse output for R=$R"
        cat $DEBUG_LOG
        return 1
    fi
    
    RECALL=$(echo $METRICS | awk '{print $1}')
    LATENCY=$(echo $METRICS | awk '{print $2}')
    
    # 计算评分 (recall/90 - latency/10)
    CURRENT_SCORE=$(echo "scale=4; $RECALL/9.9 - $LATENCY/4 " | bc)
    TOTAL_TIME=$(echo "$BUILD_TIME + $SEARCH_TIME" | bc)
    

    echo "$R,$BUILD_TIME,$RECALL,$LATENCY,$CURRENT_SCORE,$TOTAL_TIME" >> $RESULT_LOG
    echo "R=$R: BuildTime=${BUILD_TIME}s, Recall=${RECALL}%, Latency=${LATENCY}ms, Score=$CURRENT_SCORE"
    

    if (( $(echo "$CURRENT_SCORE > $TARGET_SCORE" | bc -l) )); then
        TARGET_SCORE=$CURRENT_SCORE
        BEST_R=$R
        echo "New best R found: $BEST_R with score $TARGET_SCORE"
    fi
}


binary_search_tune() {
    local low=$1
    local high=$2
    local iteration=$3
    
    [ $iteration -ge $MAX_ITER ] && return
    
    local mid=$(( (low + high) / 2 ))
    

    test_r_value $mid
    

    if [ $mid -lt $high ]; then
        test_r_value $((mid + 1))
        if (( $(echo "$CURRENT_SCORE > $TARGET_SCORE" | bc -l) )); then
            binary_search_tune $mid $high $((iteration+1))
        else
            binary_search_tune $low $mid $((iteration+1))
        fi
    fi
}


main() {
    echo "Starting DiskANN parameter tuning at $(date)"
    echo "Parameters: L_BUILD=$L_BUILD, L_SEARCH=$L_SEARCH, R range [$MIN_R,$MAX_R]"
    

    test_r_value $MIN_R
    test_r_value $MAX_R
    test_r_value $(( (MIN_R + MAX_R) / 2 ))
    

    binary_search_tune $MIN_R $MAX_R 1
    

    echo ""
    echo "===== Tuning Completed ====="
    echo "Best R value: $BEST_R"
    echo "Achieved score: $TARGET_SCORE"
    echo "Total tuning time: $(($(date +%s) - START_TIME)) seconds"
    echo "Detailed results saved to $RESULT_LOG"
    

    echo "BEST_R=$BEST_R" > best_config.txt
    echo "BEST_SCORE=$TARGET_SCORE" >> best_config.txt
}

main