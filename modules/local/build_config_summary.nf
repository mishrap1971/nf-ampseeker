// makes a small YAML of the reference files settings, shown in the run-information notebook

process BUILD_CONFIG_SUMMARY {
    label 'process_single'

    input:
    val reference_name
    val reference_fasta
    val reference_gff3
    val reference_snpeffdb

    output:
    path "config_summary.yaml", emit: yaml

    script:
    """
    cat <<-EOF > config_summary.yaml
    reference-name: "${reference_name}"
    reference-fasta: "${reference_fasta}"
    reference-gff3: "${reference_gff3}"
    reference-snpeffdb: "${reference_snpeffdb}"
    EOF
    """

    stub:
    """
    touch config_summary.yaml
    """
}
