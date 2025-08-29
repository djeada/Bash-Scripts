#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# Script Name: find_dead_code.sh
# Description:
#   This script searches for function and class definitions in Python files within a specified directory
#   and displays those with occurrences less than a specified threshold.
#   It can exclude certain files or directories and offers a verbose mode for detailed logging.
# Usage:
#   find_dead_code.sh [-n threshold] [-d directory] [-e path1,path2] [-v] [-f format] [-o output]
# Example:
#   find_dead_code.sh -n 3 -d /path/to/project -e tests,venv,.git -v -f json -o report.json

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Default values
THRESHOLD=2
DIRECTORY="."
EXCLUDED_PATHS=()
VERBOSE=false
OUTPUT_FORMAT="text"  # text, json, csv
OUTPUT_FILE=""
INCLUDE_PRIVATE=false
MIN_NAME_LENGTH=2
IGNORE_DUNDER=true

# Statistics
declare -A STATS
STATS[total_files]=0
STATS[total_functions]=0
STATS[total_classes]=0
STATS[dead_code_items]=0

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Find potentially dead code in Python projects by analyzing function and class usage.

OPTIONS:
    -n threshold        Minimum occurrences threshold (default: 2)
    -d directory        Directory to search in (default: current directory)
    -e paths           Comma-separated list of paths to exclude (supports wildcards)
    -v                 Enable verbose mode
    -f format          Output format: text, json, csv (default: text)
    -o file            Output file (default: stdout)
    -p                 Include private methods/functions (names starting with _)
    -l length          Minimum name length to consider (default: 2)
    --include-dunder   Include dunder methods (__init__, __str__, etc.)
    -h                 Display this help message

EXAMPLES:
    $0 -n 3 -d /path/to/project -e tests,venv,.git -v
    $0 -f json -o dead_code_report.json -n 1 -d src/
    $0 -e "test_*,*_test.py,__pycache__" -p

NOTES:
    - Functions/classes used in decorators, metaclasses, or string references may be flagged
    - Test files and their contents are excluded by default
    - Private methods are excluded unless -p flag is used
    - Results should be manually verified before removing code
EOF
}

log_verbose() {
    if $VERBOSE; then
        echo -e "${BLUE}[VERBOSE]${NC} $*" >&2
    fi
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*" >&2
}

validate_inputs() {
    if [[ ! "$THRESHOLD" =~ ^[0-9]+$ ]] || [ "$THRESHOLD" -lt 0 ]; then
        log_error "Threshold must be a non-negative integer"
        exit 1
    fi
    
    if [[ ! "$MIN_NAME_LENGTH" =~ ^[0-9]+$ ]] || [ "$MIN_NAME_LENGTH" -lt 1 ]; then
        log_error "Minimum name length must be a positive integer"
        exit 1
    fi
    
    if [ ! -d "$DIRECTORY" ]; then
        log_error "Directory '$DIRECTORY' does not exist"
        exit 1
    fi
    
    if [[ ! "$OUTPUT_FORMAT" =~ ^(text|json|csv)$ ]]; then
        log_error "Output format must be one of: text, json, csv"
        exit 1
    fi
    
    if [ -n "$OUTPUT_FILE" ]; then
        local output_dir
        output_dir=$(dirname "$OUTPUT_FILE")
        if [ ! -d "$output_dir" ]; then
            log_error "Output directory '$output_dir' does not exist"
            exit 1
        fi
    fi
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--threshold)
                THRESHOLD="$2"
                shift 2
                ;;
            -d|--directory)
                DIRECTORY="$2"
                shift 2
                ;;
            -e|--exclude)
                IFS=',' read -r -a EXCLUDED_PATHS <<< "$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -f|--format)
                OUTPUT_FORMAT="$2"
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            -p|--include-private)
                INCLUDE_PRIVATE=true
                shift
                ;;
            -l|--min-length)
                MIN_NAME_LENGTH="$2"
                shift 2
                ;;
            --include-dunder)
                IGNORE_DUNDER=false
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Function to build find command with exclusions
build_find_command() {
    local find_cmd=("find" "$DIRECTORY")
    
    # Add exclusions
    if [ "${#EXCLUDED_PATHS[@]}" -gt 0 ]; then
        find_cmd+=("(")
        local first=true
        for excluded_path in "${EXCLUDED_PATHS[@]}"; do
            if [ "$first" = true ]; then
                first=false
            else
                find_cmd+=("-o")
            fi
            # Handle both absolute and relative paths with wildcards
            find_cmd+=("-path" "*/$excluded_path" "-o" "-path" "*/$excluded_path/*" "-o" "-name" "$excluded_path")
        done
        find_cmd+=(")" "-prune" "-o")
    fi
    
    # Common exclusions for Python projects
    find_cmd+=("(")
    find_cmd+=("-name" "__pycache__" "-o" "-name" "*.pyc" "-o" "-name" "*.pyo" "-o" "-name" ".pytest_cache")
    find_cmd+=(")" "-prune" "-o")
    
    find_cmd+=("-type" "f" "-name" "*.py" "-print0")
    
    printf '%s\0' "${find_cmd[@]}"
}

