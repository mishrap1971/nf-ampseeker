// extra steps when the --panel ag-vampir flag is supplied: identifying the species, then colours regenerated from the updated metadata, then kdr analysis
// Species ID adds a consensus taxon to the metadata for samples that passed QC. updated metadata and colours go on to the analysis notebooks

include { PAPERMILL_NOTEBOOK as PAPERMILL_SPECIES_ID   } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_KDR_ANALYSIS } from '../../modules/local/papermill_notebook'
include { METADATA_COLOURS                              } from '../../modules/local/metadata_colours'
include { inputName } from '../../lib/utils'
include { cohortColumns } from '../../lib/utils'
include { inputRef  } from '../../lib/utils'

workflow AG_VAMPIR {

    take:
    ch_metadata_qcpass
    ch_colours
    ch_annot_targets
    ch_annot_amplicons
    ch_snps_xlsx

    main:
    ch_lib = file("${projectDir}/assets/notebooks/lib")
    def dataset     = params.dataset
    def cohort_cols = cohortColumns(params.cohort_columns).join(',')

    // Reference data files used by the notebooks.
    def kdr_snps  = file("${projectDir}/assets/ag-vampir/Kdr_marker_SNPs.csv")
    def agv_res   = file("${projectDir}/assets/ag-vampir/*").findAll { it.name != kdr_snps.name }.sort { it.name }

    def qcpass    = ch_metadata_qcpass.first()
    // (named colours_in so it doesn't shadow the 'colours' output below)
    def colours_in = ch_colours.first()
    def targets   = ch_annot_targets.first()
    def amplicons = ch_annot_amplicons.first()
    def snps_xlsx = ch_snps_xlsx.first()
    def ch_bed    = Channel.value( file(params.targets, checkIfExists: false) )

    // Species ID
    PAPERMILL_SPECIES_ID(
        qcpass.combine(colours_in).combine(targets).combine(ch_bed)
            .map { meta_f, colours_f, vcf_f, bed_f ->
                def files = [ meta_f, colours_f, vcf_f, bed_f ] + agv_res
                def stage_paths = [ 'results/config/metadata_colours.json': inputName(files, colours_f) ]
                agv_res.each { f -> stage_paths["resources/ag-vampir/${f.name}"] = inputName(files, f) }
                tuple(
                    'species-id',
                    file("${projectDir}/assets/notebooks/species-id.ipynb"),
                    files, stage_paths,
                    [
                        platform: 'illumina', dataset: dataset, wkdir: '.', cohort_cols: cohort_cols,
                        metadata_path: inputRef(files, meta_f), vcf_path: inputRef(files, vcf_f),
                        bed_targets_path: inputRef(files, bed_f),
                    ]
                )
            },
        ch_lib
    )
    ch_qcpass_new = PAPERMILL_SPECIES_ID.out.qcpass

    // Regenerate the colours from the updated metadata, unless the user supplied a colours file.
    ch_colours_new = ch_colours
    if ( !params.metadata_colours ) {
        METADATA_COLOURS( ch_qcpass_new, cohortColumns(params.cohort_columns) )
        ch_colours_new = METADATA_COLOURS.out.colours
    }

    // kdr analysis (needs the SNP spreadsheet made by the snp-dataframe notebook).
    PAPERMILL_KDR_ANALYSIS(
        ch_qcpass_new.first().combine(ch_colours_new.first()).combine(targets).combine(amplicons).combine(ch_bed).combine(snps_xlsx)
            .map { meta_f, colours_f, targets_f, amplicons_f, bed_f, xlsx_f ->
                def files = [ meta_f, colours_f, targets_f, amplicons_f, bed_f, kdr_snps, xlsx_f ]
                tuple(
                    'kdr-analysis',
                    file("${projectDir}/assets/notebooks/kdr-analysis.ipynb"),
                    files,
                    [
                        'results/config/metadata_colours.json': inputName(files, colours_f),
                        "results/vcfs/amplicons/${dataset}.annot.vcf": inputName(files, amplicons_f),
                        'config/ag-vampir.bed': inputName(files, bed_f),
                        "results/vcfs/targets/${dataset}-snps.xlsx": inputName(files, xlsx_f),
                    ],
                    [
                        platform: 'illumina', dataset: dataset, wkdir: '.', cohort_cols: cohort_cols,
                        metadata_path: inputRef(files, meta_f), vcf_path: inputRef(files, targets_f),
                        kdr_marker_snps_path: inputRef(files, kdr_snps),
                    ]
                )
            },
        ch_lib
    )

    emit:
    metadata_qcpass = ch_qcpass_new
    colours         = ch_colours_new
    notebooks       = PAPERMILL_SPECIES_ID.out.notebook.map { n, f -> f }
                          .mix( PAPERMILL_KDR_ANALYSIS.out.notebook.map { n, f -> f } )
}
