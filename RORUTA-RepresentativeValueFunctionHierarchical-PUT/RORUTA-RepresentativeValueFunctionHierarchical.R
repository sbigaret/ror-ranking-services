##########################################
# Usage:
# R --slave --vanilla --args "[inDirectory]" "[outDirectory]" < RORUTA-RepresentativeValueFunctionHierarchical.R
# Example: 
# R --slave --vanilla --args "${PWD}/in" "${PWD}/out" < RORUTA-RepresentativeValueFunctionHierarchical.R
##########################################

inDirectory <- commandArgs()[5] 
outDirectory <- commandArgs()[6]  

##########################################
# Set the working directory as the "in" directory
##########################################
setwd(inDirectory)
options( java.parameters = "-Xmx2g" )
library(rorranking)

errFile<-NULL
errData<-NULL
errCalc<-NULL
execFlag<-FALSE

#INPUT FILES:
alternatives.filename = "alternatives.xml"
criteria.filename = "criteria.xml"
performances.filename = "performances.xml"
hierarchy.of.criteria.filename = "hierarchy-of-criteria.xml"
preferences.filename = "preferences.xml"
characteristic.points.filename = "characteristic-points.xml"
parameters.filename = "parameters.xml"
rank.related.preferences.filename = "rank-related-requirements.xml"
intensities.of.preferences.filename = "intensities-of-preferences.xml"
input.necessary.relations.filename = "necessary-relations-hierarchical.xml"
preference.direction = "criteria-preference-directions.xml"
#OUTPUT FILES:
result.file <- "representative-value-function-hierarchical.xml"
result.file.messages <- "messages.xml"

is_proper_data = TRUE
performances <- rorranking:::getPerformancesFromXmcdaFiles(alternatives.filename=alternatives.filename,
                                                                criteria.filename=criteria.filename,
                                                                performances.filename=performances.filename)

hierarchy.data = rorranking:::getHierarchyOfCriteriaFromXmcdaFile(hierarchy.of.criteria.filename)
nec.relations.by.nodes = rorranking:::getNecessaryRelationsFromXmcdaFile(input.necessary.relations.filename, performances$data)

if (performances$status != "OK") {
  errFile <- paste(errFile, performances$errFile)
  errData <- paste(errData, performances$errData)
  is_proper_data = FALSE
} 

if (hierarchy.data$status != "OK") {
  errFile <- paste(errFile, hierarchy.data$errFile)
  errData <- paste(errData, hierarchy.data$errData)
  is_proper_data = FALSE
} 

if (nec.relations.by.nodes$status != "OK") {
  errFile <- paste(errFile, nec.relations.by.nodes$errFile)
  errData <- paste(errData, nec.relations.by.nodes$errData)
  is_proper_data = FALSE
} 

#optional
preferences = list("strong" = NULL, "weak" = NULL, "indif" = NULL)
intensities.of.preferences =  list("strong" = NULL, "weak" = NULL, "indif" = NULL)
rank.related.preferences = NULL
nums.of.characteristic.points = NULL
criteria.preference.directions = NULL
strict = FALSE
compromise = FALSE
if (is_proper_data) { #optional paramenters
  intensities.of.preferences.data <- rorranking:::getIntensitiesOfPreferencesFromXmcdaFile(
    filename=intensities.of.preferences.filename ,performances=performances$data)
  if (intensities.of.preferences.data$status == "OK") {
    intensities.of.preferences =  intensities.of.preferences.data$data
  } else {
    errData <- paste(errData,  intensities.of.preferences.data$errData)
  }
  
  preferences.data <- rorranking:::getPreferencesFromXmcdaFile(filename=preferences.filename, performances=performances$data)
  if (preferences.data$status == "OK") {
    preferences = preferences.data$data
  } else {
    errData <- paste(errData, preferences.data$errData)
  }
  
  rank.related.preferences.data = rorranking:::getRankRelatedPreferencesFromXmcdaFile(rank.related.preferences.filename, performances$data)
  if (rank.related.preferences.data$status == "OK") {
    rank.related.preferences = rank.related.preferences.data$data
  } else {
    errData <- paste(errData,  rank.related.preferences.data$errData)
  }
  
  characteristic.points.data <- rorranking:::getCharacteristicPointsFromXmcdaFile(filename=characteristic.points.filename,
                                                                                  performances=performances$data)
  
  if (characteristic.points.data$status == "OK") {
    nums.of.characteristic.points <- characteristic.points.data$data  
  } else {
    errData <- paste(errData,  characteristic.points.data$errData)
  }

  criteria.data <- rorranking:::getCriteriaPreferenceDirectionFromXmcdaFile(filename=preference.direction,
                                                                                  performances=performances$data)
  
  if (criteria.data$status == "OK") {
    criteria.preference.directions <- criteria.data$data 
  } else {
    errData <- paste(errData,  criteria.data$errData)
  }

  params.data <- rorranking:::getParametersDataFromXmcdaFile(filename=parameters.filename,
                                                             keys=c("strict", "compromise"), defaults=list("strict" = TRUE, "compromise"= FALSE))
  
  if (params.data$status == "OK") {
    strict <- params.data$data[['strict']]
    compromise <- params.data$data[['compromise']]
  } else {
    errData <- paste(errData,  params.data$errData)
  }
  
}
results <-NULL