# Function to find all Python files
find_python_files() {
    local find_cmd_str
    find_cmd_str=$(build_find_command)
    
    # Convert null-separated string back to array and execute
    local find_cmd=()
    while IFS= read -r -d '' element; do
        find_cmd+=("$element")
    done <<< "$find_cmd_str"
    
    "${find_cmd[@]}"
}

# Function to check if a name should be ignored
should_ignore_name() {
    local name="$1"
    
    # Check minimum length
    if [ "${#name}" -lt "$MIN_NAME_LENGTH" ]; then
        return 0  # ignore
    fi
    
    # Check private methods/functions
    if ! $INCLUDE_PRIVATE && [[ "$name" =~ ^_[^_] ]]; then
        return 0  # ignore
    fi
    
    # Check dunder methods
    if $IGNORE_DUNDER && [[ "$name" =~ ^__.*__$ ]]; then
        return 0  # ignore
    fi
    
    # Check test-related names
    if [[ "$name" =~ ^test_ ]] || [[ "$name" =~ _test$ ]] || [[ "$name" =~ Test.* ]]; then
        return 0  # ignore
    fi
    
    return 1  # don't ignore
}

# Enhanced function to extract function and class names with better regex
extract_definitions() {
    local file
    declare -A definitions
    
    for file in "${PYTHON_FILES[@]}"; do
        log_verbose "Processing file: $file"
        STATS[total_files]=$((STATS[total_files] + 1))
        
        # Extract function definitions (including async functions)
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                definitions["$line"]="function"
                STATS[total_functions]=$((STATS[total_functions] + 1))
            fi
        done < <(grep -Eho '^\s*(async\s+)?def\s+([a-zA-Z_][a-zA-Z0-9_]*)' "$file" | \
                 sed -E 's/^\s*(async\s+)?def\s+//' || true)
        
        # Extract class definitions
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                definitions["$line"]="class"
                STATS[total_classes]=$((STATS[total_classes] + 1))
            fi
        done < <(grep -Eho '^\s*class\s+([a-zA-Z_][a-zA-Z0-9_]*)' "$file" | \
                 sed -E 's/^\s*class\s+//' | cut -d'(' -f1 || true)
    done
    
    # Output unique definitions with their types
    for name in "${!definitions[@]}"; do
        echo "$name:${definitions[$name]}"
    done | sort
}

# Function to count occurrences with improved accuracy
count_occurrences() {
    local name="$1"
    local count=0
    local file
    
    for file in "${PYTHON_FILES[@]}"; do
        # More sophisticated counting that considers context
        local file_count
        file_count=$(grep -Ec "(^|[^a-zA-Z0-9_])${name}([^a-zA-Z0-9_]|$)" "$file" || echo 0)
        count=$((count + file_count))
    done
    
    echo "$count"
}

