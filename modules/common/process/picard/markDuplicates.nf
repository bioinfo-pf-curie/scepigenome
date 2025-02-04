/*
 * Picard MarkDuplicates
 */

process markDuplicates {
  tag "${meta.id}"
  label 'picard'
  label 'minCpu'
  label 'medMem'

  input:
  tuple val(meta), path(bam), path(bai)

  output:
  tuple val(meta), path('*markDups.bam'), emit: bam
  tuple val(meta), path('*markDups.bai'), optional:true, emit: bai
  path('*markDups_metrics.txt'), emit: metrics
  path('versions.txt'), emit: versions

  when:
  task.ext.when == null || task.ext.when

  script:
  def prefix = task.ext.prefix ?: "${meta.id}"
  def args = task.ext.args ?: ""
  def javaArgs = task.ext.args2 ?: ''
  markdupMemOption = "\"-Xms" +  (task.memory.toGiga() / 2).trunc() + "g -Xmx" + (task.memory.toGiga() - 1) + "g\""
  """
  echo \$(picard CollectInsertSizeMetrics --version 2>&1 | grep Version | sed -e 's/.*Version:/picard /') > versions.txt
  picard ${markdupMemOption} ${javaArgs} MarkDuplicates \\
      -MAX_RECORDS_IN_RAM 50000 \\
      -INPUT ${bam} \\
      -OUTPUT ${prefix}_markDups.bam \\
      -METRICS_FILE ${prefix}_markDups_metrics.txt \\
      ${args}
  """
}
