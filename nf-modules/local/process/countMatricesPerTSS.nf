/*
 * Create TSS sparse matrices
 */

process countMatricesPerTSS {
  tag "$meta.id"
  label 'python'
  label 'medCpu'
  label 'lowMem'

  input:
  path(tssBed)
  tuple val(meta), path(bam), path(bai)
  tuple val(meta), path(bcList)

  output:
  tuple val(meta), path ("*.tar.gz"), emit: matrix
  path ("versions.txt"), emit: versions

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  # Counts per TSS (--Bed)
  nbbarcodes=\$(wc -l ${bcList} | awk '{print \$1}')
  sc2sparsecounts.py -i ${bam} -o ${prefix}_counts_TSS_${params.tssWindow} -B ${tssBed} -s \$nbbarcodes ${args}
  
  tar -zcvf ${prefix}_counts_TSS_${params.tssWindow}.tar.gz ${prefix}_counts_TSS_${params.tssWindow}
  rm -rf ${prefix}_counts_TSS_${params.tssWindow}

  python --version &> versions.txt
  """
}