# Output functions for different formats
output_text() {
    local results=("$@")
    
    if [ "${#results[@]}" -eq 0 ]; then
        log_info "No potentially dead code found!"
        return
    fi
    
    echo -e "${YELLOW}Potentially Dead Code Report${NC}"
    echo "=================================="
    echo
    
    for result in "${results[@]}"; do
        IFS=':' read -r name type count <<< "$result"
        printf "%-20s %-10s %s occurrences\n" "$name" "($type)" "$count"
    done
    
    echo
    echo "Statistics:"
    echo "  Files processed: ${STATS[total_files]}"
    echo "  Functions found: ${STATS[total_functions]}"
    echo "  Classes found: ${STATS[total_classes]}"
    echo "  Dead code items: ${STATS[dead_code_items]}"
}

output_json() {
    local results=("$@")
    
    echo "{"
    echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
    echo "  \"threshold\": $THRESHOLD,"
    echo "  \"directory\": \"$DIRECTORY\","
    echo "  \"statistics\": {"
    echo "    \"files_processed\": ${STATS[total_files]},"
    echo "    \"functions_found\": ${STATS[total_functions]},"
    echo "    \"classes_found\": ${STATS[total_classes]},"
    echo "    \"dead_code_items\": ${STATS[dead_code_items]}"
    echo "  },"
    echo "  \"dead_code\": ["
    
    local first=true
    for result in "${results[@]}"; do
        IFS=':' read -r name type count <<< "$result"
        if [ "$first" = true ]; then
            first=false
        else
            echo ","
        fi
        echo -n "    {\"name\": \"$name\", \"type\": \"$type\", \"occurrences\": $count}"
    done
    
    echo
    echo "  ]"
    echo "}"
}

output_csv() {
    local results=("$@")
    
    echo "name,type,occurrences"
    for result in "${results[@]}"; do
        IFS=':' read -r name type count <<< "$result"
        echo "$name,$type,$count"
    done
}

# Main execution function
main() {
    parse_arguments "$@"
    validate_inputs
    
    log_info "Starting dead code analysis..."
    log_verbose "Configuration:"
    log_verbose "  Directory: $DIRECTORY"
    log_verbose "  Threshold: $THRESHOLD"
    log_verbose "  Excluded paths: ${EXCLUDED_PATHS[*]:-none}"
    log_verbose "  Output format: $OUTPUT_FORMAT"
    log_verbose "  Include private: $INCLUDE_PRIVATE"
    
    # Find Python files
    log_verbose "Finding Python files..."
    mapfile -d '' -t PYTHON_FILES < <(find_python_files)
    
    if [ "${#PYTHON_FILES[@]}" -eq 0 ]; then
        log_warning "No Python files found in the specified directory"
        exit 0
    fi
    
    log_info "Found ${#PYTHON_FILES[@]} Python files"
    
    # Extract definitions and analyze
    log_verbose "Extracting function and class definitions..."
    local results=()
    
    while IFS= read -r definition; do
        if [[ -z "$definition" ]]; then
            continue
        fi
        
        IFS=':' read -r name type <<< "$definition"
        
        if should_ignore_name "$name"; then
            log_verbose "Ignoring: $name"
            continue
        fi
        
        log_verbose "Counting occurrences for: $name"
        local count
        count=$(count_occurrences "$name")
        
        if [ "$count" -lt "$THRESHOLD" ]; then
            results+=("$name:$type:$count")
            STATS[dead_code_items]=$((STATS[dead_code_items] + 1))
        fi
        
    done < <(extract_definitions)
    
    # Output results
    local output_func
    case "$OUTPUT_FORMAT" in
        json) output_func=output_json ;;
        csv) output_func=output_csv ;;
        *) output_func=output_text ;;
    esac
    
    if [ -n "$OUTPUT_FILE" ]; then
        $output_func "${results[@]}" > "$OUTPUT_FILE"
        log_info "Results written to: $OUTPUT_FILE"
    else
        $output_func "${results[@]}"
    fi
    
    log_info "Analysis complete"
}

# Run main function with all arguments
main "$@"
