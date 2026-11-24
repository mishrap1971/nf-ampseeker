#!/usr/bin/env python3
"""
Build the canonical sample metadata table (results/config/metadata.tsv).

Two modes of input, paired-end fastqs and bcl files:

--mode metadata    : a single pre-built TSV (config['metadata'])
--mode samplesheet : one or more Illumina SampleSheet.csv files, one per
                       run directory (config['from-bcl'] = True)
"""
import argparse
import os
import re
import sys

import pandas as pd


def metadata_from_sample_sheet(sample_sheet_path):
    with open(sample_sheet_path, "r") as f:
        content = f.read()

    data_section = re.search(r"\[(BCLConvert_)?Data\],+\n(.*?)($|\[)", content, re.DOTALL)
    if not data_section:
        raise ValueError(
            f"Could not find [Data] or [BCLConvert_Data] section in '{sample_sheet_path}'"
        )

    data_content = data_section.group(2)
    lines = data_content.strip().split("\n")

    df = pd.DataFrame([line.split(",") for line in lines[1:]], columns=lines[0].split(","))
    df = df.rename(columns={"sample_ID": "sample_id"})

    if "well" in df.columns:
        df["well_letter"] = df["well"].str[0]
        df["well_number"] = df["well"].str[1:].astype(str)
        df = df.drop(columns=["well"])

    if "plate_name" in df.columns:
        df = df.rename(columns={"plate_name": "plate"})

    return df


def metadata_from_sample_sheets(run_dirs):
    """run_dirs: list of staged run directories, each containing SampleSheet.csv."""
    metadata = []
    for run_dir in run_dirs:
        sheet_path = os.path.join(run_dir, "SampleSheet.csv")
        if not os.path.exists(sheet_path):
            raise ValueError(f"SampleSheet.csv not found in run directory '{run_dir}'")
        df = metadata_from_sample_sheet(sheet_path).copy()
        # identifies which staged run directory each sample's .bcl file comes from
        df["illumina_run_dir"] = os.path.basename(os.path.normpath(run_dir))
        metadata.append(df)

    metadata = pd.concat(metadata, ignore_index=True)

    duplicate_ids = metadata["sample_id"].duplicated(keep=False)
    if duplicate_ids.any():
        duplicated = metadata.loc[duplicate_ids].copy()
        metadata_cols = [c for c in duplicated.columns if c not in ["illumina_run_dir"]]
        conflict_samples = []

        for sample_id, group in duplicated.groupby("sample_id"):
            group = group[metadata_cols]
            if any(
                group[col].dropna().astype(str).nunique() > 1
                for col in group.columns
                if col != "sample_id"
            ):
                conflict_samples.append(sample_id)

        if conflict_samples:
            raise ValueError(
                "Duplicate sample_id values with conflicting metadata were found "
                "across SampleSheets: " + ", ".join(map(str, conflict_samples))
            )

        metadata = metadata.drop_duplicates(subset=["sample_id"], keep="first")

    return metadata


def load_metadata(mode, inputs, cohort_columns):
    if mode == "metadata":
        metadata_path = inputs[0]
        if not os.path.exists(metadata_path):
            raise ValueError(
                f"Metadata file '{metadata_path}' does not exist. Is the path correct, "
                "or do you mean to run --from_bcl instead?"
            )
        metadata = pd.read_csv(metadata_path, sep="\t")
    elif mode == "samplesheet":
        if not inputs:
            raise ValueError("No SampleSheet run directories were provided for from-bcl mode.")
        metadata = metadata_from_sample_sheets(inputs)
    else:
        raise ValueError(f"Unknown mode '{mode}', expected 'metadata' or 'samplesheet'.")

    missing = [c for c in cohort_columns if c not in metadata.columns]
    if missing:
        raise ValueError(
            f"Not all provided cohort columns are present in the metadata file: {missing}"
        )

    if "sample_ID" in metadata.columns:
        metadata = metadata.rename(columns={"sample_ID": "sample_id"})

    return metadata


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--mode", required=True, choices=["metadata", "samplesheet"])
    p.add_argument(
        "--inputs",
        required=True,
        nargs="+",
        help="metadata mode: single TSV path. samplesheet mode: one or more staged run dirs.",
    )
    p.add_argument("--cohort-columns", required=True, help="comma-separated column names")
    p.add_argument("--out", default="metadata.tsv")
    args = p.parse_args()

    cohort_columns = [c for c in args.cohort_columns.split(",") if c]

    try:
        metadata = load_metadata(args.mode, args.inputs, cohort_columns)
    except ValueError as e:
        sys.exit(f"build_metadata.py: {e}")

    metadata.to_csv(args.out, sep="\t", index=False)


if __name__ == "__main__":
    main()