if (is.null(errFile) && is_proper_data){
  tmpErr<- try (
    {
      results <- findRepresentativeValueFunctionHierarchical(
        perf = performances$data, nec.relations=nec.relations.by.nodes$data,
        strong.prefs = preferences$strong, weak.prefs=preferences$weak, indif.prefs=preferences$indif,
        strong.intensities.of.prefs = intensities.of.preferences$strong,
        weak.intensities.of.prefs = intensities.of.preferences$weak,
        indif.intensities.of.prefs = intensities.of.preferences$indif,
        rank.related.requirements=rank.related.preferences,
        strict.vf=strict, nums.of.characteristic.points=nums.of.characteristic.points, 
        criteria=criteria.preference.directions, is.compromise=compromise, hierarchy.data=hierarchy.data$data) 
    }, silent=TRUE
  )  

  if (inherits(tmpErr, 'try-error')){
    errCalc<<-tmpErr
  } else {
    execFlag<-TRUE
  }
}

setwd(outDirectory)
if (execFlag) {
  
  outTree = newXMLDoc()
  newXMLNode("xmcda:XMCDA",
             attrs=c("xsi:schemaLocation" = "http://www.decision-deck.org/2012/XMCDA-2.2.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.2.0.xsd"),
             suppressNamespaceWarning=TRUE,
             namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2012/XMCDA-2.2.0"),
             parent=outTree)
  
  for (nodeid in names(results)) {
    rorranking:::putRepresentativeValueFunctions(tree=outTree, functions=results[[nodeid]], criteria.names=dimnames(performances$data)[[2]], attributes=c("id"=nodeid))
  }
  saveXML(outTree, file=result.file)

  outTreeMessage = newXMLDoc()
  newXMLNode("xmcda:XMCDA", 
      attrs=c("xsi:schemaLocation" = "http://www.decision-deck.org/2009/XMCDA-2.0.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.0.0.xsd"),
      suppressNamespaceWarning=TRUE, 
      namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2009/XMCDA-2.0.0"), 
      parent=outTreeMessage)

  status<-putLogMessage(outTreeMessage, "OK", name = "executionStatus")
  status<-saveXML(outTreeMessage, file=result.file.messages)
}

if (!is.null(errCalc)){
  outTreeMessage = newXMLDoc()
  newXMLNode("xmcda:XMCDA", 
             attrs=c("xsi:schemaLocation" = "http://www.decision-deck.org/2012/XMCDA-2.2.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.2.0.xsd"),
             suppressNamespaceWarning=TRUE, 
             namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2012/XMCDA-2.2.0"), 
             parent=outTreeMessage)
  status<-putErrorMessage(outTreeMessage, errCalc, name="Error")
  status<-saveXML(outTreeMessage, file=result.file.messages)
  
}

if ((!is.null(errData)) && (length(errData) > 0)){
  outTreeMessage = newXMLDoc()  
  newXMLNode("xmcda:XMCDA", 
             attrs=c("xsi:schemaLocation" = "http://www.decision-deck.org/2012/XMCDA-2.2.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.2.0.xsd"),
             suppressNamespaceWarning=TRUE, 
             namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2012/XMCDA-2.2.0"), 
             parent=outTreeMessage)
  status<-putErrorMessage(outTreeMessage, errData, name="Error")
  status<-saveXML(outTreeMessage, file=result.file.messages)
}

if (!is.null(errFile)) {
  outTreeMessage = newXMLDoc()
  newXMLNode("xmcda:XMCDA", 
             attrs=c("xsi:schemaLocation" = "http://www.decision-deck.org/2012/XMCDA-2.2.0 http://www.decision-deck.org/xmcda/_downloads/XMCDA-2.2.0.xsd"),
             suppressNamespaceWarning=TRUE, 
             namespace = c("xsi" = "http://www.w3.org/2001/XMLSchema-instance", "xmcda" = "http://www.decision-deck.org/2012/XMCDA-2.2.0"), 
             parent=outTreeMessage)
  status<-putErrorMessage(outTreeMessage, errFile, name="Error") 
  status<-saveXML(outTreeMessage, file=result.file.messages)
}
