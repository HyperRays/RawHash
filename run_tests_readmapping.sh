#!/bin/bash
#SBATCH --job-name=rh2
#SBATCH --output=rh2-%j.out
#SBATCH --error=rh2-%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --mem=200G
#SBATCH --time=10:00:00

### Read Mapping

export PATH="./bin:$PATH"

# ── Configuration: one entry per dataset ──────────────────────────
# Format: "label:path"
DATASETS=(
"d1_sars-cov-2_r94:/mnt/galactica/skuvalekar/genome_data/test/data/d1_sars-cov-2_r94"
"d2_ecoli_r94:/mnt/galactica/skuvalekar/genome_data/test/data/d2_ecoli_r94"
"d3_yeast_r94:/mnt/galactica/skuvalekar/genome_data/test/data/d3_yeast_r94"
"d4_green_algae_r94:/mnt/galactica/skuvalekar/genome_data/test/data/d4_green_algae_r94"
"d5_human_na12878_r94:/mnt/galactica/skuvalekar/genome_data/test/data/d5_human_na12878_r94"
"d6_ecoli_r104:/mnt/galactica/skuvalekar/genome_data/test/data/d6_ecoli_r104"
"d7_saureus_r104:/mnt/galactica/skuvalekar/genome_data/test/data/d7_saureus_r104"
)

SWEEP="${SWEEP:-16,32,64,128}"
OUTDIR="./rawhash2"
mkdir -p "${OUTDIR}"

LOG="${OUTDIR}/benchmark.csv"
echo "dataset,threads,time_sec,throughput_bytes_per_sec" > "$LOG"

# ── Loop over datasets ────────────────────────────────────────────
for entry in "${DATASETS[@]}"; do
    IFS=":" read -r LABEL BASE <<< "$entry"

    FAST5="${BASE}/fast5_files"
    REF="${BASE}/ref.fa"

    # Select pore model
    if [[ "$LABEL" == *r104* ]]; then
        PORE="./extern/local_kmer_models/uncalled_r1041_model_only_means.txt"
        PARAMS="--r10"
    else
        PORE="./extern/kmer_models/legacy/legacy_r9.4_180mv_450bps_6mer/template_median68pA.model"
        PARAMS=""
    fi

    PRESET="sensitive"

    # Compute total input size (bytes)
    INPUT_SIZE=$(du -sb "$FAST5" | cut -f1)

    echo "Processing dataset: $LABEL (size=${INPUT_SIZE} bytes)"

    # ── Thread sweep ──────────────────────────────────────────────
    IFS=',' read -ra THREADS <<< "$SWEEP"
    for THREAD in "${THREADS[@]}"; do

        PREFIX="${LABEL}_t${THREAD}"

        echo "  Running with ${THREAD} threads..."

        START=$(date +%s)

        bash ./test/scripts/run_rawhash2.sh \
            "${OUTDIR}" \
            "${PREFIX}" \
            "${FAST5}" \
            "${REF}" \
            "${PORE}" \
            "${PRESET}" \
            "${THREAD}" \
            "${PARAMS}" \
            > "${OUTDIR}/${PREFIX}.out" \
            2> "${OUTDIR}/${PREFIX}.err"

        END=$(date +%s)
        ELAPSED=$((END - START))

        # Avoid division by zero
        if [[ "$ELAPSED" -gt 0 ]]; then
            THROUGHPUT=$(awk "BEGIN {print (${INPUT_SIZE}/1024/1024) / ${ELAPSED}}")
        else
            THROUGHPUT=0
        fi

        echo "${LABEL},${THREAD},${ELAPSED},${THROUGHPUT}" >> "$LOG"

    done
done