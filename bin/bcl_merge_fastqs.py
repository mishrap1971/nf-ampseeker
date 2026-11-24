#!/usr/bin/env python3
"""
Merge per-run bcl2fastq output into per-sample FASTQs.

"""
import argparse
import glob
import json
import os
import shutil
import sys


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--run-dirs", required=True, nargs="+", help="per-run bcl2fastq output dirs")
    p.add_argument("--samples", required=True, help="comma-separated sample_id list")
    p.add_argument("--outdir", default="reads")
    args = p.parse_args()

    samples = [s for s in args.samples.split(",") if s]
    os.makedirs(os.path.join(args.outdir, "Stats"), exist_ok=True)

    for sample in samples:
        r1_files = sorted(
            f for d in args.run_dirs for f in glob.glob(f"{d}/{sample}_*_R1_001.fastq.gz")
        )
        r2_files = sorted(
            f for d in args.run_dirs for f in glob.glob(f"{d}/{sample}_*_R2_001.fastq.gz")
        )

        if not r1_files or not r2_files:
            sys.exit(f"bcl_merge_fastqs.py: missing one or more run FASTQs for sample: {sample}")

        with open(os.path.join(args.outdir, f"{sample}_1.fastq.gz"), "wb") as out_fh:
            for f in r1_files:
                with open(f, "rb") as in_fh:
                    shutil.copyfileobj(in_fh, out_fh)

        with open(os.path.join(args.outdir, f"{sample}_2.fastq.gz"), "wb") as out_fh:
            for f in r2_files:
                with open(f, "rb") as in_fh:
                    shutil.copyfileobj(in_fh, out_fh)

    i1_files = sorted(f for d in args.run_dirs for f in glob.glob(f"{d}/*_I1_001.fastq.gz"))
    i2_files = sorted(f for d in args.run_dirs for f in glob.glob(f"{d}/*_I2_001.fastq.gz"))

    if i1_files:
        with open(os.path.join(args.outdir, "I1_combined.fastq.gz"), "wb") as out_fh:
            for f in i1_files:
                with open(f, "rb") as in_fh:
                    shutil.copyfileobj(in_fh, out_fh)
    if i2_files:
        with open(os.path.join(args.outdir, "I2_combined.fastq.gz"), "wb") as out_fh:
            for f in i2_files:
                with open(f, "rb") as in_fh:
                    shutil.copyfileobj(in_fh, out_fh)

    # The first run folder's DemultiplexingStats.xml stands in for the merged one (as in the original workflow).
    shutil.copyfile(
        os.path.join(args.run_dirs[0], "Stats", "DemultiplexingStats.xml"),
        os.path.join(args.outdir, "Stats", "DemultiplexingStats.xml"),
    )

    merged_stats = {"ConversionResults": []}
    for run_dir in args.run_dirs:
        with open(os.path.join(run_dir, "Stats", "Stats.json")) as fh:
            data = json.load(fh)
        merged_stats["ConversionResults"].extend(data.get("ConversionResults", []))

    with open(os.path.join(args.outdir, "Stats", "Stats.json"), "w") as fh:
        json.dump(merged_stats, fh)


if __name__ == "__main__":
    main()
