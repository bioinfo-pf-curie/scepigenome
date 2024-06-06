/*
 * Align barcode sequences on the reference indexes
 */

process alignBarcodes {
  tag "$meta.id [$metaBc.id]"
  label 'bowtie2'
  label 'medCpu'
  label 'medMem'

  input:
  tuple val(meta), path(barcodes), val(metaBc), path(bwt2Idx)

  output:
  path ("*.log"), emit: log
  tuple val(meta), path ("*_read_barcodes.txt"), emit: readBarcodes
  tuple val(meta), path ("*_unique_barcodes.txt"), emit: uniqueBarcodes
  path ("versions.txt"), emit: versions
 
  script:
  def prefix = task.ext.prefix ?: "${meta.id}_${metaBc.id}"
  def args = task.ext.args ?: ''
  """
  localIndex=`find -L ./ -name "*.rev.1.bt2" | sed 's/.rev.1.bt2//'`
  refName=`basename \${localIndex}`
 
  bowtie2 \
    -x \${localIndex} \
    -f ${barcodes} \
    -p ${task.cpus} \
    ${args} 2> ${prefix}_bowtie2.log | awk '\$5>=30{print \$1"\tBC"substr(\$3,2)} \$5<30{print \$1"\tNone"}' > ${prefix}_read_barcodes.txt

  awk -F"\t" '\$2!=None{print \$2}' ${prefix}_read_barcodes.txt | sort -u > ${prefix}_unique_barcodes.txt

  ## version
  echo \$(bowtie2 --version | awk 'NR==1{print "bowtie2 "\$3}') > versions.txt
  """
}
