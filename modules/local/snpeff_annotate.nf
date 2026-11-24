// annotates the merged VCF with variant effects using snpEff
// -dataDir must be an absolute path, though a relative one is resolved inside the container's snpEff folder

process SNPEFF_ANNOTATE {
    tag "${meta.id}/${meta.call_type}"
    label 'process_medium'
    label 'error_retry'

    input:
    tuple val(meta), path(vcf)
    path db_dir

    output:
    tuple val(meta), path("${meta.id}.annot.vcf"), emit: vcf
    tuple val(meta), path("${meta.id}.summary.html"), emit: html
    tuple val(meta), path("${meta.id}.summary.csv"), emit: csv

    script:
    """
    snpEff eff ${db_dir.name} -dataDir "\$PWD" -configOption mysnpeffdb.genome=mysnpeffdb \\
        -stats ${meta.id}.summary.html -csvStats ${meta.id}.summary.csv -ud 0 \\
        ${vcf} > ${meta.id}.annot.vcf
    """

    stub:
    """
    touch ${meta.id}.annot.vcf ${meta.id}.summary.html ${meta.id}.summary.csv
    """
}
