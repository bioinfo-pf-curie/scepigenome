/*
 * STAR reads alignment
 */

process starAlign {
  tag "$meta.id"
  label 'star'
  label 'highCpu'
  label 'extraMem'

  input:
  tuple val(meta), path(reads)
  path index

  output:
  tuple val(meta), path('*Aligned.sortedByCoord.out.bam'), emit: bam
  path ("*out"), emit: logs
  path ("versions.txt"), emit: versions
  tuple val(meta), path("*ReadsPerGene.out.tab"), optional: true, emit: counts
  path("*out.tab"), optional: true, emit: countsLogs
  tuple val(meta), path("*Aligned.toTranscriptome.out.bam"), optional: true, emit: transcriptsBam

  script:
  def args = task.ext.args ?: ''
  def prefix = task.ext.prefix ?: "${meta.id}"
  """
  echo "STAR "\$(STAR --version 2>&1) > versions.txt
  STAR --genomeDir $index \\
       --readFilesIn $reads  \\
       --runThreadN ${task.cpus} \\
       --runMode alignReads \\
       --readFilesCommand zcat \\
       --runDirPerm All_RWX \\
       --outTmpDir "${params.tmpDir}/star_\$(date +%d%s%S%N)"\\
       --outFileNamePrefix $prefix  \\
       --outSAMattrRGline ID:$prefix \\
       ${args}
  """
}
