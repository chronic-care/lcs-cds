library LungCancerScreeningCDS version '0.1.0'

using FHIR version '4.0.1'

include FHIRHelpers version '4.0.1'
include FHIRCommon version '4.0.1' called FC

include LungCancerConcepts called Cx
include LungCancerElements called LCE

context Patient

define ScreeningSummary: {
  notifyPatient: "Notify Patient",
  recommendScreening: "Is Recommendation Applicable",
  name: 'Lung Cancer Screening',
  title: 'Should You Be Screened for Lung Cancer?',
  information: "Patient Information",
  decision: "Patient Decision",
  recommendation: "Patient Recommendation",
  questionnaire: 'mpc-lung-cancer'
}

// Notify patients starting at 40 (for pilot testing, may not keep in production).
define "Notify Patient":
  /* LCE."Age 50 through 80" */
  AgeInYears() >= 40 and AgeInYears() <= 80
    and (LCE."Is Current Smoker" or LCE."Is Former Smoker")
    and not LCE."Has Lung Cancer Diagnosis"

define "Is Recommendation Applicable":
  LCE."Age 50 through 80"
    and (LCE."Is Current Smoker" or LCE."Is former smoker who quit within past 15 years")
    and LCE."Has 20 pack-year smoking history"
    and not LCE."Has Lung Cancer Diagnosis"
    and not LCE."Has Chest CT Performed Within 1 Year"

define "Smoking Status Summary":
  if LCE."Is Current Smoker"
    then 'You are a current smoker.'
  else if LCE."Is former smoker who quit within past 15 years"
    then 'You are a former smoker who quit within the past 15 years.'
  else if LCE."Is former smoker who quit more than 15 years ago"
    then 'You are a former smoker who quit more than 15 years ago.'
  else if LCE."Is Former Smoker"
    then 'You are a former smoker with an unknown quit date.'
  else if LCE."Is Never Smoker"
    then 'You have never smoked.'
  else
    'Unknown smoking history.'

/* define "Smoking History":
  if LCS."Pack-years" is not null
    then 'You have ' + ToString(LCS."Pack-years".value) + ' pack-years'
      + ' from ' + ToString(start of LCS."Smoking Period")
      + ' to ' + ToString(end of LCS."Smoking Period") + '.'
    else null */

define "Smoking History Summary":
  if LCE."Pack-years" is not null
    then 'You smoked ' + ToString(LCE."Packs Per Day") + ' packs/day'
      + ' for ' + ToString(LCE."Smoking History In Years") + ' years'
      + (if LCE."Is Former Smoker" then ' ending in ' + ToString(year from end of LCE."Smoking Period") else '')
      + ', which equals ' + ToString(LCE."Pack-years".value) + ' pack years.'
    else null

define "Patient Information":
  (List{
    "Smoking Status Summary",
    "Smoking History Summary",
    (if exists LCE."Chest CT Performed"
      then 'Your last chest CT was on ' + ToString(date from LCE."Most Recent Chest CT Performed".performed)
    else
      null)
  }) Text where Text is not null

define "Patient Decision":
  (List{
    'The guidelines recommend a low dose CT scan for people who currently smoke or are within 15 years of quitting smoking and have smoked for at least 20 pack years.'
  }) Text where Text is not null

define "Patient Recommendation":
  (List{
    (if "Is Recommendation Applicable"
      then 'Consider Getting Screened for Lung Cancer'
    else if LCE."Pack-years" is null
      then 'Please complete your smoking history.'
    else
      'You Don’t Need Lung Cancer Screening'),
    (if LCE."Is former smoker who quit more than 15 years ago"
      then 'It is good you quit smoking in ' + Coalesce(ToString(year from end of LCE."Smoking Period"), 'an unknown year') +'. Don’t start smoking again.'
    else
      null),
    (if LCE."Is Former Smoker" and LCE."Has less than 20 pack-year smoking history"
      then 'It is good you quit smoking in ' + Coalesce(ToString(year from end of LCE."Smoking Period"), 'an unknown year') + ' and that you only have ' + ToString(LCE."Pack-years".value) + ' pack years of smoking' + '. Don’t start smoking again.'
    else
      null),
    (if LCE."Is Current Smoker" and LCE."Has less than 20 pack-year smoking history"
      then 'It is good you only have ' + ToString(LCE."Pack-years".value) + ' pack years of smoking. This means you do not need lung cancer screening. But you should quit smoking before you damage your lungs and heart more.'
    else
      null),
    (if (LCE."Is Current Smoker" or LCE."Is former smoker who quit more than 15 years ago")
        and LCE."Has 20 pack-year smoking history"
      then 'Lung cancer screening saves lives. Lung cancer is the leading cause of cancer death in the US. Most cases of lung cancer are caused by smoking. Lung cancer has a generally poor prognosis but if found early can be cured.'
    else
      null),
    (if LCE."Is Current Smoker"
      // TODO include PatientSummary.cql for PCP name?
      /* then 'Talk with ' + PS."Patient PCP name" + ' about how to help you quit smoking.' */
      then 'Talk with your doctor about how to help you quit smoking.'
    else
      null)
  }) Text where Text is not null

/*
 * CDS Hooks support
*/

define "Is Eligible Detail":
  if "Is Recommendation Applicable"
    then 'Potential eligible patient: ' + First(Patient.name).text +
      ': Born ' + ToString(Patient.birthDate) +
      ' (Age: ' + ToString(AgeInYears()) +
      '), Gender: ' + Patient.gender
  else null

define "Is Eligible Summary":
  if "Is Recommendation Applicable"
    then 'Recommend shared decision making for lung cancer screening'
  else null

define "Is Eligible Indicator":
  if "Is Recommendation Applicable"
    then 'info'
  else null

/* Exclusion Criteria */
define "Exclusion Criteria":
  (
    not (LCE."Is Current Smoker" or LCE."Is former smoker who quit within past 15 years")
      or LCE."Has Lung Cancer Diagnosis"
  )

define "Exclusion Detail":
  if "Exclusion Criteria"
    then First(Patient.name).text +
      ': Born ' + ToString(Patient.birthDate) +
      ' (Age: ' + ToString(AgeInYears()) +
      '), Gender: ' + Patient.gender
    else null

define "Exclusion Summary":
  if "Exclusion Criteria"
    then 'Patient is not currently recommended for lung cancer screening'
  else null

define "Exclusion Indicator":
  if "Exclusion Criteria"
    then 'info'
  else null
