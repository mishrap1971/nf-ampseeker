// Illumina branch: trim reads (fastp), align with bwa mem, index the BAMs and call variants for both the target regions and whole amplicons

include { FASTP                                } from '../../modules/nf-core/fastp/main'
include { BWA_INDEX                            } from '../../modules/nf-core/bwa/index/main'
include { BWA_MEM as BWA_ALIGN                 } from '../../modules/nf-core/bwa/mem/main'
include { SAMTOOLS_INDEX                       } from '../../modules/nf-core/samtools/index/main'
include { BCFTOOLS_MPILEUP_CALL                } from '../../modules/local/bcftools_mpileup_call'

workflow MAP_CALL_ILLUMINA {

    take:
    ch_reads
    ch_fasta
    ch_fasta_fai
    targets_bed
    ploidy_file

    main:
    // trim adapters and low-quality bases
    FASTP(
        ch_reads.map { meta, reads -> tuple(meta + [ single_end: false ], reads, []) },
        false, false, false
    )

    // build the bwa index for reference and then align each sample to it
    BWA_INDEX( ch_fasta )

    BWA_ALIGN( FASTP.out.reads, BWA_INDEX.out.index, ch_fasta, true )

    SAMTOOLS_INDEX( BWA_ALIGN.out.bam )

    // BAM + index per sample
    ch_bam = BWA_ALIGN.out.bam.join( SAMTOOLS_INDEX.out.index )

    // each sample is called twice: once for 'targets' and once for 'amplicons'
    ch_calls_in = ch_bam.combine( [ 'targets', 'amplicons' ] )
        .map { meta, bam, bai, call_type -> tuple(meta + [ call_type: call_type ], bam, bai) }

    BCFTOOLS_MPILEUP_CALL(
        ch_calls_in,
        ch_fasta.combine( ch_fasta_fai.map { m, fai -> fai } ).map { m, fasta, fai -> tuple(m, fasta, fai) }.first(),
        ploidy_file,
        targets_bed
    )

    emit:
    bam        = ch_bam
    calls      = BCFTOOLS_MPILEUP_CALL.out.vcf
    fastp_json = FASTP.out.json.map { meta, json -> json }
}
