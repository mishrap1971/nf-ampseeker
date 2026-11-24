// Population genetics notebooks (population structure, sample map, allele frequencies, genetic diversity), each switched on by an analysis_* parameter
// All notebooks only analyse samples in the metadata that pass QC, the colour-coding is passed by main.nf

include { PAPERMILL_NOTEBOOK as PAPERMILL_POPULATION_STRUCTURE } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_SAMPLE_MAP           } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_ALLELE_FREQUENCIES   } from '../../modules/local/papermill_notebook'
include { PAPERMILL_NOTEBOOK as PAPERMILL_GENETIC_DIVERSITY    } from '../../modules/local/papermill_notebook'
include { paramBoolean } from '../../lib/utils'
include { cohortColumns } from '../../lib/utils'
include { inputName    } from '../../lib/utils'
include { inputRef     } from '../../lib/utils'

workflow ANALYSIS {

    take:
    ch_metadata_qcpass
    ch_colours
    ch_annot_targets
    ch_annot_amplicons

    main:
    ch_lib = file("${projectDir}/assets/notebooks/lib")
    def cohort_cols = cohortColumns(params.cohort_columns).join(',')
    def dataset = params.dataset
    def platform = params.platform

    // single-value inputs, reused by every notebook below (.first()).
    def metadata_qcpass = ch_metadata_qcpass.first()
    def colours          = ch_colours.first()
    def annot_targets    = ch_annot_targets.first()
    def annot_amplicons  = ch_annot_amplicons.first()
    ch_notebooks = Channel.empty()

    // Population structure (Principal Components Analysis)
    if ( paramBoolean(params.analysis_population_structure) ) {
        ch_in = metadata_qcpass.combine(colours).combine(annot_amplicons)
            .map { meta_f, colours_f, vcf_f ->
                def files = [ meta_f, colours_f, vcf_f ]
                def vcf_dest = "results/vcfs/amplicons/${dataset}.annot.vcf"
                tuple(
                    'population-structure',
                    file("${projectDir}/assets/notebooks/population-structure.ipynb"),
                    files,
                    [
                        'results/config/metadata.qcpass.tsv': inputName(files, meta_f),
                        'results/config/metadata_colours.json': inputName(files, colours_f),
                        (vcf_dest): inputName(files, vcf_f),
                    ],
                    [
                        wkdir: '.', platform: platform,
                        metadata_path: 'results/config/metadata.qcpass.tsv',
                        dataset: dataset, vcf_path: vcf_dest, cohort_cols: cohort_cols,
                    ]
                )
            }
        PAPERMILL_POPULATION_STRUCTURE( ch_in, ch_lib )
        ch_notebooks = ch_notebooks.mix( PAPERMILL_POPULATION_STRUCTURE.out.notebook.map { n, f -> f } )
    }

    // Sample map (needs latitude/longitude in the metadata)
    if ( paramBoolean(params.analysis_sample_map) ) {
        ch_in = metadata_qcpass.map { meta_f ->
            tuple(
                'sample-map',
                file("${projectDir}/assets/notebooks/sample-map.ipynb"),
                [ meta_f ], [:],
                [ metadata_path: inputRef([ meta_f ], meta_f), dataset: dataset ]
            )
        }
        PAPERMILL_SAMPLE_MAP( ch_in, ch_lib )
        ch_notebooks = ch_notebooks.mix( PAPERMILL_SAMPLE_MAP.out.notebook.map { n, f -> f } )
    }

    // Allele frequencies per cohort (reads both the target and the amplicon VCF)
    if ( paramBoolean(params.analysis_allele_frequencies) ) {
        def ch_bed = Channel.value( file(params.targets, checkIfExists: false) )
        ch_in = metadata_qcpass.combine(annot_targets).combine(annot_amplicons).combine(ch_bed)
            .map { meta_f, targets_f, amplicons_f, bed_f ->
                def files = [ meta_f, targets_f, amplicons_f, bed_f ]
                tuple(
                    'allele-frequencies',
                    file("${projectDir}/assets/notebooks/allele-frequencies.ipynb"),
                    files,
                    [ "results/vcfs/amplicons/${dataset}.annot.vcf": inputName(files, amplicons_f) ],
                    [
                        metadata_path: inputRef(files, meta_f), platform: platform, dataset: dataset,
                        wkdir: '.', bed_path: inputRef(files, bed_f), cohort_cols: cohort_cols,
                        vcf_path: inputRef(files, targets_f),
                    ]
                )
            }
        PAPERMILL_ALLELE_FREQUENCIES( ch_in, ch_lib )
        ch_notebooks = ch_notebooks.mix( PAPERMILL_ALLELE_FREQUENCIES.out.notebook.map { n, f -> f } )
    }

    // Genetic diversity
    if ( paramBoolean(params.analysis_genetic_diversity) ) {
        ch_in = metadata_qcpass.combine(annot_amplicons)
            .map { meta_f, vcf_f ->
                def files = [ meta_f, vcf_f ]
                tuple(
                    'genetic-diversity',
                    file("${projectDir}/assets/notebooks/genetic-diversity.ipynb"),
                    files, [:],
                    [
                        dataset: dataset, platform: platform, vcf_path: inputRef(files, vcf_f),
                        wkdir: '.', cohort_cols: cohort_cols, metadata_path: inputRef(files, meta_f),
                    ]
                )
            }
        PAPERMILL_GENETIC_DIVERSITY( ch_in, ch_lib )
        ch_notebooks = ch_notebooks.mix( PAPERMILL_GENETIC_DIVERSITY.out.notebook.map { n, f -> f } )
    }

    emit:
    notebooks = ch_notebooks
}
