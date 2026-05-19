#!/bin/bash
#SBATCH --job-name=rawsamble_sars
#SBATCH --output=rawsamble_sars-%j.out
#SBATCH --error=rawsamble_sars-%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=256
#SBATCH --mem=300G
#SBATCH --time=1-00:00:00

make clean
rm -rf bin/*
make -j

export HDF5_PLUGIN_PATH=/home/skuvalekar/downloads/RawHash/ont-vbz-hdf-plugin-1.0.1-Linux/usr/local/hdf5/lib/plugin
export PATH="./bin:$PATH"

FAST5="/mnt/galactica/skuvalekar/genome_data/test/data/d1_sars-cov-2_r94/fast5_files"
PORE="/mnt/galactica/skuvalekar/downloads/RawHash/extern/kmer_models/legacy/legacy_r9.4_180mv_450bps_6mer/template_median68pA.model"
OUTDIR="./rawsamble_sars_runs"
THREAD=256
PRESET="ava"
PREFIX="d1_sars-cov-2_r94"

mkdir -p "${OUTDIR}"

echo "=== Rawsamble: indexing reads ==="
/usr/bin/time -vpo "${OUTDIR}/${PREFIX}_rawsamble_index_${PRESET}.time" \
    rawhash2 -x ${PRESET} -t ${THREAD} \
    -p ${PORE} \
    -d "${OUTDIR}/${PREFIX}_rawsamble_${PRESET}.ind" \
    ${FAST5}

echo "=== Rawsamble: all-vs-all overlapping ==="
/usr/bin/time -vpo "${OUTDIR}/${PREFIX}_rawsamble_map_${PRESET}.time" \
    rawhash2 -x ${PRESET} -t ${THREAD} \
    -o "${OUTDIR}/${PREFIX}_rawsamble_${PRESET}.paf" \
    "${OUTDIR}/${PREFIX}_rawsamble_${PRESET}.ind" \
    ${FAST5}

echo "=== Done ==="
echo "Overlap PAF: ${OUTDIR}/${PREFIX}_rawsamble_${PRESET}.paf"
