//common
include { getSoftwareVersions } from '../../common/process/utils/getSoftwareVersions'
include { starAlign } from '../../common/process/star/starAlign'
include { deeptoolsBamCoverage } from '../../common/process/deeptools/deeptoolsBamCoverage'
//include { bigwig } from '../../local/process/bigwig' // move to common one condition a mettre dans modules pour les args
// add preseq
//local
include { multiqc } from '../../local/process/multiqc'
include { bcAlign } from '../../local/process/bcAlign'
include { bcSubset } from '../../local/process/bcSubset'
include { bcTrim } from '../../local/process/bcTrim'
include { addBarcodeTag } from '../../local/process/addBarcodeTag'
  // remove duplicates
include { removePCRdup } from '../../local/process/removePCRdup' // je les passe dans common ?? Non
include { removeRTdup } from '../../local/process/removeRTdup'
include { removeWindowDup } from '../../local/process/removeWindowDup'
  // blackRegions
include { removeBlackRegions } from '../../local/process/removeBlackRegions'
  //--------
include { countSummary } from '../../local/process/countSummary' // empty channels pour éviter bug car pas de RT ni Window?
include { distribUMIs } from '../../local/process/distribUMIs'
include { bamToFrag } from '../../local/process/bamToFrag'
//subworkflow
include { countMatricesPerBin } from '../../local/subworkflow/countMatricesPerBin'
include { countMatricesPerTSS } from '../../local/subworkflow/countMatricesPerTSS' 

