#!/bin/bash

RJ=$MW_HOME/maintenance/runJobs.php
logfileName=mwjobrunner_log

echo "Starting job runner (in 10 seconds)..."
# Wait 10 seconds after the server starts up to give other processes time to get started
sleep 10
echo Job runner started.
while true; do
    logFilePrev="$logfileNow"
    logfileNow="$MW_LOG/$logfileName"_$(date +%Y%m%d)
    if [ -n "$logFilePrev" ] && [ "$logFilePrev" != "$logfileNow" ]; then
        /rotatelogs-compress.sh "$logfileNow" "$logFilePrev" &
    fi

    date >> "$logfileNow"
    # Job types that need to be run ASAP mo matter how many of them are in the queue
    # Those jobs should be very "cheap" to run
    php "$RJ" --memory-limit="$MW_JOB_RUNNER_MEMORY_LIMIT" --type="enotifNotify" >> "$logfileNow" 2>&1
    sleep 1
    php "$RJ" --memory-limit="$MW_JOB_RUNNER_MEMORY_LIMIT" --type="createPage" >> "$logfileNow" 2>&1
    sleep 1
    php "$RJ" --memory-limit="$MW_JOB_RUNNER_MEMORY_LIMIT" --type="htmlCacheUpdate" --maxjobs=500 >> "$logfileNow" 2>&1
    # Due to the way we do varnish cache reloading, we want to aim for htmlCacheUpdate jobs
    # to typically run before refreshLinks jobs, so do not sleep between them. (WLDR-314)
    php "$RJ" --memory-limit="$MW_JOB_RUNNER_MEMORY_LIMIT" --type="refreshLinks" --maxjobs=25 >> "$logfileNow" 2>&1
    sleep 1
    # Everything else, limit the number of jobs on each batch
    # The --wait parameter will pause the execution here until new jobs are added,
    # to avoid running the loop without anything to do
    php "$RJ" --memory-limit="$MW_JOB_RUNNER_MEMORY_LIMIT" --maxjobs=10 >> "$logfileNow" 2>&1

    # Wait some seconds to let the CPU do other things, like handling web requests, etc
    echo mwjobrunner waits for "$MW_JOB_RUNNER_PAUSE" seconds... >> "$logfileNow"
    sleep "$MW_JOB_RUNNER_PAUSE"
done
