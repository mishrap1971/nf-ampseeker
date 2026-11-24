// coverage (mosdepth), alignment and variant statistics + the MultiQC report. each part can be switched off with the qc_* parameters.

include { MOSDEPTH          } from '../../modules/nf-core/mosdepth/main'
include { SAMTOOLS_FLAGSTAT } from '../../modules/nf-core/samtools/flagstat/main'
include { BCFTOOLS_STATS    } from '../../modules/nf-core/bcftools/stats/main'
include { MULTIQC           } from '../../modules/nf-core/multiqc/main'
include { paramBoolean      } from '../../lib/utils'

workflow QUALITY_CONTROL {

    take:
    ch_bam
    ch_fastp_json
    ch_merged_vcf
    targets_bed

    main:
    // files collected for MultiQC, coverage and flagstat outputs are also passed on to the QC notebooks
    ch_multiqc_files = Channel.empty()
    ch_per_base_bed  = Channel.empty()
    ch_regions_bed   = Channel.empty()

    // coverage over the target regions in each sample
    if ( paramBoolean(params.qc_coverage) ) {
        MOSDEPTH(
            ch_bam.map { meta, bam, bai -> tuple(meta, bam, bai, file(targets_bed)) },
            [ [ id:'no_fasta' ], [] ],
            []
        )
        ch_multiqc_files = ch_multiqc_files
            .mix( MOSDEPTH.out.global_txt.map  { meta, f -> f } )
            .mix( MOSDEPTH.out.summary_txt.map { meta, f -> f } )
        ch_per_base_bed = MOSDEPTH.out.per_base_bed
        ch_regions_bed  = MOSDEPTH.out.regions_bed
    }

    ch_flagstat = Channel.empty()
    // alignment stats for each sample and variant stats for the final merged VCF
    if ( paramBoolean(params.qc_stats) ) {
        SAMTOOLS_FLAGSTAT( ch_bam )
        ch_multiqc_files = ch_multiqc_files.mix( SAMTOOLS_FLAGSTAT.out.flagstat.map { meta, f -> f } )
        ch_flagstat = SAMTOOLS_FLAGSTAT.out.flagstat

        BCFTOOLS_STATS(
            ch_merged_vcf,
            [ [ id:'no_regions' ], [] ],
            [ [ id:'no_targets' ], [] ],
            [ [ id:'no_samples' ], [] ],
            [ [ id:'no_exons'   ], [] ],
            [ [ id:'no_fasta'   ], [] ]
        )
        ch_multiqc_files = ch_multiqc_files.mix( BCFTOOLS_STATS.out.stats.map { meta, f -> f } )
    }

    // include the fastp trimming reports in MultiQC
    if ( paramBoolean(params.qc_fastp) ) {
        ch_multiqc_files = ch_multiqc_files.mix( ch_fastp_json )
    }

    ch_multiqc_report = Channel.empty()
    // combine all reports so far into one MultiQC report
    if ( paramBoolean(params.qc_multiqc) ) {
        MULTIQC(
            ch_multiqc_files.collect().map { files ->
                tuple(
                    [ id: params.dataset ],
                    files,
                    file("${projectDir}/assets/multiqc_config.yaml"),
                    [], [], []
                )
            }
        )
        ch_multiqc_report = MULTIQC.out.report
    }

    emit:
    multiqc_report = ch_multiqc_report
    per_base_bed   = ch_per_base_bed
    regions_bed    = ch_regions_bed
    flagstat       = ch_flagstat
}