workflow scchip {

  take:
  reads
  bowtie2Index
  starIndex
  blackList
  gtf
  binsize

  main:

  // 1) Barcode alignement and extrcation part
    bcAlign(
      reads.combine(bowtie2Index)
    )
    chReadsMatchingIndex = bcAlign.out.results
    chIndexCount = bcAlign.out.counts
    chIndexBowtie2Logs = bcAlign.out.logs
    chVersions = chVersions.mix(bcAlign.out.versions)

    bcSubset(
      chReadsMatchingIndex.groupTuple(),
      chIndexCount.groupTuple()
    )
    chReadBcNames = bcSubset.out.results
    chBowtie2Logs = bcSubset.out.logs

    // 2) DNA alignment part
    bcTrim(
      reads
    )
    chTrimmedReads = bcTrim.out.reads
    chTrimmedReadsLogs = bcTrim.out.logs
    chVersions = chVersions.mix(bcTrim.out.versions)

    reads
      .join(chTrimmedReads)
      .map{ it -> [it[0], it[1][0], it[2]]}
      .set{chReads}

    starAlign(
      //inputs
      chReads,
      starIndex
      //parameters to add in conf/modules
    )
    //outputs
    chAlignedBam = starAlign.out.bam
    chAlignedLogs = starAlign.out.logs
    chVersions = chVersions.mix(starAlign.out.versions)

    // Add barcode info into dna info
    addBarcodeTag(
      chAlignedBam.join(chReadBcNames)
    )
    chTaggedBam=addBarcodeTag.out.bam

    removePCRdup(
      //inputs
      chTaggedBam
    )
    //outputs
    chRemovePCRdupBam = removePCRdup.out.bam
    chRemovePCRdupSam = removePCRdup.out.sam
    chRemovePCRdupSummary = removePCRdup.out.count
    chR1unmappedR2Summary = removePCRdup.out.countR1unmapped
    chRemovePcrBamSummary = removePCRdup.out.bamLogs

    removeRTdup(
      //inputs
      chTaggedBam,
      chRemovePCRdupBam,
      chRemovePCRdupSam
    )
    //outputs
    chRemovePcrRtBam = removeRTdup.out.bam
    chRemoveRtSummary = removeRTdup.out.logs
    
    removeWindowDup(
      //inputs
      chRemovePcrRtBam
    )
    //outputs
    chRemoveBlackReg = removeWindowDup.out.bam
    chRemoveDupLog = removeWindowDup.out.logs

    //Chout.map{meta, table -> [meta, table, []]}

    removeBlackRegions(
      //inputs
      chRemoveBlackReg,
      blackList.collect()
    )
    chVersions = chVersions.mix(removeBlackRegions.out.versions)
    chNoDupBam = removeBlackRegions.out.bam
    chNoDupBai = removeBlackRegions.out.bai
    chfinalBClist = removeBlackRegions.out.list

    countSummary(
      //inputs
      chRemovePCRdupSummary, // pcr
      chRemovePcrBamSummary, // pcr
      chR1unmappedR2Summary, // pcr
      chRemoveRtSummary, // faire des empty channels 
    )
    chDedupCountSummary = countSummary.out.logs

    // Subworkflow
    countMatricesPerBin(
      binsize,
      chNoDupBam,
      chNoDupBai,
      chfinalBClist
    )
    chBinMatrices=countMatricesPerBin.out.matrix
    chVersions = chVersions.mix(countMatricesPerBin.out.versions)

    // Subworkflow
    countMatricesPerTSS(
      chNoDupBam,
      chNoDupBai,
      chfinalBClist,
      gtf
    )
    chTssMatrices=countMatricesPerTSS.out.matrix
    chVersions = chVersions.mix(countMatricesPerTSS.out.versions)

    distribUMIs(
      //inputs
      chfinalBClist
    )
    chMqcDistribUMI = distribUMIs.out.mqc
    chPdfDist = distribUMIs.out.pdf
    chVersions = chVersions.mix(removeBlackRegions.out.versions)

    if (!params.skipBigWig){

      chEffGenomeSize = Channel.empty()

      deeptoolsBamCoverage(
        //inputs
        chNoDupBam.join(chNoDupBai),
        chBlackList.collect(),
        chEffGenomeSize
      )
      //outputs
      chBigWig = deeptoolsBamCoverage.out.bigwig
      chVersions = chVersions.mix(deeptoolsBamCoverage.out.versions)
    }

    bamToFrag(
      //inputs
      chNoDupBam.join(chNoDupBai)
    )
    //outputs
    chFragmentFiles = bamToFrag.out.gz

    // delete $meta for mqc input
    chfinalBClist
    .map{it -> it[1]}
    .set{chfinalBClistCollected}

    //*******************************************
    // MULTIQC
  
    if (!params.skipMultiQC){

      getSoftwareVersions(
        chVersions.unique().collectFile()
      )

      multiqc(
        customRunName,
        sPlanCh.collect(),
        metadataCh.ifEmpty([]),
        multiqcConfigCh.ifEmpty([]),
        getSoftwareVersions.out.versionsYaml.collect().ifEmpty([]),
        workflowSummaryCh.collectFile(name: "workflow_summary_mqc.yaml"),
        warnCh.collect().ifEmpty([]),
        chAlignedLogs.collect().ifEmpty([]), //star
        // bcAlign:
        chIndexBowtie2Logs.collect().ifEmpty([]),//index/${sample}_indexBBowtie2.log
        // bcSubset:
        chBowtie2Logs.collect().ifEmpty([]),//bowtie2/${sample}_bowtie2.log
        // countSummary:
        chDedupCountSummary.collect().ifEmpty([]),//removeRtPcr/${sample}_removePcrRtDup.log
        // countSummary:
        chfinalBClistCollected.collect().ifEmpty([]),//cellThresholds/${sample}_rmDup.txt
        // removeWindowDup:
        chRemoveDupLog.collect().ifEmpty([]),//removeWindowDup/${sample}_removeWindowDup.log (#Number of duplicates: nnnn)
        //distribUMIs
        chMqcDistribUMI.collect().ifEmpty([])//pour config graph
      )
      chMqcReport = multiqc.out.report.toList()
    }

  emit:
  bam = chNoDupBam
  bai = chNoDupBai
  bigwig = chBigWig
  matrixTSS = chTssMatrices
  matrixBin = chBinMatrices
  mqcreport = chMqcReport
}