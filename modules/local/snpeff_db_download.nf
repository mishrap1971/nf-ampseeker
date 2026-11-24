// downloads a named snpEff database (used only when --custom_snpeffdb is false)

process SNPEFF_DB_DOWNLOAD {
    tag "$snpeffdb_name"
    label 'process_single'
    label 'error_retry'

    input:
    val snpeffdb_name

    output:
    path "${snpeffdb_name}", emit: db_dir

    script:
    """
    snpEff download ${snpeffdb_name} -dataDir "\$PWD"
    """

    stub:
    """
    mkdir -p ${snpeffdb_name}
    touch ${snpeffdb_name}/snpEffectPredictor.bin
    """
}
