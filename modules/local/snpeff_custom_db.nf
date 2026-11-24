// Builds a snpEff database from the reference FASTA and GFF (only used when --custom_snpeffdb true)
// -dataDir must be an absolute path, a relative one is resolved inside the container's snpEff folder

process SNPEFF_CUSTOM_DB {
    tag 'mysnpeffdb'
    label 'process_medium'

    input:
    path fasta
    path gff

    output:
    path 'mysnpeffdb', emit: db_dir

    script:
    """
    mkdir -p mysnpeffdb
    ln -s ../${fasta} mysnpeffdb/sequences.fa
    ln -s ../${gff} mysnpeffdb/genes.gff
    snpEff build -gff3 -v -dataDir "\$PWD" -configOption mysnpeffdb.genome=mysnpeffdb mysnpeffdb -noCheckCds -noCheckProtein
    """

    stub:
    """
    mkdir -p mysnpeffdb
    touch mysnpeffdb/sequences.fa mysnpeffdb/genes.gff mysnpeffdb/snpEffectPredictor.bin
    """
}
