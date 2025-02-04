process intersectBed {
  tag "${meta.id}"
  label 'bedtools'
  label 'minCpu'
  label 'lowMem'

  input:
  tuple val(meta), path(bam)
  path (bed)

  output:
  tuple val(meta), path("*.bam"), emit: bam
  path("versions.txt"), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ''
  """
  echo \$(bedtools --version 2>&1) &> versions.txt
  intersectBed -abam ${bam} -b ${bed} ${args} > ${prefix}.bam
  """
}
