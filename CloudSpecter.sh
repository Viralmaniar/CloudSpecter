#!/usr/bin/env bash

########################################
# CloudSpecter
# Multi-cloud bucket permission checker
# AWS S3 | GCP GCS | Azure Blob
# Supports public buckets automatically
########################################
COLORS=(
  "\e[31m"  # Red
  "\e[32m"  # Green
  "\e[33m"  # Yellow
  "\e[34m"  # Blue
  "\e[35m"  # Magenta
  "\e[36m"  # Cyan
  "\e[91m"  # Bright Red
  "\e[92m"  # Bright Green
  "\e[93m"  # Bright Yellow
  "\e[94m"  # Bright Blue
  "\e[95m"  # Bright Magenta
 163593
  "\e[96m"  # Bright Cyan
)

# Pick a random color
RANDOM_COLOR=${COLORS[$RANDOM % ${#COLORS[@]}]}

# Reset color
NC="\e[0m"

echo -e "${RANDOM_COLOR}
                                                                                                                        
    ▄▄▄▄   ▄▄▄▄                                ▄▄    ▄▄▄▄                                                               
  ██▀▀▀▀█  ▀▀██                                ██  ▄█▀▀▀▀█                                   ██                         
 ██▀         ██       ▄████▄   ██    ██   ▄███▄██  ██▄       ██▄███▄    ▄████▄    ▄█████▄  ███████    ▄████▄    ██▄████ 
 ██          ██      ██▀  ▀██  ██    ██  ██▀  ▀██   ▀████▄   ██▀  ▀██  ██▄▄▄▄██  ██▀    ▀    ██      ██▄▄▄▄██   ██▀     
 ██▄         ██      ██    ██  ██    ██  ██    ██       ▀██  ██    ██  ██▀▀▀▀▀▀  ██          ██      ██▀▀▀▀▀▀   ██      
  ██▄▄▄▄█    ██▄▄▄   ▀██▄▄██▀  ██▄▄▄███  ▀██▄▄███  █▄▄▄▄▄█▀  ███▄▄██▀  ▀██▄▄▄▄█  ▀██▄▄▄▄█    ██▄▄▄   ▀██▄▄▄▄█   ██      
    ▀▀▀▀      ▀▀▀▀     ▀▀▀▀     ▀▀▀▀ ▀▀    ▀▀▀ ▀▀   ▀▀▀▀▀    ██ ▀▀▀      ▀▀▀▀▀     ▀▀▀▀▀      ▀▀▀▀     ▀▀▀▀▀    ▀▀      
                                                             ██   - By Viral Maniar
                                                                  - Preemptive Cybersecurity pty ltd
                                                                  - @ManiarViral                                                                                                                                                                       
${NC}"

export AWS_EC2_METADATA_DISABLED=true
set -o pipefail

TESTFILE="hacker.txt"
TMPDIR="$(mktemp -d)"
GREEN="\e[92m"; RED="\e[91m"; YELLOW="\e[93m"; NC="\e[0m"

cleanup() { rm -f "$TESTFILE"; rm -rf "$TMPDIR"; }
trap cleanup EXIT

log()   { echo -e "${GREEN}[*] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[X] $1${NC}"; }

require_cmd() { command -v "$1" &>/dev/null || { error "Missing command: $1"; exit 1; }; }

echo "hacker was here" > "$TESTFILE"

# ---------------- AWS ----------------
check_aws() {
    require_cmd aws
    BUCKET="$1"
    AWS_ARGS=""
    SEVERITY="INFO"

    log "Checking AWS S3 bucket: $BUCKET"

    aws sts get-caller-identity &>/dev/null || AWS_ARGS="--no-sign-request"

    aws s3 ls "s3://$BUCKET" $AWS_ARGS \
        >"$TMPDIR/aws_read.out" 2>"$TMPDIR/aws_read.err"
    READABLE=false
    WRITABLE=false

    if [ $? -eq 0 ]; then
        READABLE=true
        log "Bucket is readable"
    else
        warn "Bucket not readable"
        cat "$TMPDIR/aws_read.err"
    fi

    # Write test
    aws s3 cp "$TESTFILE" "s3://$BUCKET/$TESTFILE" $AWS_ARGS \
        >"$TMPDIR/aws_write.out" 2>"$TMPDIR/aws_write.err"

    if [ $? -eq 0 ]; then
        WRITABLE=true
        log "Bucket is WRITABLE"
        aws s3 rm "s3://$BUCKET/$TESTFILE" $AWS_ARGS &>/dev/null
    else
        warn "Bucket is NOT writable"
    fi

    # Severity rating
    if [ "$READABLE" = true ] && [ "$WRITABLE" = true ] && [ "$AWS_ARGS" != "" ]; then
        SEVERITY="CRITICAL (anonymous write)"
    elif [ "$READABLE" = true ] && [ "$WRITABLE" = false ] && [ "$AWS_ARGS" != "" ]; then
        SEVERITY="HIGH (anonymous read)"
    elif [ "$READABLE" = true ] && [ "$WRITABLE" = true ]; then
        SEVERITY="MEDIUM (authenticated write)"
    elif [ "$READABLE" = true ]; then
        SEVERITY="LOW (authenticated read)"
    fi

    log "Severity Rating: $SEVERITY"
}

# ---------------- GCP ----------------
check_gcp() {
    require_cmd gsutil
    BUCKET="$1"
    GS_ARGS=""
    SEVERITY="INFO"

    log "Checking GCP GCS bucket: $BUCKET"

    gcloud auth list --format="value(account)" | grep -q . || GS_ARGS="-n"

    gsutil ls $GS_ARGS "gs://$BUCKET" \
        >"$TMPDIR/gcp_read.out" 2>"$TMPDIR/gcp_read.err"
    READABLE=false
    WRITABLE=false

    if [ $? -eq 0 ]; then
        READABLE=true
        log "Bucket is readable"
    else
        warn "Bucket not readable"
        cat "$TMPDIR/gcp_read.err"
    fi

    # Write test
    gsutil cp $GS_ARGS "$TESTFILE" "gs://$BUCKET/$TESTFILE" \
        >"$TMPDIR/gcp_write.out" 2>"$TMPDIR/gcp_write.err"

    if [ $? -eq 0 ]; then
        WRITABLE=true
        log "Bucket is WRITABLE"
        gsutil rm $GS_ARGS "gs://$BUCKET/$TESTFILE" &>/dev/null
    else
        warn "Bucket is NOT writable"
    fi

    # Severity rating
    if [ "$READABLE" = true ] && [ "$WRITABLE" = true ] && [ "$GS_ARGS" != "" ]; then
        SEVERITY="CRITICAL (anonymous write)"
    elif [ "$READABLE" = true ] && [ "$WRITABLE" = false ] && [ "$GS_ARGS" != "" ]; then
        SEVERITY="HIGH (anonymous read)"
    elif [ "$READABLE" = true ] && [ "$WRITABLE" = true ]; then
        SEVERITY="MEDIUM (authenticated write)"
    elif [ "$READABLE" = true ]; then
        SEVERITY="LOW (authenticated read)"
    fi

    log "Severity Rating: $SEVERITY"
}

# ---------------- Azure ----------------
check_azure() {
    require_cmd az
    CONTAINER="$1"
    ACCOUNT="$2"
    SEVERITY="INFO"

    log "Checking Azure Blob container: $CONTAINER"

    az storage blob list \
        --container-name "$CONTAINER" \
        --account-name "$ACCOUNT" \
        --auth-mode login \
        >"$TMPDIR/az_read.out" 2>"$TMPDIR/az_read.err"
    READABLE=false
    WRITABLE=false

    if [ $? -eq 0 ]; then
        READABLE=true
        log "Container is readable"
    else
        warn "Container not readable"
        cat "$TMPDIR/az_read.err"
    fi

    # Write test
    az storage blob upload \
        --container-name "$CONTAINER" \
        --account-name "$ACCOUNT" \
        --name "$TESTFILE" \
        --file "$TESTFILE" \
        --auth-mode login \
        >"$TMPDIR/az_write.out" 2>"$TMPDIR/az_write.err"

    if [ $? -eq 0 ]; then
        WRITABLE=true
        log "Container is WRITABLE"
        az storage blob delete \
            --container-name "$CONTAINER" \
            --account-name "$ACCOUNT" \
            --name "$TESTFILE" \
            --auth-mode login &>/dev/null
    else
        warn "Container is NOT writable (Azure requires auth)"
    fi

    # Severity rating
    if [ "$READABLE" = true ] && [ "$WRITABLE" = true ]; then
        SEVERITY="MEDIUM (authenticated write)"
    elif [ "$READABLE" = true ]; then
        SEVERITY="LOW (authenticated read)"
    else
        SEVERITY="INFO (not readable)"
    fi

    log "Severity Rating: $SEVERITY"
}

# ---------------- MAIN ----------------
case "$1" in
    aws)   check_aws "$2" ;;
    gcp)   check_gcp "$2" ;;
    azure) check_azure "$2" "$3" ;;
    *)
        echo "Usage:"
        echo "  $0 aws <bucket>"
        echo "  $0 gcp <bucket>"
        echo "  $0 azure <container> <storage_account>"
        exit 1
        ;;
esac
