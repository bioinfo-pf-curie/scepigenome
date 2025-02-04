/*
 * Peak calling & annotation QC
 */

process peakQC{
  label 'R'
  label 'medCpu'
  label 'lowMem'

  input:
  path(peaks)
  path(annotations) 
  path(peakHeader)

  output:
  path("*.{txt,pdf}"), emit:  output
  path("*.tsv"), emit:  mqc
  path("versions.txt"), emit: versions

  script:
  """
  echo \$(R --version | awk 'NR==1{print \$1,\$3}') > versions.txt
  plot_homer_annotatepeaks.r \\
    -i ${annotations.join(',')} \\
    -s ${annotations.join(',').replaceAll("_annotated_peaks.txt","")} \\
    -o ./ \\
    -p annotatePeaks
  cat $peakHeader annotatePeaks.summary.txt > annotatedPeaks.summary_mqc.tsv
  """
}

