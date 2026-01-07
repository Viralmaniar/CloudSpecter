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


# ---------------- CONFIG ----------------
export AWS_EC2_METADATA_DISABLED=true
set -o pipefail

TESTFILE="frogy.txt"
TMPDIR="$(mktemp -d)"
GREEN="\e[92m"; RED="\e[91m"; YELLOW="\e[93m"; NC="\e[0m"

cleanup() {
    rm -f "$TESTFILE"
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

log()   { echo -e "${GREEN}[*] $1${NC}"; }
warn()  { echo -e "${YELLOW}[!] $1${NC}"; }
error() { echo -e "${RED}[X] $1${NC}"; }

require_cmd() {
    command -v "$1" &>/dev/null || { error "Missing dependency: $1"; exit 1; }
}

echo "Frogy_was_here" > "$TESTFILE"

# ---------------- AWS ----------------
check_aws() {
    require_cmd aws
    BUCKET="$1"
    AWS_ARGS=""
    READABLE=false
    WRITABLE=false
    SEVERITY="INFO"

    OUTPUT_FILE="files_${BUCKET}.txt"
    > "$OUTPUT_FILE"

    log "Checking AWS S3 bucket: $BUCKET"

    # Determine credentials / public access
    aws sts get-caller-identity &>/dev/null || {
        warn "AWS credentials not found. Using public access (--no-sign-request)"
        AWS_ARGS="--no-sign-request"
    }

    # READ
    aws s3 ls "s3://$BUCKET" $AWS_ARGS \
        >"$TMPDIR/aws_read.out" 2>"$TMPDIR/aws_read.err"

    if [ $? -eq 0 ]; then
        READABLE=true
        log "Bucket is readable"

        if [ "$AWS_ARGS" = "--no-sign-request" ]; then
            log "Dumping public objects to $OUTPUT_FILE"
            aws s3 ls "s3://$BUCKET" --recursive --no-sign-request \
            | awk '{print "https://'${BUCKET}'.s3.amazonaws.com/"$4}' >> "$OUTPUT_FILE"
        fi
    else
        warn "Bucket not readable"
        cat "$TMPDIR/aws_read.err"
    fi

    # WRITE
    log "Testing WRITE access"
    aws s3 cp "$TESTFILE" "s3://$BUCKET/$TESTFILE" $AWS_ARGS \
        >"$TMPDIR/aws_write.out" 2>"$TMPDIR/aws_write.err"

    if [ $? -eq 0 ]; then
        WRITABLE=true
        log "Bucket is WRITABLE"
        aws s3 rm "s3://$BUCKET/$TESTFILE" $AWS_ARGS &>/dev/null
    else
        warn "Bucket is NOT writable"
    fi

    # SEVERITY
    if $READABLE && $WRITABLE && [ "$AWS_ARGS" != "" ]; then
        SEVERITY="CRITICAL (anonymous read/write)"
    elif $READABLE && ! $WRITABLE && [ "$AWS_ARGS" != "" ]; then
        SEVERITY="HIGH (anonymous read)"
    elif $READABLE && $WRITABLE; then
        SEVERITY="MEDIUM (authenticated write)"
    elif $READABLE; then
        SEVERITY="LOW (authenticated read)"
    fi

    log "Severity: $SEVERITY"
}

# ---------------- GCP ----------------
check_gcp() {
    require_cmd gsutil
    BUCKET="$1"
    GS_ARGS=""
    READABLE=false
    WRITABLE=false
    SEVERITY="INFO"

    OUTPUT_FILE="files_${BUCKET}.txt"
    > "$OUTPUT_FILE"

    log "Checking GCP GCS bucket: $BUCKET"

    gcloud auth list --format="value(account)" | grep -q . || {
        warn "GCP credentials not found. Using anonymous access"
        GS_ARGS="-n"
    }

    # READ
    gsutil ls $GS_ARGS "gs://$BUCKET" \
        >"$TMPDIR/gcp_read.out" 2>"$TMPDIR/gcp_read.err"

    if [ $? -eq 0 ]; then
        READABLE=true
        log "Bucket is readable"

        if [ "$GS_ARGS" = "-n" ]; then
            log "Dumping public objects to $OUTPUT_FILE"
            gsutil ls -r $GS_ARGS "gs://$BUCKET/**" \
            | sed 's|gs://|https://storage.googleapis.com/|' >> "$OUTPUT_FILE"
        fi
    else
        warn "Bucket not readable"
        cat "$TMPDIR/gcp_read.err"
    fi

    # WRITE
    log "Testing WRITE access"
    gsutil cp $GS_ARGS "$TESTFILE" "gs://$BUCKET/$TESTFILE" \
        >"$TMPDIR/gcp_write.out" 2>"$TMPDIR/gcp_write.err"

    if [ $? -eq 0 ]; then
        WRITABLE=true
        log "Bucket is WRITABLE"
        gsutil rm $GS_ARGS "gs://$BUCKET/$TESTFILE" &>/dev/null
    else
        warn "Bucket is NOT writable"
    fi

    # SEVERITY
    if $READABLE && $WRITABLE && [ "$GS_ARGS" != "" ]; then
        SEVERITY="CRITICAL (anonymous read/write)"
    elif $READABLE && ! $WRITABLE && [ "$GS_ARGS" != "" ]; then
        SEVERITY="HIGH (anonymous read)"
    elif $READABLE && $WRITABLE; then
        SEVERITY="MEDIUM (authenticated write)"
    elif $READABLE; then
        SEVERITY="LOW (authenticated read)"
    fi

    log "Severity: $SEVERITY"
}

# ---------------- AZURE ----------------
check_azure() {
    require_cmd az
    CONTAINER="$1"
    ACCOUNT="$2"
    READABLE=false
    WRITABLE=false
    SEVERITY="INFO"

    OUTPUT_FILE="files_${CONTAINER}.txt"
    > "$OUTPUT_FILE"

    log "Checking Azure Blob container: $CONTAINER"

    az storage blob list \
        --container-name "$CONTAINER" \
        --account-name "$ACCOUNT" \
        --auth-mode login \
        >"$TMPDIR/az_read.out" 2>"$TMPDIR/az_read.err"

    if [ $? -eq 0 ]; then
        READABLE=true
        log "Container is readable"
    else
        warn "Container not readable"
        cat "$TMPDIR/az_read.err"
    fi

    # WRITE
    log "Testing WRITE access"
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

    # SEVERITY
    if $READABLE && $WRITABLE; then
        SEVERITY="MEDIUM (authenticated read/write)"
    elif $READABLE; then
        SEVERITY="LOW (authenticated read)"
    fi

    log "Severity: $SEVERITY"
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

log "Results saved to: $OUTPUT_FILE"
