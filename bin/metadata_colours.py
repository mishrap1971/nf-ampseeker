#!/usr/bin/env python3
"""
Build results/config/metadata_colours.json from the cohort columns.

"""
import argparse
import json

import pandas as pd

PALETTES = {
    "Plotly": ["#636EFA", "#EF553B", "#00CC96", "#AB63FA", "#FFA15A", "#19D3F3", "#FF6692", "#B6E880", "#FF97FF", "#FECB52"],
    "Safe": ["#88CCEE", "#CC6677", "#DDCC77", "#117733", "#332288", "#AA4499", "#44AA99", "#999933", "#882255", "#661100", "#6699CC", "#888888"],
    "Vivid": ["#E58606", "#5D69B1", "#52BCA3", "#99C945", "#CC61B0", "#24796C", "#DAA51B", "#2F8AC4", "#764E9F", "#ED645A", "#CC3A8E", "#A5AA99"],
    "Pastel": ["#B6B6F2", "#FFB6B6", "#BFFFBF", "#FFE2BF", "#BFE2FF", "#FFB6FF", "#E2FFB6", "#FFD9B6", "#B6FFE2", "#D9B6FF"],
    "Dark2": ["#1B9E77", "#D95F02", "#7570B3", "#E7298A", "#66A61E", "#E6AB02", "#A6761D", "#666666"],
}
GREY = "#808080"
UNASSIGNED = "unassigned"


def create_color_mapping(df, columns, repeated_colors=True):
    color_mappings = {}
    palette_names = list(PALETTES.keys())

    for i, col in enumerate(columns):
        colors = PALETTES[palette_names[i % len(palette_names)]]
        unique_values = df[col].unique()
        n_colors = len(colors)

        column_colors = {}
        for j, value in enumerate(unique_values):
            if value == UNASSIGNED:
                column_colors[value] = GREY
            else:
                color_idx = j % n_colors if repeated_colors else j
                column_colors[value] = colors[color_idx]

        color_mappings[col] = column_colors

    return color_mappings


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--metadata", required=True)
    p.add_argument("--cohort-columns", required=True, help="comma-separated column names")
    p.add_argument("--out", default="metadata_colours.json")
    args = p.parse_args()

    metadata = pd.read_csv(args.metadata, sep="\t")
    cohort_columns = [c for c in args.cohort_columns.split(",") if c]

    mapping = create_color_mapping(metadata, columns=cohort_columns)
    with open(args.out, "w") as f:
        json.dump(mapping, f, indent=2)


if __name__ == "__main__":
    main()
