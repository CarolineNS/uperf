#!/system/bin/sh
# Cgroup Library
# https://github.com/yc9559/
# Author: Matt Yang
# Version: 20210204

BASEDIR="$(dirname "$0")"
. $BASEDIR/pathinfo.sh
. $BASEDIR/libcommon.sh

# launcher&home usually in foreground cpuset group
# reserve one LITTLE for hwservicemanager which will block composer
# thread priority settings not working on hwservicemanager
# okay, disabling perf-hal resulting hwservicemanager frequently wakeup
# CPUMASK_LOW="0e"
# CPUMASK_MID="73"
# CPUMASK_HIGH="f0"
# CPUID_LOW="1-3"
# CPUID_MID="0-1,4-7" # uperf set 0-1/0-6 for foreground, cpu7 reserved for launcher
# CPUID_HIGH="4-7"

# avoid matching grep itself
# ps -Ao pid,args | grep kswapd
# 150 [kswapd0]
# 16490 grep kswapd

# $1:task_name $2:cgroup_name $3:"cpuset"/"stune"
change_task_cgroup()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            log "change $1/$comm($temp_tid) -> cgroup:$2"
            echo "$temp_tid" > "/dev/$3/$2/tasks"
        done
    done
}

# $1:process_name $2:cgroup_name $3:"cpuset"/"stune"
change_proc_cgroup()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        comm="$(cat /proc/$temp_pid/comm)"
        log "change $comm($temp_pid) -> cgroup:$2"
        echo $temp_pid > "/dev/$3/$2/cgroup.procs"
    done
}

# $1:task_name $2:thread_name $3:cgroup_name $4:"cpuset"/"stune"
change_thread_cgroup()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            if [ "$(echo $comm | grep -i "$2")" != "" ]; then
                log "change $1/$comm($temp_tid) -> cgroup:$3"
                echo "$temp_tid" > "/dev/$4/$3/tasks"
            fi
        done
    done
}

# $1:task_name $2:hex_mask(0x00000003 is CPU0 and CPU1)
change_task_affinity()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            log "change $1/$comm($temp_tid) -> mask:$2"
            taskset -p "$2" "$temp_tid" >> $LOG_FILE
        done
    done
}

# $1:task_name $2:thread_name $3:hex_mask(0x00000003 is CPU0 and CPU1)
change_thread_affinity()
{
    local ps_ret
    local comm
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            if [ "$(echo $comm | grep -i "$2")" != "" ]; then
                log "change $1/$comm($temp_tid) -> mask:$3"
                taskset -p "$3" "$temp_tid" >> $LOG_FILE
            fi
        done
    done
}

# $1:task_name $2:nice(relative to 120)
change_task_nice()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            renice "$2" -p "$temp_tid" >> $LOG_FILE
        done
    done
}

# $1:task_name $2:priority(99-x, 1<=x<=99)
change_task_rt()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            log "change $1/$comm($temp_tid) -> RT policy"
            chrt -f -p "$2" "$temp_tid" >> $LOG_FILE
        done
    done
}

# $1:task_name $2:thread_name $3:priority(99-x, 1<=x<=99)
change_thread_rt()
{
    local ps_ret
    local comm
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            if [ "$(echo $comm | grep -i "$2")" != "" ]; then
                log "change $1/$comm($temp_tid) -> RT policy"
                chrt -f -p "$3" "$temp_tid" >> $LOG_FILE
            fi
        done
    done
}

# $1:task_name
change_task_high_prio()
{
    local ps_ret
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            # audio thread nice <= -16
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            log "change $1/$comm($temp_tid) -> Nice -15"
            renice -n -15 -p "$temp_tid" >> $LOG_FILE
        done
    done
}

# $1:task_name $2:thread_name
change_thread_high_prio()
{
    local ps_ret
    local comm
    ps_ret="$(ps -Ao pid,args)"
    for temp_pid in $(echo "$ps_ret" | grep -i "$1" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            if [ "$(echo $comm | grep -i "$2")" != "" ]; then
                # audio thread nice <= -16
                log "change $1/$comm($temp_tid) -> Nice -15"
                renice -n -15 -p "$temp_tid" >> $LOG_FILE
            fi
        done
    done
}

# $1:task_name $2:thread_name
unpin_thread()
{
    change_thread_cgroup "$1" "$2" "" "cpuset"
}

# $1:task_name $2:thread_name
pin_thread_on_pwr()
{
    change_thread_cgroup "$1" "$2" "background" "cpuset"
}

# $1:task_name $2:thread_name
pin_thread_on_mid()
{
    change_thread_cgroup "$1" "$2" "foreground" "cpuset"
    change_thread_affinity "$1" "$2" "7f"
}

# $1:task_name $2:thread_name
pin_thread_on_perf()
{
    unpin_thread "$1" "$2"
    change_thread_affinity "$1" "$2" "f0"
}

# $1:task_name
unpin_proc()
{
    change_task_cgroup "$1" "" "cpuset"
}

# $1:task_name
pin_proc_on_pwr()
{
    change_task_cgroup "$1" "background" "cpuset"
}

# $1:task_name
pin_proc_on_mid()
{
    change_task_cgroup "$1" "foreground" "cpuset"
    change_task_affinity "$1" "7f"
}

# $1:task_name
pin_proc_on_perf()
{
    unpin_proc "$1"
    change_task_affinity "$1" "f0"
}
