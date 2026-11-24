// runs FastQC on combined Illumina index reads

process FASTQC_INDEX_READS {
    tag "$meta.id"
    label 'process_low'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("${meta.id}.html"), path("${meta.id}.zip"), emit: report

    script:
    """
    fastqc ${reads} --outdir .
    mv \$(basename ${reads} .fastq.gz)_fastqc.html ${meta.id}.html
    mv \$(basename ${reads} .fastq.gz)_fastqc.zip ${meta.id}.zip
    """

    stub:
    """
    touch ${meta.id}.html ${meta.id}.zip
    """
}
