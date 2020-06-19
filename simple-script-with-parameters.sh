#!/bin/bash

# MIT License
#
# Copyright (c) 2020 tompaz3
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

readonly script_basename="$(basename "$0")"
readonly script_raw_args=("$@")
script_args=("$@")

readonly TRUE=1
readonly FALSE=0

readonly DEFAULT_DEPTH=1
readonly DEFAULT_PATTERN="*"

readonly TYPE_FILE="f"
readonly TYPE_DIRECTORY="d"

readonly EXIT_CODE_ERROR=1
readonly EXIT_CODE_SUCCESS=0

readonly LOG_LEVEL_NONE="NONE"
readonly LOG_LEVEL_ERROR="ERROR"
readonly LOG_LEVEL_INFO="INFO"
readonly LOG_LEVEL_DEBUG="DEBUG"

readonly LOG_LEVEL_NONE_NUM=0
readonly LOG_LEVEL_ERROR_NUM=1
readonly LOG_LEVEL_INFO_NUM=2
readonly LOG_LEVEL_DEBUG_NUM=3

script_log_level_num=$LOG_LEVEL_INFO_NUM
script_log_level="$LOG_LEVEL_INFO"

function exist_successfully() {
    exit $EXIT_CODE_SUCCESS
}

function exit_abnormally() {
    exit $EXIT_CODE_ERROR
}

function log() {
    local log_level="$script_log_level"
    if [ -n "$1" ]; then
        log_level="$1"
    fi
    echo "${script_basename} [${log_level}] $2"
}

function log_info() {
    if [ "$script_log_level_num" -ge "$LOG_LEVEL_INFO_NUM" ]; then
        log "${LOG_LEVEL_INFO}" "$1"
    fi
}

function log_error() {
    if [ "$script_log_level_num" -ge "$LOG_LEVEL_ERROR_NUM" ]; then
        log "${LOG_LEVEL_ERROR}" "$1"
    fi
}

function log_debug() {
    if [ "$script_log_level_num" -ge "$LOG_LEVEL_DEBUG_NUM" ]; then
        log "${LOG_LEVEL_DEBUG}" "$1"
    fi
}

function usage() {
    cat <<EOF
    Welcome to this script "${script_basename}".
    This script counts files or directories in the given directory and prints the result.
    This is just a demonstration script, whose main function is to present bash script's
    basic argument reading.

    usage:
    "${script_basename}" [-f | --files] [-d | --directories] [-dp | --depth <depth>]
                         [-l | --log-level <log_level>] <directory>

    Positional arguments:
        \$1 - the first positional argument will be treated as the directory
        whose files / directories will be counted
    Supported parameters are:
        -f | --files
            should count files
        -d | -directories
            should count directories
        -dp | --depth
            max depth for recursive count (infinite be default)
        -l | --log-level [NONE|ERROR|INFO|DEBUG]
            log level
        -h | --help
            will print this help / usage instruction

    e.g.
        "${script_basename}
EOF
}

files=$FALSE
directories=$FALSE
max_depth=$DEFAULT_DEPTH
depth_inifite=$TRUE
directory="."
patterns=("$DEFAULT_PATTERN")

# read log level
function read_log_level() {
    script_log_level="$1"
    case "$script_log_level" in
    "$LOG_LEVEL_NONE")
        script_log_level_num=$LOG_LEVEL_NONE_NUM
        ;;
    "$LOG_LEVEL_ERROR")
        script_log_level_num=$LOG_LEVEL_ERROR
        ;;
    "$LOG_LEVEL_INFO")
        script_log_level_num=$LOG_LEVEL_INFO_NUM
        ;;
    "$LOG_LEVEL_DEBUG")
        script_log_level_num=$LOG_LEVEL_DEBUG_NUM
        ;;
    *) # unknown
        log "$LOG_LEVEL_ERROR" "read_log_level() Invalid log level $script_log_level."
        exit_abnormally
        ;;
    esac
}

# read script's positional parameters (without "-" or "--" prefixes)
function read_targets() {
    local targets=("$@")
    if [ $# -gt 1 ]; then
        log_error "read_targets() Provided more than 1 argument. There's only 1 argument supported, which is the directory path."
        exit_abnormally
    fi
    if [ -n "${targets[1]}" ]; then
        directory="${targets[1]}"
    fi
}

# reads script's parameters with "-" or "--"
function read_args() {
    local positional_params=""
    while (("$#")); do
        case "$1" in
        -dp | --depth)
            IFS=',' read -r max_depth <<<"$2"
            depth_inifite=$FALSE
            shift 2
            ;;
        -p | --patterns)
            IFS=',' read -r -a patterns <<<"$2"
            shift 2
            ;;
        -f | --files)
            files=$TRUE
            shift 1
            ;;
        -d | --directories)
            directories=$TRUE
            shift 1
            ;;
        -l | --log-level)
            local log_level=$LOG_LEVEL_INFO
            IFS=',' read -r log_level <<<"$2"
            read_log_level "$log_level"
            shift 2
            ;;
        --) # end argument parsing
            shift
            break
            ;;
        -* | --*=) # unsupported params
            echo "Invalid parameter: $1"
            usage
            exit_abnormally
            ;;
        *) # preserve positional params
            positional_params="$positional_params $1"
            shift
            ;;
        esac
    done

    # set positional arguments
    eval set -- "$positional_params"
    script_args=("$@")
}

# count words for given dir, depth, type and name pattern
function count_words() {
    local dir="$1"
    local depth="$2"
    local type="$3"
    local pattern="$4"
    log_debug "count_words() counting for dir=$dir depth=$depth type=$type pattern=$pattern"

    local count=0
    if [ "$depth_inifite" -eq "$TRUE" ]; then
        count=$(find "$dir" -type "$type" -name "$pattern" | grep -c -v -P '^[\.]+&')
    else
        count=$(find "$dir" -maxdepth "$depth" -type "$type" -name "$pattern" | grep -c -v -P '^[\.]+&')
    fi
    log_debug "count_words() dir=$dir depth=$depth type=$type pattern=$pattern count=$count"
    return "$count"
}

#
function _count() {
    log_debug "_count() Parameters are directory=$directory max_depth=$max_depth files=$files directories=$directories patterns=${patterns[*]}"
    local count=0
    for idx in "${!patterns[@]}"; do
        if [ "$files" -eq "$TRUE" ]; then
            local pattern="${patterns[$idx]}"
            count_words "$directory" "$max_depth" "$TYPE_FILE" "$pattern"
            local pattern_count=$?
            count=$((count + pattern_count))
        fi
        if [ "$directories" -eq "$TRUE" ]; then
            local pattern="${patterns[$idx]}"
            count_words "$directory" "$max_depth" "$TYPE_DIRECTORY" "$pattern"
            local pattern_count=$?
            count=$((count + pattern_count))
        fi
    done
    return $count
}

function _main() {
    read_args "${script_args[@]}"
    log_debug "_main() Sript start"
    log_debug "_main() Arguments ${script_raw_args[*]}"
    _count
    local result=$?
    log "" "_main() Count is $result"
    log_debug "_main() Script end"
    exist_successfully
}

_main
