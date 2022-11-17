/*
 * Create TSS sparse matrices
 */

process createTssMatrices {
  tag "$meta.id"
  label 'python'
  label 'medCpu'
  label 'medMem'

  input:
  path(tssBed)
  tuple val(meta), path(nbBc)
  tuple val(meta), path(bam), path(bai) 

  output:
  tuple val(meta), path ("*.zip"), emit: matrix
  path ("versions.txt"), emit: versions

 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  # Counts per TSS (--Bed)
  nbbarcodes=\$(awk '{print \$1}' ${nbBc})
  sc2sparsecounts.py -i ${bam} -o ${prefix}_counts_TSS_${params.tssWindow} -B ${tssBed} -s \$barcodes ${args} 
  zip -r ${prefix}_counts_TSS_${params.tssWindow}.zip ${prefix}_counts_TSS_${params.tssWindow}
  rm -rf ${prefix}_counts_TSS_${params.tssWindow}

  python --version &> versions.txt
  """
}
