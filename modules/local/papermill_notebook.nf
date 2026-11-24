// Runs one notebook with papermill. This single process is reused under different names for every notebook
// Each call of this process supplies its own input files, parameters and the layout the notebook expects

process PAPERMILL_NOTEBOOK {
    tag "$notebook_name"
    label 'process_low'

    input:
    // inputs: the notebook, its data files, where each file should appear (stage_paths) and papermill parameters
    // the notebook is staged as source.ipynb so the output never overwrites it, data files go to numbered folders so identically-names files don't clash
    tuple val(notebook_name), path(notebook, stageAs: 'source.ipynb'), path(data_files, stageAs: 'inputs/input_*/*'), val(stage_paths), val(param_map)
    path lib_dir, stageAs: 'workflow/lib'

    output:
    tuple val(notebook_name), path("${notebook_name}.ipynb"), emit: notebook
    // outputs: the executed notebook, plus any tables/plots it wrote. matched at any folder depth
    path "{*.tsv,**/*.tsv}",   optional: true, emit: extra_tsv
    path "{*.xlsx,**/*.xlsx}", optional: true, emit: extra_xlsx
    path "{*.png,**/*.png}",   optional: true, emit: extra_png
    path "results/config/metadata.qcpass.tsv", optional: true, emit: qcpass

    script:
    // link the staged files into the results/layout the notebook needs, then run it
    def link_cmds = stage_paths.collect { dest, src ->
        "mkdir -p \$(dirname '${dest}') && ln -s \"\$PWD/inputs/${src}\" '${dest}'"
    }.join('\n    ')
    // papermill only turns True/False into booleans; a Groovy false would arrive as the string "false", which Python treats as true
    def param_args = param_map.collect { k, v -> "-p ${k} '${v instanceof Boolean ? (v ? 'True' : 'False') : v}'" }.join(' ')
    // Create folders for notebooks to write new files into a folder that doesn't exist yet
    def out_dirs = [
        'genetic-diversity': [ 'results/genetic-diversity' ],
        'species-id':        [ 'results/ag-vampir/aims' ],
        'kdr-analysis':      [ 'results/ag-vampir/kdr-origins' ],
    ]
    def extra_mkdirs = (out_dirs[notebook_name] ?: []).collect { "mkdir -p ${it}" }.join('\n    ')
    """
    mkdir -p results
    ${extra_mkdirs}
    ${link_cmds}
    papermill ${notebook} ${notebook_name}.ipynb -k ampseq_python ${param_args}
    """

    // makes up fake outputs so -stub runs can check the workflow channel
    stub:
    """
    touch ${notebook_name}.ipynb
    if [ "${notebook_name}" = "sample-quality-control" ]; then
        touch metadata.qcpass.tsv
    fi
    if [ "${notebook_name}" = "snp-dataframe" ]; then
        mkdir -p results/vcfs/targets results/vcfs/amplicons
        touch results/vcfs/targets/${param_map.dataset}-snps.xlsx results/vcfs/amplicons/${param_map.dataset}-snps.xlsx
    fi
    if [ "${notebook_name}" = "species-id" ]; then
        mkdir -p results/config
        touch results/config/metadata.qcpass.tsv
    fi
    """
}
